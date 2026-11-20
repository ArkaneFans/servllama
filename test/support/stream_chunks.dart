import 'dart:convert';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';

/// Concise complete fixtures; lifecycle/partial-stream tests use explicit chunks.
List<StreamChunk> fixtureChunks({
  String text = '',
  String reasoning = '',
  List<AiToolCall> calls = const [],
  String? stopReason,
}) => [
  if (reasoning.isNotEmpty)
    ReasoningDelta(id: 'fixture-reasoning', text: reasoning),
  if (text.isNotEmpty) TextDelta(id: 'fixture-text', text: text),
  for (final call in calls) ...[
    ToolCallStart(
      id: 'fixture-tool:${call.id}',
      callId: call.id,
      toolName: call.name,
    ),
    ToolCallDelta(
      id: 'fixture-tool:${call.id}',
      inputDelta: jsonEncode(call.arguments),
    ),
    ToolCallEnd(id: 'fixture-tool:${call.id}', call: call),
  ],
  if (stopReason != null) Finish(stopReason: stopReason),
];
