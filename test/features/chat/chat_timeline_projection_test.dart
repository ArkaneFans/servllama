import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_timeline.dart';
import 'package:servllama/features/chat/presentation/chat_timeline_projection.dart';

ToolInvocation receipt(
  String call, {
  String state = 'succeeded',
  String run = 'run',
}) => ToolInvocation(
  id: '$run:$call',
  runId: run,
  conversationId: 'chat',
  callId: call,
  name: 'clock',
  state: state,
  payload: const {'arguments': {}, 'result': 'saved'},
);
ChatMessageRecord message(
  List<ChatTimelinePart> parts, {
  String text = '',
  String reasoning = '',
}) => ChatMessageRecord(
  id: 'm',
  sessionId: 'chat',
  runId: 'run',
  role: ChatRole.assistant,
  content: text,
  reasoningContent: reasoning,
  createdAt: DateTime(2026),
  timeline: parts,
);

void main() {
  test(
    'tokens coalesce; immutable snapshots preserve timing and multi-round order',
    () {
      final start = DateTime.utc(2026);
      final builder = ChatTimelineBuilder();
      builder.append(reasoning: '想', at: start);
      final earlier = builder.snapshot;
      builder.append(
        reasoning: '一想🦙',
        at: start.add(const Duration(seconds: 1)),
      );
      builder.append(text: '先说明', at: start.add(const Duration(seconds: 2)));
      builder.tool('first', 'clock');
      builder.append(text: '\n\n');
      builder.append(
        reasoning: '再确认',
        at: start.add(const Duration(seconds: 3)),
      );
      builder.finish(at: start.add(const Duration(seconds: 4)));
      builder.append(text: '结论');
      final parts = builder.snapshot;
      expect(earlier.single.end, 1);
      expect(earlier.single.finishedAt, isNull);
      expect(parts.map((p) => p.kind), [
        ChatTimelineKind.reasoning,
        ChatTimelineKind.text,
        ChatTimelineKind.tool,
        ChatTimelineKind.text,
        ChatTimelineKind.reasoning,
        ChatTimelineKind.text,
      ]);
      expect(
        parts.first.finishedAt!.difference(start),
        const Duration(seconds: 2),
      );
      final blocks = projectChatTimeline(
        message(parts, text: '先说明\n\n结论', reasoning: '想一想🦙再确认'),
        [receipt('first')],
      );
      expect(
        blocks.map(
          (b) => b.text ?? b.steps.map((s) => s.part.kind.name).join(','),
        ),
        ['reasoning', '先说明', 'tool,reasoning', '结论'],
      );
      expect(blocks[2].steps.first.invocation?.payload['result'], 'saved');
      expect(ChatTimelinePart.encode(parts), isNot(contains('结论')));
      expect(ChatTimelinePart.encode(parts), isNot(contains('saved')));
      expect(
        ChatTimelinePart.encode(
          ChatTimelinePart.decode(ChatTimelinePart.encode(parts)),
        ),
        ChatTimelinePart.encode(parts),
      );
    },
  );

  test(
    'a model boundary creates a distinct reasoning step even without text',
    () {
      final b = ChatTimelineBuilder()..append(reasoning: 'A');
      b.finish();
      b.append(reasoning: 'B');
      b.finish();
      expect(b.snapshot, hasLength(2));
      expect(b.snapshot.every((p) => p.finishedAt != null), isTrue);
    },
  );

  test(
    'tool results replace nodes by scoped call ID without reordering or duplication',
    () {
      final b = ChatTimelineBuilder()
        ..tool('first', 'clock')
        ..tool('second', 'clock');
      b.append(text: 'Answer');
      final m = message(b.snapshot, text: 'Answer');
      final blocks = projectChatTimeline(m, [
        receipt('second'),
        receipt('first'),
        receipt('first', run: 'other'),
      ]);
      expect(blocks.first.steps.map((s) => s.invocation?.id), [
        'run:first',
        'run:second',
      ]);
      expect(blocks.last.text, 'Answer');
      expect(
        projectChatTimeline(m, [
          receipt('second'),
        ]).first.steps.first.invocation,
        isNull,
      );
    },
  );

  test(
    'folding keeps pending approval, executing, and unknown outcomes visible',
    () {
      final b = ChatTimelineBuilder();
      for (var i = 0; i < 5; i++) {
        b.tool('$i', 'clock');
      }
      for (final state in ['pendingApproval', 'executing', 'unknownOutcome']) {
        final steps = projectChatTimeline(message(b.snapshot), [
          for (var i = 0; i < 5; i++)
            receipt('$i', state: i == 1 ? state : 'succeeded'),
        ]).single.steps;
        expect(chatTimelineVisibleStart(steps, expanded: false), 1);
        expect(chatTimelineVisibleStart(steps, expanded: true), 0);
      }
      final finished = projectChatTimeline(message(b.snapshot), [
        for (var i = 0; i < 5; i++) receipt('$i'),
      ]).single.steps;
      expect(chatTimelineVisibleStart(finished, expanded: false), 3);
    },
  );

  test(
    'invalid or old ranges retain both bodies and receipts without slicing errors',
    () {
      for (final parts in <List<ChatTimelinePart>>[
        [],
        [
          const ChatTimelinePart(
            kind: ChatTimelineKind.text,
            start: -1,
            end: 999,
          ),
        ],
        [const ChatTimelinePart(kind: ChatTimelineKind.text, start: 1, end: 4)],
      ]) {
        final blocks = projectChatTimeline(
          message(parts, text: 'Body', reasoning: 'Think'),
          [receipt('a')],
        );
        expect(blocks.first.steps.first.text, 'Think');
        expect(blocks.first.steps.last.invocation?.id, 'run:a');
        expect(blocks.last.text, 'Body');
      }
      for (final raw in [
        'broken',
        '{}',
        '[{"kind":"future"}]',
        '[{"kind":"text","end":"bad"}]',
      ]) {
        expect(ChatTimelinePart.decode(raw), isEmpty);
      }
    },
  );

  test(
    'receipt beyond the last checkpoint stays inspectable after interruption',
    () {
      final b = ChatTimelineBuilder()..append(text: 'Before tool');
      final blocks = projectChatTimeline(
        message(b.snapshot, text: 'Before tool'),
        [receipt('missing', state: 'unknownOutcome')],
      );
      expect(blocks.first.text, 'Before tool');
      expect(blocks.last.steps.single.invocation?.state, 'unknownOutcome');
    },
  );
}
