import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';

Map<String, Object?> encodeMessage(ChatMessageRecord m) => {
  'id': m.id,
  'role': m.role.name,
  'content': m.content,
  'createdAt': m.createdAt.millisecondsSinceEpoch,
  'sessionId': m.sessionId,
  'runId': m.runId,
  if (m.author != null) 'author': m.author!.toJson(),
  'modelName': m.modelName,
  'reasoningContent': m.reasoningContent,
  'imageFilePaths': m.imageFilePaths,
  'versionIds': m.versionIds,
  'currentVersionIndex': m.currentVersionIndex,
};
ChatMessageRecord decodeMessage(Map<String, dynamic> m) => ChatMessageRecord(
  id: m['id'] as String,
  role: ChatRole.values.byName(m['role'] as String),
  content: m['content'] as String,
  createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
  sessionId: m['sessionId'] as String?,
  runId: m['runId'] as String?,
  author: m['author'] == null
      ? null
      : MessageAuthor.fromJson(Map<String, dynamic>.from(m['author'])),
  modelName: m['modelName'] as String?,
  reasoningContent: m['reasoningContent'] as String?,
  imageFilePaths: List<String>.from(m['imageFilePaths'] as List? ?? []),
  versionIds: List<String>.from(m['versionIds'] as List? ?? []),
  currentVersionIndex: m['currentVersionIndex'] as int? ?? 0,
);
Map<String, Object?> encodeVersion(ChatMessageVersionRecord v) => {
  'id': v.id,
  'messageId': v.messageId,
  'runId': v.runId,
  if (v.author != null) 'author': v.author!.toJson(),
  'content': v.content,
  'createdAt': v.createdAt.millisecondsSinceEpoch,
  'modelName': v.modelName,
  'reasoningContent': v.reasoningContent,
  'imageFilePaths': v.imageFilePaths,
};
ChatMessageVersionRecord decodeVersion(Map<String, dynamic> m) =>
    ChatMessageVersionRecord(
      id: m['id'] as String,
      messageId: m['messageId'] as String,
      runId: m['runId'] as String?,
      author: m['author'] == null
          ? null
          : MessageAuthor.fromJson(Map<String, dynamic>.from(m['author'])),
      content: m['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      modelName: m['modelName'] as String?,
      reasoningContent: m['reasoningContent'] as String?,
      imageFilePaths: List<String>.from(m['imageFilePaths'] as List? ?? []),
    );
