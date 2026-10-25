import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

void main() {
  test(
    'draft preparation never reads the history or message membership',
    () async {
      final repository = _DelayedHistory();
      final chat = ChatProvider(repository: repository);
      addTearDown(chat.dispose);
      await chat.prepareDrafts();
      expect(repository.reads, 0);
      expect(chat.selectedSession, isNull);
      expect(chat.isShowingDraftSession, isTrue);
    },
  );

  test(
    'initial history is single flight and preserves concurrent mutations',
    () async {
      final repository = _DelayedHistory();
      final controller = ChatSessionListController(repository: repository);
      addTearDown(controller.dispose);
      final first = controller.load();
      expect(identical(first, controller.load()), isTrue);
      expect(controller.isLoading, isTrue);
      controller.upsertSession(_session('new', 'new draft'));
      controller.upsertSession(_session('edited', 'new title'));
      controller.removeSessions({'deleted'});
      repository.ready.complete([
        _session('edited', 'old title'),
        _session('deleted', 'old deleted row'),
        _session('kept', 'old history'),
      ]);
      await first;
      expect(repository.reads, 1);
      expect(
        controller.sessions.map((s) => s.id),
        unorderedEquals(['new', 'edited', 'kept']),
      );
      expect(controller.findSession('edited')!.title, 'new title');
      await controller.load();
      expect(repository.reads, 1);
      expect(controller.isLoaded, isTrue);
    },
  );

  test(
    'disposing during history load suppresses late state notifications',
    () async {
      final repository = _DelayedHistory();
      final controller = ChatSessionListController(repository: repository);
      final loading = controller.load();
      controller.dispose();
      repository.ready.complete([_session('old', 'history')]);
      await loading;
      expect(controller.sessions, isEmpty);
    },
  );

  test(
    'app-owned chat can be disposed while its background history is pending',
    () async {
      final repository = _DelayedHistory();
      final chat = ChatProvider(repository: repository);
      final loading = chat.load(preloadMessages: false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.reads, 1);
      chat.dispose();
      repository.ready.complete([_session('old', 'history')]);
      await loading;
      expect(chat.sessions, isEmpty);
    },
  );
}

ChatSessionRecord _session(String id, String title) => ChatSessionRecord(
  id: id,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _DelayedHistory extends ChatSessionRepository {
  final ready = Completer<List<ChatSessionRecord>>();
  int reads = 0;
  @override
  Future<List<ChatSessionRecord>> loadSessions() {
    reads++;
    return ready.future;
  }
}
