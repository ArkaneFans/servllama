import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
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
    testWidgets('shows empty-state copy and starts server from action button', (
      tester,
    ) async {
      final repository = _FakeChatSessionRepository(
        sessions: <ChatSessionRecord>[],
      );
      final apiClient = _FakeLlamaChatApiClient(
        models: <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.unloaded,
          ),
        ],
      );
      final chatProvider = ChatProvider(
        repository: repository,
        apiClient: apiClient,
      );
      await chatProvider.load();

      final serverService = _FakeLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
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
      await tester.pump();

      expect(find.text('开始对话'), findsOneWidget);
      expect(find.text('请先启动服务器，然后选择一个模型开始聊天。'), findsOneWidget);
      expect(apiClient.fetchModelsCallCount, 0);
      expect(
        tester
            .widget<Align>(
              find.byKey(const Key('chat_conversation_hero_align')),
            )
            .alignment,
        const Alignment(0, -0.236),
      );
      expect(
        find.byKey(const Key('chat_empty_state_action_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat_empty_state_logo')), findsOneWidget);
      expect(
        find.byKey(const Key('chat_model_selector_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('chat_input_field')), findsOneWidget);
      expect(find.text('请先启动服务器'), findsOneWidget);
      expect(find.text('启动服务器'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('chat_server_toggle_button')),
            )
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('chat_model_selector_button')),
            )
            .style
            ?.foregroundColor
            ?.resolve(<WidgetState>{WidgetState.disabled}),
        const Color(0xAA565C68),
      );
      expect(
        tester.widget<SizedBox>(find.byKey(const Key('chat_empty_state_logo'))),
        isA<SizedBox>()
            .having((widget) => widget.width, 'width', 118)
            .having((widget) => widget.height, 'height', 118),
      );

      final actionButton = tester.widget<FilledButton>(
        find.byKey(const Key('chat_empty_state_action_button')),
      );
      final actionStyle = actionButton.style;
      expect(
        actionStyle?.backgroundColor?.resolve(<WidgetState>{}),
        const Color(0xFF565C68),
      );
      expect(
        actionStyle?.foregroundColor?.resolve(<WidgetState>{}),
        Colors.white,
      );
      expect(
        actionStyle?.shape?.resolve(<WidgetState>{}),
        isA<StadiumBorder>(),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_empty_state_action_button')),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('chat_empty_state_action_button')));
      await tester.pump();

      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('chat_server_toggle_button')),
            )
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{WidgetState.disabled}),
        Colors.transparent,
      );

      await tester.pumpAndSettle();

      expect(serverProvider.isRunning, isTrue);
      expect(find.text('服务器已启动，请先选择或加载一个模型，马上开始你的 AI 对话。'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_empty_state_action_button')),
        findsOneWidget,
      );
      expect(find.text('选择模型'), findsWidgets);

      apiClient.fetchModelsCompleter = Completer<void>();
      await tester.tap(find.byKey(const Key('chat_empty_state_action_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(apiClient.fetchModelsCallCount, 1);
      expect(
        find.byKey(const Key('chat_model_sheet_loading_indicator')),
        findsOneWidget,
      );
      expect(find.text('已加载模型'), findsNothing);

      apiClient.fetchModelsCompleter!.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('已加载模型'), findsOneWidget);
      expect(find.text('可用模型'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('已加载模型可直接切换，未加载模型会在选中时自动加载。'), findsNothing);
    });

    testWidgets(
      'opens model list from empty-state action when server is running',
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
            const ChatModelOption(
              id: 'beta',
              displayName: 'beta',
              status: ChatModelStatus.unloaded,
            ),
          ],
        );
        final chatProvider = ChatProvider(
          repository: repository,
          apiClient: apiClient,
        );

        final serverService = _FakeLlamaServerService();
        final serverProvider = ServerProvider(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
        );
        await serverProvider.start();
        chatProvider.updateServerState(
          baseUrl: serverProvider.baseUrl,
          isServerRunning: serverProvider.isRunning,
        );
        await chatProvider.load();

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

        expect(apiClient.fetchModelsCallCount, 0);
        expect(
          find.byKey(const Key('chat_empty_state_action_button')),
          findsOneWidget,
        );

        apiClient.fetchModelsCompleter = Completer<void>();
        await tester.tap(
          find.byKey(const Key('chat_empty_state_action_button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(apiClient.fetchModelsCallCount, 1);
        expect(
          find.byKey(const Key('chat_model_sheet_loading_indicator')),
          findsOneWidget,
        );
        expect(find.text('已加载模型'), findsNothing);

        apiClient.fetchModelsCompleter!.complete();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('已加载模型'), findsOneWidget);
        expect(find.text('可用模型'), findsOneWidget);
        expect(find.text('alpha'), findsOneWidget);
        expect(find.text('beta'), findsOneWidget);
        expect(find.text('已加载模型可直接切换，未加载模型会在选中时自动加载。'), findsNothing);
      },
    );

    testWidgets(
      'quick toggles server from input bar and updates status badge',
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
        final serverProvider = ServerProvider(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
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

        expect(serverService.startCallCount, 1);
        expect(serverProvider.isRunning, isTrue);
        expect(badgeDecoration().color, const Color(0xFF10B981));

        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();

        expect(serverService.stopCallCount, 1);
        expect(serverProvider.isRunning, isFalse);
        expect(badgeDecoration().color, colorScheme.outlineVariant);
      },
    );

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
        final serverProvider = ServerProvider(
          serverService: serverService,
          settingsLoader: _FixedServerLaunchSettingsLoader(),
          modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
        );
        await serverProvider.start();
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

        expect(find.text('开始对话'), findsNothing);
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
          find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
          findsOneWidget,
        );
        expect(tester.getCenter(find.text('新会话')).dx, lessThan(200));
        expect(find.text('历史消息'), findsNothing);

        provider.selectSession('s1');
        await tester.pump();

        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('现有会话')),
          findsOneWidget,
        );
        expect(find.text('历史消息'), findsOneWidget);

        await tester.tap(find.byTooltip('新建会话'));
        await tester.pump();

        expect(provider.selectedSession, isNull);
        expect(provider.sessions, hasLength(1));
        expect(
          find.descendant(of: find.byType(AppBar), matching: find.text('新会话')),
          findsOneWidget,
        );
        expect(find.text('历史消息'), findsNothing);
      },
    );

    testWidgets('shows loaded and available model groups and loads a model', (
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
          const ChatModelOption(
            id: 'beta',
            displayName: 'beta',
            status: ChatModelStatus.unloaded,
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

      expect(find.text('当前模型'), findsNothing);
      expect(
        find.byKey(const Key('chat_model_selector_button')),
        findsOneWidget,
      );
      expect(find.byTooltip('选择模型'), findsOneWidget);
      expect(apiClient.fetchModelsCallCount, 0);

      apiClient.fetchModelsCompleter = Completer<void>();
      await tester.tap(find.byKey(const Key('chat_model_selector_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(apiClient.fetchModelsCallCount, 1);
      expect(
        find.byKey(const Key('chat_model_sheet_loading_indicator')),
        findsOneWidget,
      );
      expect(find.text('已加载模型'), findsNothing);

      apiClient.fetchModelsCompleter!.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('已加载模型'), findsOneWidget);
      expect(find.text('可用模型'), findsOneWidget);
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('已加载模型可直接切换，未加载模型会在选中时自动加载。'), findsNothing);

      await tester.tap(find.text('beta'));
      await tester.pumpAndSettle();

      expect(provider.currentModelId, 'beta');
      expect(find.text('模型已加载: beta'), findsNothing);
      expect(find.byTooltip('beta'), findsOneWidget);
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
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
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

    testWidgets('unloads current loaded model from model sheet', (
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
          const ChatModelOption(
            id: 'beta',
            displayName: 'beta',
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

      await tester.tap(find.byKey(const Key('chat_model_selector_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('chat_model_unload_button_alpha')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_model_unload_button_beta')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('chat_model_unload_button_alpha')));
      await tester.pumpAndSettle();

      expect(provider.currentModelId, isNull);
      expect(find.byTooltip('选择模型'), findsOneWidget);
      expect(find.text('已加载模型'), findsOneWidget);
      expect(find.text('可用模型'), findsOneWidget);
      expect(
        find.byKey(const Key('chat_model_unload_button_beta')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chat_model_unload_button_alpha')),
        findsNothing,
      );
      expect(find.text('alpha'), findsOneWidget);
      expect(find.text('输入消息'), findsNothing);
      expect(find.text('请先选择模型'), findsOneWidget);
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
      provider.selectSession('s1');

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
      provider.selectSession('s1');

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
                  reasoningContent: '这里是推理过程',
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
        provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();

        expect(find.text('最终回答'), findsOneWidget);
        expect(find.text('推理过程'), findsOneWidget);
        expect(find.text('这里是推理过程'), findsNothing);
        expect(
          tester.getTopLeft(find.text('推理过程')).dy,
          lessThan(tester.getTopLeft(find.text('最终回答')).dy),
        );

        await tester.tap(find.text('推理过程'));
        await tester.pumpAndSettle();

        expect(find.text('这里是推理过程'), findsOneWidget);
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
        provider.selectSession('s1');

        await tester.pumpWidget(
          ChangeNotifierProvider<ChatProvider>.value(
            value: provider,
            child: const MaterialApp(home: ChatPage()),
          ),
        );
        await tester.pump();

        expect(find.text('推理过程'), findsOneWidget);
        expect(find.text('只有推理没有正文'), findsNothing);

        await tester.tap(find.text('推理过程'));
        await tester.pumpAndSettle();

        expect(find.text('只有推理没有正文'), findsOneWidget);
      },
    );
  });
}

class _TestChatApp extends StatelessWidget {
  const _TestChatApp({
    required this.chatProvider,
    required this.serverProvider,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
  });

  final ChatProvider chatProvider;
  final ServerProvider serverProvider;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
        ChangeNotifierProxyProvider<ServerProvider, ChatProvider>(
          create: (_) => chatProvider,
          update: (_, serverProvider, current) {
            final provider = current ?? chatProvider;
            provider.updateServerState(
              baseUrl: serverProvider.baseUrl,
              isServerRunning: serverProvider.isRunning,
            );
            return provider;
          },
        ),
      ],
      child: MaterialApp(
        theme: theme,
        darkTheme: darkTheme,
        themeMode: themeMode,
        home: const ChatPage(),
      ),
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
    : super(settingsLoader: _FixedServerLaunchSettingsLoader());

  List<ChatModelOption> models;
  int fetchModelsCallCount = 0;
  Completer<void>? fetchModelsCompleter;
  List<ChatStreamDelta> streamDeltas = const <ChatStreamDelta>[];

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
  Future<bool> copyBinaryFromAssets() async => true;

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
