import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';
import 'package:servllama/features/chat/widgets/chat_session_drawer_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatSessionDrawerSection', () {
    testWidgets('shows loading indicator while sessions are loading', (
      tester,
    ) async {
      final repository = _PendingChatSessionRepository();
      final provider = ChatProvider(
        repository: repository,
        apiClient: _FakeLlamaChatApiClient(),
      );

      unawaited(provider.load());

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.complete(<ChatSessionRecord>[
        _session(id: 's1', title: '会话一'),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('会话一'), findsOneWidget);
    });

    testWidgets('filters sessions with fuzzy query and shows empty state', (
      tester,
    ) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: 'Flutter 性能'),
          _session(id: 's2', title: '量子计算'),
        ],
      );

      provider.updateSessionQuery('Flutter');

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pump();

      expect(find.byKey(const Key('chat_session_item_s1')), findsOneWidget);
      expect(find.byKey(const Key('chat_session_item_s2')), findsNothing);

      provider.updateSessionQuery('不存在');
      await tester.pump();

      expect(find.text('未找到匹配对话'), findsOneWidget);
    });

    testWidgets(
      'starts with no selected history session and selects one on tap',
      (tester) async {
        final provider = await _createProvider(
          sessions: <ChatSessionRecord>[
            _session(id: 's1', title: '会话一'),
            _session(id: 's2', title: '会话二'),
          ],
        );

        var openedChat = false;
        await tester.pumpWidget(
          _TestHost(
            provider: provider,
            onOpenChat: () {
              openedChat = true;
            },
          ),
        );
        await tester.pump();

        final sessionOneInk = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(const Key('chat_session_item_s1')),
            matching: find.byType(Ink),
          ),
        );
        final sessionTwoInk = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(const Key('chat_session_item_s2')),
            matching: find.byType(Ink),
          ),
        );

        expect(
          (sessionOneInk.decoration! as BoxDecoration).color,
          Colors.transparent,
        );
        expect(
          (sessionTwoInk.decoration! as BoxDecoration).color,
          Colors.transparent,
        );

        await tester.tap(find.byKey(const Key('chat_session_item_s2')));
        await tester.pumpAndSettle();

        expect(provider.selectedSession?.id, 's2');
        final selectedSessionInk = tester.widget<Ink>(
          find.descendant(
            of: find.byKey(const Key('chat_session_item_s2')),
            matching: find.byType(Ink),
          ),
        );
        expect(
          (selectedSessionInk.decoration! as BoxDecoration).color,
          isNot(Colors.transparent),
        );
        expect(openedChat, isTrue);
      },
    );

    testWidgets('switches and loads session before drawer close completes', (
      tester,
    ) async {
      final closeCompleter = Completer<void>();
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话一',
            messages: <ChatMessageRecord>[
              _message(id: 'old', content: '旧会话消息'),
            ],
          ),
          _session(
            id: 's2',
            title: '会话二',
            messages: <ChatMessageRecord>[
              _message(id: 'new', content: '新会话消息'),
            ],
          ),
        ],
      );
      await provider.switchSession('s1');

      await tester.pumpWidget(
        _TestHost(provider: provider, onOpenChat: () => closeCompleter.future),
      );
      await tester.pump();

      expect(provider.selectedSession?.id, 's1');
      expect(provider.visibleMessages.single.content, '旧会话消息');

      await tester.tap(find.byKey(const Key('chat_session_item_s2')));
      await tester.pump();

      expect(closeCompleter.isCompleted, isFalse);
      expect(provider.selectedSession?.id, 's2');
      await tester.pumpAndSettle();

      expect(closeCompleter.isCompleted, isFalse);
      expect(provider.visibleMessages.single.content, '新会话消息');

      closeCompleter.complete();
    });

    testWidgets('renames a session from the action sheet', (tester) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[_session(id: 's1', title: '旧名称')],
      );

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('chat_session_item_s1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('修改名称'), findsOneWidget);

      await tester.tap(find.text('修改名称'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '新名称');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(provider.selectedSession, isNull);
      expect(provider.sessions.single.title, '新名称');
      expect(find.text('新名称'), findsOneWidget);
    });

    testWidgets('deletes the selected session and returns to blank state', (
      tester,
    ) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ],
      );

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pump();

      await tester.tap(find.byKey(const Key('chat_session_item_s2')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const Key('chat_session_item_s2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('删除'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(provider.sessions.map((session) => session.id), <String>['s1']);
      expect(provider.selectedSession, isNull);
      final remainingSessionInk = tester.widget<Ink>(
        find.descendant(
          of: find.byKey(const Key('chat_session_item_s1')),
          matching: find.byType(Ink),
        ),
      );
      expect(
        (remainingSessionInk.decoration! as BoxDecoration).color,
        Colors.transparent,
      );
      expect(find.byKey(const Key('chat_session_item_s2')), findsNothing);
    });
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.provider, this.onOpenChat});

  final ChatProvider provider;
  final FutureOr<void> Function()? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: SafeArea(
              child: SizedBox(
                height: 480,
                child: ChatSessionDrawerSection(
                  presentationContext: context,
                  isChatSelected: true,
                  onOpenChat: onOpenChat ?? () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FakeChatSessionRepository extends ChatSessionRepository {
  _FakeChatSessionRepository({required this.sessions})
    : super(appSupportDirectory: Directory.systemTemp);

  List<ChatSessionRecord> sessions;
  final Map<String, ChatMessageRecord> messages = <String, ChatMessageRecord>{};

  @override
  Future<List<ChatSessionRecord>> loadSessions() async {
    final loadedSessions = sessions.map(_migrateSession).toList();
    sessions = List<ChatSessionRecord>.from(loadedSessions);
    return loadedSessions;
  }

  @override
  Future<void> saveSession(ChatSessionRecord session) async {
    final cleanSession = _migrateSession(session);
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = cleanSession;
    } else {
      sessions.add(cleanSession);
    }
  }

  @override
  Future<void> warmUpMessageStore() async {}

  @override
  Future<void> saveMessage(ChatMessageRecord message) async {
    messages[message.id] = message;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord session, {
    int limit = 30,
  }) async {
    final start = session.messageIds.length > limit
        ? session.messageIds.length - limit
        : 0;
    return _messagesByIds(session.messageIds.skip(start));
  }

  @override
  Future<List<ChatMessageRecord>> loadInitialMessages(
    ChatSessionRecord session, {
    int minMessages = ChatSessionRepository.defaultInitialMessageMin,
    int maxMessages = ChatSessionRepository.defaultInitialMessageMax,
    int textBudget = ChatSessionRepository.defaultInitialTextBudget,
  }) async {
    return loadRecentMessages(session, limit: maxMessages);
  }

  @override
  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    return _messagesByIds(session.messageIds);
  }

  ChatSessionRecord _migrateSession(ChatSessionRecord session) {
    if (session.legacyMessages.isEmpty) {
      return session;
    }
    final savedMessages = session.legacyMessages
        .map((message) => message.copyWith(sessionId: session.id))
        .toList(growable: false);
    for (final message in savedMessages) {
      messages[message.id] = message;
    }
    return session.copyWith(
      messageIds: savedMessages
          .map((message) => message.id)
          .toList(growable: false),
      legacyMessages: const <ChatMessageRecord>[],
    );
  }

  List<ChatMessageRecord> _messagesByIds(Iterable<String> messageIds) {
    return messageIds
        .map((messageId) => messages[messageId])
        .whereType<ChatMessageRecord>()
        .toList(growable: false);
  }
}

class _PendingChatSessionRepository extends ChatSessionRepository {
  _PendingChatSessionRepository()
    : super(appSupportDirectory: Directory.systemTemp);

  final Completer<List<ChatSessionRecord>> _completer =
      Completer<List<ChatSessionRecord>>();
  final List<ChatSessionRecord> sessions = <ChatSessionRecord>[];
  final Map<String, ChatMessageRecord> messages = <String, ChatMessageRecord>{};

  void complete(List<ChatSessionRecord> values) {
    sessions
      ..clear()
      ..addAll(values);
    _completer.complete(List<ChatSessionRecord>.from(values));
  }

  @override
  Future<List<ChatSessionRecord>> loadSessions() async {
    final loadedSessions = await _completer.future;
    final migratedSessions = loadedSessions.map(_migrateSession).toList();
    sessions
      ..clear()
      ..addAll(migratedSessions);
    return migratedSessions;
  }

  @override
  Future<void> saveSession(ChatSessionRecord session) async {
    final cleanSession = _migrateSession(session);
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = cleanSession;
    } else {
      sessions.add(cleanSession);
    }
  }

  @override
  Future<void> warmUpMessageStore() async {}

  @override
  Future<void> saveMessage(ChatMessageRecord message) async {
    messages[message.id] = message;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord session, {
    int limit = 30,
  }) async {
    final start = session.messageIds.length > limit
        ? session.messageIds.length - limit
        : 0;
    return _messagesByIds(session.messageIds.skip(start));
  }

  @override
  Future<List<ChatMessageRecord>> loadInitialMessages(
    ChatSessionRecord session, {
    int minMessages = ChatSessionRepository.defaultInitialMessageMin,
    int maxMessages = ChatSessionRepository.defaultInitialMessageMax,
    int textBudget = ChatSessionRepository.defaultInitialTextBudget,
  }) async {
    return loadRecentMessages(session, limit: maxMessages);
  }

  @override
  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    return _messagesByIds(session.messageIds);
  }

  ChatSessionRecord _migrateSession(ChatSessionRecord session) {
    if (session.legacyMessages.isEmpty) {
      return session;
    }
    final savedMessages = session.legacyMessages
        .map((message) => message.copyWith(sessionId: session.id))
        .toList(growable: false);
    for (final message in savedMessages) {
      messages[message.id] = message;
    }
    return session.copyWith(
      messageIds: savedMessages
          .map((message) => message.id)
          .toList(growable: false),
      legacyMessages: const <ChatMessageRecord>[],
    );
  }

  List<ChatMessageRecord> _messagesByIds(Iterable<String> messageIds) {
    return messageIds
        .map((messageId) => messages[messageId])
        .whereType<ChatMessageRecord>()
        .toList(growable: false);
  }
}

class _FakeLlamaChatApiClient extends LlamaChatApiClient {
  _FakeLlamaChatApiClient()
    : super(settingsLoader: _FixedServerLaunchSettingsLoader());

  @override
  Future<List<ChatModelOption>> fetchModels() async =>
      const <ChatModelOption>[];

  @override
  Future<void> loadModel(String modelId) async {}

  @override
  Stream<ChatStreamDelta> streamChatCompletion({
    required String modelId,
    required List<ChatMessageRecord> messages,
    required CancelToken cancelToken,
  }) {
    return const Stream<ChatStreamDelta>.empty();
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();
}

Future<ChatProvider> _createProvider({
  required List<ChatSessionRecord> sessions,
}) async {
  final provider = ChatProvider(
    repository: _FakeChatSessionRepository(sessions: sessions),
    apiClient: _FakeLlamaChatApiClient(),
  );
  await provider.load();
  return provider;
}

ChatSessionRecord _session({
  required String id,
  required String title,
  List<ChatMessageRecord> messages = const <ChatMessageRecord>[],
}) {
  final timestamp = DateTime(2026, 3, 25, 10);
  return ChatSessionRecord(
    id: id,
    title: title,
    messages: messages,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

ChatMessageRecord _message({required String id, required String content}) {
  return ChatMessageRecord(
    id: id,
    role: ChatRole.user,
    content: content,
    createdAt: DateTime(2026, 3, 25, 10),
  );
}
