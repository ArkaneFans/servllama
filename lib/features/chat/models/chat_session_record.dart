import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';

part 'chat_session_record.g.dart';

@HiveType(typeId: 2)
class ChatSessionRecord {
  ChatSessionRecord({
    required this.id,
    required this.title,
    List<String>? messageIds,
    List<ChatMessageRecord> messages = const <ChatMessageRecord>[],
    List<ChatMessageRecord>? legacyMessages,
    required this.createdAt,
    required this.updatedAt,
  }) : messageIds =
           messageIds ??
           messages.map((message) => message.id).toList(growable: false),
       legacyMessages = legacyMessages ?? messages;

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final List<String> messageIds;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  final List<ChatMessageRecord> legacyMessages;

  ChatSessionRecord copyWith({
    String? id,
    String? title,
    List<String>? messageIds,
    List<ChatMessageRecord>? legacyMessages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSessionRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      messageIds: messageIds ?? this.messageIds,
      legacyMessages: legacyMessages ?? this.legacyMessages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
