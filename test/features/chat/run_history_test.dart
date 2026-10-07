import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/controllers/chat_runner.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';

void main() {
  test(
    'opaque provider parts and tool receipts survive durable round history',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final runs = GenerationRunRepository(db);
      final message = ChatMessageRecord(
        id: 'm',
        runId: 'r',
        role: ChatRole.assistant,
        content: 'Checking.\nAnswer.',
        createdAt: DateTime(2026),
      );
      final trace = [
        const AiTurn(
          role: 'assistant',
          text: 'Checking.',
          calls: [AiToolCall(id: 'c', name: 'clock', arguments: {})],
          providerParts: [
            {
              'thoughtSignature': 'opaque',
              'functionCall': {'name': 'clock', 'args': {}},
            },
          ],
        ),
        const AiTurn(
          role: 'tool',
          toolCallId: 'c',
          toolName: 'clock',
          text: '12:00',
        ),
        const AiTurn(role: 'assistant', text: 'Answer.'),
      ];
      await runs.begin('r', 'conversation', 'm', {});
      await runs.checkpoint(
        'r',
        message,
        trace: trace.map((t) => t.toJson()).toList(),
        finalText: 'Answer.',
        contextKey: 'exact-context',
      );
      expect(await runs.finalAnswer(message), isNull);
      await runs.finish('r', 'completed');
      final saved = await runs.history(message);
      final turn = AiTurn.fromJson(saved!['checkpoint']['trace'][0]);
      expect(turn.providerParts.single['thoughtSignature'], 'opaque');
      expect(turn.calls.single.id, 'c');
      expect(await runs.finalAnswer(message), 'Answer.');
      await runs.finish('r', 'toolBudget');
      expect(await runs.finalAnswer(message), 'Answer.');
      expect(await runs.history(message), isNull);
      expect(
        await runs.history(message.copyWith(content: 'Manually changed')),
        isNull,
      );
      expect(await db.query('SELECT id FROM tool_invocations'), isEmpty);
    },
  );
  test(
    'model, prompt, revision or context cropping invalidates continuation signatures',
    () {
      const a = Assistant(id: 'a', name: 'A');
      const c = AiConnection(
        id: 'c',
        name: 'C',
        protocol: AiProtocol.gemini,
        baseUrl: 'https://example.org',
      );
      ChatRunConfig config({
        AiConnection connection = c,
        Assistant assistant = a,
      }) => ChatRunConfig(
        assistant: assistant,
        connection: connection,
        key: 'secret-not-persisted',
        modelId: 'model',
        isLocal: false,
      );
      final user = ChatMessageRecord(
        id: 'u',
        role: ChatRole.user,
        content: 'Original',
        createdAt: DateTime(2026),
      );
      final key = ChatRunner.historyContextKey(config(), [user]);
      expect(ChatRunner.historyContextKey(config(), [user]), key);
      expect(
        ChatRunner.historyContextKey(config(), [
          user.copyWith(content: 'Edited'),
        ]),
        isNot(key),
      );
      expect(ChatRunner.historyContextKey(config(), []), isNot(key));
      expect(
        ChatRunner.historyContextKey(
          config(connection: c.changed({'protocol': 'openai'})),
          [user],
        ),
        isNot(key),
      );
      expect(
        ChatRunner.historyContextKey(
          config(assistant: a.changed({'revision': 2})),
          [user],
        ),
        isNot(key),
      );
    },
  );
}
