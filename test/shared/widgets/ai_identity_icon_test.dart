import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';

void main() {
  test('recognizes model families through namespaces and quantization', () {
    for (final entry in {
      'Qwen/Qwen3-8B-Q4_K_M.gguf': 'qwen',
      'community/DeepSeek-R1-Distill-Qwen-7B': 'deepseek',
      'meta-llama/Llama-3.3-70B-Instruct': 'meta',
      'google/gemma-3-4b': 'gemma',
      'claude-sonnet-4': 'claude',
      'kimi-k2': 'kimi',
      'moonshot-v1-8k': 'moonshot',
      'gpt-4.1-mini': 'openai',
      'microsoft/Phi-4-mini': 'microsoft',
    }.entries) {
      expect(AiBrand.model(entry.key), entry.value);
    }
    expect(AiBrand.model('llamazing'), isNull);
    expect(AiBrand.model('custom-model'), isNull);
  });

  test('provider resolution uses stable identities without URLs', () {
    expect(AiBrand.provider(id: 'preset:siliconflow'), 'siliconcloud');
    expect(AiBrand.provider(name: 'Local proxy'), isNull);
  });

  test('provider names resolve brands without requiring an exact match', () {
    for (final entry in {
      'OpenAI compatible': 'openai',
      'My OpenAI Proxy': 'openai',
      'GPT-4 Proxy': 'openai',
      'Google Gemini': 'gemini',
      'Claude API': 'claude',
      '硅基流动': 'siliconcloud',
      '阿里云百炼': 'alibabacloud',
      '智谱 AI': 'zhipu',
      '月之暗面': 'kimi',
      'OpenRouter Proxy': 'openrouter',
      'Local DeepSeek': 'deepseek',
    }.entries) {
      expect(AiBrand.provider(name: entry.key), entry.value);
    }

    expect(AiBrand.provider(name: 'local proxy'), isNull);
    expect(AiBrand.provider(name: 'myowncloud'), isNull);
  });

  testWidgets('bundled brands render in both brightness modes and fall back', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: Wrap(
              children: [
                AiIdentityIcon(model: 'Qwen3-8B'),
                AiIdentityIcon(providerId: 'preset:openai'),
                AiIdentityIcon(model: 'custom-model', local: true),
                AiIdentityIcon(providerName: 'Unknown'),
                AiIdentityIcon(providerId: 'custom-provider'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget);
      expect(find.text('U'), findsOneWidget);
      expect(find.byIcon(Icons.memory_outlined), findsNothing);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
