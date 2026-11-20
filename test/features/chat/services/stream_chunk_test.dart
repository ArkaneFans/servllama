import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_timeline.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/presentation/chat_timeline_projection.dart';
import 'package:servllama/features/chat/services/chat_stream_decoder.dart';
import 'package:servllama/features/chat/services/stream_chunk_handler.dart';

Map<String, dynamic> openai(Map<String, dynamic> delta, {String? finish}) => {
  'choices': [
    {'delta': delta, if (finish != null) 'finish_reason': finish},
  ],
};
Map<String, dynamic> tool(
  int index, {
  String? id,
  String? name,
  String input = '',
}) => {
  'index': index,
  if (id != null) 'id': id,
  'function': {if (name != null) 'name': name, 'arguments': input},
};
ChatMessageRecord snapshot(StreamChunkHandler h) => ChatMessageRecord(
  id: 'm',
  sessionId: 'c',
  runId: 'run',
  role: ChatRole.assistant,
  createdAt: DateTime.utc(2026),
  content: h.content,
  reasoningContent: h.reasoning,
  timeline: h.timeline.snapshot,
  toolCallPreviews: h.previews,
);

void main() {
  test('late vendor IDs keep one live node and preserve interleaved prose', () {
    final decoder = ChatStreamDecoder(AiProtocol.openai);
    final handler = StreamChunkHandler();
    void receive(Map<String, dynamic> data) {
      for (final chunk in decoder.accept(data)) {
        handler.handle(chunk);
      }
    }

    receive(openai({'reasoning_content': 'Plan'}));
    receive(
      openai({
        'tool_calls': [tool(0, name: 'ask_', input: '{"question":')],
      }),
    );
    final early = snapshot(handler);
    final streamId = early.timeline.last.streamId!;
    expect(early.timeline.last.callId, isNull);
    expect(early.timeline.last.inputComplete, isFalse);
    expect(early.toolCallPreviews[streamId]!.input, '{"question":');
    expect(
      projectChatTimeline(
        early,
        [],
        streaming: true,
      ).single.steps.last.needsAttention,
      isTrue,
    );
    receive(openai({'content': 'Checking'}));
    receive(
      openai({
        'tool_calls': [
          tool(0, id: 'vendor', name: 'user', input: '"Continue?"}'),
        ],
      }),
    );
    receive(openai({}, finish: 'tool_calls'));
    for (final chunk in decoder.finish()) {
      handler.handle(chunk);
    }
    final finalMessage = snapshot(handler);
    expect(finalMessage.timeline.map((p) => p.kind), [
      ChatTimelineKind.reasoning,
      ChatTimelineKind.tool,
      ChatTimelineKind.text,
    ]);
    expect(finalMessage.timeline[1].streamId, streamId);
    expect(finalMessage.timeline[1].callId, 'vendor');
    expect(finalMessage.timeline[1].toolName, 'ask_user');
    expect(finalMessage.timeline[1].inputComplete, isTrue);
    expect(early.toolCallPreviews[streamId]!.complete, isFalse);
    expect(early.timeline[1].callId, isNull);
    final encoded = ChatTimelinePart.encode(finalMessage.timeline);
    expect(encoded, isNot(contains('Continue?')));
    expect(encoded, isNot(contains('Checking')));
    expect(ChatTimelinePart.decode(encoded)[1].streamId, streamId);
  });

  test('interleaved calls accumulate by index; IDs are scoped per request', () {
    final d = ChatStreamDecoder(AiProtocol.openai);
    final chunks = <StreamChunk>[
      ...d.accept(
        openai({
          'tool_calls': [
            tool(1, id: 'b', name: 'clock', input: '{'),
            tool(0, id: 'a', name: 'clock', input: '{'),
          ],
        }),
      ),
      ...d.accept(
        openai({
          'tool_calls': [tool(0, input: '"n":1}'), tool(1, input: '"n":2}')],
        }),
      ),
      ...d.accept(openai({}, finish: 'tool_calls')),
      ...d.finish(),
    ];
    expect(chunks.whereType<ToolCallStart>(), hasLength(2));
    final ends = chunks.whereType<ToolCallEnd>().toList();
    expect(ends.map((e) => e.call.id), ['b', 'a']);
    expect(ends.map((e) => e.call.arguments['n']), [2, 1]);
    final other = ChatStreamDecoder(AiProtocol.openai).accept(
      openai({
        'tool_calls': [tool(0, id: 'a', name: 'clock')],
      }),
    );
    expect(
      other.whereType<ToolCallStart>().single.id,
      isNot(chunks.whereType<ToolCallStart>().first.id),
    );
  });

  test(
    'omitted indices with distinct vendor IDs do not overwrite sparse indices',
    () {
      final d = ChatStreamDecoder(AiProtocol.openai);
      final chunks = <StreamChunk>[
        ...d.accept(
          openai({
            'tool_calls': [tool(7, id: 'a', name: 'clock')],
          }),
        ),
        ...d.accept(
          openai({
            'tool_calls': [
              {
                'id': 'b',
                'function': {'name': 'clock', 'arguments': '{}'},
              },
              {
                'id': 'c',
                'function': {'name': 'clock', 'arguments': '{}'},
              },
            ],
          }, finish: 'tool_calls'),
        ),
        ...d.finish(),
      ];
      expect(chunks.whereType<ToolCallStart>(), hasLength(3));
      expect(chunks.whereType<ToolCallEnd>().map((c) => c.call.id), [
        'a',
        'b',
        'c',
      ]);
    },
  );

  test(
    'Anthropic block ends close reasoning and expose a validated call before round finish',
    () {
      final d = ChatStreamDecoder(AiProtocol.anthropic);
      final h = StreamChunkHandler();
      List<StreamChunk> receive(Map<String, dynamic> data) {
        final chunks = d.accept(data);
        for (final chunk in chunks) {
          h.handle(chunk);
        }
        return chunks;
      }

      receive({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'thinking', 'thinking': 'Plan'},
      });
      receive({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'signature_delta', 'signature': 'opaque'},
      });
      receive({'type': 'content_block_stop', 'index': 0});
      expect(h.timeline.snapshot.single.finishedAt, isNotNull);
      receive({
        'type': 'content_block_start',
        'index': 1,
        'content_block': {
          'type': 'tool_use',
          'id': 't',
          'name': 'clock',
          'input': {},
        },
      });
      receive({
        'type': 'content_block_delta',
        'index': 1,
        'delta': {'type': 'input_json_delta', 'partial_json': '{}'},
      });
      expect(
        receive({'type': 'content_block_stop', 'index': 1}).single,
        isA<ToolCallEnd>(),
      );
      expect(() => d.finish(), throwsStateError);
      receive({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      });
      final finish = d.finish();
      expect(finish.whereType<ToolCallEnd>(), isEmpty);
      expect(finish.whereType<ReasoningEnd>(), isEmpty);
      expect(
        (finish.last as Finish).providerParts.first['signature'],
        'opaque',
      );
      expect((finish.last as Finish).providerParts.last['input'], isEmpty);
    },
  );

  test(
    'Gemini complete function arguments emit start/delta/end and retain signature',
    () {
      final d = ChatStreamDecoder(AiProtocol.gemini);
      final chunks = d.accept({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': 'Plan', 'thought': true},
                {
                  'functionCall': {
                    'name': 'clock',
                    'args': {'zone': 'UTC'},
                  },
                  'thoughtSignature': 'opaque',
                },
                {'text': 'Checking'},
              ],
            },
          },
        ],
      });
      expect(chunks.whereType<ToolCallEnd>().single.call.arguments, {
        'zone': 'UTC',
      });
      expect(
        chunks.indexWhere((e) => e is ToolCallStart),
        lessThan(chunks.indexWhere((e) => e is TextDelta)),
      );
      final finish = d.finish().last as Finish;
      expect(finish.providerParts[1]['thoughtSignature'], 'opaque');
    },
  );

  test(
    'cancellation history retains an incomplete node without partial payload',
    () {
      final h = StreamChunkHandler();
      h.handle(const ToolCallStart(id: 's', toolName: 'clock'));
      h.handle(const ToolCallDelta(id: 's', inputDelta: '{"secret":'));
      h.timeline.finish();
      final m = snapshot(h).copyWith(toolCallPreviews: const {});
      final parts = ChatTimelinePart.decode(
        ChatTimelinePart.encode(m.timeline),
      );
      final step = projectChatTimeline(
        m.copyWith(timeline: parts),
        [],
      ).single.steps.single;
      expect(step.part.inputComplete, isFalse);
      expect(step.invocation, isNull);
      expect(step.preview, isNull);
      expect(ChatTimelinePart.encode(parts), isNot(contains('secret')));
    },
  );

  test(
    'malformed, duplicate, conflicting, missing and oversized calls cannot finish',
    () {
      for (final input in ['{', '[]', '"payload"']) {
        final d = ChatStreamDecoder(AiProtocol.openai);
        d.accept(
          openai({
            'tool_calls': [tool(0, id: 't', name: 'clock', input: input)],
          }, finish: 'tool_calls'),
        );
        expect(() => d.finish(), throwsFormatException);
      }
      final duplicate = ChatStreamDecoder(AiProtocol.openai);
      duplicate.accept(
        openai({
          'tool_calls': [
            tool(0, id: 't', name: 'clock'),
            tool(1, id: 't', name: 'clock'),
          ],
        }, finish: 'tool_calls'),
      );
      expect(() => duplicate.finish(), throwsFormatException);
      final missing = ChatStreamDecoder(AiProtocol.openai);
      missing.accept(
        openai({
          'tool_calls': [tool(0, name: 'clock')],
        }, finish: 'tool_calls'),
      );
      expect(() => missing.finish(), throwsFormatException);
      final conflict = ChatStreamDecoder(AiProtocol.openai);
      conflict.accept(
        openai({
          'tool_calls': [tool(0, id: 'a', name: 'clock')],
        }),
      );
      expect(
        () => conflict.accept(
          openai({
            'tool_calls': [tool(0, id: 'b')],
          }),
        ),
        throwsFormatException,
      );
      expect(
        () => ChatStreamDecoder(AiProtocol.openai).accept(
          openai({
            'tool_calls': [
              tool(0, id: 't', name: 'clock', input: 'x' * (128 * 1024 + 1)),
            ],
          }),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'no Finish on dropped response; empty response and usage remain explicit',
    () {
      final dropped = ChatStreamDecoder(AiProtocol.openai);
      dropped.accept(openai({'content': 'partial'}));
      expect(() => dropped.finish(), throwsStateError);
      final empty = ChatStreamDecoder(AiProtocol.openai);
      final chunks = empty.finish(doneMarker: true);
      expect(chunks.whereType<TextDelta>(), isEmpty);
      expect(chunks.last, isA<Finish>());
      final usage =
          empty.accept({
                'usage': {'prompt_tokens': 12, 'completion_tokens': 4},
              }).single
              as Usage;
      expect(usage.inputTokens, 12);
      expect(usage.outputTokens, 4);
    },
  );
}
