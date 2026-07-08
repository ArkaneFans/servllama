import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/controllers/chat_conversation_controller.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

void main() {
  group('ChatConversationController visible window updates', () {
    late ChatSessionListController sessionList;
    late ChatConversationController controller;

    setUp(() {
      final repository = ChatSessionRepository(
        appSupportDirectory: Directory.systemTemp,
      );
      sessionList = ChatSessionListController(repository: repository);
      controller = ChatConversationController(
        repository: repository,
        sessionList: sessionList,
        messageWindowSize: 30,
      );
      sessionList.upsertSession(_session('s1', <String>['m1', 'm2']));
      controller.beginSessionSelection('s1');
      controller.syncVisibleMessagesFromFullMessages('s1', <ChatMessageRecord>[
        _message('m1', '第一条'),
        _message('m2', '第二条'),
      ]);
    });

    test('updateVisibleMessage replaces the record in place', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.updateVisibleMessage(_message('m2', '修改后'));

      expect(
        controller.visibleMessages.map((message) => message.content),
        <String>['第一条', '修改后'],
      );
      expect(notified, isTrue);
    });

    test('updateVisibleMessage ignores messages outside the window', () {
      final before = controller.visibleMessages;

      controller.updateVisibleMessage(_message('missing', '不存在'));

      expect(controller.visibleMessages, same(before));
    });

    test('removeVisibleMessage drops the record from the window', () {
      controller.removeVisibleMessage('m1');

      expect(
        controller.visibleMessages.map((message) => message.id),
        <String>['m2'],
      );

      // Removing an unknown id is a no-op.
      final before = controller.visibleMessages;
      controller.removeVisibleMessage('missing');
      expect(controller.visibleMessages, same(before));
    });
  });
}

ChatSessionRecord _session(String id, List<String> messageIds) {
  final timestamp = DateTime(2026, 3, 25, 10);
  return ChatSessionRecord(
    id: id,
    title: '会话',
    messageIds: messageIds,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

ChatMessageRecord _message(String id, String content) {
  return ChatMessageRecord(
    id: id,
    role: ChatRole.assistant,
    content: content,
    createdAt: DateTime(2026, 3, 25, 10, 30),
  );
}
