import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/message_part.dart';

class ChatTimelineStep {
  const ChatTimelineStep({
    required this.key,
    required this.part,
    this.text = '',
    this.invocation,
    this.streaming = false,
  });
  final String key, text;
  final MessagePart part;
  final ToolActivity? invocation;
  final bool streaming;
  bool get needsAttention =>
      part is ToolPart &&
      ((part as ToolPart).state == ToolState.unknownOutcome ||
          (streaming && (part as ToolPart).needsAttention));
}

class ChatTimelineBlock {
  const ChatTimelineBlock.text(this.key, this.text) : steps = const [];
  const ChatTimelineBlock.activity(this.key, this.steps) : text = null;
  final String key;
  final String? text;
  final List<ChatTimelineStep> steps;
}

/// Pure projection of canonical parts; no database reads or live receipt join.
List<ChatTimelineBlock> projectChatTimeline(
  ChatMessageRecord message, {
  bool streaming = false,
}) {
  final blocks = <ChatTimelineBlock>[];
  var pending = <ChatTimelineStep>[];
  void flush() {
    if (pending.isEmpty) return;
    blocks.add(
      ChatTimelineBlock.activity(pending.first.key, List.unmodifiable(pending)),
    );
    pending = [];
  }

  for (final p in message.parts) {
    final key = '${message.id}:${p.id}';
    if (p is TextPart) {
      if (p.text.trim().isEmpty) continue;
      flush();
      blocks.add(ChatTimelineBlock.text(key, p.text));
    } else {
      pending.add(
        ChatTimelineStep(
          key: key,
          part: p,
          text: p is ReasoningPart ? p.text : '',
          streaming: streaming,
          invocation: p is ToolPart
              ? ToolActivity(
                  runId: message.runId ?? '',
                  conversationId: message.sessionId ?? '',
                  revisionId: message.versionIds.isEmpty
                      ? ''
                      : message.versionIds[message.currentVersionIndex],
                  part: p,
                )
              : null,
        ),
      );
    }
  }
  flush();
  return List.unmodifiable(blocks);
}

/// Collapse completed history, but keep everything from the first actionable or
/// unresolved step visible, including steps queued later in the same round.
int chatTimelineVisibleStart(
  List<ChatTimelineStep> steps, {
  required bool expanded,
}) {
  if (expanded || steps.length <= 2) return 0;
  final attention = steps.indexWhere((s) => s.needsAttention);
  return attention < 0 || attention > steps.length - 2
      ? steps.length - 2
      : attention;
}
