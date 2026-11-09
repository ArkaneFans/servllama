import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';

import '../../../support/chat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatFixture fixture;
  setUp(() async {
    fixture = ChatFixture();
    await fixture.initialize();
  });
  tearDown(() => fixture.close());

  test(
    'sending commits the question, streamed reasoning and reply together with ownership',
    () async {
      final chat = fixture.chat;
      fixture.protocol.events = const [
        AiEvent(reasoning: 'Think'),
        AiEvent(text: 'First '),
        AiEvent(text: 'reply'),
        AiEvent(stopReason: 'stop'),
      ];
      chat.updateDraft('Question');
      await chat.sendMessage(chat.currentDraft);
      final session = chat.selectedSession!;
      final messages = await fixture.repository.loadAllMessages(session);
      expect(session.assistantId, 'assistant');
      expect(messages.map((m) => m.content), ['Question', 'First reply']);
      expect(messages.last.reasoningContent, 'Think');
      expect(messages.last.modelName, 'model-one');
      expect(chat.currentDraft, isEmpty);
      expect(chat.isSending, isFalse);
      expect(fixture.protocol.models, ['model-one']);
      expect(
        (await fixture.database.query(
          'SELECT state FROM generation_runs',
        )).single.read<String>('state'),
        'completed',
      );

      await chat.sendMessage('Follow-up');
      expect(fixture.protocol.inputs.last.map((t) => t.role), [
        'user',
        'assistant',
        'user',
      ]);
      expect((await fixture.repository.loadSessions()).single.id, session.id);
    },
  );

  test(
    'concurrent sends have one owner and cancellation saves the partial reply',
    () async {
      fixture.protocol.events = const [AiEvent(text: 'Partial reply')];
      fixture.protocol.blocked = Completer<void>();
      final sending = fixture.chat.sendMessage('Question');
      await fixture.protocol.started.future;
      await fixture.chat.sendMessage('Duplicate tap');
      expect(fixture.protocol.models, hasLength(1));
      fixture.chat.cancelStreaming();
      await sending;
      expect(fixture.chat.isSending, isFalse);
      final messages = await fixture.repository.loadAllMessages(
        fixture.chat.selectedSession!,
      );
      expect(messages.map((m) => m.content), ['Question', 'Partial reply']);
      expect(
        (await fixture.database.query(
          'SELECT state FROM generation_runs',
        )).single.read<String>('state'),
        'cancelled',
      );
    },
  );

  test(
    'provider failure preserves the question and makes another send possible',
    () async {
      fixture.protocol.events = const [];
      fixture.protocol.error = StateError('Provider unavailable');
      await fixture.chat.sendMessage('Keep this question');
      expect(fixture.chat.isSending, isFalse);
      expect(fixture.chat.visibleMessages.first.content, 'Keep this question');
      fixture.protocol.error = null;
      fixture.protocol.events = const [
        AiEvent(text: 'Recovered'),
        AiEvent(stopReason: 'stop'),
      ];
      await fixture.chat.sendMessage('Try again');
      expect(fixture.chat.visibleMessages.last.content, 'Recovered');
    },
  );

  test(
    'history opens a recent window and loads earlier messages on demand',
    () async {
      final timestamp = DateTime(2026);
      await fixture.repository.saveSession(
        ChatSessionRecord(
          id: 'history',
          title: 'Long conversation',
          assistantId: 'assistant',
          createdAt: timestamp,
          updatedAt: timestamp,
          messages: List.generate(
            65,
            (i) => ChatMessageRecord(
              id: 'message-$i',
              role: i.isEven ? ChatRole.user : ChatRole.assistant,
              content: 'Message $i',
              createdAt: timestamp.add(Duration(minutes: i)),
            ),
          ),
        ),
      );
      final restored = ChatProvider(
        repository: fixture.repository,
        protocolClient: fixture.protocol,
      );
      addTearDown(restored.dispose);
      restored.bind(fixture.assistants, fixture.runtime);
      await restored.load();
      await restored.selectSession('history');
      expect(restored.visibleMessages.last.id, 'message-64');
      expect(restored.visibleMessages.length, lessThan(65));
      await restored.loadOlderMessages();
      expect(restored.visibleMessages.first.id, 'message-5');
      expect(restored.visibleMessages.last.id, 'message-64');
    },
  );
}
