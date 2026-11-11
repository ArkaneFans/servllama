import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

import 'stub_engine_adapter.dart';

/// Real business storage and providers, with only the remote inference replaced.
class ChatFixture {
  late final Directory directory;
  late final AppDatabase database;
  late final AssistantProvider assistants;
  late final EngineRuntimeProvider runtime;
  late final ChatSessionRepository repository;
  late final ChatProvider chat;
  final protocol = FixtureProtocol();

  Future<void> initialize() async {
    directory = await Directory.systemTemp.createTemp('servllama-chat-test-');
    database = AppDatabase.memory();
    AppDatabase.current = database;
    await database.setMetadata('legacyImportComplete', '1');
    await database.setMetadata('legacyInventoryImportComplete', '1');
    final settings = AssistantRepository(database, preferences: KvStorage());
    await settings.saveConnection(
      const AiConnection(
        id: 'provider',
        name: 'Test provider',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        apiKey: 'fixture-key',
        models: ['model-one', 'model-two'],
      ),
    );
    await settings.saveAssistant(
      const Assistant(
        id: 'assistant',
        name: 'Assistant',
        instructions: 'Be concise',
        chatTarget: ChatTarget.remote('provider', 'model-one'),
      ),
    );
    assistants = AssistantProvider(
      repository: settings,
      models: UnifiedModelRepository(database: database),
    );
    await assistants.load();
    await assistants.select('assistant');
    runtime = EngineRuntimeProvider(
      kvStorage: KvStorage(),
      llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
      mnnAdapter: StubEngineAdapter(),
    );
    repository = ChatSessionRepository(
      database: database,
      appSupportDirectory: directory,
    );
    chat = ChatProvider(repository: repository, protocolClient: protocol);
    assistants.addListener(_bind);
    runtime.addListener(_bind);
    _bind();
    await chat.load();
  }

  void _bind() => chat.bind(assistants, runtime);

  Widget app(Widget home) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
      ChangeNotifierProvider<EngineRuntimeProvider>.value(value: runtime),
      ChangeNotifierProvider<ChatProvider>.value(value: chat),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  Future<void> close() async {
    assistants.removeListener(_bind);
    runtime.removeListener(_bind);
    chat.dispose();
    await chat.flushDrafts();
    assistants.dispose();
    runtime.dispose();
    runtime.resources.dispose();
    AppDatabase.current = null;
    await database.close();
    await directory.delete(recursive: true);
  }
}

class FixtureProtocol extends ChatProtocolClient {
  final inputs = <List<AiTurn>>[];
  final models = <String>[];
  final reasoningLevels = <ReasoningLevel>[];
  List<AiEvent> events = const [
    AiEvent(text: 'Reply'),
    AiEvent(stopReason: 'stop'),
  ];
  Object? error;
  Completer<void>? blocked;
  final started = Completer<void>();

  @override
  Stream<AiEvent> complete(
    AiConnection connection,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    ReasoningLevel reasoningLevel = ReasoningLevel.auto,
    String? runId,
  }) async* {
    models.add(model);
    reasoningLevels.add(reasoningLevel);
    inputs.add(List.of(turns));
    if (!started.isCompleted) started.complete();
    for (final event in events) {
      yield event;
    }
    if (blocked != null) {
      await Future.any([blocked!.future, cancelToken.whenCancel]);
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    if (error != null) throw error!;
  }
}

/// Wait for a business outcome while allowing Drift's scheduler and UI frames.
Future<void> settleBusiness(
  WidgetTester tester,
  bool Function() complete,
) async {
  for (var attempt = 0; attempt < 100 && !complete(); attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(complete(), isTrue, reason: 'Business operation did not finish');
  await tester.pumpAndSettle();
}
