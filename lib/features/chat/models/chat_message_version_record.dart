import 'package:hive/hive.dart';
import 'package:servllama/features/chat/models/message_author.dart';

import 'package:servllama/features/chat/models/message_part.dart';

part 'chat_message_version_record.g.dart';

@HiveType(typeId: 4)
class ChatMessageVersionRecord {
  const ChatMessageVersionRecord({
    required this.id,
    required this.messageId,
    String content = '',
    required this.createdAt,
    this.modelName,
    this.runId,
    this.author,
    String? reasoningContent,
    List<MessagePart>? parts,
    this.imageFilePaths = const [],
  }) : _parts = parts,
       _bodyText = parts == null ? content : '',
       _bodyReasoning = parts == null ? reasoningContent : null;

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String messageId;

  @HiveField(2)
  String get content => messageText(parts);

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? modelName;

  final String? runId;
  final MessageAuthor? author;
  final List<MessagePart>? _parts;
  final String _bodyText;
  final String? _bodyReasoning;
  List<MessagePart> get parts =>
      _parts ??
      messagePartsFromText(content: _bodyText, reasoning: _bodyReasoning);

  @HiveField(5)
  String? get reasoningContent => messageReasoning(parts);

  @HiveField(6)
  final List<String> imageFilePaths;
}
