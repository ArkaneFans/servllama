import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';

part 'chat_session_record.g.dart';

@HiveType(typeId: 2)
class ChatSessionRecord {
  const ChatSessionRecord({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<ChatMessageRecord> messages;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  ChatSessionRecord copyWith({
    String? id,
    String? title,
    List<ChatMessageRecord>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSessionRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
