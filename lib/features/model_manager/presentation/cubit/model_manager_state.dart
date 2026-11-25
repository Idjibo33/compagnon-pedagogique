import 'package:equatable/equatable.dart';

import '../../domain/model_status.dart';

class ModelManagerState extends Equatable {
  final Map<String, ModelFileStatus> modelsStatus;
  final bool isLoading;
  final bool isImporting;
  final double importProgress;
  final String? infoMessage;
  final String? errorMessage;
  final bool isDiskSpaceInsufficient;
  final int? availableDiskSpaceBytes;

  const ModelManagerState({
    this.modelsStatus = const {},
    this.isLoading = false,
    this.isImporting = false,
    this.importProgress = 0.0,
    this.infoMessage,
    this.errorMessage,
    this.isDiskSpaceInsufficient = false,
    this.availableDiskSpaceBytes,
  });

  bool get areAllModelsReady {
    if (modelsStatus.isEmpty) return false;
    return modelsStatus.values.every((s) => s.isReady);
  }

  double get overallProgress {
    if (modelsStatus.isEmpty) return 0.0;
    int totalBytes = 0;
    int totalExpected = 0;
    for (final status in modelsStatus.values) {
      totalBytes += status.currentBytes;
      totalExpected += status.expectedSize;
    }
    if (totalExpected == 0) return 0.0;
    return (totalBytes / totalExpected).clamp(0.0, 1.0);
  }

  int get totalCurrentBytes {
    return modelsStatus.values.fold(0, (sum, item) => sum + item.currentBytes);
  }

  int get totalExpectedBytes {
    return modelsStatus.values.fold(0, (sum, item) => sum + item.expectedSize);
  }

  bool get isDownloadingAny {
    return modelsStatus.values.any(
      (s) => s.state == ModelDownloadState.downloading,
    );
  }

  ModelManagerState copyWith({
    Map<String, ModelFileStatus>? modelsStatus,
    bool? isLoading,
    bool? isImporting,
    double? importProgress,
    String? infoMessage,
    String? errorMessage,
    bool? isDiskSpaceInsufficient,
    int? availableDiskSpaceBytes,
  }) {
    return ModelManagerState(
      modelsStatus: modelsStatus ?? this.modelsStatus,
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      importProgress: importProgress ?? this.importProgress,
      infoMessage: infoMessage,
      errorMessage: errorMessage,
      isDiskSpaceInsufficient:
          isDiskSpaceInsufficient ?? this.isDiskSpaceInsufficient,
      availableDiskSpaceBytes:
          availableDiskSpaceBytes ?? this.availableDiskSpaceBytes,
    );
  }

  @override
  List<Object?> get props => [
        modelsStatus,
        isLoading,
        isImporting,
        importProgress,
        infoMessage,
        errorMessage,
        isDiskSpaceInsufficient,
        availableDiskSpaceBytes,
      ];
}
