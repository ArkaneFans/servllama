import 'package:hive/hive.dart';

part 'chat_message_version_record.g.dart';

@HiveType(typeId: 4)
class ChatMessageVersionRecord {
  const ChatMessageVersionRecord({
    required this.id,
    required this.messageId,
    required this.content,
    required this.createdAt,
    this.modelName,
    this.reasoningContent,
    this.imageFilePaths = const [],
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String messageId;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? modelName;

  @HiveField(5)
  final String? reasoningContent;

  @HiveField(6)
  final List<String> imageFilePaths;
}
