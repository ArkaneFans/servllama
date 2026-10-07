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

  test(
    'provider resolution uses stable identities and real host boundaries',
    () {
      expect(AiBrand.provider(id: 'preset:siliconflow'), 'siliconcloud');
      expect(AiBrand.provider(url: 'https://api.openai.com/v1'), 'openai');
      expect(
        AiBrand.provider(url: 'https://openai.com.example.net/v1'),
        isNull,
      );
      expect(AiBrand.provider(url: 'https://example.net/openai.com'), isNull);
      expect(AiBrand.provider(name: 'Local proxy'), isNull);
    },
  );

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
                AiIdentityIcon(model: 'unknown', local: true),
                AiIdentityIcon(providerName: 'Unknown'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.memory_outlined), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
