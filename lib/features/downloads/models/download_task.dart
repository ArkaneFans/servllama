import 'package:hive/hive.dart';

part 'download_task.g.dart';

@HiveType(typeId: 5)
class DownloadFileRecord {
  DownloadFileRecord({
    required this.remotePath,
    required this.fileName,
    required this.totalBytes,
    this.receivedBytes = 0,
    this.sha256,
    this.completed = false,
  });

  @HiveField(0)
  String remotePath;

  @HiveField(1)
  String fileName;

  @HiveField(2)
  int totalBytes;

  @HiveField(3)
  int receivedBytes;

  @HiveField(4)
  String? sha256;

  @HiveField(5)
  bool completed;

  Map<String, dynamic> toJson() => {
    'remotePath': remotePath,
    'fileName': fileName,
    'totalBytes': totalBytes,
    'receivedBytes': receivedBytes,
    'sha256': sha256,
    'completed': completed,
  };

  factory DownloadFileRecord.fromJson(Map<String, dynamic> json) =>
      DownloadFileRecord(
        remotePath: json['remotePath'] as String,
        fileName: json['fileName'] as String,
        totalBytes: json['totalBytes'] as int,
        receivedBytes: json['receivedBytes'] as int,
        sha256: json['sha256'] as String?,
        completed: json['completed'] as bool,
      );
}

@HiveType(typeId: 6)
class DownloadTaskRecord {
  DownloadTaskRecord({
    required this.id,
    required this.engineValue,
    required this.sourceValue,
    required this.repoId,
    required this.revision,
    required this.modelName,
    String? requestedModelName,
    required this.files,
    required this.statusValue,
    required this.createdAt,
    required this.stagingDirPath,
    this.quantLabel,
    this.errorDetail,
    this.pausedByNetwork = false,
    this.targetModelId,
  }) : requestedModelName = requestedModelName ?? modelName;

  @HiveField(0)
  String id;

  /// [InferenceEngine.storageValue] — decides whether the finished download
  /// is registered as a GGUF file or imported as an MNN model directory.
  @HiveField(1)
  String engineValue;

  /// [ModelHubSource.storageValue].
  @HiveField(2)
  String sourceValue;

  @HiveField(3)
  String repoId;

  @HiveField(4)
  String revision;

  @HiveField(5)
  String modelName;

  /// One entry per remote file. MNN models are whole directories, so a single
  /// task routinely covers many files.
  @HiveField(6)
  List<DownloadFileRecord> files;

  /// [DownloadStatus.name].
  @HiveField(7)
  String statusValue;

  @HiveField(8)
  DateTime createdAt;

  /// Private-storage directory the parts are written into before the model
  /// is committed to the library.
  @HiveField(9)
  String stagingDirPath;

  @HiveField(10)
  String? quantLabel;

  @HiveField(11)
  String? errorDetail;

  @HiveField(12, defaultValue: false)
  bool pausedByNetwork;

  /// The name derived from the hub before automatic conflict resolution.
  @HiveField(13)
  String requestedModelName;

  /// When set, this task adds a projector to an already-imported GGUF
  /// instead of creating a new library entry.
  @HiveField(14)
  String? targetModelId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'engineValue': engineValue,
    'sourceValue': sourceValue,
    'repoId': repoId,
    'revision': revision,
    'modelName': modelName,
    'requestedModelName': requestedModelName,
    'files': files.map((file) => file.toJson()).toList(),
    'statusValue': statusValue,
    'createdAt': createdAt.toIso8601String(),
    'stagingDirPath': stagingDirPath,
    'quantLabel': quantLabel,
    'errorDetail': errorDetail,
    'pausedByNetwork': pausedByNetwork,
    'targetModelId': targetModelId,
  };

  factory DownloadTaskRecord.fromJson(Map<String, dynamic> json) =>
      DownloadTaskRecord(
        id: json['id'] as String,
        engineValue: json['engineValue'] as String,
        sourceValue: json['sourceValue'] as String,
        repoId: json['repoId'] as String,
        revision: json['revision'] as String,
        modelName: json['modelName'] as String,
        requestedModelName: json['requestedModelName'] as String,
        files: (json['files'] as List)
            .map(
              (file) => DownloadFileRecord.fromJson(
                Map<String, dynamic>.from(file as Map),
              ),
            )
            .toList(),
        statusValue: json['statusValue'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        stagingDirPath: json['stagingDirPath'] as String,
        quantLabel: json['quantLabel'] as String?,
        errorDetail: json['errorDetail'] as String?,
        pausedByNetwork: json['pausedByNetwork'] as bool,
        targetModelId: json['targetModelId'] as String?,
      );
}
