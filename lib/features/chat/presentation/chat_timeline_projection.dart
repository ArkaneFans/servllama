import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_timeline.dart';

class ChatTimelineStep {
  const ChatTimelineStep({
    required this.key,
    required this.part,
    this.text = '',
    this.invocation,
  });
  final String key, text;
  final ChatTimelinePart part;
  final ToolInvocation? invocation;

  bool get needsAttention => const {
    'prepared',
    'approved',
    'pendingApproval',
    'executing',
    'unknownOutcome',
  }.contains(invocation?.state);
}

class ChatTimelineBlock {
  const ChatTimelineBlock.text(this.key, this.text) : steps = const [];
  const ChatTimelineBlock.activity(this.key, this.steps) : text = null;
  final String key;
  final String? text;
  final List<ChatTimelineStep> steps;
}

/// Pure display projection; it neither executes tools nor restores Runs.
/// Valid ordering metadata addresses existing bodies and receipts. Invalid or
/// old metadata uses the original reasoning/tools/body layout without guessing.
List<ChatTimelineBlock> projectChatTimeline(
  ChatMessageRecord message,
  List<ToolInvocation> records,
) {
  final receipts = {
    for (final record in records)
      if (record.runId == message.runId &&
          record.conversationId == message.sessionId)
        record.callId: record,
  };
  final reasoning = message.reasoningContent ?? '';
  var textEnd = 0, reasoningEnd = 0;
  final calls = <String>{};
  var valid = message.timeline.isNotEmpty;
  for (final part in message.timeline) {
    switch (part.kind) {
      case ChatTimelineKind.text:
        valid &=
            part.start == textEnd &&
            part.end >= part.start &&
            part.end <= message.content.length;
        textEnd = part.end;
      case ChatTimelineKind.reasoning:
        valid &=
            part.start == reasoningEnd &&
            part.end >= part.start &&
            part.end <= reasoning.length;
        reasoningEnd = part.end;
      case ChatTimelineKind.tool:
        valid &=
            message.runId != null &&
            part.callId != null &&
            part.callId!.isNotEmpty &&
            calls.add(part.callId!);
    }
  }
  valid &=
      textEnd == message.content.length && reasoningEnd == reasoning.length;
  final parts = valid
      ? message.timeline
      : <ChatTimelinePart>[
          if (reasoning.isNotEmpty)
            ChatTimelinePart(
              kind: ChatTimelineKind.reasoning,
              end: reasoning.length,
            ),
          for (final receipt in receipts.values)
            ChatTimelinePart(
              kind: ChatTimelineKind.tool,
              callId: receipt.callId,
              toolName: receipt.name,
            ),
          if (message.content.isNotEmpty)
            ChatTimelinePart(
              kind: ChatTimelineKind.text,
              end: message.content.length,
            ),
        ];
  final blocks = <ChatTimelineBlock>[];
  var pending = <ChatTimelineStep>[];
  final used = <String>{};
  void flush() {
    if (pending.isEmpty) return;
    blocks.add(
      ChatTimelineBlock.activity(pending.first.key, List.unmodifiable(pending)),
    );
    pending = [];
  }

  for (final (index, part) in parts.indexed) {
    final key = '${message.runId ?? message.id}:$index';
    if (part.kind == ChatTimelineKind.text) {
      final text = message.content.substring(part.start, part.end);
      if (text.trim().isEmpty) continue;
      flush();
      blocks.add(ChatTimelineBlock.text(key, text));
    } else {
      if (part.kind == ChatTimelineKind.tool) used.add(part.callId!);
      pending.add(
        ChatTimelineStep(
          key: key,
          part: part,
          text: part.kind == ChatTimelineKind.reasoning
              ? reasoning.substring(part.start, part.end)
              : '',
          invocation: receipts[part.callId],
        ),
      );
    }
  }
  // A receipt may commit before the next draft checkpoint. Keep it inspectable
  // even if a process interruption left its reference outside that checkpoint.
  for (final receipt in receipts.values.where(
    (r) => !used.contains(r.callId),
  )) {
    pending.add(
      ChatTimelineStep(
        key: receipt.id,
        part: ChatTimelinePart(
          kind: ChatTimelineKind.tool,
          callId: receipt.callId,
          toolName: receipt.name,
        ),
        invocation: receipt,
      ),
    );
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
