import 'package:servllama/features/settings/pages/download_settings_page.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/app/model_library_page.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/pages/mcp_servers_page.dart';
import 'package:servllama/features/agent/pages/skill_detail_page.dart';
import 'package:servllama/features/agent/pages/skills_page.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/pages/connections_page.dart';
import 'package:servllama/features/assistants/pages/profile_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/assistants/widgets/assistant_selector.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/downloads/pages/downloads_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/logs/pages/app_logs_page.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/pages/speech_models_page.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/push_sidebar.dart';
import 'package:servllama/shared/widgets/app_empty_state.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';

import '../features/speech/speech_test_support.dart';
import '../support/stub_engine_adapter.dart';

class _Assets extends UnifiedModelRepository {
  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async => [];
}

class _Models extends ModelManagementProvider {
  List<LibraryModel> entries = [];
  @override
  List<LibraryModel> libraryModelsFor(InferenceEngine engine) =>
      entries.where((m) => m.engine == engine).toList();
  @override
  Future<void> load() async {}
}

class _Downloads extends DownloadProvider {
  @override
  Future<void> load({bool startTransfers = true}) async {}
  @override
  Future<int> orphanedStagingBytes() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const target = ChatTarget.remote('fixture', 'model-one');
  late SpeechHarness speech;
  late AssistantProvider assistants;
  late ChatProvider chat;
  late EngineRuntimeProvider runtime;
  late AgentToolService tools;
  late _Models models;
  late _Downloads downloads;
  late AppThemeModeProvider theme;
  late AppLocaleProvider locale;
  late ChatTimeoutProvider timeout;
  void bind() => chat.bind(assistants, runtime);

  setUp(() async {
    speech = SpeechHarness();
    await speech.initialize();
    // SQLite remains real; debounced draft persistence has separate tests.
    AppDatabase.current = null;
    await speech.db.setMetadata('legacyImportComplete', '1');
    final repository = AssistantRepository(speech.db, preferences: KvStorage());
    await repository.saveAssistant(
      const Assistant(id: 'daily', name: 'Daily', chatTarget: target),
    );
    await repository.saveAssistant(const Assistant(id: 'study', name: 'Study'));
    await repository.saveConnection(
      const AiConnection(
        id: 'fixture',
        name: 'Fixture',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        models: ['model-one'],
      ),
    );
    assistants = AssistantProvider(repository: repository, models: _Assets());
    await assistants.load();
    await assistants.select('daily');
    runtime = EngineRuntimeProvider(
      kvStorage: KvStorage(),
      llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
      mnnAdapter: StubEngineAdapter(),
    );
    final sessions = ChatSessionRepository(
      database: speech.db,
      appSupportDirectory: speech.directory,
    );
    await sessions.saveSession(
      ChatSessionRecord(
        id: 'original',
        title: 'Original conversation',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        assistantId: 'daily',
      ),
    );
    chat = ChatProvider(repository: sessions);
    assistants.addListener(bind);
    bind();
    await chat.load();
    await chat.selectSession('original');
    tools = AgentToolService(AgentRepository(speech.db), speech.directory);
    models = _Models();
    downloads = _Downloads();
    theme = AppThemeModeProvider();
    locale = AppLocaleProvider();
    timeout = ChatTimeoutProvider();
  });

  tearDown(() async {
    assistants.removeListener(bind);
    chat.dispose();
    await chat.flushDrafts();
    assistants.dispose();
    runtime.dispose();
    runtime.resources.dispose();
    tools.dispose();
    models.dispose();
    downloads.dispose();
    theme.dispose();
    locale.dispose();
    timeout.dispose();
    await speech.close();
  });

  Widget app({Widget home = const MainScaffold(), double scale = 1}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
          ChangeNotifierProvider<ChatProvider>.value(value: chat),
          ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
          ChangeNotifierProvider<AgentToolService>.value(value: tools),
          ChangeNotifierProvider<ModelManagementProvider>.value(value: models),
          ChangeNotifierProvider<DownloadProvider>.value(value: downloads),
          ChangeNotifierProvider<SpeechJobService>.value(value: speech.service),
          ChangeNotifierProvider<AppThemeModeProvider>.value(value: theme),
          ChangeNotifierProvider<AppLocaleProvider>.value(value: locale),
          ChangeNotifierProvider<ChatTimeoutProvider>.value(value: timeout),
        ],
        child: MaterialApp(
          navigatorObservers: [AppNavigationObserver()],
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        ),
      );

  void screen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settleSql(WidgetTester tester, bool Function() ready) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (ready()) break;
    }
    expect(ready(), isTrue);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, String key) async {
    final sidebar = tester.widget<PushSidebar>(find.byType(PushSidebar));
    if (!sidebar.controller!.isOpen) {
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  EditableText input(WidgetTester tester, String key) =>
      tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key), skipOffstage: false),
          matching: find.byType(EditableText, skipOffstage: false),
        ),
      );

  for (final engine in InferenceEngine.values) {
    testWidgets(
      'remote chat can start and stop ${engine.name} with its saved model',
      (tester) async {
        screen(tester, const Size(360, 800));
        await tester.runAsync(() async {
          await runtime.switchEngine(engine);
          await runtime.selectModel('local-default');
        });
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ChatPage)))!;
        expect(chat.isRemote, isTrue);
        expect(find.byTooltip(l.v2ToolActivity), findsNothing);
        expect(find.byTooltip(l.serverStart), findsOneWidget);
        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('chat_engine_start_option_mnn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('chat_engine_start_option_llama_cpp')),
          findsOneWidget,
        );
        // Dismissing the sheet does not start a service or change the chat.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(runtime.isRunning, isFalse);
        expect(chat.currentTarget?.toJson(), target.toJson());
        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(Key('chat_engine_start_option_${engine.storageValue}')),
        );
        await settleSql(
          tester,
          () => runtime.isRunning || runtime.lastError != null,
        );
        expect(runtime.isRunning, isTrue, reason: '${runtime.lastError}');
        expect(runtime.activeEngine, engine);
        expect(runtime.activeModelId, 'local-default');
        expect(runtime.isPublished, isFalse);
        expect(chat.currentTarget?.toJson(), target.toJson());
        expect(find.byTooltip(l.serverStop), findsOneWidget);
        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await settleSql(tester, () => !runtime.isRunning && !runtime.isBusy);
        expect(chat.currentTarget?.toJson(), target.toJson());
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'remote chat local shortcut picks a missing model without replacing its target',
    (tester) async {
      screen(tester, const Size(360, 800));
      models.entries = [
        LibraryModel(
          id: 'mnn:local',
          runtimeId: 'local',
          engine: InferenceEngine.mnn,
          name: 'Local fixture',
          sizeBytes: 10,
          importedAt: DateTime(2026),
          storagePath: '/fixture',
        ),
      ];
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
      await tester.pumpAndSettle();
      await settleSql(
        tester,
        () => find
            .byKey(const Key('chat_engine_start_option_mnn'))
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.byKey(const Key('chat_engine_start_option_mnn')));
      await settleSql(
        tester,
        () => find
            .byKey(const Key('chat_model_sheet_row_local'))
            .evaluate()
            .isNotEmpty,
      );
      expect(
        find.byKey(const Key('chat_model_sheet_row_local')),
        findsOneWidget,
      );
      expect(runtime.isRunning, isFalse);
      expect(chat.currentTarget?.toJson(), target.toJson());
      await tester.tap(find.byKey(const Key('chat_model_sheet_row_local')));
      await settleSql(
        tester,
        () => runtime.isRunning || runtime.lastError != null,
      );
      expect(runtime.isRunning, isTrue, reason: '${runtime.lastError}');
      expect(runtime.activeModelId, 'local');
      expect(runtime.isPublished, isFalse);
      expect(chat.currentTarget?.toJson(), target.toJson());
      await tester.runAsync(runtime.stop);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'sidebar and history search keep text and icon vertically centered at large text sizes',
    (tester) async {
      screen(tester, const Size(360, 800));
      for (final scale in [1.0, 1.6]) {
        for (final history in [false, true]) {
          await tester.pumpWidget(
            app(
              home: history ? const ChatHistoryPage() : const MainScaffold(),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          if (!history) {
            await tester.tap(find.byIcon(Icons.menu));
            await tester.pumpAndSettle();
          }
          final field = find.byKey(
            Key(history ? 'history_page_search_input' : 'drawer_search_input'),
          );
          await tester.enterText(field, 'Search 搜索');
          await tester.pump();
          final search = find.ancestor(
            of: field,
            matching: find.byType(ChatSessionSearchField),
          );
          final editable = find.descendant(
            of: field,
            matching: find.byType(EditableText),
          );
          final icon = find.descendant(
            of: search,
            matching: find.byIcon(Icons.search_rounded),
          );
          expect(
            (tester.getCenter(editable).dy - tester.getCenter(search).dy).abs(),
            lessThan(1),
          );
          expect(
            (tester.getCenter(icon).dy - tester.getCenter(search).dy).abs(),
            lessThan(1),
          );
          expect(chat.sessionQuery, 'Search 搜索');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );

  testWidgets('chat model selection releases both composer and search focus', (
    tester,
  ) async {
    screen(tester, const Size(360, 800));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chat_input_field')),
      'Keep this draft',
    );
    await tester.tap(find.byKey(const Key('chat_model_selector_button')));
    await tester.pumpAndSettle();
    expect(input(tester, 'chat_input_field').focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.enterText(
      find.byKey(const Key('chat_target_search')),
      'model',
    );
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(find.byKey(const Key('chat_target_close')));
    await tester.pumpAndSettle();
    expect(input(tester, 'chat_input_field').focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(chat.currentDraft, 'Keep this draft');
    await tester.tap(find.byKey(const Key('chat_input_field')));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'chat attachment action follows the selected model capabilities',
    (tester) async {
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final attach = find.byKey(const Key('chat_gallery_button'));
      expect(tester.widget<IconButton>(attach).onPressed, isNotNull);
      for (final enabled in [false, true]) {
        await tester.runAsync(
          () => assistants.saveConnection(
            assistants.connection('fixture')!.changed({
              'modelCapabilities': {
                'model-one': ModelCapabilities(
                  supportsImages: enabled,
                ).toJson(),
              },
            }),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(attach).onPressed != null, enabled);
        expect(chat.canSend, isTrue);
        expect(chat.currentTarget?.modelId, 'model-one');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'MCP and profile forms separate adjacent inputs on a narrow screen',
    (tester) async {
      screen(tester, const Size(360, 800));
      for (final page in [const McpEditor(), const ProfilePage()]) {
        await tester.pumpWidget(app(home: page, scale: 1.3));
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        expect(fields.evaluate().length, greaterThanOrEqualTo(2));
        expect(
          tester.getTopLeft(fields.at(1)).dy -
              tester.getBottomLeft(fields.first).dy,
          greaterThanOrEqualTo(16),
        );
        await tester.enterText(fields.first, 'Draft');
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('sidebar routes preserve the open drawer, chat and draft', (
    tester,
  ) async {
    screen(tester, const Size(360, 800));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(AssistantSelector),
      ),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const Key('chat_input_field')),
      'Keep this draft',
    );
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer_ui_primitives')), findsNothing);
    expect(find.byKey(const Key('drawer_migration_preview')), findsNothing);
    expect(input(tester, 'chat_input_field').focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    final drawerAction = find.descendant(
      of: find.byKey(const Key('drawer_settings_action')),
      matching: find.byType(IconButton),
    );
    final actionStyle = tester.widget<IconButton>(drawerAction).style!;
    final drawerColors = Theme.of(tester.element(drawerAction)).colorScheme;
    expect(
      actionStyle.minimumSize?.resolve(<WidgetState>{}),
      const Size(40, 40),
    );
    expect(
      actionStyle.backgroundColor?.resolve(<WidgetState>{}),
      drawerColors.surfaceContainerLow,
    );
    for (final route in <String, Type>{
      'drawer_assistants_action': AssistantsPage,
      'drawer_server_action': ServerPage,
      'drawer_models_action': ModelLibraryPage,
      'drawer_speech_action': SpeechPage,
      'drawer_settings_action': SettingsPage,
    }.entries) {
      await tester.showKeyboard(find.byKey(const Key('drawer_search_input')));
      expect(tester.testTextInput.isVisible, isTrue);
      await open(tester, route.key);
      expect(input(tester, 'drawer_search_input').focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byType(route.value), findsOneWidget);
      final sidebar = tester.widget<PushSidebar>(
        find.byType(PushSidebar, skipOffstage: false),
      );
      expect(sidebar.controller!.isOpen, isTrue);
      expect(sidebar.controller!.progress, 1);
      if (route.key == 'drawer_settings_action') {
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      } else {
        await back(tester);
      }
      expect(find.byType(ChatPage), findsOneWidget);
      expect(chat.selectedSession?.id, 'original');
      expect(chat.currentTarget?.toJson(), target.toJson());
      expect(chat.currentDraft, 'Keep this draft');
      expect(input(tester, 'chat_input_field').focusNode.hasFocus, isFalse);
      expect(input(tester, 'drawer_search_input').focusNode.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        find.byKey(const Key('drawer_assistant_selector')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'sidebar actions and library downloads return without replaying touch feedback',
    (tester) async {
      screen(tester, const Size(360, 800));
      final boundary = GlobalKey();
      Future<Uint8List> pixels() async => (await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      }))!;
      Future<void> roundTrip(String key) async {
        final baseline = await pixels();
        final press = await tester.startGesture(
          tester.getCenter(find.byKey(Key(key))),
        );
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 100));
        await press.up();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pump();
        // Wait for the route transition, without settling extra ink frames.
        await tester.pump(const Duration(milliseconds: 350));
        expect(await pixels(), orderedEquals(baseline), reason: key);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        app(
          home: RepaintBoundary(key: boundary, child: const MainScaffold()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      for (final key in [
        'drawer_assistants_action',
        'drawer_server_action',
        'drawer_models_action',
        'drawer_speech_action',
        'drawer_settings_action',
      ]) {
        await roundTrip(key);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          home: RepaintBoundary(key: boundary, child: const ModelLibraryPage()),
        ),
      );
      await tester.pumpAndSettle();
      await roundTrip('model_library_downloads_button');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('assistant management cannot switch the current chat', (
    tester,
  ) async {
    screen(tester, const Size(360, 800));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await open(tester, 'drawer_settings_action');
    await tester.tap(find.byKey(const Key('settings_assistants_tile')));
    await tester.pumpAndSettle();
    final study = find.ancestor(
      of: find.text('Study'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(
        of: study,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use assistant'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Study'), findsOneWidget);
    await back(tester);
    await back(tester);
    await back(tester);
    expect(find.byType(ChatPage), findsOneWidget);
    expect(chat.selectedSession?.id, 'original');
    expect(chat.currentAssistantId, 'daily');
    expect(chat.currentDraft, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'profile and new settings menus are reachable and update in place',
    (tester) async {
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app(home: const SettingsPage(), scale: 1.6));
      await tester.pumpAndSettle();
      final profileTile = find.byKey(const Key('settings_profile_tile'));
      expect(profileTile.hitTestable(), findsOneWidget);
      await tester.tap(profileTile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Local user');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await settleSql(tester, () => assistants.profile.name == 'Local user');
      expect(
        find.descendant(of: profileTile, matching: find.text('Local user')),
        findsOneWidget,
      );
      for (final route in <String, Type>{
        'settings_downloads_tile': DownloadSettingsPage,
        'settings_assistants_tile': AssistantsPage,
        'settings_providers_tile': ConnectionsPage,
        'settings_skills_tile': SkillsPage,
        'settings_mcp_tile': McpServersPage,
        'settings_server_tile': ServerPage,
        'settings_speech_tile': SpeechPage,
        'settings_logs_tile': AppLogsPage,
      }.entries) {
        await tester.scrollUntilVisible(find.byKey(Key(route.key)), 160);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(route.key)));
        await tester.pump();
        if (route.value == SkillsPage || route.value == McpServersPage) {
          await settleSql(
            tester,
            () =>
                find.byType(route.value).evaluate().isNotEmpty &&
                find
                    .byType(LinearProgressIndicator, skipOffstage: false)
                    .evaluate()
                    .isEmpty,
          );
        } else {
          await tester.pumpAndSettle();
        }
        expect(find.byType(route.value), findsOneWidget);
        if (route.value == SkillsPage) {
          expect(
            find.byTooltip('Import skill (ZIP / Markdown)'),
            findsOneWidget,
          );
          expect(find.byIcon(Icons.extension_outlined), findsOneWidget);
          expect(find.text('No skills yet'), findsOneWidget);
          expect(
            find.text('Tap + in the upper-right corner to import one'),
            findsOneWidget,
          );
          expect(find.byType(McpServersPage), findsNothing);
          expect(find.byTooltip('Add'), findsNothing);
        } else if (route.value == McpServersPage) {
          expect(find.byTooltip('Add'), findsOneWidget);
          expect(find.text('No MCP servers yet'), findsOneWidget);
          expect(
            find.text('Tap + in the upper-right corner to add one'),
            findsOneWidget,
          );
          expect(find.byType(SkillsPage), findsNothing);
          expect(find.byTooltip('Import skill (ZIP / Markdown)'), findsNothing);
        }
        await back(tester);
        expect(find.byType(SettingsPage), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_about_tile')),
        200,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings_about_tile')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('model, skill and MCP empty states share text styles', (
    tester,
  ) async {
    screen(tester, const Size(360, 800));
    final pages = <(Widget, String, String)>[
      (const ModelLibraryPage(), 'No models yet', 'Tap + to add a model'),
      (
        const SkillsPage(),
        'No skills yet',
        'Tap + in the upper-right corner to import one',
      ),
      (
        const McpServersPage(),
        'No MCP servers yet',
        'Tap + in the upper-right corner to add one',
      ),
    ];
    for (final (page, title, description) in pages) {
      await tester.pumpWidget(app(home: page, scale: 1.6));
      await settleSql(tester, () => find.text(title).evaluate().isNotEmpty);

      final titleFinder = find.text(title);
      final theme = Theme.of(tester.element(titleFinder));
      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(
        tester.widget<Text>(titleFinder).style,
        theme.textTheme.titleMedium,
      );
      expect(
        tester.widget<Text>(find.text(description)).style,
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('skills add sheet validates and imports pasted markdown', (
    tester,
  ) async {
    screen(tester, const Size(360, 800));
    await tester.pumpWidget(app(home: const SkillsPage()));
    await settleSql(
      tester,
      () => find.text('No skills yet').evaluate().isNotEmpty,
    );

    await tester.tap(find.byKey(const Key('skills_add_button')));
    await tester.pumpAndSettle();
    expect(find.text('Paste Markdown'), findsOneWidget);
    expect(find.text('Import from file'), findsOneWidget);

    await tester.tap(find.byKey(const Key('skills_import_paste')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('skills_paste_field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('skills_paste_field')),
      '---\nname: Invalid fixture\n---\nBody',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('skills_paste_submit')));
    await tester.tap(find.byKey(const Key('skills_paste_submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('SKILL.md metadata must include a description.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('skills_paste_field')),
      '---\nname: Pasted fixture\ndescription: Imported from clipboard\n'
      '---\nRead these instructions.',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('skills_paste_submit')));
    await tester.tap(find.byKey(const Key('skills_paste_submit')));
    await settleSql(
      tester,
      () => find.text('Pasted fixture').evaluate().isNotEmpty,
    );
    expect(find.text('Pasted fixture'), findsOneWidget);
    expect(find.byKey(const Key('skills_paste_field')), findsNothing);
    expect(find.text('No skills yet'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'separate skill and MCP pages refresh their own catalog and permissions',
    (tester) async {
      const server = McpServer(
        id: '12345678-0000-0000-0000-000000000001',
        name: 'Fixture MCP',
        url: 'https://example.com/mcp',
      );
      late final SkillRecord skill;
      await tester.runAsync(() async {
        skill = await tools.skills.importMarkdown(
          '---\nname: Fixture skill\ndescription: Static skill fixture\n---\n'
          'Fixture body',
        );
        await tools.repository.saveServer(server);
        await assistants.save(
          assistants.assistants.firstWhere((a) => a.id == 'daily').changed({
            'skillIds': [skill.id],
            'mcpServerIds': [server.id],
          }),
        );
      });
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app(home: const SettingsPage()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_skills_tile')),
        160,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_skills_tile')));
      await settleSql(
        tester,
        () => find.text(skill.name).evaluate().isNotEmpty,
      );
      final search = find.byKey(const Key('skills_search'));
      expect(search, findsOneWidget);
      await tester.enterText(search, 'missing skill');
      await tester.pump();
      expect(find.text('No matching skills'), findsOneWidget);
      expect(find.text(skill.name), findsNothing);
      await tester.enterText(search, 'static skill fixture');
      await tester.pump();
      expect(find.text(skill.name), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text(skill.name),
            matching: find.byType(Card),
          ),
          matching: find.byIcon(Icons.extension_outlined),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Import static packages'), findsNothing);
      expect(find.text(server.name), findsNothing);
      await tester.tap(find.byKey(ValueKey('skill_${skill.id}')));
      await settleSql(
        tester,
        () =>
            find.byType(SkillDetailPage).evaluate().isNotEmpty &&
            find.byTooltip('More actions').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete skill'));
      await tester.pumpAndSettle();
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleSql(
        tester,
        () =>
            find.byType(SkillDetailPage).evaluate().isEmpty &&
            find.text(skill.name).evaluate().isEmpty,
      );
      expect(
        assistants.assistants.firstWhere((a) => a.id == 'daily').skillIds,
        isEmpty,
      );
      await back(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_mcp_tile')),
        160,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_mcp_tile')));
      await settleSql(
        tester,
        () => find.text(server.name).evaluate().isNotEmpty,
      );
      expect(find.text(server.url), findsNothing);
      expect(find.text('Disconnected'), findsOneWidget);
      expect(find.text('HTTP'), findsOneWidget);
      expect(find.text('0 tools'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(
        find.textContaining('Streamable HTTP and legacy SSE'),
        findsNothing,
      );
      expect(find.text(skill.name), findsNothing);
      final mcpSearch = find.byKey(const Key('mcp_search'));
      expect(mcpSearch, findsOneWidget);
      await tester.enterText(mcpSearch, 'missing MCP');
      await tester.pump();
      expect(find.text('No matching MCP servers'), findsOneWidget);
      expect(find.text(server.name), findsNothing);
      await tester.enterText(mcpSearch, 'example.com');
      await tester.pump();
      expect(find.text(server.name), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      await tester.tap(find.text(server.name));
      await tester.pumpAndSettle();
      expect(find.byType(McpEditor), findsOneWidget);
      expect(find.text('Custom request headers'), findsOneWidget);
      expect(find.byKey(const Key('mcp_enabled_switch')), findsOneWidget);
      expect(
        find.textContaining('Disabling keeps the configuration'),
        findsNothing,
      );
      expect(find.textContaining('Sent with every MCP request'), findsNothing);
      expect(find.textContaining('Save to apply'), findsNothing);
      await tester.tap(find.byKey(const Key('mcp_enabled_switch')));
      await tester.pump();
      expect(find.text('Disabled'), findsOneWidget);
      final addHeader = find.byKey(const Key('mcp_add_header'));
      await tester.ensureVisible(addHeader);
      await tester.tap(addHeader);
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('mcp_header_name_0'))).width,
        tester.getSize(find.byKey(const Key('mcp_header_value_0'))).width,
      );
      await tester.enterText(
        find.byKey(const Key('mcp_header_name_0')),
        'X-Test',
      );
      await tester.enterText(
        find.byKey(const Key('mcp_header_value_0')),
        'header-value',
      );
      await tester.tap(find.byTooltip('Remove header'));
      await tester.pump();
      expect(find.byKey(const Key('mcp_header_name_0')), findsNothing);
      await tester.tap(addHeader);
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('mcp_header_name_0')),
        'X-Test',
      );
      await tester.enterText(
        find.byKey(const Key('mcp_header_value_0')),
        'header-value',
      );
      await tester.enterText(find.byType(TextField).first, 'Renamed MCP');
      final save = find.byKey(const Key('mcp_save_button'));
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await settleSql(
        tester,
        () =>
            find.byType(McpEditor).evaluate().isEmpty &&
            find.text('Renamed MCP').evaluate().isNotEmpty,
      );
      expect(find.byType(McpEditor), findsNothing);
      final saved = await tester.runAsync(
        () async => (await tools.repository.servers()).single,
      );
      final savedHeaders = await tester.runAsync(
        () => tools.mcpHeadersFor(saved!),
      );
      expect(savedHeaders, {'X-Test': 'header-value'});
      expect(saved!.enabled, isFalse);
      expect(find.text('Disabled'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);

      await tester.tap(find.text('Renamed MCP'));
      await tester.pumpAndSettle();
      expect(find.byType(McpEditor), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      final delete = find.byKey(const Key('mcp_delete_button'));
      await tester.scrollUntilVisible(
        delete,
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settleSql(
        tester,
        () => find.text('Renamed MCP').evaluate().isEmpty,
      );
      expect(
        assistants.assistants.firstWhere((a) => a.id == 'daily').mcpServerIds,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('MCP cards show connection errors and open bounded details', (
    tester,
  ) async {
    late final McpServer server;
    await tester.runAsync(() async {
      final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      server = McpServer(
        id: '12345678-0000-0000-0000-000000000003',
        name: 'Unavailable MCP',
        url: 'http://127.0.0.1:$port/mcp',
      );
      await tools.repository.saveServer(server);
      await tools.mcp.refreshAll();
    });
    screen(tester, const Size(360, 800));
    await tester.pumpWidget(app(home: const McpServersPage()));
    await settleSql(tester, () => find.text(server.name).evaluate().isNotEmpty);
    expect(tester.takeException(), isNull);
    expect(find.text(server.url), findsNothing);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('0 tools'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('mcp_error_12345678-0000-0000-0000-000000000003'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Connection error'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'model tabs preserve search and keep language downloads reachable',
    (tester) async {
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app(home: const ModelLibraryPage(), scale: 1.6));
      await tester.pumpAndSettle();
      final search = find.byKey(const Key('model_library_search_input'));
      await tester.enterText(search, 'remember this search');
      final searchFocus = tester
          .widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .focusNode;
      await tester.drag(find.byType(TabBarView), const Offset(-360, 0));
      await tester.pumpAndSettle();
      expect(searchFocus.hasFocus, isFalse);
      expect(find.byType(SpeechModelsPage), findsOneWidget);
      expect(
        find.byKey(const Key('model_library_downloads_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('model_library_language_tab')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: search, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      expect(
        tester.widget<TextField>(search).controller!.text,
        'remember this search',
      );
      await tester.tap(find.byKey(const Key('model_library_downloads_button')));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsPage), findsOneWidget);
      await back(tester);
      expect(
        tester.widget<TextField>(search).controller!.text,
        'remember this search',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'speech opens the voice model tab and keeps its active job on back',
    (tester) async {
      await tester.runAsync(() async {
        final asset = await speech.model();
        await speech.service.enqueue(
          asset: asset,
          text: 'Queued before navigating',
        );
        await until(() => speech.workers.isNotEmpty);
        await speech.workers.single.started.future;
      });
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await open(tester, 'drawer_speech_action');
      await tester.tap(find.byTooltip('Speech models'));
      await tester.pumpAndSettle();
      expect(find.byType(ModelLibraryPage), findsOneWidget);
      final tabContext = tester.element(find.byType(TabBar));
      expect(DefaultTabController.of(tabContext).index, 1);
      await back(tester);
      await back(tester);
      expect(speech.service.jobs.single.state, SpeechJobState.running);
      expect(speech.workers.single.cancellationRequested, isFalse);
      expect(chat.selectedSession?.id, 'original');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'sidebar actions fit with a keyboard and a narrow embedded sidebar',
    (tester) async {
      screen(tester, const Size(360, 800));
      await tester.pumpWidget(app(scale: 1.6));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const Key('drawer_search_input')),
        'filter',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('drawer_settings_action')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(1000, 500);
      await tester.pumpAndSettle();
      tester
          .widget<PushSidebar>(find.byType(PushSidebar))
          .onSidebarWidthChanged!(200);
      await tester.pumpAndSettle();
      for (final name in [
        'assistants',
        'server',
        'models',
        'speech',
        'settings',
      ]) {
        expect(
          find.byKey(Key('drawer_${name}_action')).hitTestable(),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'welcome shortcuts preserve chat and open the exact destination',
    (tester) async {
      screen(tester, const Size(390, 844));
      await chat.createSession();
      chat.updateDraft('Keep the welcome draft');
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final id in ['server', 'speech']) {
        await tester.tap(find.byKey(Key('chat_welcome_$id')));
        await tester.pumpAndSettle();
        if (id == 'server') {
          expect(find.byType(ServerPage), findsOneWidget);
        } else {
          final page = tester.widget<SpeechPage>(find.byType(SpeechPage));
          expect(page.initialKind, isNull);
          final context = tester.element(find.byType(TabBarView));
          expect(DefaultTabController.of(context).index, 0);
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(chat.currentDraft, 'Keep the welcome draft');
        expect(chat.currentTarget, target);
        expect(chat.selectedSession, isNull);
        expect(runtime.isRunning, isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
