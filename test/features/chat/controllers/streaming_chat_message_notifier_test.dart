import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';

void main() {
  group('StreamingChatMessageNotifier', () {
    test('notifies global listeners when a streaming message updates', () {
      final notifier = StreamingChatMessageNotifier();
      final message = ChatMessageRecord(
        id: 'a1',
        role: ChatRole.assistant,
        content: 'hello',
        createdAt: DateTime(2026, 3, 25, 11),
        sessionId: 's1',
      );

      expect(notifier, isA<Listenable>());

      var notificationCount = 0;
      (notifier as Listenable).addListener(() {
        notificationCount += 1;
      });

      notifier.update(message, isStreaming: true);

      expect(notificationCount, 1);
    });

    test('remove detaches the entry and notifies listeners', () {
      final notifier = StreamingChatMessageNotifier();
      final message = ChatMessageRecord(
        id: 'a1',
        role: ChatRole.assistant,
        content: 'hello',
        createdAt: DateTime(2026, 3, 25, 11),
        sessionId: 's1',
      );
      notifier.update(message, isStreaming: true);

      var notificationCount = 0;
      notifier.addListener(() {
        notificationCount += 1;
      });

      notifier.remove(message.id);

      expect(notifier.listenableFor(message.id), isNull);
      expect(notifier.hasNotifier(message.id), isFalse);
      expect(notificationCount, 1);
    });

    test('remove of an unknown id does not notify', () {
      final notifier = StreamingChatMessageNotifier();

      var notificationCount = 0;
      notifier.addListener(() {
        notificationCount += 1;
      });

      notifier.remove('missing');

      expect(notificationCount, 0);
    });
  });
}
