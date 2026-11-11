import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

void main() {
  late ChatProtocolClient client;
  setUp(() => client = ChatProtocolClient());
  tearDown(() => client.dio.close(force: true));

  Map<String, dynamic> request(
    AiProtocol protocol,
    ReasoningLevel level, {
    bool thinking = true,
    int? maxTokens,
  }) => client.requestBody(
    AiConnection(
      id: 'provider',
      name: 'Provider',
      protocol: protocol,
      baseUrl: 'https://example.com/v1',
      modelCapabilities: {
        'model': ModelCapabilities(supportsThinking: thinking),
      },
    ),
    'model',
    const [AiTurn(role: 'user', text: 'Hello')],
    reasoningLevel: level,
    maxTokens: maxTokens,
  );

  test('OpenAI uses the declared model capability and seven preferences', () {
    for (final level in ReasoningLevel.values) {
      final body = request(AiProtocol.openai, level);
      expect(
        body['reasoning_effort'],
        level == ReasoningLevel.auto ? null : level.effort,
      );
    }
    expect(
      request(AiProtocol.openai, ReasoningLevel.high, thinking: false),
      request(AiProtocol.openai, ReasoningLevel.auto, thinking: false),
    );
  });

  test('Anthropic uses adaptive thinking and effort for explicit levels', () {
    for (final level in ReasoningLevel.values) {
      final body = request(AiProtocol.anthropic, level, maxTokens: 2048);
      expect(
        body['thinking'],
        level == ReasoningLevel.off
            ? {'type': 'disabled'}
            : {'type': 'adaptive', 'display': 'summarized'},
      );
      expect(
        body['output_config'],
        level == ReasoningLevel.off || level == ReasoningLevel.auto
            ? null
            : {'effort': level.effort},
      );
      expect(body['max_tokens'], 2048);
      expect(body['temperature'], level == ReasoningLevel.off ? .7 : null);
    }
  });

  test(
    'Gemini uses thinking budgets and includes thoughts unless disabled',
    () {
      Map config(ReasoningLevel level) =>
          request(
                AiProtocol.gemini,
                level,
              )['generationConfig']['thinkingConfig']
              as Map;
      expect(config(ReasoningLevel.auto), {'includeThoughts': true});
      expect(config(ReasoningLevel.off), {
        'includeThoughts': false,
        'thinkingBudget': 0,
      });
      for (final (level, budget) in [
        (ReasoningLevel.low, 1000),
        (ReasoningLevel.medium, 2000),
        (ReasoningLevel.high, 8000),
        (ReasoningLevel.xhigh, 16000),
        (ReasoningLevel.max, 32000),
      ]) {
        expect(config(level), {
          'includeThoughts': true,
          'thinkingBudget': budget,
        });
      }
    },
  );
}
