// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadFileRecordAdapter extends TypeAdapter<DownloadFileRecord> {
  @override
  final int typeId = 5;

  @override
  DownloadFileRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadFileRecord(
      remotePath: fields[0] as String,
      fileName: fields[1] as String,
      totalBytes: fields[2] as int,
      receivedBytes: fields[3] as int,
      sha256: fields[4] as String?,
      completed: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadFileRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.remotePath)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.totalBytes)
      ..writeByte(3)
      ..write(obj.receivedBytes)
      ..writeByte(4)
      ..write(obj.sha256)
      ..writeByte(5)
      ..write(obj.completed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadFileRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DownloadTaskRecordAdapter extends TypeAdapter<DownloadTaskRecord> {
  @override
  final int typeId = 6;

  @override
  DownloadTaskRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTaskRecord(
      id: fields[0] as String,
      engineValue: fields[1] as String,
      sourceValue: fields[2] as String,
      repoId: fields[3] as String,
      revision: fields[4] as String,
      modelName: fields[5] as String,
      files: (fields[6] as List).cast<DownloadFileRecord>(),
      statusValue: fields[7] as String,
      createdAt: fields[8] as DateTime,
      stagingDirPath: fields[9] as String,
      quantLabel: fields[10] as String?,
      errorDetail: fields[11] as String?,
      pausedByNetwork: fields[12] == null ? false : fields[12] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTaskRecord obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.engineValue)
      ..writeByte(2)
      ..write(obj.sourceValue)
      ..writeByte(3)
      ..write(obj.repoId)
      ..writeByte(4)
      ..write(obj.revision)
      ..writeByte(5)
      ..write(obj.modelName)
      ..writeByte(6)
      ..write(obj.files)
      ..writeByte(7)
      ..write(obj.statusValue)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.stagingDirPath)
      ..writeByte(10)
      ..write(obj.quantLabel)
      ..writeByte(11)
      ..write(obj.errorDetail)
      ..writeByte(12)
      ..write(obj.pausedByNetwork);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
