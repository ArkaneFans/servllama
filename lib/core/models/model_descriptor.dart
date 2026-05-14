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

  static const _unset = Object();

  ModelDescriptor copyWith({
    String? id,
    String? modelName,
    int? sizeBytes,
    String? storedDirectoryPath,
    String? storedFilePath,
    DateTime? importedAt,
    Object? mmprojFilePath = _unset,
  }) {
    final nextMmproj = identical(mmprojFilePath, _unset)
        ? this.mmprojFilePath
        : mmprojFilePath as String?;
    return ModelDescriptor(
      id: id ?? this.id,
      modelName: modelName ?? this.modelName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      storedDirectoryPath: storedDirectoryPath ?? this.storedDirectoryPath,
      storedFilePath: storedFilePath ?? this.storedFilePath,
      importedAt: importedAt ?? this.importedAt,
      mmprojFilePath: nextMmproj,
    );
  }
}
