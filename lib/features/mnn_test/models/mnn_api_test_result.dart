enum MnnApiTestStepStatus { pending, running, succeeded, failed, skipped }

extension MnnApiTestStepStatusLabel on MnnApiTestStepStatus {
  String get label {
    switch (this) {
      case MnnApiTestStepStatus.pending:
        return '待执行';
      case MnnApiTestStepStatus.running:
        return '执行中';
      case MnnApiTestStepStatus.succeeded:
        return '成功';
      case MnnApiTestStepStatus.failed:
        return '失败';
      case MnnApiTestStepStatus.skipped:
        return '已跳过';
    }
  }
}

class MnnApiValidationCheck {
  const MnnApiValidationCheck({
    required this.id,
    required this.label,
    required this.succeeded,
    this.detail,
  });

  final String id;
  final String label;
  final bool succeeded;
  final String? detail;
}

class MnnApiExchange {
  const MnnApiExchange({
    required this.method,
    required this.url,
    required this.requestDisplay,
    required this.responseDisplay,
    required this.succeeded,
    required this.elapsedMs,
    this.statusCode,
    this.contentType,
    this.firstTokenMs,
    this.sseEventCount = 0,
    this.sseCompleted = false,
    this.cancelled = false,
    this.responseData,
    this.sseEvents = const <Object?>[],
    this.errorMessage,
  });

  final String method;
  final String url;
  final String requestDisplay;
  final String responseDisplay;
  final bool succeeded;
  final int elapsedMs;
  final int? statusCode;
  final String? contentType;
  final int? firstTokenMs;
  final int sseEventCount;
  final bool sseCompleted;
  final bool cancelled;

  /// The decoded response is used by the tool flow. It never contains the
  /// original request body; the complete request is available separately in
  /// [requestDisplay] for the development/debug page.
  final Object? responseData;
  final List<Object?> sseEvents;
  final String? errorMessage;
}

class MnnApiCallResult {
  const MnnApiCallResult({required this.exchange});

  final MnnApiExchange exchange;

  Object? get responseData => exchange.responseData;

  bool get succeeded => exchange.succeeded;
}

class MnnApiTestStep {
  const MnnApiTestStep({
    required this.id,
    required this.title,
    required this.status,
    this.checks = const <MnnApiValidationCheck>[],
    this.exchange,
    this.input,
    this.output,
    this.elapsedMs,
    this.error,
  });

  final String id;
  final String title;
  final MnnApiTestStepStatus status;
  final List<MnnApiValidationCheck> checks;
  final MnnApiExchange? exchange;
  final String? input;
  final String? output;
  final int? elapsedMs;
  final String? error;

  MnnApiTestStep copyWith({
    MnnApiTestStepStatus? status,
    List<MnnApiValidationCheck>? checks,
    MnnApiExchange? exchange,
    bool clearExchange = false,
    String? input,
    String? output,
    int? elapsedMs,
    String? error,
    bool clearError = false,
  }) {
    return MnnApiTestStep(
      id: id,
      title: title,
      status: status ?? this.status,
      checks: checks ?? this.checks,
      exchange: clearExchange ? null : exchange ?? this.exchange,
      input: input ?? this.input,
      output: output ?? this.output,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      error: clearError ? null : error ?? this.error,
    );
  }
}

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
    this.exchanges = const <MnnApiExchange>[],
    this.steps = const <MnnApiTestStep>[],
    this.streamingText,
    this.cancelled = false,
    this.errorMessage,
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
  final List<MnnApiExchange> exchanges;
  final List<MnnApiTestStep> steps;
  final String? streamingText;
  final bool cancelled;
  final String? errorMessage;
}
