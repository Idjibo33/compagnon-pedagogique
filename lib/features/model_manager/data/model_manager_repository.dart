import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/core/utils/disk_space_checker.dart';
import 'package:fpdart/fpdart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/model_status.dart';

abstract class ModelManagerRepository {
  Future<Directory> getModelsDirectory();

  /// Vérifie l'espace disque libre disponible en octets.
  Future<int?> getAvailableDiskSpace();

  /// Vérifie si l'espace disque est suffisant (>= 1.5 Go par défaut).
  Future<bool> hasEnoughDiskSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
  });

  /// Vérifie l'état des modèles locaux en capturant les erreurs de stockage.
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus();

  /// Lance les téléchargements manquants.
  ///
  /// Les erreurs de files d'attente sont renvoyées dans le `Left`, tandis que
  /// les échecs de chaque tâche sont transmis via [onStatus] sous forme de
  /// `Left<DownloadFailure, ...>`.
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
      String fileName,
      Either<Failure, ModelDownloadState> status,
    ) onStatus,
  });

  Future<void> pauseDownload();

  /// Importe un `.gguf` local. `null` signifie que l'utilisateur a annulé.
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  });

  Future<bool> areAllModelsReady();
  Future<String> getModelPath(String fileName);
}

class ModelManagerRepositoryImpl implements ModelManagerRepository {
  final FileDownloader _downloader;
  final int? minLlmBytes;
  final int? minEmbBytes;
  final Directory? customModelsDirectory;
  final DiskSpaceChecker _diskSpaceChecker;

  ModelManagerRepositoryImpl({
    FileDownloader? downloader,
    this.minLlmBytes,
    this.minEmbBytes,
    this.customModelsDirectory,
    DiskSpaceChecker? diskSpaceChecker,
  })  : _downloader = downloader ?? FileDownloader(),
        _diskSpaceChecker = diskSpaceChecker ?? const SystemDiskSpaceChecker();

  @override
  Future<int?> getAvailableDiskSpace() async {
    final dir = await getModelsDirectory();
    return _diskSpaceChecker.getFreeDiskSpaceBytes(dir.path);
  }

  @override
  Future<bool> hasEnoughDiskSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
  }) async {
    final dir = await getModelsDirectory();
    return _diskSpaceChecker.hasEnoughSpace(
      requiredBytes: requiredBytes,
      path: dir.path,
    );
  }

  @override
  Future<Directory> getModelsDirectory() async {
    if (customModelsDirectory != null) {
      if (!await customModelsDirectory!.exists()) {
        await customModelsDirectory!.create(recursive: true);
      }
      return customModelsDirectory!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir =
        Directory(p.join(appDir.path, AppConstants.modelsDirectoryName));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  @override
  Future<String> getModelPath(String fileName) async {
    final dir = await getModelsDirectory();
    return p.join(dir.path, fileName);
  }

  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() {
    return TaskEither.tryCatch(() async {
      final modelsDir = await getModelsDirectory();

      final llmPath = p.join(modelsDir.path, AppConstants.llmModelFileName);
      final embPath =
          p.join(modelsDir.path, AppConstants.embeddingModelFileName);

      final llmFile = File(llmPath);
      final embFile = File(embPath);

      final llmExists = await llmFile.exists();
      final embExists = await embFile.exists();

      final llmBytes = llmExists ? await llmFile.length() : 0;
      final embBytes = embExists ? await embFile.length() : 0;

      // Seuil de tolérance (au moins 80% de la taille attendue, ou seuil custom pour tests)
      final requiredLlm =
          minLlmBytes ?? (AppConstants.llmModelExpectedSize * 0.8).toInt();
      final requiredEmb = minEmbBytes ??
          (AppConstants.embeddingModelExpectedSize * 0.8).toInt();

      final llmReady = llmExists && llmBytes >= requiredLlm;
      final embReady = embExists && embBytes >= requiredEmb;

      final llmStatus = ModelFileStatus(
        fileName: AppConstants.llmModelFileName,
        displayName: 'Modèle de Langage (Qwen 2.5 1.5B)',
        expectedSize: AppConstants.llmModelExpectedSize,
        currentBytes: llmBytes,
        progress:
            (llmBytes / AppConstants.llmModelExpectedSize).clamp(0.0, 1.0),
        state: llmReady
            ? ModelDownloadState.ready
            : ModelDownloadState.notDownloaded,
        localPath: llmExists ? llmPath : null,
      );

      final embStatus = ModelFileStatus(
        fileName: AppConstants.embeddingModelFileName,
        displayName: 'Modèle Vectoriel (Multilingual E5)',
        expectedSize: AppConstants.embeddingModelExpectedSize,
        currentBytes: embBytes,
        progress: (embBytes / AppConstants.embeddingModelExpectedSize)
            .clamp(0.0, 1.0),
        state: embReady
            ? ModelDownloadState.ready
            : ModelDownloadState.notDownloaded,
        localPath: embExists ? embPath : null,
      );

      return {
        AppConstants.llmModelFileName: llmStatus,
        AppConstants.embeddingModelFileName: embStatus,
      };
    },
        (error, stack) =>
            StorageFailure('Vérification des modèles impossible : $error'));
  }

  @override
  Future<bool> areAllModelsReady() async {
    final result = await checkModelsStatus().run();
    return result.fold(
      (_) => false,
      (statuses) => statuses.values.every((s) => s.isReady),
    );
  }

  @override
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
      String fileName,
      Either<Failure, ModelDownloadState> status,
    ) onStatus,
  }) {
    return checkModelsStatus().flatMap((statuses) {
      final tasks = <DownloadTask>[];

      // Téléchargement du LLM si non prêt
      if (!statuses[AppConstants.llmModelFileName]!.isReady) {
        tasks.add(
          DownloadTask(
            url: AppConstants.llmModelDownloadUrl,
            filename: AppConstants.llmModelFileName,
            baseDirectory: BaseDirectory.applicationDocuments,
            directory: AppConstants.modelsDirectoryName,
            updates: Updates.statusAndProgress,
            allowPause: true,
            requiresWiFi: false,
          ),
        );
      }

      // Téléchargement de l'Embedding si non prêt
      if (!statuses[AppConstants.embeddingModelFileName]!.isReady) {
        tasks.add(
          DownloadTask(
            url: AppConstants.embeddingModelDownloadUrl,
            filename: AppConstants.embeddingModelFileName,
            baseDirectory: BaseDirectory.applicationDocuments,
            directory: AppConstants.modelsDirectoryName,
            updates: Updates.statusAndProgress,
            allowPause: true,
            requiresWiFi: false,
          ),
        );
      }

      return TaskEither.tryCatch(() async {
        if (tasks.isEmpty) return unit;

        // Contrôle pré-vol de l'espace disque (au moins 1.5 Go)
        final hasSpace = await hasEnoughDiskSpace();
        if (!hasSpace) {
          final avail = await getAvailableDiskSpace();
          final availStr = avail != null
              ? ' (${SystemDiskSpaceChecker.formatBytes(avail)} disponible)'
              : '';
          throw StorageFailure(
            'Espace disque insuffisant : au moins 1.5 Go d\'espace libre est requis pour télécharger les modèles$availStr.',
          );
        }

        // Écoute de la progression et des statuts via background_downloader
        _downloader.registerCallbacks(
          taskStatusCallback: (TaskStatusUpdate update) {
            final filename = update.task.filename;
            onStatus(filename, _downloadStatusFrom(update, filename));
          },
          taskProgressCallback: (TaskProgressUpdate update) {
            final filename = update.task.filename;
            final progress = update.progress.clamp(0.0, 1.0);
            final expected = filename == AppConstants.llmModelFileName
                ? AppConstants.llmModelExpectedSize
                : AppConstants.embeddingModelExpectedSize;
            final currentBytes = (progress * expected).toInt();
            onProgress(filename, progress, currentBytes);
          },
        );

        for (final task in tasks) {
          await _downloader.enqueue(task);
        }
        return unit;
      }, (error, stack) {
        return toFailure(error, 'Impossible de lancer le téléchargement');
      });
    });
  }

  /// Convertit un statut natif en résultat typé : un échec HTTP/réseau devient
  /// un [DownloadFailure] que la couche presentation peut afficher.
  Either<Failure, ModelDownloadState> _downloadStatusFrom(
    TaskStatusUpdate update,
    String fileName,
  ) {
    switch (update.status) {
      case TaskStatus.enqueued:
      case TaskStatus.running:
        return const Right<Failure, ModelDownloadState>(
            ModelDownloadState.downloading);
      case TaskStatus.paused:
      case TaskStatus.canceled:
        return const Right<Failure, ModelDownloadState>(
            ModelDownloadState.paused);
      case TaskStatus.complete:
        return const Right<Failure, ModelDownloadState>(
            ModelDownloadState.ready);
      case TaskStatus.failed:
        return Left<Failure, ModelDownloadState>(
          DownloadFailure(
            update.exception?.description ?? 'Erreur réseau ou HTTP inconnue',
            fileName: fileName,
          ),
        );
      default:
        return const Right<Failure, ModelDownloadState>(
            ModelDownloadState.notDownloaded);
    }
  }

  @override
  Future<void> pauseDownload() async {
    await _downloader.pauseAll();
  }

  @override
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  }) {
    return TaskEither.tryCatch(() async {
      // Contrôle pré-vol de l'espace disque (au moins 1.5 Go)
      final hasSpace = await hasEnoughDiskSpace();
      if (!hasSpace) {
        final avail = await getAvailableDiskSpace();
        final availStr = avail != null
            ? ' (${SystemDiskSpaceChecker.formatBytes(avail)} disponible)'
            : '';
        throw StorageFailure(
          'Espace disque insuffisant : au moins 1.5 Go d\'espace libre est requis pour importer un modèle$availStr.',
        );
      }

      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf', 'bin'],
      );

      if (pickedFiles.isEmpty || pickedFiles.first.path == null) {
        return null;
      }

      final selectedFile = pickedFiles.first;
      final sourceFile = File(selectedFile.path!);
      final fileName = selectedFile.name.toLowerCase();

      // Validation de la taille minimale
      final sourceLength = await sourceFile.length();
      if (sourceLength < 4) {
        throw const ImportFailure(
          'Fichier corrompu ou invalide : le fichier sélectionné est vide ou fait moins de 4 octets.',
        );
      }

      // Validation stricte du Magic Number GGUF (0x47 0x47 0x55 0x46 -> "GGUF")
      final raf = await sourceFile.open(mode: FileMode.read);
      final List<int> magicBytes;
      try {
        magicBytes = await raf.read(4);
      } finally {
        await raf.close();
      }

      final isValidGguf = magicBytes.length == 4 &&
          magicBytes[0] == AppConstants.ggufMagicNumber[0] &&
          magicBytes[1] == AppConstants.ggufMagicNumber[1] &&
          magicBytes[2] == AppConstants.ggufMagicNumber[2] &&
          magicBytes[3] == AppConstants.ggufMagicNumber[3];

      if (!isValidGguf) {
        throw const ImportFailure(
          'Fichier invalide ou corrompu : l\'en-tête ne correspond pas au format GGUF '
          '(Magic Number attendu : 0x47 0x47 0x55 0x46 "GGUF").',
        );
      }

      // Identifier s'il s'agit du LLM ou de l'Embedding
      final String targetFileName;
      if (fileName.contains('e5') ||
          fileName.contains('embed') ||
          sourceLength < 500000000) {
        targetFileName = AppConstants.embeddingModelFileName;
      } else {
        targetFileName = AppConstants.llmModelFileName;
      }

      final modelsDir = await getModelsDirectory();
      final targetPath = p.join(modelsDir.path, targetFileName);
      final targetFile = File(targetPath);
      final tempTargetPath = '$targetPath.tmp';
      final tempTargetFile = File(tempTargetPath);

      // Copie par morceaux atomique pour éviter de saturer la RAM et empêcher
      // la persistance de fichiers partiels corrompus en cas d'interruption.
      final totalBytes = sourceLength;
      int copiedBytes = 0;

      final reader = sourceFile.openRead();
      final sink = tempTargetFile.openWrite();

      try {
        await for (final chunk in reader) {
          sink.add(chunk);
          copiedBytes += chunk.length;
          onCopyProgress((copiedBytes / totalBytes).clamp(0.0, 1.0));
        }
        await sink.flush();
        await sink.close();

        // Remplacement atomique du fichier de destination
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempTargetFile.rename(targetPath);
      } catch (e) {
        try {
          await sink.close();
        } catch (_) {}
        if (await tempTargetFile.exists()) {
          await tempTargetFile.delete();
        }
        rethrow;
      }

      return targetFileName;
    }, (error, stack) {
      if (error is Failure) return error;
      return ImportFailure('$error');
    });
  }
}
