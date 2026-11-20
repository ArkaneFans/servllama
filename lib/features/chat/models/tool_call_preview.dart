/// In-memory display snapshot. Raw partial JSON is never a tool invocation or
/// revision payload. Durable timeline metadata only records order/completeness.
class ToolCallPreview {
  const ToolCallPreview({
    required this.id,
    this.callId,
    this.name = '',
    this.input = '',
    this.complete = false,
  });
  final String id, name, input;
  final String? callId;
  final bool complete;
}
