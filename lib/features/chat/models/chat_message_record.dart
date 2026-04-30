import 'package:hive/hive.dart';

part 'chat_message_record.g.dart';

enum ChatRole { user, assistant }

@HiveType(typeId: 1)
class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.modelName,
    this.reasoningContent,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final ChatRole role;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? modelName;

  @HiveField(5)
  final String? reasoningContent;

  ChatMessageRecord copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    String? modelName,
    String? reasoningContent,
    bool clearModelName = false,
    bool clearReasoningContent = false,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      modelName: clearModelName ? null : modelName ?? this.modelName,
      reasoningContent: clearReasoningContent
          ? null
          : reasoningContent ?? this.reasoningContent,
    );
  }
}
