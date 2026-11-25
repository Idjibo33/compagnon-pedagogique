import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository de test qui permet de simuler aussi bien un échec global
/// (`Left`) qu'un échec de tâche transmis par le callback de statut.
class StubModelRepository implements ModelManagerRepository {
  TaskEither<Failure, Map<String, ModelFileStatus>> checkResult =
      TaskEither.right({});
  TaskEither<Failure, Unit> downloadResult = TaskEither.right(unit);
  TaskEither<Failure, String?> importResult = TaskEither.right(null);
  bool enoughDiskSpace = true;
  int? availableDiskSpace = 2000000000;

  @override
  Future<int?> getAvailableDiskSpace() async => availableDiskSpace;

  @override
  Future<bool> hasEnoughDiskSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
  }) async =>
      enoughDiskSpace;

  void Function(String, Either<Failure, ModelDownloadState>)? emitStatus;

  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() =>
      checkResult;

  @override
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
      String fileName,
      Either<Failure, ModelDownloadState> status,
    ) onStatus,
  }) {
    emitStatus = onStatus;
    return downloadResult;
  }

  @override
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  }) =>
      importResult;

  @override
  Future<Directory> getModelsDirectory() async => Directory.systemTemp;

  @override
  Future<String> getModelPath(String fileName) async => '/tmp/$fileName';

  @override
  Future<bool> areAllModelsReady() async => false;

  @override
  Future<void> pauseDownload() async {}
}

Map<String, ModelFileStatus> _twoPendingModels() => const {
      AppConstants.llmModelFileName: ModelFileStatus(
        fileName: AppConstants.llmModelFileName,
        displayName: 'LLM',
        expectedSize: AppConstants.llmModelExpectedSize,
      ),
      AppConstants.embeddingModelFileName: ModelFileStatus(
        fileName: AppConstants.embeddingModelFileName,
        displayName: 'Embedding',
        expectedSize: AppConstants.embeddingModelExpectedSize,
      ),
    };

void main() {
  group('ModelManagerCubit - gestion des erreurs', () {
    test('un échec de vérification est exposé via errorMessage', () async {
      final repository = StubModelRepository()
        ..checkResult = TaskEither.left(
          const StorageFailure('Disque inaccessible'),
        );
      final cubit = ModelManagerCubit(repository: repository);

      await cubit.checkStatus();

      expect(cubit.state.errorMessage, contains('Disque inaccessible'));
      expect(cubit.state.isLoading, isFalse);
    });

    test('un échec de téléchargement affiche et catalogues l erreur', () async {
      final repository = StubModelRepository()
        ..checkResult = TaskEither.right(_twoPendingModels());
      final cubit = ModelManagerCubit(repository: repository);

      await cubit.checkStatus();
      await cubit.startDownload();

      repository.emitStatus!(
        AppConstants.embeddingModelFileName,
        const Left<Failure, ModelDownloadState>(
          DownloadFailure(
            'HTTP 404',
            fileName: AppConstants.embeddingModelFileName,
          ),
        ),
      );

      expect(cubit.state.errorMessage, contains('HTTP 404'));
      expect(
        cubit.state.modelsStatus[AppConstants.embeddingModelFileName]!.state,
        ModelDownloadState.error,
      );
      expect(
        cubit.state.modelsStatus[AppConstants.embeddingModelFileName]!
            .errorMessage,
        contains('HTTP 404'),
      );
    });

    test('un échec lors de la mise en file remonte errorMessage', () async {
      final repository = StubModelRepository()
        ..checkResult = TaskEither.right(_twoPendingModels())
        ..downloadResult = TaskEither.left(
          const DownloadFailure('File indisponible'),
        );
      final cubit = ModelManagerCubit(repository: repository);

      await cubit.checkStatus();
      await cubit.startDownload();

      expect(cubit.state.errorMessage, contains('File indisponible'));
    });

    test('un échec d import remonte errorMessage et termine le chargement',
        () async {
      final repository = StubModelRepository()
        ..importResult =
            TaskEither.left(const ImportFailure('Copie impossible'));
      final cubit = ModelManagerCubit(repository: repository);

      await cubit.importLocalFile();

      expect(cubit.state.errorMessage, contains('Copie impossible'));
      expect(cubit.state.isImporting, isFalse);
    });
  });
}
