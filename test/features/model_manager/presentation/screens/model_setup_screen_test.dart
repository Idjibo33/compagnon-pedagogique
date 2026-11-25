import 'dart:io';

import 'package:compagnon_pedagogique/core/errors/failures.dart';
import 'package:compagnon_pedagogique/features/model_manager/data/model_manager_repository.dart';
import 'package:compagnon_pedagogique/features/model_manager/domain/model_status.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/cubit/model_manager_cubit.dart';
import 'package:compagnon_pedagogique/features/model_manager/presentation/screens/model_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';

class FailingRepository implements ModelManagerRepository {
  @override
  TaskEither<Failure, Map<String, ModelFileStatus>> checkModelsStatus() =>
      TaskEither.left(const StorageFailure('Disque inaccessible'));

  @override
  TaskEither<Failure, Unit> startDownload({
    required Function(String fileName, double progress, int bytes) onProgress,
    required Function(
      String fileName,
      Either<Failure, ModelDownloadState> status,
    ) onStatus,
  }) =>
      TaskEither.left(const DownloadFailure('HTTP 404'));

  @override
  TaskEither<Failure, String?> importModelFromFilePicker({
    required Function(double progress) onCopyProgress,
  }) =>
      TaskEither.left(const ImportFailure('Copie impossible'));

  @override
  Future<Directory> getModelsDirectory() async => Directory.systemTemp;

  @override
  Future<String> getModelPath(String fileName) async => '/tmp/$fileName';

  @override
  Future<bool> areAllModelsReady() async => false;

  @override
  Future<void> pauseDownload() async {}

  @override
  Future<int?> getAvailableDiskSpace() async => 2000000000;

  @override
  Future<bool> hasEnoughDiskSpace({int requiredBytes = 1610612736}) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('affiche un SnackBar lorsqu une erreur de modèle survient',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ModelManagerCubit>(
          create: (_) => ModelManagerCubit(repository: FailingRepository()),
          child: const ModelSetupScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Erreur de stockage local'), findsWidgets);
  });
}
