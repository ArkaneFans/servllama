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
}
