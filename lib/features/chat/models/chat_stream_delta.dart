import 'package:servllama/features/chat/models/generation_metrics.dart';

class ChatStreamDelta {
  const ChatStreamDelta({
    this.content = '',
    this.reasoningContent = '',
    this.generationMetrics,
  });

  final GenerationMetrics? generationMetrics;
  final String content;
  final String reasoningContent;

  bool get isEmpty =>
      content.isEmpty && reasoningContent.isEmpty && generationMetrics == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatStreamDelta &&
          runtimeType == other.runtimeType &&
          content == other.content &&
          reasoningContent == other.reasoningContent &&
          generationMetrics == other.generationMetrics;

  @override
  int get hashCode => Object.hash(content, reasoningContent, generationMetrics);
}
