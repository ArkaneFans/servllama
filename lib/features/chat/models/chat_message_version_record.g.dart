// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_version_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageVersionRecordAdapter
    extends TypeAdapter<ChatMessageVersionRecord> {
  @override
  final int typeId = 4;

  @override
  ChatMessageVersionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageVersionRecord(
      id: fields[0] as String,
      messageId: fields[1] as String,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      modelName: fields[4] as String?,
      reasoningContent: fields[5] as String?,
      imageFilePaths: (fields[6] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageVersionRecord obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.messageId)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modelName)
      ..writeByte(5)
      ..write(obj.reasoningContent)
      ..writeByte(6)
      ..write(obj.imageFilePaths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageVersionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
