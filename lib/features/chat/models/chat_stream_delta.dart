import 'package:servllama/features/chat/models/ai_turn.dart';

class ChatStreamDelta {
  const ChatStreamDelta({
    this.content = '',
    this.reasoningContent = '',
    this.toolCalls = const [],
    this.endRound = false,
  });

  final String content;
  final String reasoningContent;
  final List<AiToolCall> toolCalls;
  final bool endRound;

  bool get isEmpty =>
      content.isEmpty &&
      reasoningContent.isEmpty &&
      toolCalls.isEmpty &&
      !endRound;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatStreamDelta &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          reasoningContent == other.reasoningContent &&
          toolCalls == other.toolCalls &&
          endRound == other.endRound;

  @override
  int get hashCode =>
      Object.hash(content, reasoningContent, toolCalls, endRound);
}
