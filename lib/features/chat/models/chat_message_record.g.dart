// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageRecordAdapter extends TypeAdapter<ChatMessageRecord> {
  @override
  final int typeId = 1;

  @override
  ChatMessageRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessageRecord(
      id: fields[0] as String,
      role: fields[1] as ChatRole,
      content: fields[2] as String,
      createdAt: fields[3] as DateTime,
      modelName: fields[4] as String?,
      reasoningContent: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.modelName)
      ..writeByte(5)
      ..write(obj.reasoningContent);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ChatRoleAdapter extends TypeAdapter<ChatRole> {
  @override
  final int typeId = 3;

  @override
  ChatRole read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ChatRole.user;
      case 1:
        return ChatRole.assistant;
      default:
        return ChatRole.user;
    }
  }

  @override
  void write(BinaryWriter writer, ChatRole obj) {
    switch (obj) {
      case ChatRole.user:
        writer.writeByte(0);
      case ChatRole.assistant:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRoleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
