// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_session_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatSessionRecordAdapter extends TypeAdapter<ChatSessionRecord> {
  @override
  final int typeId = 2;

  @override
  ChatSessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSessionRecord(
      id: fields[0] as String,
      title: fields[1] as String,
      messages: (fields[2] as List).cast<ChatMessageRecord>(),
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatSessionRecord obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.messages)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatSessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
