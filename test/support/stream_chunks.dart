import 'dart:convert';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';

/// Concise complete fixtures; lifecycle/partial-stream tests use explicit chunks.
int _scope = 0;
List<StreamChunk> fixtureChunks({
  String text = '',
  String reasoning = '',
  List<AiToolCall> calls = const [],
  String? stopReason,
}) {
  final scope = _scope;
  if (stopReason != null) _scope++;
  return [
    if (reasoning.isNotEmpty)
      ReasoningDelta(id: 'fixture-reasoning:$scope', text: reasoning),
    if (text.isNotEmpty) TextDelta(id: 'fixture-text:$scope', text: text),
    for (final call in calls) ...[
      ToolCallStart(
        id: 'fixture-tool:$scope:${call.id}',
        callId: call.id,
        toolName: call.name,
      ),
      ToolCallDelta(
        id: 'fixture-tool:$scope:${call.id}',
        inputDelta: jsonEncode(call.arguments),
      ),
      ToolCallEnd(id: 'fixture-tool:$scope:${call.id}', call: call),
    ],
    if (stopReason != null) Finish(stopReason: stopReason),
  ];
}
