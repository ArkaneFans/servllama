class MnnApiTestResult {
  const MnnApiTestResult({
    required this.label,
    required this.output,
    required this.succeeded,
    required this.elapsedMs,
    this.statusCode,
    this.firstTokenMs,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.toolCallId,
    this.toolName,
    this.toolArguments,
  });

  final String label;
  final String output;
  final bool succeeded;
  final int elapsedMs;
  final int? statusCode;
  final int? firstTokenMs;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? toolCallId;
  final String? toolName;
  final String? toolArguments;
}
