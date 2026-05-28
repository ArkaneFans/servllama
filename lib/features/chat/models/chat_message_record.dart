import 'package:hive/hive.dart';

part 'chat_message_record.g.dart';

@HiveType(typeId: 3)
enum ChatRole {
  @HiveField(0)
  user,

  @HiveField(1)
  assistant,
}

@HiveType(typeId: 1)
class ChatMessageRecord {
  const ChatMessageRecord({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.sessionId,
    this.modelName,
    this.reasoningContent,
    this.imageFilePaths = const [],
    this.versionIds = const [],
    this.currentVersionIndex = 0,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final ChatRole role;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(9)
  final String? sessionId;

  @HiveField(4)
  final String? modelName;

  @HiveField(5)
  final String? reasoningContent;

  @HiveField(6)
  final List<String> imageFilePaths;

  @HiveField(7)
  final List<String> versionIds;

  @HiveField(8)
  final int currentVersionIndex;

  int get versionCount => versionIds.isEmpty ? 1 : versionIds.length;

  bool get hasMultipleVersions => versionIds.length > 1;

  ChatMessageRecord copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? createdAt,
    String? sessionId,
    bool clearSessionId = false,
    String? modelName,
    String? reasoningContent,
    bool clearModelName = false,
    bool clearReasoningContent = false,
    List<String>? imageFilePaths,
    bool clearImageFilePaths = false,
    List<String>? versionIds,
    bool clearVersionIds = false,
    int? currentVersionIndex,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      sessionId: clearSessionId ? null : sessionId ?? this.sessionId,
      modelName: clearModelName ? null : modelName ?? this.modelName,
      reasoningContent: clearReasoningContent
          ? null
          : reasoningContent ?? this.reasoningContent,
      imageFilePaths: clearImageFilePaths
          ? const []
          : imageFilePaths ?? this.imageFilePaths,
      versionIds: clearVersionIds ? const [] : versionIds ?? this.versionIds,
      currentVersionIndex: currentVersionIndex ?? this.currentVersionIndex,
    );
  }
}
