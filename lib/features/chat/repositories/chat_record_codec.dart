import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';

/// Canonical values for equality checks and continuation keys, not SQL payloads.
Map<String, Object?> encodeMessage(ChatMessageRecord m) => {
  'id': m.id,
  'role': m.role.name,
  'content': m.content,
  'createdAt': m.createdAt.millisecondsSinceEpoch,
  'sessionId': m.sessionId,
  'runId': m.runId,
  if (m.author != null) 'author': m.author!.toJson(),
  'modelName': m.modelName,
  if (m.generationMetrics != null)
    'generationMetrics': m.generationMetrics!.toJson(),
  'reasoningContent': m.reasoningContent,
  'imageFilePaths': m.imageFilePaths,
  'versionIds': m.versionIds,
  'currentVersionIndex': m.currentVersionIndex,
};
Map<String, Object?> encodeVersion(ChatMessageVersionRecord v) => {
  'id': v.id,
  'messageId': v.messageId,
  'runId': v.runId,
  if (v.author != null) 'author': v.author!.toJson(),
  'content': v.content,
  'createdAt': v.createdAt.millisecondsSinceEpoch,
  'modelName': v.modelName,
  if (v.generationMetrics != null)
    'generationMetrics': v.generationMetrics!.toJson(),
  'reasoningContent': v.reasoningContent,
  'imageFilePaths': v.imageFilePaths,
};
