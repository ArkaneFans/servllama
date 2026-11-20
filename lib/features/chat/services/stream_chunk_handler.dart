import 'package:servllama/features/chat/models/chat_timeline.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/models/tool_call_preview.dart';

/// One generation's ordered, immutable display snapshots. Receipts stay in the
/// existing AgentToolService; no provisional argument is persisted or executed.
class StreamChunkHandler {
  final timeline = ChatTimelineBuilder();
  String content = '', reasoning = '';
  final _tools = <String, ToolCallPreview>{};
  Map<String, ToolCallPreview> get previews => Map.unmodifiable(_tools);

  bool handle(StreamChunk chunk) {
    switch (chunk) {
      case TextStart():
        timeline.finish();
      case TextDelta(:final id, :final text):
        if (text.isEmpty) return false;
        content += text;
        timeline.append(text: text, streamId: id);
      case ReasoningStart(:final id):
        timeline.reasoningStart(id);
      case ReasoningDelta(:final id, :final text):
        if (text.isEmpty) return false;
        reasoning += text;
        timeline.append(reasoning: text, streamId: id);
      case ReasoningEnd(:final id):
        timeline.endSeries(id);
      case ToolCallStart(:final id, :final callId, :final toolName):
        if (_tools.containsKey(id)) {
          throw const FormatException('Repeated tool start');
        }
        _tools[id] = ToolCallPreview(id: id, callId: callId, name: toolName);
        timeline.toolStream(id, callId: callId, name: toolName);
      case ToolCallDelta(
        :final id,
        :final callId,
        :final toolNameDelta,
        :final inputDelta,
      ):
        final previous = _tools[id];
        if (previous == null || previous.complete) {
          throw const FormatException('Invalid tool delta');
        }
        if (previous.input.length + inputDelta.length > 128 * 1024) {
          throw const FormatException('Tool arguments exceed limit');
        }
        final next = ToolCallPreview(
          id: id,
          callId: callId ?? previous.callId,
          name: previous.name + toolNameDelta,
          input: previous.input + inputDelta,
        );
        _tools[id] = next;
        timeline.toolStream(id, callId: next.callId, name: next.name);
      case ToolCallEnd(:final id, :final call):
        final previous = _tools[id];
        if (previous == null || previous.complete) {
          throw const FormatException('Invalid tool end');
        }
        _tools[id] = ToolCallPreview(
          id: id,
          callId: call.id,
          name: call.name,
          input: previous.input,
          complete: true,
        );
        timeline.toolStream(
          id,
          callId: call.id,
          name: call.name,
          inputComplete: true,
        );
      case Finish() || AssistantRoundEnd():
        timeline.finish();
      case TextEnd() || ToolCallResult() || Usage():
        return false;
    }
    return true;
  }
}
