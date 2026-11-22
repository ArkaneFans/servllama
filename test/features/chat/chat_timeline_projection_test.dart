import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/services/stream_chunk_handler.dart';
import 'package:servllama/features/chat/presentation/chat_timeline_projection.dart';

ChatMessageRecord message(List<MessagePart> parts) => ChatMessageRecord(
  id: 'm',
  sessionId: 'chat',
  runId: 'run',
  role: ChatRole.assistant,
  createdAt: DateTime(2026),
  parts: parts,
);
ToolPart tool(String id, {ToolState state = ToolState.succeeded}) => ToolPart(
  id: id,
  callId: id,
  name: 'clock',
  input: '{}',
  inputComplete: true,
  state: state,
  result: state == ToolState.succeeded ? 'saved' : null,
);

void main() {
  test(
    'tokens coalesce and immutable snapshots keep their original values',
    () {
      final h = StreamChunkHandler();
      h.handle(const ReasoningStart('reason'));
      h.handle(const ReasoningDelta(id: 'reason', text: '想'));
      final early = h.parts;
      h.handle(const ReasoningDelta(id: 'reason', text: '一想🦙'));
      h.handle(const TextDelta(id: 'text', text: '先说明'));
      h.handle(const TextDelta(id: 'text', text: '。'));
      expect((early.single as ReasoningPart).text, '想');
      expect((early.single as ReasoningPart).finishedAt, isNull);
      expect(h.parts, hasLength(2));
      expect((h.parts.first as ReasoningPart).finishedAt, isNotNull);
      expect(h.content, '先说明。');
      expect(h.reasoning, '想一想🦙');
    },
  );

  test(
    'ordered parts group consecutive thinking/tools across blank separators',
    () {
      final m = message([
        const ReasoningPart('r1', 'Plan'),
        const TextPart('t1', 'Checking'),
        tool('call'),
        const TextPart('sep', '\n\n'),
        const ReasoningPart('r2', 'Verify'),
        const TextPart('t2', 'Answer'),
      ]);
      final blocks = projectChatTimeline(m);
      expect(
        blocks.map(
          (b) => b.text ?? b.steps.map((s) => s.part.kind.name).join(','),
        ),
        ['reasoning', 'Checking', 'tool,reasoning', 'Answer'],
      );
      expect(blocks[2].steps.first.invocation!.part.result, 'saved');
      expect(m.content, 'Checking\n\nAnswer');
      expect(m.reasoningContent, 'PlanVerify');
      final encoded = MessagePart.encode(m.parts);
      expect(MessagePart.encode(MessagePart.decode(encoded)), encoded);
    },
  );

  test(
    'same tool slot changes result without moving prose or changing keys',
    () {
      final first = message([
        tool('a', state: ToolState.executing),
        const TextPart('body', 'Answer'),
        tool('b'),
      ]);
      final next = first.copyWith(parts: [tool('a'), ...first.parts.skip(1)]);
      final before = projectChatTimeline(first, streaming: true);
      final after = projectChatTimeline(next);
      expect(before.map((b) => b.key), after.map((b) => b.key));
      expect(after.first.steps.single.invocation!.part.result, 'saved');
      expect(after[1].text, 'Answer');
      expect(after.last.steps.single.invocation!.callId, 'b');
    },
  );

  test('folding keeps live approvals and unknown outcomes visible', () {
    for (final state in [
      ToolState.pendingApproval,
      ToolState.executing,
      ToolState.unknownOutcome,
    ]) {
      final steps = projectChatTimeline(
        message([
          for (var i = 0; i < 5; i++)
            tool('$i', state: i == 1 ? state : ToolState.succeeded),
        ]),
        streaming: true,
      ).single.steps;
      expect(chatTimelineVisibleStart(steps, expanded: false), 1);
      expect(chatTimelineVisibleStart(steps, expanded: true), 0);
    }
    final finished = projectChatTimeline(
      message([for (var i = 0; i < 5; i++) tool('$i')]),
    ).single.steps;
    expect(chatTimelineVisibleStart(finished, expanded: false), 3);
  });

  test(
    'version projection uses the selected body even if its Run is shared',
    () {
      final original = message([tool('a'), const TextPart('body', 'Original')]);
      final edited = original.copyWith(
        parts: [const TextPart('edited', 'Manual')],
      );
      expect(projectChatTimeline(edited).single.text, 'Manual');
      expect(
        projectChatTimeline(original).first.steps.single.invocation!.callId,
        'a',
      );
    },
  );
}
