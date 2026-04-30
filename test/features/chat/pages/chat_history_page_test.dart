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
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatHistoryPage', () {
    testWidgets('filters sessions by fuzzy search query', (tester) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: 'Flutter 性能'),
          _session(id: 's2', title: '量子计算'),
        ],
      );

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('Flutter 性能'), findsOneWidget);
      expect(find.text('量子计算'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('history_page_search_input')),
        'Flutter',
      );
      await tester.pumpAndSettle();

      expect(find.text('Flutter 性能'), findsOneWidget);
      expect(find.text('量子计算'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('history_page_search_input')),
        '不存在',
      );
      await tester.pumpAndSettle();

      expect(find.text('未找到匹配会话'), findsOneWidget);
    });

    testWidgets('opens selected session and returns to previous page', (
      tester,
    ) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatHistoryPage(),
                        ),
                      );
                    },
                    child: const Text('打开历史'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开历史'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_session_item_s2')));
      await tester.pumpAndSettle();

      expect(find.text('打开历史'), findsOneWidget);
      expect(provider.selectedSession?.id, 's2');
    });

    testWidgets('calls onSessionOpened after selecting session', (
      tester,
    ) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ],
      );
      var callbackCount = 0;

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatHistoryPage(
                            onSessionOpened: () {
                              callbackCount += 1;
                            },
                          ),
                        ),
                      );
                    },
                    child: const Text('打开历史'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开历史'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_session_item_s2')));
      await tester.pumpAndSettle();

      expect(callbackCount, 1);
      expect(provider.selectedSession?.id, 's2');
    });

    testWidgets(
      'does not highlight the currently selected session in history page',
      (tester) async {
        final provider = await _createProvider(
          sessions: <ChatSessionRecord>[
            _session(id: 's1', title: '会话一'),
            _session(id: 's2', title: '会话二'),
          ],
        );
        provider.selectSession('s2');

        await tester.pumpWidget(_TestHost(provider: provider));
        await tester.pumpAndSettle();

        final colorScheme = Theme.of(
          tester.element(find.byType(ChatHistoryPage)),
        ).colorScheme;
        final sessionInk = tester.widget<Ink>(
          find.ancestor(
            of: find.byKey(const Key('history_session_item_s2')),
            matching: find.byType(Ink),
          ),
        );
        final sessionTitle = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('history_session_item_s2')),
            matching: find.text('会话二'),
          ),
        );

        expect(provider.selectedSession?.id, 's2');
        expect(
          (sessionInk.decoration! as BoxDecoration).color,
          colorScheme.surfaceContainerLowest,
        );
        expect(sessionTitle.style?.color, colorScheme.onSurface);
        expect(sessionTitle.style?.fontWeight, FontWeight.w500);
      },
    );

    testWidgets('renames session from history page', (tester) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[_session(id: 's1', title: '旧名称')],
      );

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_session_menu_s1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('修改名称'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '新名称');
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();

      expect(provider.sessions.single.title, '新名称');
      expect(find.text('新名称'), findsOneWidget);
    });

    testWidgets('deletes session from history page', (tester) async {
      final provider = await _createProvider(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ],
      );

      await tester.pumpWidget(_TestHost(provider: provider));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('history_session_menu_s2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(provider.sessions.map((session) => session.id), <String>['s1']);
      expect(find.byKey(const Key('history_session_item_s2')), findsNothing);
    });
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.provider});

  final ChatProvider provider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatProvider>.value(
      value: provider,
      child: const MaterialApp(home: ChatHistoryPage()),
    );
  }
}

class _FakeChatSessionRepository extends ChatSessionRepository {
  _FakeChatSessionRepository({required this.sessions})
    : super(appSupportDirectory: Directory.systemTemp);

  List<ChatSessionRecord> sessions;

  @override
  Future<List<ChatSessionRecord>> loadSessions() async =>
      List<ChatSessionRecord>.from(sessions);

  @override
  Future<void> saveSession(ChatSessionRecord session) async {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((session) => session.id == sessionId);
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

ChatSessionRecord _session({required String id, required String title}) {
  final timestamp = DateTime(2026, 3, 25, 10);
  return ChatSessionRecord(
    id: id,
    title: title,
    messages: const <ChatMessageRecord>[],
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
