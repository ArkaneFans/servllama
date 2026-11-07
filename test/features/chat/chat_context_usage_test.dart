import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_context_usage.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';

void main() {
  final response = ChatMessageRecord(
    id: 'response',
    role: ChatRole.assistant,
    content: 'Done',
    createdAt: DateTime(2026),
    generationMetrics: const GenerationMetrics(
      inputTokens: 1800,
      cachedInputTokens: 1600,
      outputTokens: 200,
      modelId: 'm',
      connectionId: 'local',
      contextKey: 'prefix',
    ),
  );
  int? read(
    List<ChatMessageRecord> messages, {
    String model = 'm',
    String connection = 'local',
    String key = 'prefix',
    bool draft = false,
    bool sending = false,
  }) => ChatContextUsage.currentTokens(
    messages: messages,
    modelId: model,
    connectionId: connection,
    expectedContextKey: key,
    hasDraft: draft,
    isSending: sending,
  );

  test('uses one actual response including cache, never conversation sum', () {
    expect(read([response, response.copyWith(id: 'latest')]), 2000);
    final usage = ChatContextUsage(
      usedTokens: read([response]),
      capacityTokens: 4000,
    );
    expect(usage.percentageLabel, '50%');
    expect(usage.progress, .5);
  });
  test('tool rounds use last context, not aggregate input/output usage', () {
    final metrics = GenerationMetrics.combineRounds([
      const GenerationMetrics(inputTokens: 1000, outputTokens: 100),
      const GenerationMetrics(inputTokens: 1500, outputTokens: 200),
    ])!.withIdentity(modelId: 'm', connectionId: 'local', contextKey: 'prefix');
    expect(read([response.copyWith(generationMetrics: metrics)]), 1700);
  });
  test(
    'missing usage/capacity and over-capacity occupancy stay ASCII dash',
    () {
      for (final usage in [
        const ChatContextUsage(),
        const ChatContextUsage(usedTokens: 100),
        const ChatContextUsage(capacityTokens: 4000),
        const ChatContextUsage(usedTokens: 100, capacityTokens: 0),
        const ChatContextUsage(usedTokens: -1, capacityTokens: 4000),
        const ChatContextUsage(usedTokens: 4001, capacityTokens: 4000),
      ]) {
        expect(usage.percentageLabel, '-');
        expect(usage.progress, 0);
      }
      expect(
        const ChatContextUsage(
          usedTokens: 0,
          capacityTokens: 4000,
        ).percentageLabel,
        '0%',
      );
    },
  );
  test('new conversation, draft, generation and trailing user are unknown', () {
    expect(read([]), isNull);
    expect(read([response], draft: true), isNull);
    expect(read([response], sending: true), isNull);
    expect(read([response, response.copyWith(role: ChatRole.user)]), isNull);
  });
  test('model/provider switches and changed full history invalidate usage', () {
    expect(read([response], model: 'other'), isNull);
    expect(read([response], connection: 'other'), isNull);
    expect(read([response], key: 'edited-prefix'), isNull);
    expect(read([response.copyWith(clearGenerationMetrics: true)]), isNull);
    expect(
      read([
        response.copyWith(
          generationMetrics: const GenerationMetrics(
            inputTokens: 5,
            outputTokens: 5,
          ),
        ),
      ]),
      isNull,
    );
  });
  test('revision selection takes only that revision measurement', () {
    final revised = response.copyWith(
      generationMetrics: const GenerationMetrics(
        inputTokens: 1000,
        outputTokens: 100,
        modelId: 'm',
        connectionId: 'local',
        contextKey: 'prefix',
      ),
    );
    expect(read([revised]), 1100);
    expect(read([response]), 2000);
  });
}
