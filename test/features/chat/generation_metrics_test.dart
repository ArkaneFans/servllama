import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';

void main() {
  test('native phase speeds keep cached input separate from processing', () {
    final metrics = GenerationMetrics.fromResponse(
      timings: {
        'prompt_n': 20,
        'cache_n': 80,
        'prompt_ms': 100,
        'predicted_n': 10,
        'predicted_ms': 500,
      },
    )!;
    expect(metrics.inputTokens, 100);
    expect(metrics.cachedInputTokens, 80);
    expect(metrics.outputTokens, 10);
    expect(metrics.prefillTokensPerSecond, 200);
    expect(metrics.decodeTokensPerSecond, 20);
    expect(metrics.contextTokens, 110);
    expect(metrics.prefillIsEstimated, isFalse);
  });
  test('MNN input count is total; unknown cache stays unknown', () {
    final metrics = GenerationMetrics.fromResponse(
      timings: {
        'prompt_n': 100,
        'prompt_tokens_scope': 'total_input',
        'prompt_ms': 200,
      },
      usage: {
        'prompt_tokens': 100,
        'completion_tokens': 20,
        'prompt_tokens_details': {'cached_tokens': null},
      },
    )!;
    expect(metrics.inputTokens, 100);
    expect(metrics.cachedInputTokens, isNull);
    expect(metrics.prefillTokensPerSecond, 500);
  });
  test('zero nonfinite malformed durations never produce native rates', () {
    for (final value in [0, -1, double.infinity, double.nan, '30', null]) {
      final metrics = GenerationMetrics.fromTimings({
        'prompt_n': 20,
        'prompt_ms': value,
        'predicted_n': 0,
        'predicted_ms': 100,
      });
      expect(metrics?.prefillTokensPerSecond, isNull);
      expect(metrics?.decodeTokensPerSecond, isNull);
    }
    expect(GenerationMetrics.fromTimings({'prompt_per_second': 50}), isNull);
  });
  test('estimates use actual counts and exclude first decoded token', () {
    final metrics = const GenerationMetrics(
      inputTokens: 100,
      outputTokens: 11,
      cachedInputTokens: 20,
    ).withEstimates(firstTokenMilliseconds: 200, outputMilliseconds: 500);
    expect(metrics.prefillTokensPerSecond, 400);
    expect(metrics.decodeTokensPerSecond, 20);
    expect(metrics.prefillIsEstimated, isTrue);
    expect(metrics.decodeIsEstimated, isTrue);
    expect(GenerationMetrics.fromJson(metrics.toJson()), metrics);
    expect(
      const GenerationMetrics()
          .withEstimates(firstTokenMilliseconds: 100, outputMilliseconds: 500)
          .prefillTokensPerSecond,
      isNull,
    );
    expect(
      const GenerationMetrics(
        outputTokens: 1,
      ).withEstimates(outputMilliseconds: 100).decodeTokensPerSecond,
      isNull,
    );
  });
  test('fallback fills only unavailable phase and never overwrites native', () {
    final metrics = const GenerationMetrics(
      promptTokens: 10,
      promptMilliseconds: 20,
      inputTokens: 100,
      outputTokens: 11,
    ).withEstimates(firstTokenMilliseconds: 500, outputMilliseconds: 1000);
    expect(metrics.prefillTokensPerSecond, 500);
    expect(metrics.prefillIsEstimated, isFalse);
    expect(metrics.decodeTokensPerSecond, 10);
    expect(metrics.decodeIsEstimated, isTrue);
  });
  test(
    'tool rounds weight phase durations, preserve latest context and unknowns',
    () {
      const first = GenerationMetrics(
        promptTokens: 100,
        promptMilliseconds: 100,
        predictedTokens: 10,
        predictedMilliseconds: 1000,
        inputTokens: 150,
        outputTokens: 10,
        cachedInputTokens: 50,
      );
      const last = GenerationMetrics(
        promptTokens: 50,
        promptMilliseconds: 100,
        predictedTokens: 10,
        predictedMilliseconds: 500,
        inputTokens: 200,
        outputTokens: 11,
        decodeIsEstimated: true,
      );
      final combined = GenerationMetrics.combineRounds([first, last])!;
      expect(combined.prefillTokensPerSecond, 750);
      expect(combined.decodeTokensPerSecond, closeTo(13.333333, .0001));
      expect(combined.decodeIsEstimated, isTrue);
      expect(combined.inputTokens, 350);
      expect(combined.outputTokens, 21);
      expect(combined.cachedInputTokens, isNull);
      expect(combined.contextTokens, 211);
      expect(GenerationMetrics.fromJson(combined.toJson()), combined);
      expect(GenerationMetrics.combineRounds([first, null]), isNull);
      final missing = GenerationMetrics.combineRounds([
        first,
        const GenerationMetrics(outputTokens: 5),
      ])!;
      expect(missing.outputTokens, 15);
      expect(missing.contextTokens, isNull);
      expect(missing.prefillTokensPerSecond, isNull);
    },
  );
  test('last-round actual context survives missing earlier tool usage', () {
    final metrics = GenerationMetrics.combineRounds([
      null,
      const GenerationMetrics(inputTokens: 200, outputTokens: 20),
    ])!;
    expect(metrics.inputTokens, isNull);
    expect(metrics.contextTokens, 220);
    expect(GenerationMetrics.fromJson(metrics.toJson())!.contextTokens, 220);
  });
  test(
    'malformed huge/fractional counts and invalid cached usage stay unknown',
    () {
      for (final value in [1e300, 1.5, -1, double.infinity, double.nan]) {
        expect(GenerationMetrics.tokenCount(value), isNull);
      }
      expect(
        const GenerationMetrics()
            .withUsage(inputTokens: 10, cachedInputTokens: 20)
            .cachedInputTokens,
        isNull,
      );
      expect(
        const GenerationMetrics()
            .withUsage(inputTokens: 10, cachedInputTokens: 0)
            .cachedInputTokens,
        0,
      );
    },
  );
}
