import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';

enum DownloadStatus {
  queued,
  running,
  paused,
  failed,

  /// All bytes fetched; waiting to be committed into the model library.
  downloaded,
  completed;

  static DownloadStatus fromName(String? value) {
    for (final status in DownloadStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return DownloadStatus.queued;
  }

  /// Still belongs in the model library's in-progress section.
  bool get isActive =>
      this == DownloadStatus.queued ||
      this == DownloadStatus.running ||
      this == DownloadStatus.downloaded;

  /// A transfer that can be interrupted without racing the native import.
  bool get canPause =>
      this == DownloadStatus.queued || this == DownloadStatus.running;

  bool get isTransferActive =>
      this == DownloadStatus.queued || this == DownloadStatus.running;

  bool get isResumable =>
      this == DownloadStatus.paused || this == DownloadStatus.failed;

  /// A model-library commit is not cancellable once it has started.
  bool get canCancel => this != DownloadStatus.downloaded;
}

/// Presentation-facing view of a [DownloadTaskRecord] with the derived
/// numbers the UI needs, so pages never do arithmetic on the raw record.
class DownloadTaskView {
  DownloadTaskView(this.record, {this.bytesPerSecond = 0});

  final DownloadTaskRecord record;

  /// Instantaneous throughput, sampled by the download provider. Zero for
  /// anything that is not currently running.
  final double bytesPerSecond;

  String get id => record.id;
  String get modelName => record.modelName;
  String get requestedModelName => record.requestedModelName;
  bool get wasAutoRenamed => requestedModelName != modelName;
  String get repoId => record.repoId;
  String? get quantLabel => record.quantLabel;

  InferenceEngine get engine =>
      InferenceEngine.fromStorageValue(record.engineValue);

  ModelHubSource get source =>
      ModelHubSource.fromStorageValue(record.sourceValue);

  DownloadStatus get status => DownloadStatus.fromName(record.statusValue);

  int get totalBytes =>
      record.files.fold(0, (sum, file) => sum + file.totalBytes);

  int get receivedBytes =>
      record.files.fold(0, (sum, file) => sum + file.receivedBytes);

  /// Repository listings occasionally omit a file size. In that case a
  /// percentage would be misleading until the HTTP response supplies it.
  bool get hasKnownTotal =>
      record.files.isNotEmpty &&
      record.files.every((file) => file.totalBytes > 0);

  double get progress {
    final total = totalBytes;
    if (!hasKnownTotal || total <= 0) {
      return 0;
    }
    return (receivedBytes / total).clamp(0.0, 1.0);
  }

  int get fileCount => record.files.length;

  int get completedFileCount =>
      record.files.where((file) => file.completed).length;

  /// Null when there is no throughput sample yet, so the UI can hide the ETA
  /// instead of showing a nonsense number.
  Duration? get remaining {
    if (!hasKnownTotal || bytesPerSecond <= 0) {
      return null;
    }
    final left = totalBytes - receivedBytes;
    if (left <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: (left / bytesPerSecond).round());
  }

  String? get errorDetail => record.errorDetail;
}
