import 'package:servllama/features/chat/models/ai_turn.dart';

/// Provider-independent events. Series IDs are request-scoped, stable even
/// when a vendor supplies a tool call ID late, and separate from execution IDs.
/// Start/delta events are display data. Only validated End calls may execute,
/// and ChatRunner still waits for a successfully completed model round.
sealed class StreamChunk {
  const StreamChunk();
}

final class TextStart extends StreamChunk {
  const TextStart(this.id);
  final String id;
}

final class TextDelta extends StreamChunk {
  const TextDelta({required this.id, required this.text});
  final String id, text;
}

final class TextEnd extends StreamChunk {
  const TextEnd(this.id);
  final String id;
}

final class ReasoningStart extends StreamChunk {
  const ReasoningStart(this.id);
  final String id;
}

final class ReasoningDelta extends StreamChunk {
  const ReasoningDelta({required this.id, required this.text});
  final String id, text;
}

final class ReasoningEnd extends StreamChunk {
  const ReasoningEnd(this.id);
  final String id;
}

final class ToolCallStart extends StreamChunk {
  const ToolCallStart({required this.id, this.callId, this.toolName = ''});
  final String id, toolName;
  final String? callId;
}

final class ToolCallDelta extends StreamChunk {
  const ToolCallDelta({
    required this.id,
    this.callId,
    this.toolNameDelta = '',
    this.inputDelta = '',
  });
  final String id, toolNameDelta, inputDelta;
  final String? callId;
}

final class ToolCallEnd extends StreamChunk {
  const ToolCallEnd({required this.id, required this.call});
  final String id;
  final AiToolCall call;
}

/// Produced after AgentToolService commits the result in the owning ToolPart.
/// Live state callbacks have already updated that same message slot.
final class ToolCallResult extends StreamChunk {
  const ToolCallResult({required this.callId});
  final String callId;
}

final class Usage extends StreamChunk {
  const Usage({this.inputTokens = 0, this.outputTokens = 0});
  final int inputTokens, outputTokens;
}

/// One provider response finished, not the whole multi-round Agent run.
/// Opaque parts preserve vendor signatures/state for subsequent requests.
final class Finish extends StreamChunk {
  const Finish({required this.stopReason, this.providerParts = const []});
  final String stopReason;
  final List<Map<String, dynamic>> providerParts;
}

/// Run-level boundary emitted by ChatRunner before tool execution/follow-up.
final class AssistantRoundEnd extends StreamChunk {
  const AssistantRoundEnd();
}
