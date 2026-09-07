import 'package:hive/hive.dart';

part 'model_descriptor.g.dart';

@HiveType(typeId: 0)
class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.modelName,
    required this.sizeBytes,
    required this.storedDirectoryPath,
    required this.storedFilePath,
    required this.importedAt,
    this.mmprojFilePath,
    this.sourceValue,
    this.repoId,
    this.revision,
    this.visionEnabled,
    this.mmprojFiles = const <String, String>{},
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String modelName;

  @HiveField(2)
  final int sizeBytes;

  @HiveField(3)
  final String storedDirectoryPath;

  @HiveField(4)
  final String storedFilePath;

  @HiveField(5)
  final DateTime importedAt;

  @HiveField(6)
  final String? mmprojFilePath;

  /// [ModelHubSource.storageValue] when this GGUF was downloaded from a hub.
  /// Local imports leave it null, so mmproj can only be added by hand.
  @HiveField(7)
  final String? sourceValue;

  @HiveField(8)
  final String? repoId;

  @HiveField(9)
  final String? revision;

  /// Null on older records: preserve their behavior by using an attached
  /// projector when present. Turning vision off never deletes its files.
  @HiveField(10)
  final bool? visionEnabled;

  /// Repository-relative projector paths mapped to their installed files.
  /// Older records and local imports may only have [mmprojFilePath].
  @HiveField(11, defaultValue: <String, String>{})
  final Map<String, String> mmprojFiles;

  bool get isVisionEnabled => visionEnabled ?? mmprojFilePath != null;

  String? get activeMmprojFilePath => isVisionEnabled ? mmprojFilePath : null;

  Map<String, String> get availableMmprojs {
    final files = <String, String>{...mmprojFiles};
    final selected = mmprojFilePath;
    if (selected != null && !files.containsValue(selected)) {
      files[selected.split(RegExp(r'[\\/]')).last] = selected;
    }
    return Map<String, String>.unmodifiable(files);
  }

  /// Downloaded models remember the hub repo; older records and local imports
  /// do not, and cannot fetch a replacement mmproj online.
  bool get hasHubSource {
    final source = sourceValue?.trim();
    final repo = repoId?.trim();
    return source != null &&
        source.isNotEmpty &&
        repo != null &&
        repo.isNotEmpty;
  }

  static const _unset = Object();

  ModelDescriptor copyWith({
    String? id,
    String? modelName,
    int? sizeBytes,
    String? storedDirectoryPath,
    String? storedFilePath,
    DateTime? importedAt,
    Object? mmprojFilePath = _unset,
    Object? sourceValue = _unset,
    Object? repoId = _unset,
    Object? revision = _unset,
    bool? visionEnabled,
    Map<String, String>? mmprojFiles,
  }) {
    final nextMmproj = identical(mmprojFilePath, _unset)
        ? this.mmprojFilePath
        : mmprojFilePath as String?;
    final nextSource = identical(sourceValue, _unset)
        ? this.sourceValue
        : sourceValue as String?;
    final nextRepoId = identical(repoId, _unset)
        ? this.repoId
        : repoId as String?;
    final nextRevision = identical(revision, _unset)
        ? this.revision
        : revision as String?;
    return ModelDescriptor(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      storedDirectoryPath: storedDirectoryPath ?? this.storedDirectoryPath,
      storedFilePath: storedFilePath ?? this.storedFilePath,
      importedAt: importedAt ?? this.importedAt,
      mmprojFilePath: nextMmproj,
      sourceValue: nextSource,
      repoId: nextRepoId,
      revision: nextRevision,
      visionEnabled: visionEnabled ?? this.visionEnabled,
      mmprojFiles: mmprojFiles ?? this.mmprojFiles,
    );
  }
}
