import 'package:equatable/equatable.dart';

enum ModelDownloadState {
  notDownloaded,
  downloading,
  paused,
  verifying,
  ready,
  error,
}

class ModelFileStatus extends Equatable {
  final String fileName;
  final String displayName;
  final int expectedSize;
  final int currentBytes;
  final double progress; // 0.0 to 1.0
  final ModelDownloadState state;
  final String? errorMessage;
  final String? localPath;

  const ModelFileStatus({
    required this.fileName,
    required this.displayName,
    required this.expectedSize,
    this.currentBytes = 0,
    this.progress = 0.0,
    this.state = ModelDownloadState.notDownloaded,
    this.errorMessage,
    this.localPath,
  });

  bool get isReady => state == ModelDownloadState.ready;
  bool get isDownloading => state == ModelDownloadState.downloading;

  ModelFileStatus copyWith({
    int? currentBytes,
    double? progress,
    ModelDownloadState? state,
    String? errorMessage,
    String? localPath,
  }) {
    return ModelFileStatus(
      fileName: fileName,
      displayName: displayName,
      expectedSize: expectedSize,
      currentBytes: currentBytes ?? this.currentBytes,
      progress: progress ?? this.progress,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      localPath: localPath ?? this.localPath,
    );
  }

  @override
  List<Object?> get props => [
        fileName,
        displayName,
        expectedSize,
        currentBytes,
        progress,
        state,
        errorMessage,
        localPath,
      ];
}
