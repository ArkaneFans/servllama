import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens server from drawer and returns to chat', (tester) async {
    final repository = _FakeChatSessionRepository(
      sessions: <ChatSessionRecord>[
        _session(id: 's1', title: '会话一'),
        _session(id: 's2', title: '会话二'),
      ],
    );
    final apiClient = _FakeLlamaChatApiClient(
      models: <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
      ],
    );
    final chatProvider = ChatProvider(
      repository: repository,
      apiClient: apiClient,
    );
    chatProvider.updateServerState(
      baseUrl: 'http://127.0.0.1:8080',
      isServerRunning: true,
    );
    await chatProvider.load();

    final serverService = _FakeLlamaServerService();
    final serverProvider = ServerProvider(
      serverService: serverService,
      settingsLoader: _FixedServerLaunchSettingsLoader(
        const ServerLaunchSettings(),
      ),
      modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
    );
    addTearDown(() {
      serverProvider.dispose();
      serverService.dispose();
    });

    await tester.pumpWidget(
      _TestApp(chatProvider: chatProvider, serverProvider: serverProvider),
    );
    await tester.pump();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsNothing);
    expect(find.text('原型'), findsNothing);
    expect(find.text('聊天'), findsNothing);
    expect(find.text('服务器'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('drawer_search_box')), findsOneWidget);
    expect(find.byKey(const Key('drawer_history_button')), findsOneWidget);
    expect(find.byKey(const Key('drawer_server_action')), findsOneWidget);
    expect(find.byKey(const Key('drawer_settings_action')), findsOneWidget);
    expect(find.byKey(const Key('drawer_server_status_badge')), findsOneWidget);
    expect(find.byKey(const Key('chat_session_item_s1')), findsOneWidget);
    expect(find.byKey(const Key('chat_session_item_s2')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('drawer_search_input')), '会话一');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_session_item_s1')), findsOneWidget);
    expect(find.byKey(const Key('chat_session_item_s2')), findsNothing);

    await tester.tap(find.byKey(const Key('drawer_server_action')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('服务器')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat_session_item_s2')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('会话二')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.longPress(find.byKey(const Key('chat_session_item_s2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('修改名称'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  });

  testWidgets('keeps chat reachable after entering server with no sessions', (
    tester,
  ) async {
    final repository = _FakeChatSessionRepository(
      sessions: <ChatSessionRecord>[],
    );
    final apiClient = _FakeLlamaChatApiClient(
      models: const <ChatModelOption>[],
    );
    final chatProvider = ChatProvider(
      repository: repository,
      apiClient: apiClient,
    );
    await chatProvider.load();

    final serverService = _FakeLlamaServerService();
    final serverProvider = ServerProvider(
      serverService: serverService,
      settingsLoader: _FixedServerLaunchSettingsLoader(
        const ServerLaunchSettings(),
      ),
      modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
    );
    addTearDown(() {
      serverProvider.dispose();
      serverService.dispose();
    });

    await tester.pumpWidget(
      _TestApp(chatProvider: chatProvider, serverProvider: serverProvider),
    );
    await tester.pump();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('暂无会话'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.byKey(const Key('drawer_settings_action')), findsOneWidget);

    await tester.tap(find.byKey(const Key('drawer_server_action')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('服务器')),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
      findsOneWidget,
    );
  });

  testWidgets('opens chat history page from drawer history button', (
    tester,
  ) async {
    final repository = _FakeChatSessionRepository(
      sessions: <ChatSessionRecord>[_session(id: 's1', title: '会话一')],
    );
    final chatProvider = ChatProvider(
      repository: repository,
      apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
    );
    await chatProvider.load();

    final serverService = _FakeLlamaServerService();
    final serverProvider = ServerProvider(
      serverService: serverService,
      settingsLoader: _FixedServerLaunchSettingsLoader(
        const ServerLaunchSettings(),
      ),
      modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
    );
    addTearDown(() {
      serverProvider.dispose();
      serverService.dispose();
    });

    await tester.pumpWidget(
      _TestApp(chatProvider: chatProvider, serverProvider: serverProvider),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_history_button')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('聊天历史')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('history_page_search_input')), findsOneWidget);
  });

  testWidgets('opens settings page from drawer settings action', (
    tester,
  ) async {
    final repository = _FakeChatSessionRepository(
      sessions: <ChatSessionRecord>[_session(id: 's1', title: '会话一')],
    );
    final chatProvider = ChatProvider(
      repository: repository,
      apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
    );
    await chatProvider.load();

    final serverService = _FakeLlamaServerService();
    final serverProvider = ServerProvider(
      serverService: serverService,
      settingsLoader: _FixedServerLaunchSettingsLoader(
        const ServerLaunchSettings(),
      ),
      modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
    );
    addTearDown(() {
      serverProvider.dispose();
      serverService.dispose();
    });

    await tester.pumpWidget(
      _TestApp(chatProvider: chatProvider, serverProvider: serverProvider),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_settings_action')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('设置')),
      findsOneWidget,
    );
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('应用语言'), findsOneWidget);
  });

  testWidgets('selecting a session from history page closes the drawer', (
    tester,
  ) async {
    final repository = _FakeChatSessionRepository(
      sessions: <ChatSessionRecord>[
        _session(id: 's1', title: '会话一'),
        _session(id: 's2', title: '会话二'),
      ],
    );
    final chatProvider = ChatProvider(
      repository: repository,
      apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
    );
    await chatProvider.load();

    final serverService = _FakeLlamaServerService();
    final serverProvider = ServerProvider(
      serverService: serverService,
      settingsLoader: _FixedServerLaunchSettingsLoader(
        const ServerLaunchSettings(),
      ),
      modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
    );
    addTearDown(() {
      serverProvider.dispose();
      serverService.dispose();
    });

    await tester.pumpWidget(
      _TestApp(chatProvider: chatProvider, serverProvider: serverProvider),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer_history_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_session_item_s2')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('会话二')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('drawer_search_box')), findsNothing);
    expect(find.text('服务器'), findsNothing);
    expect(find.text('设置'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.chatProvider, required this.serverProvider});

  final ChatProvider chatProvider;
  final ServerProvider serverProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppThemeModeProvider>(
          create: (_) => AppThemeModeProvider(),
        ),
        ChangeNotifierProvider<AppLocaleProvider>(
          create: (_) => AppLocaleProvider(),
        ),
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
      ],
      child: const MaterialApp(home: MainScaffold()),
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
  _FakeLlamaChatApiClient({required this.models})
    : super(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
      );

  List<ChatModelOption> models;

  @override
  Future<List<ChatModelOption>> fetchModels() async =>
      List<ChatModelOption>.from(models);

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
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _FakeLlamaServerService implements LlamaServerService {
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => false;

  @override
  Future<bool> copyBinaryFromAssets() async => true;

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async => true;

  @override
  Future<bool> stopServer() async => true;
}

class _FixedModelStoragePaths extends ModelStoragePaths {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
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
