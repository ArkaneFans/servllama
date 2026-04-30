// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_descriptor.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ModelDescriptorAdapter extends TypeAdapter<ModelDescriptor> {
  @override
  final int typeId = 0;

  @override
  ModelDescriptor read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ModelDescriptor(
      id: fields[0] as String,
      modelName: fields[1] as String,
      sizeBytes: fields[2] as int,
      storedDirectoryPath: fields[3] as String,
      storedFilePath: fields[4] as String,
      importedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ModelDescriptor obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.modelName)
      ..writeByte(2)
      ..write(obj.sizeBytes)
      ..writeByte(3)
      ..write(obj.storedDirectoryPath)
      ..writeByte(4)
      ..write(obj.storedFilePath)
      ..writeByte(5)
      ..write(obj.importedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelDescriptorAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
