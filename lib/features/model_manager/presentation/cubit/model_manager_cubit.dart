import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../data/model_manager_repository.dart';
import '../../domain/model_status.dart';
import 'model_manager_state.dart';

class ModelManagerCubit extends Cubit<ModelManagerState> {
  final ModelManagerRepository _repository;

  ModelManagerCubit({required ModelManagerRepository repository})
      : _repository = repository,
        super(const ModelManagerState());

  /// Recharge l'état des fichiers depuis le disque.
  Future<void> checkStatus() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    final result = await _repository.checkModelsStatus().run();
    result.fold(
      (failure) => emit(
        state.copyWith(isLoading: false, errorMessage: failure.displayMessage),
      ),
      (statuses) => emit(
        state.copyWith(modelsStatus: statuses, isLoading: false),
      ),
    );
  }

  /// Lance les téléchargements et remonte immédiatement les échecs de tâches
  /// dans `errorMessage` pour que l'écran affiche un SnackBar.
  Future<void> startDownload() async {
    final result = await _repository.startDownload(
      onProgress: (fileName, progress, bytes) {
        final currentMap = Map<String, ModelFileStatus>.from(
          state.modelsStatus,
        );
        final existing = currentMap[fileName];
        if (existing != null) {
          currentMap[fileName] = existing.copyWith(
            progress: progress,
            currentBytes: bytes,
            state: ModelDownloadState.downloading,
            errorMessage: null,
          );
          emit(state.copyWith(modelsStatus: currentMap));
        }
      },
      onStatus: (fileName, statusResult) {
        final currentMap = Map<String, ModelFileStatus>.from(
          state.modelsStatus,
        );
        final existing = currentMap[fileName];
        if (existing == null) return;

        statusResult.fold(
          (failure) {
            // Une tâche en échec (404, réseau...) est à la fois visible dans
            // la ligne du modèle et signalée par un SnackBar.
            currentMap[fileName] = existing.copyWith(
              state: ModelDownloadState.error,
              errorMessage: failure.displayMessage,
            );
            emit(
              state.copyWith(
                modelsStatus: currentMap,
                errorMessage: failure.displayMessage,
              ),
            );
          },
          (downloadState) {
            currentMap[fileName] = existing.copyWith(
              state: downloadState,
              errorMessage: null,
            );
            emit(state.copyWith(modelsStatus: currentMap));
            if (downloadState == ModelDownloadState.ready) {
              checkStatus();
            }
          },
        );
      },
    ).run();

    result.fold(
      (failure) => emit(
        state.copyWith(errorMessage: failure.displayMessage),
      ),
      (_) {},
    );
  }

  Future<void> pauseDownload() async {
    try {
      await _repository.pauseDownload();
      final currentMap = Map<String, ModelFileStatus>.from(state.modelsStatus);
      for (final key in currentMap.keys) {
        if (currentMap[key]!.state == ModelDownloadState.downloading) {
          currentMap[key] = currentMap[key]!.copyWith(
            state: ModelDownloadState.paused,
          );
        }
      }
      emit(state.copyWith(modelsStatus: currentMap, errorMessage: null));
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage:
              toFailure(e, 'Erreur lors de la mise en pause').displayMessage,
        ),
      );
    }
  }

  Future<void> importLocalFile() async {
    emit(
      state.copyWith(
        isImporting: true,
        importProgress: 0.0,
        errorMessage: null,
        infoMessage: null,
      ),
    );

    final result = await _repository.importModelFromFilePicker(
      onCopyProgress: (progress) {
        emit(state.copyWith(importProgress: progress));
      },
    ).run();

    result.fold(
      (failure) => emit(
        state.copyWith(
          isImporting: false,
          errorMessage: failure.displayMessage,
        ),
      ),
      (importedFile) async {
        if (importedFile != null) {
          emit(
            state.copyWith(
              isImporting: false,
              infoMessage: 'Fichier $importedFile importé avec succès !',
            ),
          );
          await checkStatus();
        } else {
          emit(state.copyWith(isImporting: false));
        }
      },
    );
  }
}
