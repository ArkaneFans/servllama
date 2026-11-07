/// Per-response token usage and phase speeds. Native phase timings are preferred;
/// explicitly marked estimates use measured first-output/request boundaries.
class GenerationMetrics {
  const GenerationMetrics({
    this.promptTokens,
    this.promptMilliseconds,
    this.predictedTokens,
    this.predictedMilliseconds,
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.finalContextTokens,
    this.roundCount = 1,
    this.modelId,
    this.connectionId,
    this.contextKey,
    this.prefillIsEstimated = false,
    this.decodeIsEstimated = false,
  });

  /// Tokens counted by the backend phase timer (not necessarily total input).
  final int? promptTokens, predictedTokens;
  final double? promptMilliseconds, predictedMilliseconds;

  /// Total input/output usage. Null means unknown, distinct from a known zero.
  final int? inputTokens, outputTokens, cachedInputTokens;
  final bool prefillIsEstimated, decodeIsEstimated;

  /// Actual latest model-round context occupancy, not aggregate billed usage.
  final int? finalContextTokens;
  final int roundCount;
  final String? modelId, connectionId, contextKey;

  GenerationMetrics withIdentity({
    required String modelId,
    String? connectionId,
    String? contextKey,
  }) => GenerationMetrics.fromJson({
    ...toJson(),
    'model_id': modelId,
    if (connectionId != null) 'connection_id': connectionId,
    if (contextKey != null) 'context_key': contextKey,
  })!;
  int? get contextTokens =>
      finalContextTokens ??
      (roundCount == 1 && inputTokens != null && outputTokens != null
          ? inputTokens! + outputTokens!
          : null);

  double? get prefillTokensPerSecond => _rate(promptTokens, promptMilliseconds);
  double? get decodeTokensPerSecond =>
      _rate(predictedTokens, predictedMilliseconds);

  static double? _rate(int? tokens, double? milliseconds) {
    if (tokens == null ||
        tokens <= 0 ||
        milliseconds == null ||
        !milliseconds.isFinite ||
        milliseconds <= 0) {
      return null;
    }
    final rate = tokens * 1000 / milliseconds;
    return rate.isFinite && rate > 0 ? rate : null;
  }

  static int? tokenCount(Object? value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    final count = value.toInt();
    return count == value ? count : null;
  }

  static double? _duration(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;

  /// llama.cpp's timings extension, supported by compatible custom backends.
  static GenerationMetrics? fromTimings(Object? value) =>
      fromResponse(timings: value);

  static GenerationMetrics? fromResponse({Object? timings, Object? usage}) {
    final t = timings is Map ? timings : const {};
    final u = usage is Map ? usage : const {};
    final prompt = tokenCount(t['prompt_n']);
    final predicted = tokenCount(t['predicted_n']);
    var input = tokenCount(u['prompt_tokens']);
    final details = u['prompt_tokens_details'];
    var cached =
        tokenCount(details is Map ? details['cached_tokens'] : null) ??
        tokenCount(t['cache_n']);
    // llama.cpp's prompt_n is newly processed input, cache_n is reused input.
    // Custom backends may explicitly report total_input without a cache counter.
    if (input == null && prompt != null) {
      if (t['prompt_tokens_scope'] == 'total_input') {
        input = prompt;
      } else if (cached != null) {
        input = prompt + cached;
      }
    }
    if (input != null && cached != null && cached > input) cached = null;
    final raw = GenerationMetrics(
      promptTokens: prompt,
      promptMilliseconds: _duration(t['prompt_ms']),
      predictedTokens: predicted,
      predictedMilliseconds: _duration(t['predicted_ms']),
      inputTokens: input,
      outputTokens: tokenCount(u['completion_tokens']) ?? predicted,
      cachedInputTokens: cached,
    );
    return raw._normalized();
  }

  GenerationMetrics withUsage({
    int? inputTokens,
    int? outputTokens,
    int? cachedInputTokens,
  }) {
    final input = tokenCount(inputTokens ?? this.inputTokens);
    var cached = tokenCount(cachedInputTokens ?? this.cachedInputTokens);
    if (input != null && cached != null && cached > input) cached = null;
    return GenerationMetrics(
      promptTokens: promptTokens,
      promptMilliseconds: promptMilliseconds,
      predictedTokens: predictedTokens,
      predictedMilliseconds: predictedMilliseconds,
      finalContextTokens: finalContextTokens,
      roundCount: roundCount,
      modelId: modelId,
      connectionId: connectionId,
      contextKey: contextKey,
      inputTokens: input,
      outputTokens: tokenCount(outputTokens ?? this.outputTokens),
      cachedInputTokens: cached,
      prefillIsEstimated: prefillIsEstimated,
      decodeIsEstimated: decodeIsEstimated,
    );
  }

  /// TTFT includes network/queue/sampling overhead. Decode excludes the first
  /// output token; its interval ends when the response's final usage arrives.
  /// Reasoning counts as first output too. Without real usage counts there is
  /// no token-speed estimate; characters/chunks are never treated as tokens.
  GenerationMetrics withEstimates({
    double? firstTokenMilliseconds,
    double? outputMilliseconds,
  }) {
    final prefill = prefillTokensPerSecond == null;
    final decode = decodeTokensPerSecond == null;
    final newPrompt = inputTokens == null
        ? null
        : inputTokens! - (cachedInputTokens ?? 0);
    final newPredicted = outputTokens == null ? null : outputTokens! - 1;
    final estimatePrefill =
        prefill && _rate(newPrompt, firstTokenMilliseconds) != null;
    final estimateDecode =
        decode && _rate(newPredicted, outputMilliseconds) != null;
    return GenerationMetrics(
      promptTokens: estimatePrefill ? newPrompt : promptTokens,
      promptMilliseconds: estimatePrefill
          ? firstTokenMilliseconds
          : promptMilliseconds,
      predictedTokens: estimateDecode ? newPredicted : predictedTokens,
      predictedMilliseconds: estimateDecode
          ? outputMilliseconds
          : predictedMilliseconds,
      finalContextTokens: finalContextTokens,
      roundCount: roundCount,
      modelId: modelId,
      connectionId: connectionId,
      contextKey: contextKey,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cachedInputTokens: cachedInputTokens,
      prefillIsEstimated: estimatePrefill || prefillIsEstimated,
      decodeIsEstimated: estimateDecode || decodeIsEstimated,
    );
  }

  GenerationMetrics? _normalized() {
    final prefill = prefillTokensPerSecond != null;
    final decode = decodeTokensPerSecond != null;
    if (!prefill &&
        !decode &&
        inputTokens == null &&
        outputTokens == null &&
        cachedInputTokens == null &&
        finalContextTokens == null) {
      return null;
    }
    return GenerationMetrics(
      promptTokens: prefill ? promptTokens : null,
      promptMilliseconds: prefill ? promptMilliseconds : null,
      predictedTokens: decode ? predictedTokens : null,
      predictedMilliseconds: decode ? predictedMilliseconds : null,
      finalContextTokens: finalContextTokens,
      roundCount: roundCount,
      modelId: modelId,
      connectionId: connectionId,
      contextKey: contextKey,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cachedInputTokens: cachedInputTokens,
      prefillIsEstimated: prefill && prefillIsEstimated,
      decodeIsEstimated: decode && decodeIsEstimated,
    );
  }

  /// Sum matching phase counters/durations across tool rounds, excluding tool
  /// waits. Any missing round makes that aggregate unknown. Mixed native and
  /// estimated rounds are labelled estimated, never passed off as native.
  static GenerationMetrics? combineRounds(List<GenerationMetrics?> rounds) {
    if (rounds.isEmpty) return null;
    int? sumCounts(int? Function(GenerationMetrics) get) =>
        rounds.every((m) => m != null && get(m) != null)
        ? rounds.fold<int>(0, (n, m) => n + get(m!)!)
        : null;
    final prefill = rounds.every((m) => m?.prefillTokensPerSecond != null);
    final decode = rounds.every((m) => m?.decodeTokensPerSecond != null);
    return GenerationMetrics(
      promptTokens: prefill ? sumCounts((m) => m.promptTokens) : null,
      promptMilliseconds: prefill
          ? rounds.fold<double>(0, (n, m) => n + m!.promptMilliseconds!)
          : null,
      predictedTokens: decode ? sumCounts((m) => m.predictedTokens) : null,
      predictedMilliseconds: decode
          ? rounds.fold<double>(0, (n, m) => n + m!.predictedMilliseconds!)
          : null,
      finalContextTokens: rounds.last?.contextTokens,
      roundCount: rounds.length,
      inputTokens: sumCounts((m) => m.inputTokens),
      outputTokens: sumCounts((m) => m.outputTokens),
      cachedInputTokens: sumCounts((m) => m.cachedInputTokens),
      prefillIsEstimated: prefill && rounds.any((m) => m!.prefillIsEstimated),
      decodeIsEstimated: decode && rounds.any((m) => m!.decodeIsEstimated),
    )._normalized();
  }

  Map<String, Object> toJson() => {
    if (prefillTokensPerSecond != null) ...{
      'prompt_n': promptTokens!,
      'prompt_ms': promptMilliseconds!,
      'prefill_estimated': prefillIsEstimated,
    },
    if (decodeTokensPerSecond != null) ...{
      'predicted_n': predictedTokens!,
      'predicted_ms': predictedMilliseconds!,
      'decode_estimated': decodeIsEstimated,
    },
    if (finalContextTokens != null) 'context_tokens': finalContextTokens!,
    'round_count': roundCount,
    if (modelId != null) 'model_id': modelId!,
    if (connectionId != null) 'connection_id': connectionId!,
    if (contextKey != null) 'context_key': contextKey!,
    if (inputTokens != null) 'input_tokens': inputTokens!,
    if (outputTokens != null) 'output_tokens': outputTokens!,
    if (cachedInputTokens != null) 'cached_input_tokens': cachedInputTokens!,
  };

  static GenerationMetrics? fromJson(Object? value) {
    if (value is! Map) return null;
    return GenerationMetrics(
      promptTokens: tokenCount(value['prompt_n']),
      promptMilliseconds: _duration(value['prompt_ms']),
      predictedTokens: tokenCount(value['predicted_n']),
      predictedMilliseconds: _duration(value['predicted_ms']),
      finalContextTokens: tokenCount(value['context_tokens']),
      roundCount: tokenCount(value['round_count']) ?? 1,
      contextKey: value['context_key'] is String
          ? value['context_key'] as String
          : null,
      modelId: value['model_id'] is String ? value['model_id'] as String : null,
      connectionId: value['connection_id'] is String
          ? value['connection_id'] as String
          : null,
      inputTokens: tokenCount(value['input_tokens']),
      outputTokens: tokenCount(value['output_tokens']),
      cachedInputTokens: tokenCount(value['cached_input_tokens']),
      prefillIsEstimated: value['prefill_estimated'] == true,
      decodeIsEstimated: value['decode_estimated'] == true,
    )._normalized();
  }

  @override
  bool operator ==(Object other) =>
      other is GenerationMetrics &&
      promptTokens == other.promptTokens &&
      promptMilliseconds == other.promptMilliseconds &&
      predictedTokens == other.predictedTokens &&
      predictedMilliseconds == other.predictedMilliseconds &&
      contextKey == other.contextKey &&
      modelId == other.modelId &&
      connectionId == other.connectionId &&
      roundCount == other.roundCount &&
      finalContextTokens == other.finalContextTokens &&
      inputTokens == other.inputTokens &&
      outputTokens == other.outputTokens &&
      cachedInputTokens == other.cachedInputTokens &&
      prefillIsEstimated == other.prefillIsEstimated &&
      decodeIsEstimated == other.decodeIsEstimated;
  @override
  int get hashCode => Object.hash(
    promptTokens,
    promptMilliseconds,
    predictedTokens,
    predictedMilliseconds,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    prefillIsEstimated,
    decodeIsEstimated,
    finalContextTokens,
    roundCount,
    modelId,
    connectionId,
    contextKey,
  );
}
