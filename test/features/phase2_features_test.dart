import 'dart:io';

import 'package:compagnon_pedagogique/core/constants/app_constants.dart';
import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/core/theme/app_theme.dart';
import 'package:compagnon_pedagogique/core/utils/disk_space_checker.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/screens/model_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final String appDocDir;

  MockPathProviderPlatform(this.appDocDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => appDocDir;
}

class FakeDiskSpaceChecker implements DiskSpaceChecker {
  int? freeBytes;
  bool shouldHaveEnough;

  FakeDiskSpaceChecker({
    this.freeBytes = 2000000000,
    this.shouldHaveEnough = true,
  });

  @override
  Future<int?> getFreeDiskSpaceBytes([String? path]) async => freeBytes;

  @override
  Future<bool> hasEnoughSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
    String? path,
  }) async {
    return shouldHaveEnough;
  }
}

class TestableModelRepo implements ModelManagerRepository {
  final DiskSpaceChecker checker;
  final Directory tempModelsDir;
  Map<String, ModelFileStatus>? modelsStatusOverride;

  TestableModelRepo({
    required this.checker,
    required this.tempModelsDir,
    this.modelsStatusOverride,
  });

  @override
  Future<Directory> getModelsDirectory() async => tempModelsDir;

  @override
  Future<int?> getAvailableDiskSpace() async =>
      checker.getFreeDiskSpaceBytes(tempModelsDir.path);

  @override
  Future<bool> hasEnoughDiskSpace({
    int requiredBytes = AppConstants.minFreeDiskSpaceBytes,
  }) async =>
      checker.hasEnoughSpace(
        requiredBytes: requiredBytes,
        path: tempModelsDir.path,
      );

  @override
  Future<bool> areAllModelsReady() async {
    if (modelsStatusOverride != null) {
      return modelsStatusOverride!.values.every((s) => s.isReady);
    }
    return false;
  }

  @override
  Future<String> getModelPath(String fileName) async =>
      p.join(tempModelsDir.path, fileName);

  @override
  Future<void> pauseDownload() async {}

  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() =>
      TaskEither.right(modelsStatusOverride ?? {});

  @override
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
            String fileName, Either<Failure, ModelDownloadState> status)
        onStatus,
  }) {
    return TaskEither.tryCatch(() async {
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
      return unit;
    }, (error, _) => error is Failure ? error : StorageFailure('$error'));
  }

  @override
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  }) {
    return TaskEither.tryCatch(() async {
      final hasSpace = await hasEnoughDiskSpace();
      if (!hasSpace) {
        throw const StorageFailure(
          'Espace disque insuffisant : au moins 1.5 Go d\'espace libre est requis pour importer un modèle.',
        );
      }
      return null;
    }, (error, _) => error is Failure ? error : ImportFailure('$error'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockPathProviderPlatform fakePlatform;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase2_test_');
    fakePlatform = MockPathProviderPlatform(tempDir.path);
    PathProviderPlatform.instance = fakePlatform;
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phase 2 - Contrôle Pré-vol Espace Disque', () {
    test('Formatage lisible des octets en Mo et Go', () {
      expect(SystemDiskSpaceChecker.formatBytes(0), equals('0 Mo'));
      expect(SystemDiskSpaceChecker.formatBytes(500 * 1024 * 1024),
          equals('500 Mo'));
      expect(SystemDiskSpaceChecker.formatBytes(1610612736), equals('1.50 Go'));
      expect(SystemDiskSpaceChecker.formatBytes(2 * 1024 * 1024 * 1024),
          equals('2.00 Go'));
    });

    test('startDownload bloque avec StorageFailure si espace < 1.5 Go',
        () async {
      final fakeChecker = FakeDiskSpaceChecker(
        freeBytes: 500 * 1024 * 1024,
        shouldHaveEnough: false,
      );
      final repo = TestableModelRepo(
        checker: fakeChecker,
        tempModelsDir: tempDir,
      );

      final result = await repo
          .startDownload(
            onProgress: (_, __, ___) {},
            onStatus: (_, __) {},
          )
          .run();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<StorageFailure>());
          expect(failure.displayMessage, contains('Espace disque insuffisant'));
          expect(failure.displayMessage, contains('1.5 Go'));
        },
        (_) => fail('Devrait échouer'),
      );
    });

    test('ModelManagerCubit émet isDiskSpaceInsufficient si espace faible',
        () async {
      final fakeChecker = FakeDiskSpaceChecker(
        freeBytes: 800 * 1024 * 1024,
        shouldHaveEnough: false,
      );
      final repo = TestableModelRepo(
        checker: fakeChecker,
        tempModelsDir: tempDir,
      );
      final cubit = ModelManagerCubit(repository: repo);

      final hasSpace = await cubit.checkDiskSpace();
      expect(hasSpace, isFalse);
      expect(cubit.state.isDiskSpaceInsufficient, isTrue);
      expect(cubit.state.errorMessage, contains('Espace disque insuffisant'));

      cubit.dismissDiskSpaceAlert();
      expect(cubit.state.isDiskSpaceInsufficient, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test(
        'ModelManagerCubit checkStatus ne bloque PAS avec alerte si les modèles sont déjà prêts',
        () async {
      final fakeChecker = FakeDiskSpaceChecker(
        freeBytes: 800 * 1024 * 1024,
        shouldHaveEnough: false, // < 1.5 Go
      );
      final repo = TestableModelRepo(
        checker: fakeChecker,
        tempModelsDir: tempDir,
      );
      // Simuler que les modèles sont déjà tous prêts sur le disque
      final readyModels = {
        AppConstants.llmModelFileName: const ModelFileStatus(
          fileName: AppConstants.llmModelFileName,
          displayName: 'LLM',
          expectedSize: 1000,
          currentBytes: 1000,
          state: ModelDownloadState.ready,
        ),
        AppConstants.embeddingModelFileName: const ModelFileStatus(
          fileName: AppConstants.embeddingModelFileName,
          displayName: 'Emb',
          expectedSize: 500,
          currentBytes: 500,
          state: ModelDownloadState.ready,
        ),
      };
      repo.modelsStatusOverride = readyModels;

      final cubit = ModelManagerCubit(repository: repo);
      await cubit.checkStatus();

      expect(cubit.state.areAllModelsReady, isTrue);
      // L'utilisateur ne doit PAS être bloqué ou alarmé si les modèles sont déjà sur son téléphone
      expect(cubit.state.isDiskSpaceInsufficient, isFalse);
      expect(cubit.state.errorMessage, isNull);
      await cubit.close();
    });

    test(
        'SystemDiskSpaceChecker remonte vers le dossier parent existant si le sous-dossier n existe pas',
        () async {
      const checker = SystemDiskSpaceChecker();
      final nonExistentPath = p.join(tempDir.path, 'nested', 'not_yet_created');
      final freeBytes = await checker.getFreeDiskSpaceBytes(nonExistentPath);

      // Sur Linux, doit renvoyer la valeur du système de fichiers de tempDir
      if (Platform.isLinux) {
        expect(freeBytes, isNotNull);
        expect(freeBytes!, greaterThan(0));
      }
    });

    testWidgets(
        'ModelSetupScreen affiche une alerte bloquante si espace < 1.5 Go',
        (tester) async {
      final fakeChecker = FakeDiskSpaceChecker(
        freeBytes: 900 * 1024 * 1024,
        shouldHaveEnough: false,
      );
      final repo = TestableModelRepo(
        checker: fakeChecker,
        tempModelsDir: tempDir,
      );
      final cubit = ModelManagerCubit(repository: repo);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider.value(
            value: cubit,
            child: const ModelSetupScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Espace Disque Insuffisant'), findsOneWidget);
      expect(find.text('Espace minimal requis :'), findsOneWidget);
      expect(find.text('1.50 Go'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);

      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();

      expect(find.text('Espace Disque Insuffisant'), findsNothing);
      await cubit.close();
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Phase 2 - Validation Stricte Magic Number GGUF', () {
    test('Validation du Magic Number 0x47 0x47 0x55 0x46 ("GGUF")', () async {
      // 1. Fichier GGUF valide
      final validGgufFile = File(p.join(tempDir.path, 'valid_model.gguf'));
      await validGgufFile.writeAsBytes([0x47, 0x47, 0x55, 0x46, 0x01, 0x02]);

      final raf = await validGgufFile.open(mode: FileMode.read);
      final header = await raf.read(4);
      await raf.close();

      final isValid = header.length == 4 &&
          header[0] == AppConstants.ggufMagicNumber[0] &&
          header[1] == AppConstants.ggufMagicNumber[1] &&
          header[2] == AppConstants.ggufMagicNumber[2] &&
          header[3] == AppConstants.ggufMagicNumber[3];

      expect(isValid, isTrue);

      // 2. Fichier corrompu ou invalide (ex: en-tête PDF %PDF = 0x25 0x50 0x44 0x46)
      final fakeGgufFile = File(p.join(tempDir.path, 'fake_model.gguf'));
      await fakeGgufFile.writeAsBytes([0x25, 0x50, 0x44, 0x46, 0x31, 0x2E]);

      final rafFake = await fakeGgufFile.open(mode: FileMode.read);
      final headerFake = await rafFake.read(4);
      await rafFake.close();

      final isFakeValid = headerFake.length == 4 &&
          headerFake[0] == AppConstants.ggufMagicNumber[0] &&
          headerFake[1] == AppConstants.ggufMagicNumber[1] &&
          headerFake[2] == AppConstants.ggufMagicNumber[2] &&
          headerFake[3] == AppConstants.ggufMagicNumber[3];

      expect(isFakeValid, isFalse);

      // 3. Fichier vide ou tronqué (< 4 octets)
      final truncatedFile = File(p.join(tempDir.path, 'truncated.gguf'));
      await truncatedFile.writeAsBytes([0x47, 0x47]);
      expect(await truncatedFile.length(), lessThan(4));
    });
  });
}
