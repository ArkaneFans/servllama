import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/core/services/engines/llama_cpp_engine_adapter.dart';

import '../../../support/stub_engine_adapter.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatPage', () {
    setUp(() {
      AppL10nService.instance.setLocale(const Locale('zh'));
      SharedPreferences.setMockInitialValues(<String, Object>{
        // Marking the prompt as already shown keeps start() away from the
        // foreground-task permission channel, whose future never resolves
        // under the test clock.
        'flutter.server.foreground_notification_permission_prompted': true,
      });
      // The unified library also queries the MNN plugin; with no handler the
      // platform call never settles under the fake clock.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            (call) async =>
                call.method == 'listImportedModels' ? <Object?>[] : null,
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            null,
          );
    });

    testWidgets('calls onOpenSidebar when menu button is tapped', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[],
      );
      final chatProvider = ChatProvider(
        repository: repository,
        apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
      );
      await chatProvider.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      var openSidebarCount = 0;

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
          home: ChatPage(
            onOpenSidebar: () {
              openSidebarCount += 1;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();

      expect(openSidebarCount, 1);
    });

    testWidgets('empty state offers downloading when the library is empty', (
      tester,
    ) async {
      final chatProvider = ChatProvider(
        repository: _FakeChatSessionRepository(sessions: <ChatSessionRecord>[]),
        apiClient: _FakeLlamaChatApiClient(models: <ChatModelOption>[]),
      );
      await chatProvider.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:/app/models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Starting the server is no longer something the user is asked to do
      // (FR-C1); with nothing to pick, the only offer is to download.
      expect(find.text('选一个模型开始'), findsOneWidget);
      expect(find.text('先下载一个模型，之后全程在本机运行。'), findsOneWidget);
      expect(find.text('启动服务器'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_empty_state_action_button')),
          matching: find.text('发现模型'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat_empty_state_logo')), findsOneWidget);
    });

    testWidgets('empty state opens the model sheet once the library has one', (
      tester,
    ) async {
      final chatProvider = ChatProvider(
        repository: _FakeChatSessionRepository(sessions: <ChatSessionRecord>[]),
        apiClient: _FakeLlamaChatApiClient(models: <ChatModelOption>[]),
      );
      await chatProvider.load();

      final library = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[_libraryDescriptor('alpha')],
        ),
      );
      await library.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:/app/models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
          library: library,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('chat_empty_state_action_button')),
          matching: find.text('选择模型'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('chat_empty_state_action_button')));
      await tester.pumpAndSettle();

      // Only the active engine's models are listed (FR-C3).
      expect(
        find.byKey(const Key('chat_model_sheet_row_alpha')),
        findsOneWidget,
      );
      expect(find.text('可加载'), findsOneWidget);
      expect(find.textContaining('可直接切换'), findsNothing);
      expect(find.text('其他引擎'), findsNothing);
    });

    testWidgets(
      'hides empty state when server is running and a model is loaded',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[],
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

        final serverService = _FakeLlamaServerService();
        final serverProvider = EngineRuntimeProvider(
          llamaCppAdapter: LlamaCppEngineAdapter(
            serverService: serverService,
            settingsLoader: _FixedServerLaunchSettingsLoader(),
            modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
            controlClient: StubServerControlClient(),
          ),
          mnnAdapter: StubEngineAdapter(),
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          kvStorage: KvStorage(),
        );
        await tester.runAsync(() => serverProvider.start());
        chatProvider.updateServerState(
          baseUrl: serverProvider.baseUrl,
          isServerRunning: serverProvider.isRunning,
        );
        await chatProvider.load();
        await chatProvider.refreshModels();
        chatProvider.selectLoadedModel('alpha');

        addTearDown(() {
          serverProvider.dispose();
          serverService.dispose();
        });

        await tester.pumpWidget(
          _TestChatApp(
            chatProvider: chatProvider,
            serverProvider: serverProvider,
          ),
        );
        await tester.pump();

        expect(find.text('选一个模型开始'), findsNothing);
        expect(
          find.byKey(const Key('chat_empty_state_action_button')),
          findsNothing,
        );
        expect(find.byKey(const Key('chat_input_field')), findsOneWidget);
        expect(find.text('输入消息'), findsOneWidget);
        expect(find.byTooltip('alpha'), findsOneWidget);
      },
    );

    testWidgets(
      'starts as a blank chat page and can return to blank state from app bar',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[
            _session(
              id: 's1',
              title: '现有会话',
              messages: <ChatMessageRecord>[
                ChatMessageRecord(
                  id: 'm1',
                  role: ChatRole.assistant,
                  content: '历史消息',
                  createdAt: DateTime(2026, 3, 25, 11, 0),
                  modelName: 'alpha',
                ),
              ],
            ),
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
        final provider = ChatProvider(
          repository: repository,
          apiClient: apiClient,
        );
        provider.updateServerState(
          baseUrl: 'http://127.0.0.1:8080',
          isServerRunning: true,
        );
        await provider.load();

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();

        expect(provider.selectedSession, isNull);
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('新对话')),
          findsOneWidget,
        );
        expect(tester.getCenter(find.text('新对话')).dx, closeTo(400, 24));
        expect(find.text('历史消息'), findsNothing);

        await provider.selectSession('s1');
        await _pumpConversationSwitch(tester);

        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('现有会话')),
          findsOneWidget,
        );
        expect(find.text('历史消息'), findsOneWidget);

        await tester.tap(find.byTooltip('新建对话'));
        await _pumpConversationSwitch(tester);

        expect(provider.selectedSession, isNull);
        expect(provider.sessions, hasLength(1));
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('新对话')),
          findsOneWidget,
        );
        expect(find.text('历史消息'), findsNothing);
      },
    );

    testWidgets('picking a model in the sheet activates it on the runtime', (
      tester,
    ) async {
      final chatProvider = ChatProvider(
        repository: _FakeChatSessionRepository(sessions: <ChatSessionRecord>[]),
        apiClient: _FakeLlamaChatApiClient(models: <ChatModelOption>[]),
      );
      await chatProvider.load();

      final library = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[
            _libraryDescriptor('alpha'),
            _libraryDescriptor('beta'),
          ],
        ),
      );
      await library.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:/app/models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
          library: library,
        ),
      );
      await tester.pumpAndSettle();

      expect(serverProvider.isRunning, isFalse);

      await tester.tap(find.byKey(const Key('chat_empty_state_action_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_model_sheet_row_alpha')));
      await tester.pumpAndSettle();

      // One tap owns the whole bring-up: the sheet closes and the orchestrator
      // starts the engine with the chosen model (FR-C1).
      await tester.runAsync(
        () => _waitForRuntime(
          () => serverProvider.isRunning || serverProvider.lastError != null,
        ),
      );
      // A ready runtime keeps the status treatment animated, so settling is
      // intentionally bounded.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(serverProvider.isRunning, isTrue);
      expect(serverProvider.activeModelId, 'alpha');

      await tester.tap(find.byKey(const Key('chat_model_selector_button')));
      await tester.pumpAndSettle();

      expect(find.text('当前运行'), findsOneWidget);
      expect(find.text('可加载'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_model_sheet_row_alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_model_sheet_row_beta')),
        findsOneWidget,
      );
      expect(find.textContaining('可直接切换'), findsNothing);
    });

    testWidgets('uses dedicated dark hero button colors', (tester) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[],
      );
      final chatProvider = ChatProvider(
        repository: repository,
        apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
      );
      await chatProvider.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();

      final actionButton = tester.widget<FilledButton>(
        find.byKey(const Key('chat_empty_state_action_button')),
      );
      final actionStyle = actionButton.style;
      expect(
        actionStyle?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF253042),
      );
      expect(
        actionStyle?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFFF4F7FD),
      );
      expect(
        actionStyle?.shape?.resolve(<WidgetState>{}),
        isA<StadiumBorder>(),
      );
    });

    testWidgets('shows stored modelName for assistant message history', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.assistant,
                content: '你好',
                createdAt: DateTime(2026, 3, 25, 11, 0),
                modelName: 'alpha',
              ),
            ],
          ),
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      expect(find.text('你好'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_model_selector_button')),
        findsOneWidget,
      );
      expect(find.byTooltip('选择模型'), findsOneWidget);
    });

    testWidgets(
      'loads long history as recent window and prepends older messages',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[
            _session(id: 's1', title: '长会话', messages: _messages(count: 65)),
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
        final provider = ChatProvider(
          repository: repository,
          apiClient: apiClient,
        );
        provider.updateServerState(
          baseUrl: 'http://127.0.0.1:8080',
          isServerRunning: true,
        );
        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(provider.visibleMessages, hasLength(30));
        expect(provider.visibleMessages.first.id, 'm35');
        expect(provider.visibleMessages.last.id, 'm64');
        expect(find.text('message 64'), findsOneWidget);
        expect(find.text('message 35'), findsNothing);

        for (var index = 0; index < 8; index += 1) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 600),
          );
          await tester.pump();
        }
        await tester.pump();

        expect(provider.visibleMessages, hasLength(60));
        expect(provider.visibleMessages.first.id, 'm5');
        expect(provider.visibleMessages.last.id, 'm64');
      },
    );

    testWidgets('opens a history session at the latest message', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '长会话', messages: _messages(count: 65)),
        ],
      );
      final provider = ChatProvider(
        repository: repository,
        apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
      );
      await provider.load();

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      await provider.selectSession('s1');
      await _pumpConversationSwitch(tester);

      expect(provider.visibleMessages, hasLength(30));
      expect(provider.visibleMessages.first.id, 'm35');
      expect(provider.visibleMessages.last.id, 'm64');
      expect(find.text('message 35'), findsNothing);
      expect(find.text('message 64'), findsOneWidget);
    });

    testWidgets('uses stronger send button contrast than model selector', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[_session(id: 's1', title: '会话')],
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      final buttonTheme = Theme.of(
        tester.element(find.byType(ChatPage)),
      ).colorScheme;
      final serverButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_server_toggle_button')),
      );
      final modelButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_model_selector_button')),
      );
      final sendButton = tester.widget<IconButton>(
        find.byKey(const Key('chat_send_button')),
      );

      expect(
        modelButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        modelButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF565C68),
      );
      expect(
        modelButton.style?.shape?.resolve(<WidgetState>{}),
        isA<RoundedRectangleBorder>(),
      );
      expect(
        tester.getSize(find.byKey(const Key('chat_server_toggle_button'))),
        const Size(42, 42),
      );
      expect(
        tester.getSize(find.byKey(const Key('chat_model_selector_button'))),
        const Size(42, 42),
      );
      expect(
        tester.getSize(find.byKey(const Key('chat_send_button'))),
        const Size(42, 42),
      );
      expect(
        serverButton.style?.shape?.resolve(<WidgetState>{}),
        isA<RoundedRectangleBorder>(),
      );
      expect(
        serverButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        serverButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF565C68),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_model_selector_button')),
          matching: find.byIcon(Icons.memory_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_model_selector_button')),
          matching: find.text('alpha'),
        ),
        findsNothing,
      );
      expect(
        sendButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        buttonTheme.primary,
      );
      expect(
        sendButton.style?.foregroundColor?.resolve(<WidgetState>{}),
        buttonTheme.onPrimary,
      );

      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        '你好，测试发送按钮样式',
      );
      await tester.pump();

      expect(
        sendButton.style?.backgroundColor?.resolve(<WidgetState>{}),
        buttonTheme.primary,
      );
    });

    testWidgets('shows user message time below bubble and hides modelName', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: '这是用户消息',
                createdAt: DateTime(2026, 3, 25, 11, 5),
                modelName: 'alpha',
              ),
            ],
          ),
        ],
      );
      final provider = ChatProvider(
        repository: repository,
        apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
      );
      await provider.load();
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      final messageFinder = find.text('这是用户消息');
      final timeFinder = find.text('11:05');

      expect(messageFinder, findsOneWidget);
      expect(timeFinder, findsOneWidget);
      expect(find.text('alpha'), findsNothing);
      expect(
        tester.getTopLeft(timeFinder).dy,
        greaterThan(tester.getBottomLeft(messageFinder).dy),
      );
    });

    testWidgets(
      'shows reasoning content collapsed by default and expands on tap',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[
            _session(
              id: 's1',
              title: '会话',
              messages: <ChatMessageRecord>[
                ChatMessageRecord(
                  id: 'm1',
                  role: ChatRole.assistant,
                  content: '最终回答',
                  createdAt: DateTime(2026, 3, 25, 11, 0),
                  modelName: 'alpha',
                  reasoningContent: '这里是深度思考',
                ),
              ],
            ),
          ],
        );
        final provider = ChatProvider(
          repository: repository,
          apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
        );
        await provider.load();
        await provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();

        expect(find.text('最终回答'), findsOneWidget);
        expect(find.text('深度思考'), findsOneWidget);
        expect(find.text('这里是深度思考'), findsNothing);
        expect(
          tester.getTopLeft(find.text('深度思考')).dy,
          lessThan(tester.getTopLeft(find.text('最终回答')).dy),
        );

        await tester.tap(find.text('深度思考'));
        await tester.pumpAndSettle();

        expect(find.text('这里是深度思考'), findsOneWidget);
      },
    );

    testWidgets(
      'shows reasoning section when assistant message has no content',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[
            _session(
              id: 's1',
              title: '会话',
              messages: <ChatMessageRecord>[
                ChatMessageRecord(
                  id: 'm1',
                  role: ChatRole.assistant,
                  content: '',
                  createdAt: DateTime(2026, 3, 25, 11, 0),
                  modelName: 'alpha',
                  reasoningContent: '只有推理没有正文',
                ),
              ],
            ),
          ],
        );
        final provider = ChatProvider(
          repository: repository,
          apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
        );
        await provider.load();
        await provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();

        expect(find.text('深度思考'), findsOneWidget);
        expect(find.text('只有推理没有正文'), findsNothing);

        await tester.tap(find.text('深度思考'));
        await tester.pumpAndSettle();

        expect(find.text('只有推理没有正文'), findsOneWidget);
      },
    );

    testWidgets('shows quick action buttons for user and assistant messages', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '用户消息',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '助手消息',
                createdAt: DateTime(2026, 3, 25, 11, 1),
                modelName: 'alpha',
              ),
            ],
          ),
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('chat_message_copy_button_u1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_edit_button_u1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_regenerate_button_u1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_more_button_u1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_copy_button_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_edit_button_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_regenerate_button_a1')),
        findsOneWidget,
      );
      // Delete is no longer a quick action; it moved behind the overflow sheet.
      expect(
        find.byKey(const Key('chat_message_more_button_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_delete_button_a1')),
        findsNothing,
      );
    });

    testWidgets('long press opens message action sheet for normal message', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '长按菜单消息',
                createdAt: DateTime(2026, 3, 25, 11, 0),
                modelName: 'alpha',
              ),
            ],
          ),
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      await tester.longPress(
        find.byKey(const Key('chat_message_target_a1_content')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_message_action_copy_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_action_edit_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_action_regenerate_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_action_delete_a1')),
        findsOneWidget,
      );
    });

    testWidgets('editing a message updates only that message', (tester) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '旧文本',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '保留文本',
                createdAt: DateTime(2026, 3, 25, 11, 1),
                modelName: 'alpha',
              ),
            ],
          ),
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('chat_message_edit_button_u1')));
      await tester.pumpAndSettle();

      expect(find.text('编辑消息'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('chat_message_edit_field')),
        '新文本',
      );
      await tester.tap(find.byKey(const Key('chat_message_edit_save_button')));
      await tester.pumpAndSettle();

      expect(find.text('新文本'), findsOneWidget);
      expect(find.text('保留文本'), findsOneWidget);
      expect(provider.visibleMessages.first.content, '新文本');
      expect(provider.visibleMessages.last.content, '保留文本');
    });

    testWidgets('copy action copies message text and shows feedback', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '复制这条消息',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
            ],
          ),
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
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('chat_message_copy_button_u1')));
      await tester.pumpAndSettle();

      expect(clipboardText, '复制这条消息');
      expect(find.text('消息已复制'), findsOneWidget);
    });

    testWidgets('keeps streaming response pinned while already at bottom', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(id: 's1', title: '长会话', messages: _messages(count: 65)),
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
      final streamController = StreamController<ChatStreamDelta>();
      apiClient.streamController = streamController;
      apiClient.streamStartedCompleter = Completer<void>();
      addTearDown(() async {
        if (!streamController.isClosed) {
          await streamController.close();
        }
      });
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();
      await _scrollMessageListToBottom(tester);

      expect(
        _isMessageListAtBottom(tester),
        isTrue,
        reason: _messageListPositionDescription(tester),
      );

      await tester.enterText(find.byKey(const Key('chat_input_field')), 'next');
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pump();
      await apiClient.streamStartedCompleter!.future;
      await tester.pump(const Duration(milliseconds: 300));
      await _scrollMessageListToBottom(tester);

      expect(
        _isMessageListAtBottom(tester),
        isTrue,
        reason: _messageListPositionDescription(tester),
      );

      streamController.add(
        ChatStreamDelta(
          content: List.filled(48, 'generated line').join('\n\n'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _isMessageListAtBottom(tester),
        isTrue,
        reason: _messageListPositionDescription(tester),
      );

      await streamController.close();
      await tester.pump();
    });

    testWidgets(
      'pauses streaming auto-stick after user scrolls away and resumes from button',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[
            _session(id: 's1', title: '长会话', messages: _messages(count: 65)),
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
        final streamController = StreamController<ChatStreamDelta>();
        apiClient.streamController = streamController;
        apiClient.streamStartedCompleter = Completer<void>();
        addTearDown(() async {
          if (!streamController.isClosed) {
            await streamController.close();
          }
        });
        final provider = ChatProvider(
          repository: repository,
          apiClient: apiClient,
        );
        provider.updateServerState(
          baseUrl: 'http://127.0.0.1:8080',
          isServerRunning: true,
        );
        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();
        await _scrollMessageListToBottom(tester);

        await tester.enterText(
          find.byKey(const Key('chat_input_field')),
          'next',
        );
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pump();
        await apiClient.streamStartedCompleter!.future;
        await tester.pump(const Duration(milliseconds: 300));
        await _scrollMessageListToBottom(tester);

        await tester.drag(_messageScrollable(), const Offset(0, 520));
        await tester.pump();

        expect(_isMessageListAtBottom(tester), isFalse);

        streamController.add(
          ChatStreamDelta(
            content: List.filled(48, 'more generated text').join('\n\n'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(_isMessageListAtBottom(tester), isFalse);
        expect(
          find.byKey(const Key('chat_jump_to_latest_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('chat_jump_to_latest_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          _isMessageListAtBottom(tester),
          isTrue,
          reason: _messageListPositionDescription(tester),
        );
        expect(
          find.byKey(const Key('chat_jump_to_latest_button')),
          findsNothing,
        );

        await streamController.close();
        await tester.pump();
      },
    );

    testWidgets('regenerate adds assistant reply versions and switches them', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '你好',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '旧回答',
                createdAt: DateTime(2026, 3, 25, 11, 1),
                modelName: 'alpha',
              ),
            ],
          ),
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
      apiClient.streamDeltas = const <ChatStreamDelta>[
        ChatStreamDelta(content: '新'),
        ChatStreamDelta(content: '回答'),
      ];
      final provider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: provider,
          child: const MaterialApp(home: ChatPage()),
        ),
      );
      await tester.pump();

      expect(find.text('旧回答'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('chat_message_regenerate_button_a1')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('旧回答'), findsNothing);
      expect(find.text('新回答'), findsOneWidget);
      expect(provider.visibleMessages.last.content, '新回答');
      expect(find.text('2/2'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_message_version_previous_button_a1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_message_version_next_button_a1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('chat_message_version_previous_button_a1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('旧回答'), findsOneWidget);
      expect(find.text('新回答'), findsNothing);
      expect(find.text('1/2'), findsOneWidget);
      expect(provider.visibleMessages.last.currentVersionIndex, 0);
    });
    testWidgets('shows each engine default model in the start sheet', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.arkanefans.mnn_engine/methods'),
            (call) async => call.method == 'listImportedModels'
                ? <Object?>[
                    <String, Object?>{
                      'modelId': 'mnn-default',
                      'modelKey': 'mnn-default',
                      'displayName': 'Qwen MNN',
                      'modelDirPath': 'C:/models/mnn-default',
                      'configPath': 'C:/models/mnn-default/config.json',
                      'sizeBytes': 1024,
                      'importedAt': 0,
                      'isActive': false,
                    },
                  ]
                : null,
          );

      final chatProvider = ChatProvider(
        repository: _FakeChatSessionRepository(sessions: <ChatSessionRecord>[]),
        apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
      );
      await chatProvider.load();

      final library = ModelManagementProvider(
        repository: FakeLocalModelRepository(
          initialModels: <ModelDescriptor>[_libraryDescriptor('alpha')],
        ),
      );
      await library.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = EngineRuntimeProvider(
        llamaCppAdapter: LlamaCppEngineAdapter(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
          controlClient: StubServerControlClient(),
        ),
        mnnAdapter: StubEngineAdapter(),
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        kvStorage: KvStorage(),
      );
      await serverProvider.selectModel('alpha');
      await serverProvider.switchEngine(InferenceEngine.mnn);
      await serverProvider.selectModel('mnn-default');
      await serverProvider.switchEngine(InferenceEngine.llamaCpp);
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestChatApp(
          chatProvider: chatProvider,
          serverProvider: serverProvider,
          library: library,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
      await tester.pumpAndSettle();

      expect(find.text('默认模型：alpha'), findsOneWidget);
      expect(find.text('默认模型：mnn-default'), findsOneWidget);
    });

    testWidgets(
      'opens the MNN model picker when the selected engine needs a model',
      (tester) async {
        final chatProvider = ChatProvider(
          repository: _FakeChatSessionRepository(
            sessions: <ChatSessionRecord>[],
          ),
          apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
        );
        await chatProvider.load();

        final serverService = _FakeLlamaServerService();
        final mnnAdapter = StubEngineAdapter();
        final serverProvider = EngineRuntimeProvider(
          llamaCppAdapter: LlamaCppEngineAdapter(
            serverService: serverService,
            settingsLoader: _FixedServerLaunchSettingsLoader(),
            modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
            controlClient: StubServerControlClient(),
          ),
          mnnAdapter: mnnAdapter,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          kvStorage: KvStorage(),
        );
        addTearDown(() {
          serverProvider.dispose();
          serverService.dispose();
        });

        await tester.pumpWidget(
          _TestChatApp(
            chatProvider: chatProvider,
            serverProvider: serverProvider,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chat_engine_start_option_mnn')));
        await tester.pumpAndSettle();

        expect(serverProvider.activeEngine, InferenceEngine.mnn);
        expect(serverProvider.isRunning, isFalse);
        expect(mnnAdapter.isRunning, isFalse);
        expect(
          find.byKey(const Key('chat_model_sheet_discover')),
          findsOneWidget,
        );
        expect(find.text('选择模型'), findsOneWidget);
      },
    );

    testWidgets(
      'chooses an engine before starting and stops directly from input bar',
      (tester) async {
        final repository = _FakeChatSessionRepository(
          sessions: <ChatSessionRecord>[],
        );
        final chatProvider = ChatProvider(
          repository: repository,
          apiClient: _FakeLlamaChatApiClient(models: const <ChatModelOption>[]),
        );
        await chatProvider.load();

        final serverService = _FakeLlamaServerService();
        final serverProvider = EngineRuntimeProvider(
          llamaCppAdapter: LlamaCppEngineAdapter(
            serverService: serverService,
            settingsLoader: _FixedServerLaunchSettingsLoader(),
            modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
            controlClient: StubServerControlClient(),
          ),
          mnnAdapter: StubEngineAdapter(),
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          kvStorage: KvStorage(),
        );
        addTearDown(() {
          serverProvider.dispose();
          serverService.dispose();
        });

        await tester.pumpWidget(
          _TestChatApp(
            chatProvider: chatProvider,
            serverProvider: serverProvider,
          ),
        );
        await tester.pumpAndSettle();

        final colorScheme = Theme.of(
          tester.element(find.byType(ChatPage)),
        ).colorScheme;

        BoxDecoration badgeDecoration() {
          return tester
                  .widget<Container>(
                    find.byKey(const Key('chat_server_status_badge')),
                  )
                  .decoration!
              as BoxDecoration;
        }

        expect(
          find.byKey(const Key('chat_server_toggle_button')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.dns_outlined), findsOneWidget);
        expect(badgeDecoration().color, colorScheme.outlineVariant);

        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();

        expect(find.text('启动服务器'), findsOneWidget);
        expect(find.text('选择要启动的推理引擎'), findsOneWidget);
        expect(
          find.byKey(const Key('chat_engine_start_option_llama_cpp')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('chat_engine_start_option_mnn')),
          findsOneWidget,
        );
        expect(find.text('默认模型：未选择模型'), findsNWidgets(2));
        expect(serverService.startCallCount, 0);

        await tester.tap(
          find.byKey(const Key('chat_engine_start_option_llama_cpp')),
        );
        await tester.runAsync(
          () => _waitForRuntime(
            () => serverProvider.isRunning || serverProvider.lastError != null,
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        expect(serverService.startCallCount, 1);
        expect(serverProvider.isRunning, isTrue);
        expect(badgeDecoration().color, const Color(0xFF10B981));

        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.runAsync(
          () => _waitForRuntime(
            () => !serverProvider.isRunning && !serverProvider.isBusy,
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 40));
        }

        expect(serverService.stopCallCount, 1);
        expect(serverProvider.isRunning, isFalse);
        expect(badgeDecoration().color, colorScheme.outlineVariant);

        // Toggling runs real-clock work (model refresh after the runtime comes
        // up); let it finish here rather than leaking into the next test.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      },
    );
  });
}

class _TestChatApp extends StatelessWidget {
  const _TestChatApp({
    required this.chatProvider,
    required this.serverProvider,
    this.library,
    this.home,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
  });

  final ChatProvider chatProvider;
  final EngineRuntimeProvider serverProvider;
  final ModelManagementProvider? library;
  final Widget? home;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EngineRuntimeProvider>.value(
          value: serverProvider,
        ),
        // The empty state asks the library whether there is anything to pick,
        // and the model sheet lists downloads in flight (FR-C1 / FR-C3).
        if (library == null)
          ChangeNotifierProvider<ModelManagementProvider>(
            create: (_) => ModelManagementProvider(),
          )
        else
          ChangeNotifierProvider<ModelManagementProvider>.value(
            value: library!,
          ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(),
        ),
        ChangeNotifierProxyProvider<EngineRuntimeProvider, ChatProvider>(
          create: (_) => chatProvider,
          update: (_, serverProvider, current) {
            final provider = current ?? chatProvider;
            provider.updateServerState(
              baseUrl: serverProvider.baseUrl,
              isServerRunning: serverProvider.isRunning,
              activeModelId: serverProvider.activeModelId,
            );
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Pinned so the Chinese assertions do not follow the host locale.
        locale: const Locale('zh'),
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: home ?? const ChatPage(),
      ),
    );
  }
}

class _FakeChatSessionRepository extends ChatSessionRepository {
  _FakeChatSessionRepository({required this.sessions})
    : super(appSupportDirectory: Directory.systemTemp);

  List<ChatSessionRecord> sessions;
  final Map<String, ChatMessageRecord> messages = <String, ChatMessageRecord>{};
  final Map<String, ChatMessageVersionRecord> versions =
      <String, ChatMessageVersionRecord>{};

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
  Future<ChatMessageRecord?> loadMessage(String messageId) async {
    return messages[messageId];
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final matchingSessions = sessions.where(
      (session) => session.id == sessionId,
    );
    if (matchingSessions.isNotEmpty) {
      for (final messageId in matchingSessions.first.messageIds) {
        messages.remove(messageId);
      }
    }
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
  Future<List<ChatMessageRecord>> loadMessagesBefore(
    ChatSessionRecord session, {
    required String beforeMessageId,
    int limit = 30,
  }) async {
    final beforeIndex = session.messageIds.indexOf(beforeMessageId);
    if (beforeIndex <= 0) {
      return const <ChatMessageRecord>[];
    }
    final start = beforeIndex > limit ? beforeIndex - limit : 0;
    return _messagesByIds(session.messageIds.sublist(start, beforeIndex));
  }

  @override
  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    return _messagesByIds(session.messageIds);
  }

  @override
  Future<void> deleteMessages(
    Iterable<ChatMessageRecord> deletedMessages,
  ) async {
    final messageList = deletedMessages.toList(growable: false);
    await deleteMessageResources(messageList);
    for (final message in messageList) {
      messages.remove(message.id);
    }
  }

  @override
  Future<void> saveMessageVersion(ChatMessageVersionRecord version) async {
    versions[version.id] = version;
  }

  @override
  Future<ChatMessageVersionRecord?> loadMessageVersion(String versionId) async {
    return versions[versionId];
  }

  @override
  Future<List<ChatMessageVersionRecord>> loadMessageVersions(
    Iterable<String> versionIds,
  ) async {
    return versionIds
        .map((versionId) => versions[versionId])
        .whereType<ChatMessageVersionRecord>()
        .toList(growable: false);
  }

  @override
  Future<void> deleteMessageVersions(Iterable<String> versionIds) async {
    for (final versionId in versionIds) {
      versions.remove(versionId);
    }
  }

  @override
  Future<void> deleteMessageResources(
    Iterable<ChatMessageRecord> messages,
  ) async {
    final messageList = messages.toList(growable: false);
    await deleteAttachmentFiles(
      messageList.expand((message) => message.imageFilePaths),
    );
    await deleteMessageVersions(
      messageList.expand((message) => message.versionIds),
    );
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

  List<ChatMessageRecord> messagesForSession(String sessionId) {
    final session = sessions.firstWhere((session) => session.id == sessionId);
    return _messagesByIds(session.messageIds);
  }
}

class _FakeLlamaChatApiClient extends LlamaChatApiClient {
  _FakeLlamaChatApiClient({required this.models})
    : super(settingsLoader: _FixedServerLaunchSettingsLoader());

  List<ChatModelOption> models;
  int fetchModelsCallCount = 0;
  Completer<void>? fetchModelsCompleter;
  Completer<void>? streamStartedCompleter;
  StreamController<ChatStreamDelta>? streamController;
  List<ChatStreamDelta> streamDeltas = const <ChatStreamDelta>[];
  Object? loadError;

  @override
  Future<List<ChatModelOption>> fetchModels() async {
    fetchModelsCallCount += 1;
    if (fetchModelsCompleter != null) {
      await fetchModelsCompleter!.future;
    }
    return List<ChatModelOption>.from(models);
  }

  @override
  Future<void> loadModel(String modelId) async {
    if (loadError != null) {
      throw loadError!;
    }
    models = models
        .map(
          (model) => model.id == modelId
              ? ChatModelOption(
                  id: model.id,
                  displayName: model.displayName,
                  status: ChatModelStatus.loaded,
                )
              : model,
        )
        .toList(growable: false);
  }

  @override
  Future<void> unloadModel(String modelId) async {
    models = models
        .map(
          (model) => model.id == modelId
              ? ChatModelOption(
                  id: model.id,
                  displayName: model.displayName,
                  status: ChatModelStatus.unloaded,
                )
              : model,
        )
        .toList(growable: false);
  }

  @override
  Stream<ChatStreamDelta> streamChatCompletion({
    required String modelId,
    required List<ChatMessageRecord> messages,
    required CancelToken cancelToken,
  }) {
    final controller = streamController;
    if (controller != null) {
      streamStartedCompleter?.complete();
      return controller.stream;
    }
    return Stream<ChatStreamDelta>.fromIterable(streamDeltas);
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();
}

class _FakeLlamaServerService implements LlamaServerService {
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => _isRunning;

  bool _isRunning = false;
  int startCallCount = 0;
  int stopCallCount = 0;

  @override
  Future<String> loadBundledVersion() async => 'b9830';

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async {
    startCallCount += 1;
    _isRunning = true;
    _runningStateController.add(true);
    return true;
  }

  @override
  Future<bool> stopServer() async {
    stopCallCount += 1;
    _isRunning = false;
    _runningStateController.add(false);
    return true;
  }
}

class _FixedModelStoragePaths extends ModelStoragePaths {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
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

List<ChatMessageRecord> _messages({required int count}) {
  return List<ChatMessageRecord>.generate(
    count,
    (index) => ChatMessageRecord(
      id: 'm$index',
      role: index.isEven ? ChatRole.user : ChatRole.assistant,
      content: 'message $index',
      createdAt: DateTime(2026, 3, 25, 10, index),
    ),
  );
}

Finder _messageScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('chat_message_list')),
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _pumpConversationSwitch(WidgetTester tester) async {
  // The Android path uses a Timer-backed switch delay. One large pump only
  // fires that timer; follow-up frames are still needed for the async commit,
  // staged list and end-of-frame callback.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<void> _waitForRuntime(bool Function() isDone) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!isDone()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure('runtime operation did not settle within 3 seconds');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> _scrollMessageListToBottom(WidgetTester tester) async {
  await tester.dragUntilVisible(
    find.text('message 64'),
    _messageScrollable(),
    const Offset(0, -640),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

bool _isMessageListAtBottom(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(_messageScrollable());
  final position = scrollable.position;
  return position.maxScrollExtent - position.pixels <= 1;
}

String _messageListPositionDescription(WidgetTester tester) {
  final scrollable = tester.state<ScrollableState>(_messageScrollable());
  final position = scrollable.position;
  return 'pixels=${position.pixels}, max=${position.maxScrollExtent}';
}

ModelDescriptor _libraryDescriptor(String name) {
  return ModelDescriptor(
    id: name,
    modelName: name,
    sizeBytes: 1073741824,
    storedDirectoryPath: 'C:/models/$name',
    storedFilePath: 'C:/models/$name/$name.gguf',
    importedAt: DateTime(2026, 1, 1),
  );
}

class FakeLocalModelRepository extends LocalModelRepository {
  FakeLocalModelRepository({List<ModelDescriptor>? initialModels})
    : _models = List<ModelDescriptor>.from(
        initialModels ?? const <ModelDescriptor>[],
      ),
      super(appSupportDirectory: Directory.systemTemp);

  final List<ModelDescriptor> _models;

  @override
  Future<List<ModelDescriptor>> listModels() async =>
      List<ModelDescriptor>.from(_models);
}
