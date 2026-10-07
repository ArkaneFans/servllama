import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/widgets/chat_session_drawer_section.dart';
import 'package:servllama/features/chat/widgets/chat_speech_button.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences extends KvStorage {
  final values = <String, String>{'v2.activeAssistant': 'a'};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _Assets extends UnifiedModelRepository {
  static const local = ModelAsset(
    id: 'local-asset',
    kind: AssetKind.llm,
    engine: 'mnn',
    runtimeId: 'local-runtime',
    storageOwner: 'mnn_engine',
    path: '/fixture/model',
    name: 'Local fixture',
    revision: 'fixture',
  );
  List<ModelAsset> entries = [local];
  Completer<void>? lookup;
  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async => entries;
  @override
  Future<ModelAsset?> asset(String id) async {
    await lookup?.future;
    return entries.where((a) => a.id == id).firstOrNull;
  }
}

class _Runtime extends Fake implements EngineRuntimeProvider {
  bool running = false, published = false, residue = false;
  String? model;
  InferenceEngine engine = InferenceEngine.mnn;
  final actions = <String>[];
  final started = Completer<void>();
  Completer<void>? startBlocker;
  @override
  void addListener(VoidCallback listener) {}
  @override
  void removeListener(VoidCallback listener) {}
  @override
  RuntimePhase? get currentPhase => null;
  @override
  final resources = ResourceCoordinator();
  @override
  bool get isRunning => running;
  @override
  bool get isBusy => false;
  @override
  bool get isPublished => published;
  @override
  bool get canStop => running || residue;
  @override
  bool get canSwitchEngine => !running && !residue;
  @override
  InferenceEngine get activeEngine => engine;
  @override
  String? get activeModelId => running ? model : null;
  @override
  String? get activeModelName => running ? model : null;
  @override
  String? get selectedModelId => model;
  @override
  EngineRuntimeError? get lastError => null;
  @override
  String get baseUrl => 'http://127.0.0.1:8080';
  @override
  String get apiKey => '';
  @override
  Future<void> stop() async {
    actions.add('stop');
    running = false;
  }

  @override
  Future<void> switchEngine(InferenceEngine value) async {
    engine = value;
  }

  @override
  Future<void> selectModel(String? value) async {
    model = value;
  }

  @override
  Future<void> startPrivate() async {
    actions.add('start');
    if (!started.isCompleted) started.complete();
    await startBlocker?.future;
    running = true;
  }
}

class _Protocol extends ChatProtocolClient {
  final models = <String>[], systems = <String>[];
  final started = <String>[];
  final firstRequest = Completer<void>();
  Completer<void>? blocker;
  @override
  Stream<AiEvent> complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int maxTokens = 2048,
    String? runId,
  }) async* {
    models.add(model);
    systems.add(system);
    started.add(c.id);
    if (!firstRequest.isCompleted) firstRequest.complete();
    if (blocker != null) {
      await Future.any([blocker!.future, cancelToken.whenCancel]);
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    yield AiEvent(text: 'Reply from $model');
    yield const AiEvent(stopReason: 'stop');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const one = ChatTarget.remote('c', 'one');
  const two = ChatTarget.remote('c', 'two');
  const local = ChatTarget.local('local-asset');
  const a = Assistant(
    id: 'a',
    name: 'A',
    instructions: 'A instructions',
    chatTarget: one,
  );
  const b = Assistant(id: 'b', name: 'B', instructions: 'B instructions');
  late AppDatabase db;
  late Directory directory;
  late AssistantRepository assistantRepository;
  late AssistantProvider assistants;
  late ChatSessionRepository repository;
  late ChatProvider chat;
  late _Runtime runtime;
  late _Assets assets;
  late _Protocol protocol;
  void bind() => chat.bind(assistants, runtime);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('servllama_conversation_');
    db = AppDatabase.memory();
    AppDatabase.current = db;
    await db.setMetadata('legacyImportComplete', '1');
    assistantRepository = AssistantRepository(db, preferences: _Preferences());
    await assistantRepository.saveAssistant(a);
    await assistantRepository.saveAssistant(b);
    await assistantRepository.saveConnection(
      const AiConnection(
        id: 'c',
        name: 'Fixture',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        models: ['one', 'two'],
      ),
    );
    assets = _Assets();
    await assets.saveAsset(_Assets.local);
    assistants = AssistantProvider(
      repository: assistantRepository,
      models: assets,
    );
    await assistants.load();
    repository = ChatSessionRepository(
      database: db,
      appSupportDirectory: directory,
    );
    runtime = _Runtime();
    protocol = _Protocol();
    chat = ChatProvider(repository: repository, protocolClient: protocol);
    assistants.addListener(bind);
    bind();
  });
  tearDown(() async {
    assistants.removeListener(bind);
    chat.dispose();
    await chat.flushDrafts();
    assistants.dispose();
    runtime.resources.dispose();
    AppDatabase.current = null;
    await db.close();
    directory.deleteSync(recursive: true);
  });
  ChatSessionRecord session(String id, String? assistantId) =>
      ChatSessionRecord(
        id: id,
        title: id,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        assistantId: assistantId,
      );

  Widget app(Widget home, {double scale = 1}) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<ChatProvider>.value(value: chat),
    ],
    child: MaterialApp(
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

  // Pump Flutter frames and the real SQLite scheduler until the UI action commits.
  Future<void> changeOnScreen(
    WidgetTester tester,
    Future<void> Function() action,
    bool Function() completed,
  ) async {
    await action();
    for (var attempt = 0; attempt < 100 && !completed(); attempt++) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(completed(), isTrue, reason: 'The settings action did not finish');
    await tester.pumpAndSettle();
  }

  testWidgets(
    'deleted provider leaves an editable draft and send asks for a model',
    (tester) async {
      AppDatabase.current = null;
      await tester.runAsync(() async {
        await chat.load();
        await assistants.deleteConnection('c');
      });
      await tester.pumpWidget(app(const ChatPage()));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(ChatPage)))!;
      expect(chat.currentTarget, isNull);
      expect(chat.canSend, isFalse);
      expect(chat.canSubmitInput, isTrue);
      expect(find.text(l.v2MissingTarget), findsNothing);
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'Keep this draft',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await tester.pumpAndSettle();
      expect(find.text(l.v2ChooseConversationModel), findsOneWidget);
      expect(chat.currentDraft, 'Keep this draft');
      expect(chat.selectedSession, isNull);
      expect(protocol.models, isEmpty);
      await tester.runAsync(() async {
        expect(await db.query('SELECT id FROM messages'), isEmpty);
        expect(await db.query('SELECT id FROM generation_runs'), isEmpty);
      });
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'saving unrelated assistant edits preserves a newer chat selection',
    (tester) async {
      AppDatabase.current = null;
      await tester.runAsync(chat.load);
      await tester.pumpWidget(app(const AssistantEditor(assistant: a)));
      await tester.pumpAndSettle();
      await tester.runAsync(() => assistants.setChatTarget('a', two));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      await changeOnScreen(
        tester,
        () => tester.tap(find.text(l.commonSave)),
        () => assistants.assistants.first.revision == 3,
      );
      expect(assistants.assistants.first.chatTarget, two);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'chat model picker updates the owning assistant on a narrow screen',
    (tester) async {
      // Persistence of debounced drafts is covered by the real-clock tests below.
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await repository.saveSession(session('original', 'a'));
          await chat.load();
          await chat.selectSession('original');
        });
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(const ChatPage(), scale: 1.6));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('chat_runtime_subtitle')));
        await tester.pumpAndSettle();
        expect(find.byType(ChatTargetPicker), findsOneWidget);
        expect(find.byType(AssistantEditor), findsNothing);
        await tester.enterText(
          find.byKey(const Key('chat_target_search')),
          'two',
        );
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(chat.currentModelId, 'one');
        await tester.tap(find.byKey(const Key('chat_runtime_subtitle')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('chat_target_search')),
          'two',
        );
        await tester.pump();
        await changeOnScreen(
          tester,
          () => tester.tap(find.byKey(const Key('chat_target_remote_c_two'))),
          () => chat.canManageSessions && chat.currentModelId == 'two',
        );
        expect(chat.currentModelId, 'two');
        expect(chat.selectedSession!.id, 'original');
        expect(assistants.assistants.first.chatTarget?.modelId, 'two');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'assistant model picker and clear action remain drafts until saved',
    (tester) async {
      // Persistence of debounced drafts is covered by the real-clock tests below.
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await repository.saveSession(session('existing', 'a'));
          await chat.load();
          await chat.selectSession('existing');
        });
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => AppScaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AssistantEditor(
                        assistant: assistants.assistants.first,
                      ),
                    ),
                  ),
                  child: const Text('Editor'),
                ),
              ),
            ),
          ),
        );
        Future<void> openEditor() async {
          await tester.tap(find.text('Editor'));
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(AssistantEditor)),
          )!;
          await tester.scrollUntilVisible(
            find.text(l.v2AssistantDefaultModel),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }

        await openEditor();
        final l = AppLocalizations.of(
          tester.element(find.byType(AssistantEditor)),
        )!;
        await tester.tap(find.text(l.v2AssistantDefaultModel));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('chat_target_search')),
          'two',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('chat_target_remote_c_two')));
        await tester.pumpAndSettle();
        expect(assistants.assistants.first.chatTarget?.modelId, 'one');
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(assistants.assistants.first.chatTarget?.modelId, 'one');
        await openEditor();
        await tester.tap(find.byTooltip(l.v2ClearDefaultModel));
        await tester.pumpAndSettle();
        expect(assistants.assistants.first.chatTarget?.modelId, 'one');
        await changeOnScreen(
          tester,
          () => tester.tap(find.text(l.commonSave)),
          () => assistants.assistants.first.chatTarget == null,
        );
        expect(assistants.assistants.first.chatTarget, isNull);
        expect(chat.currentModelId, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'explicit server shortcut stops the local service without changing the chat target',
    (tester) async {
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await assistants.setChatTarget('a', local);
          await repository.saveSession(session('local', 'a'));
          await chat.load();
          await chat.selectSession('local');
        });
        runtime.running = runtime.published = true;
        runtime.model = 'other-published-model';
        bind();
        await tester.pumpWidget(
          ChangeNotifierProvider<EngineRuntimeProvider>.value(
            value: runtime,
            child: app(const ChatPage()),
          ),
        );
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ChatPage)))!;
        expect(find.byTooltip(l.serverStop), findsOneWidget);
        await tester.tap(find.byKey(const Key('chat_server_toggle_button')));
        await tester.pumpAndSettle();
        expect(runtime.actions, ['stop']);
        expect(runtime.running, isFalse);
        expect(runtime.model, 'other-published-model');
        expect(chat.currentTarget?.toJson(), local.toJson());
        expect(find.byKey(const Key('app_top_message')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'assistant selector starts a new draft while explicit reassignment keeps the conversation',
    (tester) async {
      // Persistence of debounced drafts is covered by the real-clock tests below.
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await repository.saveSession(session('original', 'a'));
          await chat.load();
          await chat.selectSession('original');
          chat.updateDraft('Retained conversation draft');
        });
        await tester.pumpWidget(app(const MainScaffold()));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(find.byType(ChatPage)))!;
        await tester.tap(find.byIcon(Icons.menu));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('drawer_assistant_selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('B').last);
        await tester.pumpAndSettle();
        expect(chat.selectedSession, isNull);
        expect(chat.currentAssistantId, 'b');
        expect(chat.currentDraft, isEmpty);
        expect(chat.sessions.single.assistantId, 'a');
        await chat.selectSession('original');
        await tester.pumpAndSettle();
        Future<void> chooseB() async {
          await tester.longPress(
            find.byKey(const Key('chat_session_item_original')),
          );
          await tester.pump(const Duration(milliseconds: 180));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.v2ChangeConversationAssistant));
          await tester.pumpAndSettle();
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('B').last);
          await tester.pumpAndSettle();
        }

        await chooseB();
        await tester.tap(find.text(l.commonCancel));
        await tester.pumpAndSettle();
        expect(chat.currentAssistantId, 'a');
        await chooseB();
        await changeOnScreen(
          tester,
          () => tester.tap(find.text(l.commonSave)),
          () => chat.canManageSessions && chat.currentAssistantId == 'b',
        );
        expect(chat.currentAssistantId, 'b');
        expect(chat.selectedSession!.id, 'original');
        expect(chat.currentModelId, isNull);
        expect(chat.currentDraft, 'Retained conversation draft');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'sidebar filters by assistant and all history restores another assistant and model',
    (tester) async {
      // Persistence of debounced drafts is covered by the real-clock tests below.
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          for (final s in [
            session('a1', 'a'),
            session('a2', 'a'),
            session('b1', 'b'),
          ]) {
            await repository.saveSession(s);
          }
          await chat.load();
          await chat.selectSession('a1');
        });
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => AppScaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatHistoryPage(),
                        ),
                      ),
                      child: const Text('History'),
                    ),
                    Expanded(
                      child: ChatSessionDrawerSection(
                        presentationContext: context,
                        isChatSelected: true,
                        onOpenChat: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('a1'), findsOneWidget);
        expect(find.text('b1'), findsNothing);
        await tester.tap(find.text('a2'));
        await tester.pumpAndSettle();
        expect(chat.currentModelId, 'one');
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        expect(find.text('b1'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);
        await tester.tap(find.text('b1'));
        await tester.pumpAndSettle();
        expect(chat.currentAssistantId, 'b');
        expect(chat.currentModelId, isNull);
        expect(find.text('a1'), findsNothing);
        expect(find.text('b1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  Widget transcriptAction(SpeechJob job) => app(
    Builder(
      builder: (context) => AppScaffold(
        body: FilledButton(
          onPressed: () =>
              runUiAction(context, () => insertTranscript(context, job)),
          child: const Text('Insert'),
        ),
      ),
    ),
  );

  SpeechJob transcript(String destination) => SpeechJob(
    id: 'asr',
    state: SpeechJobState.completed,
    createdAt: DateTime(2026),
    snapshot: {
      'assetId': 'speech-model',
      'kind': 'asr',
      'conversationId': destination,
    },
    result: {'text': 'Transcript'},
  );

  testWidgets(
    'transcript returns to its assistant draft and rechecks deletion on confirmation',
    (tester) async {
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await chat.load();
          chat.updateDraft('A unsent');
          await chat.selectAssistant('b');
          chat.updateDraft('B unsent');
        });
        await tester.pumpWidget(transcriptAction(transcript('draft:a')));
        await tester.tap(find.text('Insert'));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        )!;
        expect(find.text(l.v2AssistantDraft('A')), findsOneWidget);
        expect(find.text(l.v2OriginalChatMissing), findsNothing);
        await tester.tap(find.text(l.v2AppendDraft));
        await tester.pumpAndSettle();
        expect(chat.draftFor('draft:a'), 'A unsent\nTranscript');
        expect(chat.currentDraft, 'B unsent');
        expect(chat.currentAssistantId, 'b');
        expect(protocol.models, isEmpty);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Insert'));
        await tester.pumpAndSettle();
        await tester.runAsync(() => chat.deleteAssistant('a'));
        expect(chat.hasDraftDestination('draft:a'), isFalse);
        await tester.tap(find.text(l.v2AppendDraft));
        await tester.pumpAndSettle();
        expect(find.textContaining(l.v2OriginalChatMissing), findsOneWidget);
        expect(chat.draftFor('draft:a'), isEmpty);
        expect(chat.currentDraft, 'B unsent');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'unowned legacy and deleted assistant transcripts require destination confirmation',
    (tester) async {
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await chat.load();
          await chat.selectAssistant('b');
        });
        for (final source in ['draft', 'draft:deleted']) {
          chat.updateDraft('B unsent');
          await tester.pumpWidget(transcriptAction(transcript(source)));
          await tester.tap(find.text('Insert'));
          await tester.pumpAndSettle();
          final l = AppLocalizations.of(
            tester.element(find.byType(AlertDialog)),
          )!;
          expect(find.text(l.v2OriginalChatMissing), findsOneWidget);
          expect(find.text(l.v2AssistantDraft('B')), findsOneWidget);
          expect(chat.currentDraft, 'B unsent');
          await tester.tap(find.text(l.commonCancel));
          await tester.pumpAndSettle();
          expect(chat.currentDraft, 'B unsent');
          await tester.tap(find.text('Insert'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.v2AppendDraft));
          await tester.pumpAndSettle();
          expect(chat.currentDraft, 'B unsent\nTranscript');
          expect(chat.draftFor(source), isEmpty);
          expect(protocol.models, isEmpty);
          expect(tester.takeException(), isNull);
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  test('history entry points resolve the owning assistant model', () async {
    await assistants.setChatTarget('b', two);
    for (final record in [
      session('a1', 'a'),
      session('a2', 'a'),
      session('b1', 'b'),
    ]) {
      await repository.saveSession(record);
    }
    await chat.load();
    await chat.switchSession('a2', staged: true);
    expect(chat.currentModelId, 'one');
    await chat.selectTarget(two);
    await chat.selectSession('a1');
    expect(chat.currentModelId, 'two');
    expect(assistants.activeId, 'a');
    await chat.selectSession('b1');
    expect(chat.currentAssistantId, 'b');
    expect(chat.currentModelId, 'two');
    await chat.selectTarget(one);
    expect(assistants.activeId, 'a');
    expect(assistants.assistants.first.chatTarget?.modelId, 'two');
    expect(assistants.assistants.last.chatTarget?.modelId, 'one');
    expect(chat.assistantSessions.map((s) => s.id), ['b1']);
    chat.beginSessionSelection('a1', keepVisibleMessages: false);
    expect(chat.currentModelId, 'two');
    await chat.loadSelectedSessionMessages('a1');
    final first = chat.switchSession('a2', staged: true);
    final second = chat.switchSession('b1');
    await Future.wait([first, second]);
    expect(chat.currentAssistantId, 'b');
    expect(chat.currentModelId, 'one');
  });

  test(
    'model changes and reassignment affect future runs, retaining historical versions',
    () async {
      await chat.load();
      await chat.sendMessage('Hello');
      final id = chat.selectedSession!.id;
      final messageId = chat.visibleMessages.last.id;
      await chat.selectTarget(two);
      await chat.regenerateFromMessage(messageId);
      expect(protocol.models, ['one', 'two']);
      expect(protocol.systems, ['A instructions', 'A instructions']);
      expect(
        (await assistantRepository.assistants()).first.chatTarget?.modelId,
        'two',
      );
      await chat.reassignAssistant(id, 'b');
      expect(chat.currentTarget, isNull);
      expect(chat.canSend, isFalse);
      await chat.selectTarget(one);
      await chat.regenerateFromMessage(messageId);
      expect(protocol.models, ['one', 'two', 'one']);
      expect(protocol.systems.last, 'B instructions');
      expect(chat.visibleMessages.last.author?.assistantId, 'b');
      final latestRunId = chat.visibleMessages.last.runId!;
      await chat.selectMessageVersion(messageId: messageId, versionIndex: 1);
      expect(chat.visibleMessages.last.author?.assistantId, 'a');
      expect(chat.visibleMessages.last.modelName, 'two');
      expect(chat.currentAssistantId, 'b');
      expect(chat.currentModelId, 'one');
      final run = (await db.query(
        'SELECT snapshot FROM generation_runs WHERE id=?',
        [latestRunId],
      )).single;
      final snapshot = jsonDecode(run.read<String>('snapshot'));
      expect(snapshot['assistant'], isNot(contains('chatTarget')));
      expect(snapshot['target'], one.toJson());
    },
  );

  test(
    'assistant setting updates existing and new chats without fallback or empty conversations',
    () async {
      await chat.load();
      await chat.sendMessage('Hello');
      final original = chat.selectedSession!.id;
      await assistants.setChatTarget('a', two);
      expect(chat.currentModelId, 'two');
      await chat.createSession();
      expect(chat.currentTarget?.modelId, 'two');
      await chat.selectAssistant('b');
      expect(chat.currentTarget, isNull);
      await chat.selectTarget(one);
      expect(chat.selectedSession, isNull);
      expect(chat.sessions, hasLength(1));
      expect(
        (await assistantRepository.assistants()).last.chatTarget?.modelId,
        'one',
      );
      await chat.selectSession(original);
      expect(chat.currentAssistantId, 'a');
      expect(chat.currentModelId, 'two');
      expect(
        jsonDecode(
          (await db.query(
            'SELECT config FROM conversations',
          )).single.read<String>('config'),
        ),
        {'assistantId': 'a'},
      );
    },
  );

  test(
    'assistant and conversation drafts do not carry text or attachments across contexts',
    () async {
      await chat.load();
      chat.updateDraft('A unsent');
      chat.addImageAttachment('/fixture/a.png');
      await chat.selectAssistant('b');
      expect(chat.currentDraft, isEmpty);
      expect(chat.pendingImageAttachments, isEmpty);
      chat.updateDraft('B unsent');
      await chat.selectTarget(two);
      await chat.ensureConversation();
      final id = chat.selectedSession!.id;
      expect(chat.currentDraft, 'B unsent');
      await chat.selectAssistant('a');
      expect(chat.currentDraft, 'A unsent');
      expect(chat.pendingImageAttachments, ['/fixture/a.png']);
      await chat.selectSession(id);
      expect(chat.currentDraft, 'B unsent');
      expect(chat.pendingImageAttachments, isEmpty);
      await chat.flushDrafts();
      final stored = jsonDecode((await db.metadata('chatDrafts'))!);
      expect(stored['draft:a'], 'A unsent');
      expect(stored[id], 'B unsent');
    },
  );

  test(
    'missing owners and targets stay unresolved until an explicit repair',
    () async {
      await repository.saveSession(session('orphan', 'removed'));
      await chat.load();
      await chat.switchSession('orphan');
      expect(chat.currentAssistant, isNull);
      expect(chat.canSend, isFalse);
      await assistants.select('b');
      await assistants.load();
      expect(chat.currentAssistantId, 'removed');
      await chat.reassignAssistant('orphan', 'b');
      expect(chat.canSend, isFalse);
      await chat.selectTarget(two);
      expect(chat.canSend, isTrue);
      expect(await chat.countUsingConnection('c'), 1);
      await assistants.deleteConnection('c');
      expect(chat.currentTarget, isNull);
      expect(chat.canSend, isFalse);
    },
  );

  test(
    'first user message commits ownership atomically and preserves draft after storage failure',
    () async {
      await chat.load();
      chat.updateDraft('retained');
      await db.execute(
        "CREATE TRIGGER reject_conversation BEFORE INSERT ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(chat.sendMessage('retained'), throwsA(anything));
      expect(await db.query('SELECT id FROM messages'), isEmpty);
      expect(chat.currentDraft, 'retained');
      await db.execute('DROP TRIGGER reject_conversation');
      await chat.sendMessage('retained');
      final saved = (await repository.loadSessions()).single;
      expect(saved.assistantId, 'a');
      expect(chat.currentTarget?.modelId, 'one');
      expect(chat.currentDraft, isEmpty);
    },
  );

  for (final disable in [true, false]) {
    test(
      '${disable ? 'disabling a provider' : 'removing the active model'} cancels its stream and keeps the conversation repairable',
      () async {
        await chat.load();
        protocol.blocker = Completer<void>();
        final sending = chat.sendMessage('Retained question');
        await protocol.firstRequest.future.timeout(const Duration(seconds: 5));
        final id = chat.selectedSession!.id;
        await assistants.saveConnection(
          assistants
              .connection('c')!
              .changed(
                disable
                    ? {'enabled': false}
                    : {
                        'models': ['two'],
                      },
              ),
        );
        await sending;
        expect(chat.isSending, isFalse);
        expect(chat.canSend, isFalse);
        expect(chat.currentTarget, isNull);
        expect(assistants.assistants.first.chatTarget, isNull);
        expect((await repository.loadSessions()).single.id, id);
        await assistants.saveConnection(
          assistants.connection('c')!.changed({
            'enabled': true,
            'models': ['one', 'two'],
          }),
        );
        expect(chat.canSend, isFalse);
        await chat.selectTarget(two);
        expect(chat.canSend, isTrue);
      },
    );
  }

  test(
    'one local selection owns startup and rejects published switches before changing the target',
    () async {
      await chat.load();
      runtime.running = true;
      runtime.published = true;
      runtime.model = 'other';
      await expectLater(
        chat.selectTarget(local, startLocal: true),
        throwsStateError,
      );
      expect(chat.currentTarget?.modelId, 'one');
      expect(chat.selectedSession, isNull);
      expect(runtime.actions, isEmpty);
      runtime.published = false;
      runtime.startBlocker = Completer<void>();
      final selection = chat.selectTarget(local, startLocal: true);
      await runtime.started.future.timeout(const Duration(seconds: 5));
      expect(chat.canManageSessions, isFalse);
      await chat.selectTarget(two);
      expect(chat.currentTarget?.assetId, 'local-asset');
      runtime.startBlocker!.complete();
      await selection;
      // Match app.dart's runtime notification; this fake has no listeners.
      chat.updateServerState(
        baseUrl: runtime.baseUrl,
        isServerRunning: runtime.isRunning,
        engine: runtime.activeEngine,
        activeModelId: runtime.activeModelId,
        activeModelName: runtime.activeModelName,
      );
      expect(runtime.actions, ['stop', 'start']);
      expect(chat.canSend, isTrue);
      await chat.selectTarget(local, startLocal: true);
      expect(runtime.actions, ['stop', 'start']);
      await chat.selectTarget(two, startLocal: true);
      expect(runtime.running, isTrue);
      expect(runtime.actions, ['stop', 'start']);
      await expectLater(
        chat.selectTarget(const ChatTarget.remote('c', 'unlisted')),
        throwsStateError,
      );
      expect(chat.currentTarget?.modelId, 'two');
    },
  );

  test(
    'run in progress blocks context changes and credential deletion cancels its request',
    () async {
      await chat.load();
      protocol.blocker = Completer<void>();
      final sending = chat.sendMessage('Hello');
      await protocol.firstRequest.future.timeout(const Duration(seconds: 5));
      final id = chat.selectedSession!.id;
      await chat.selectAssistant('b');
      await chat.selectTarget(two);
      await chat.reassignAssistant(id, 'b');
      expect(chat.currentAssistantId, 'a');
      expect(chat.currentModelId, 'one');
      await assistants.deleteConnection('c');
      await sending;
      expect(chat.isSending, isFalse);
      expect(chat.canSend, isFalse);
      expect(protocol.models, ['one']);
    },
  );

  test(
    'local selection is locked during lookup and startup never replaces a published model',
    () async {
      await chat.load();
      assets.lookup = Completer<void>();
      final selection = chat.selectTarget(local);
      await chat.selectAssistant('b');
      expect(chat.currentAssistantId, 'a');
      assets.lookup!.complete();
      await selection;
      runtime.running = true;
      runtime.published = true;
      runtime.model = 'other';
      bind();
      await expectLater(chat.prepareLocalTarget(), throwsStateError);
      expect(runtime.actions, isEmpty);
      runtime.published = false;
      runtime.startBlocker = Completer<void>();
      final start = chat.prepareLocalTarget();
      await runtime.started.future.timeout(const Duration(seconds: 5));
      await chat.selectTarget(two);
      expect(chat.currentTarget?.assetId, 'local-asset');
      runtime.startBlocker!.complete();
      await start;
      expect(runtime.actions, ['stop', 'start']);
      expect(runtime.model, 'local-runtime');
      await chat.selectTarget(two);
      expect(runtime.running, isTrue);
      expect(runtime.actions, ['stop', 'start']);
    },
  );

  test(
    'assistant deletion removes only owned conversations and drafts, and survives restart',
    () async {
      await assistants.setChatTarget('b', two);
      await repository.saveSession(session('a1', 'a'));
      await repository.saveSession(session('a2', 'a'));
      await repository.saveSession(session('moved', 'a'));
      await repository.saveSession(session('b1', 'b'));
      await chat.load();
      chat.updateDraft('Remove A draft');
      chat.addImageAttachment('/fixture/a.png');
      await chat.selectAssistant('b');
      chat.updateDraft('Keep B draft');
      chat.addImageAttachment('/fixture/b.png');
      await chat.reassignAssistant('moved', 'b');
      chat.updateDraft('Keep moved draft', key: 'moved');
      await chat.selectSession('a1');
      chat.updateDraft('Remove A1 draft');
      chat.addImageAttachment('/fixture/a1.png');
      chat.updateDraft('Remove A2 draft', key: 'a2');
      final saving = chat.flushDrafts();
      final deleting = chat.deleteAssistant('a');
      expect(chat.canManageSessions, isFalse);
      await chat.reassignAssistant('a2', 'b');
      await Future.wait([saving, deleting]);
      expect(chat.canManageSessions, isTrue);
      expect(chat.currentAssistantId, 'b');
      expect(chat.selectedSession, isNull);
      expect(chat.visibleMessages, isEmpty);
      expect(chat.sessions.map((s) => s.id), unorderedEquals(['moved', 'b1']));
      expect(chat.currentDraft, 'Keep B draft');
      expect(chat.pendingImageAttachments, ['/fixture/b.png']);
      for (final key in ['draft:a', 'a1', 'a2']) {
        expect(chat.draftFor(key), isEmpty);
        expect(chat.hasDraftDestination(key), isFalse);
        chat.updateDraft('A late callback must not restore this', key: key);
      }
      await chat.flushDrafts();
      final saved = jsonDecode((await db.metadata('chatDrafts'))!) as Map;
      expect(saved.keys, unorderedEquals(['draft:b', 'moved']));
      await chat.selectSession('moved');
      expect(chat.currentAssistantId, 'b');
      expect(chat.currentTarget?.modelId, 'two');
      expect(chat.currentDraft, 'Keep moved draft');
      final restored = ChatProvider(
        repository: repository,
        protocolClient: _Protocol(),
      );
      try {
        restored.bind(assistants, runtime);
        await restored.load();
        expect(
          restored.sessions.map((s) => s.id),
          unorderedEquals(['moved', 'b1']),
        );
        expect(restored.currentDraft, 'Keep B draft');
        expect(restored.draftFor('draft:a'), isEmpty);
        await restored.selectSession('moved');
        expect(restored.currentDraft, 'Keep moved draft');
        expect(restored.canSend, isTrue);
      } finally {
        restored.dispose();
        await restored.flushDrafts();
      }
    },
  );

  test('deleting an assistant also removes its adopted legacy draft', () async {
    await db.setMetadata('chatDrafts', jsonEncode({'draft': 'Legacy A draft'}));
    await chat.load();
    expect(chat.currentDraft, 'Legacy A draft');
    await chat.deleteAssistant('a');
    expect(jsonDecode((await db.metadata('chatDrafts'))!), isEmpty);
    expect(chat.currentAssistantId, 'b');
    expect(chat.currentDraft, isEmpty);
  });

  test(
    'deleting the preferred assistant keeps another selected conversation intact',
    () async {
      await assistants.setChatTarget('b', two);
      await chat.load();
      await chat.sendMessage('A history');
      final id = chat.selectedSession!.id;
      await chat.reassignAssistant(id, 'b');
      chat.updateDraft('Continue with B');
      final messages = chat.visibleMessages.map((m) => m.id).toList();
      expect(assistants.activeId, 'a');
      await chat.deleteAssistant('a');
      expect(assistants.activeId, 'b');
      expect(chat.selectedSession!.id, id);
      expect(chat.visibleMessages.map((m) => m.id), messages);
      expect(chat.visibleMessages.last.author!.assistantId, 'a');
      expect(chat.currentDraft, 'Continue with B');
      expect(chat.canSend, isTrue);
      expect(
        await assistantRepository.preferences.getString('v2.activeAssistant'),
        'b',
      );
    },
  );

  test(
    'a failed assistant deletion retains UI, history, attachments and drafts',
    () async {
      await chat.load();
      await chat.sendMessage('Keep history');
      final id = chat.selectedSession!.id;
      chat.updateDraft('Keep draft');
      chat.addImageAttachment('/fixture/keep.png');
      await db.execute(
        "CREATE TRIGGER reject_assistant_delete BEFORE DELETE ON assistants BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(chat.deleteAssistant('a'), throwsA(anything));
      expect(chat.canManageSessions, isTrue);
      expect(assistants.activeId, 'a');
      expect(assistants.assistants, hasLength(2));
      expect(chat.selectedSession!.id, id);
      expect(chat.visibleMessages, hasLength(2));
      expect(chat.currentDraft, 'Keep draft');
      expect(chat.pendingImageAttachments, ['/fixture/keep.png']);
      expect(jsonDecode((await db.metadata('chatDrafts'))!)[id], 'Keep draft');
      await db.execute('DROP TRIGGER reject_assistant_delete');
      await chat.deleteAssistant('a');
      expect(chat.visibleMessages, isEmpty);
      expect(chat.currentAssistantId, 'b');
      expect(chat.pendingImageAttachments, isEmpty);
      await expectLater(chat.deleteAssistant('b'), throwsStateError);
      expect(chat.canManageSessions, isTrue);
      expect(assistants.assistants.single.id, 'b');
    },
  );

  test(
    'assistant deletion is blocked while generation owns the conversation',
    () async {
      await chat.load();
      protocol.blocker = Completer<void>();
      final generation = chat.sendMessage('In progress');
      await protocol.firstRequest.future;
      await chat.deleteAssistant('a');
      expect(assistants.assistants, hasLength(2));
      expect(chat.currentAssistantId, 'a');
      protocol.blocker!.complete();
      await generation;
      await chat.deleteAssistant('a');
      expect(chat.sessions, isEmpty);
    },
  );

  testWidgets(
    'assistant deletion warns about associated data; cancel preserves it and confirm deletes it',
    (tester) async {
      AppDatabase.current = null;
      try {
        await tester.runAsync(() async {
          await repository.saveSession(session('owned', 'a'));
          await chat.load();
          await chat.selectSession('owned');
          chat.updateDraft('Keep until confirmed');
        });
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(const AssistantsPage(), scale: 1.6));
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(
          tester.element(find.byType(AssistantsPage)),
        )!;
        Future<void> openConfirmation() async {
          await tester.tap(
            find.descendant(
              of: find.widgetWithText(ListTile, 'A'),
              matching: find.byType(PopupMenuButton<String>),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(l.commonDelete));
          await tester.pumpAndSettle();
          expect(find.text(l.v2DeleteAssistantHelp), findsOneWidget);
          expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        }

        await openConfirmation();
        await tester.tap(find.text(l.commonCancel));
        await tester.pumpAndSettle();
        expect(assistants.assistants, hasLength(2));
        expect(chat.selectedSession!.id, 'owned');
        expect(chat.currentDraft, 'Keep until confirmed');
        await openConfirmation();
        await changeOnScreen(
          tester,
          () => tester.tap(find.text(l.commonDelete)),
          () => assistants.assistants.length == 1 && chat.canManageSessions,
        );
        expect(chat.sessions, isEmpty);
        expect(chat.currentAssistantId, 'b');
        expect(find.text('A'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  test(
    'incomplete legacy defaults and missing local assets require explicit repair',
    () async {
      await db.execute('UPDATE assistants SET config=? WHERE id=?', [
        jsonEncode({
          'id': 'a',
          'name': 'A',
          'target': const ChatTarget.remote('c', null).toJson(),
        }),
        'a',
      ]);
      await assistants.load();
      await chat.load();
      await chat.selectAssistant('a');
      expect(chat.currentTarget, isNull);
      expect(chat.canSend, isFalse);
      await chat.selectTarget(local);
      await chat.ensureConversation();
      final id = chat.selectedSession!.id;
      assets.entries = [];
      await db.execute("UPDATE model_assets SET state='missing'");
      await assistants.refreshAssets();
      expect(chat.currentTarget, isNull);
      expect(assistants.assistants.first.chatTarget, isNull);
      await chat.selectTarget(two);
      expect(chat.selectedSession!.id, id);
      expect(chat.canSend, isTrue);
      expect(chat.currentModelId, 'two');
    },
  );

  test(
    'conversation writes cannot race with model or assistant changes',
    () async {
      await chat.load();
      await chat.sendMessage('Hello');
      final id = chat.selectedSession!.id;
      final reply = chat.visibleMessages.last.id;
      for (final operation in <Future<void> Function()>[
        () => chat.renameSession(id, 'Renamed'),
        () => chat.editMessage(messageId: reply, newContent: 'Edited reply'),
        () => chat.selectMessageVersion(messageId: reply, versionIndex: 0),
        () => chat.deleteMessage(reply),
      ]) {
        final writing = operation();
        expect(chat.canManageSessions, isFalse);
        await chat.selectTarget(two);
        await chat.selectAssistant('b');
        await writing;
        expect(chat.canManageSessions, isTrue);
        expect(chat.currentAssistantId, 'a');
        expect(chat.currentModelId, 'one');
      }
      await db.execute(
        "CREATE TRIGGER reject_update BEFORE UPDATE ON conversations BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(chat.renameSession(id, 'Rejected'), throwsA(anything));
      expect(chat.canManageSessions, isTrue);
      await db.execute('DROP TRIGGER reject_update');
      await chat.selectTarget(two);
      expect(chat.currentModelId, 'two');
    },
  );

  test(
    'startup never infers a model from historical conversation or runtime',
    () async {
      await repository.saveSession(session('recent', 'b'));
      runtime.model = 'local-runtime';
      await assistants.select('b');
      final restored = ChatProvider(
        repository: repository,
        protocolClient: _Protocol(),
      );
      try {
        restored.bind(assistants, runtime);
        expect(restored.currentTarget, isNull);
        await restored.load();
        expect(restored.currentAssistantId, 'b');
        expect(restored.currentModelId, isNull);
        expect(restored.canSend, isFalse);
      } finally {
        restored.dispose();
        await restored.flushDrafts();
      }
    },
  );

  test(
    'cold state restoration keeps session selection data and text drafts',
    () async {
      await db.setMetadata(
        'chatDrafts',
        jsonEncode({'draft': 'Legacy unsent'}),
      );
      await chat.load();
      expect(chat.currentDraft, 'Legacy unsent');
      await chat.selectTarget(two);
      await chat.ensureConversation();
      final id = chat.selectedSession!.id;
      await chat.flushDrafts();
      final restored = ChatProvider(
        repository: repository,
        protocolClient: _Protocol(),
      );
      try {
        restored.bind(assistants, runtime);
        await restored.load();
        await restored.selectSession(id);
        expect(restored.currentAssistantId, 'a');
        expect(restored.currentModelId, 'two');
        expect(restored.currentDraft, 'Legacy unsent');
        expect(
          jsonDecode((await db.metadata('chatDrafts'))!),
          isNot(contains('draft')),
        );
      } finally {
        restored.dispose();
        await restored.flushDrafts();
      }
    },
  );

  test(
    'startup preserves explicit session settings without inferring from defaults or old runs',
    () async {
      Future<void> old(String id, Map<String, dynamic> config) => db
          .execute(
            'INSERT INTO conversations(id,title,created_at,updated_at,message_ids,config) VALUES(?,?,1,2,?,?)',
            [id, id, '[]', jsonEncode(config)],
          )
          .then((_) {});
      await old('from-default', {'assistantId': 'a'});
      await old('from-run', {});
      await old('unknown', {});
      await old('configured', {'assistantId': 'b', 'target': two.toJson()});
      await db.execute(
        'INSERT INTO generation_runs(id,conversation_id,message_id,state,snapshot,checkpoint,updated_at) VALUES(?,?,?,?,?,?,1)',
        [
          'run',
          'from-run',
          'message',
          'completed',
          jsonEncode({
            'assistant': {'id': 'removed', 'name': 'Former'},
            'local': false,
            'connection': {'id': 'c'},
            'modelId': 'actual',
          }),
          '{}',
        ],
      );
      final loaded = {for (final s in await repository.loadSessions()) s.id: s};
      expect(loaded['from-run']!.assistantId, isNull);
      expect(loaded['unknown']!.assistantId, isNull);
      final before = await db.query('SELECT * FROM conversations ORDER BY id');
      await ChatSessionRepository(
        database: db,
        appSupportDirectory: directory,
      ).loadSessions();
      final after = await db.query('SELECT * FROM conversations ORDER BY id');
      expect(
        after.map((r) => r.data).toList(),
        before.map((r) => r.data).toList(),
      );
      expect(
        Assistant.fromJson({
          'id': 'legacy',
          'name': 'Legacy',
          'target': one.toJson(),
        }).chatTarget?.modelId,
        'one',
      );
      expect(
        Assistant.fromJson({
          'id': 'legacy',
          'name': 'Legacy',
          'target': const ChatTarget.local(null).toJson(),
        }).chatTarget,
        isNull,
      );
    },
  );
}
