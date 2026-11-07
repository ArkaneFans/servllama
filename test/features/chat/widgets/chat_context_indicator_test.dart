import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/context_capacity_client.dart';
import 'package:servllama/features/chat/widgets/chat_context_indicator.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class _Chat extends ChangeNotifier implements ChatProvider {
  String revision = 'session-a';
  int? tokens = 1000;
  Completer<int?>? pending;
  @override
  ChatTarget? currentTarget = const ChatTarget.local('asset');
  String model = 'a';
  InferenceEngine engine = InferenceEngine.llamaCpp;
  @override
  String get contextUsageKey => revision;
  @override
  ModelAsset? get targetAsset => ModelAsset(
    id: 'asset',
    kind: AssetKind.llm,
    engine: engine.storageValue,
    runtimeId: model,
    storageOwner: 'app',
    path: '/model',
    name: model,
    revision: '1',
  );
  @override
  Future<int?> loadCurrentContextTokens() =>
      pending?.future ?? Future.value(tokens);
  void changed(String key) {
    revision = key;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Runtime extends ChangeNotifier implements EngineRuntimeProvider {
  String model = 'a';
  InferenceEngine engine = InferenceEngine.llamaCpp;
  @override
  bool get isRunning => true;
  @override
  InferenceEngine get activeEngine => engine;
  @override
  String get activeModelId => model;
  @override
  String get baseUrl => 'http://127.0.0.1:8080';
  @override
  String get apiKey => '';
  @override
  EngineRuntimeState get state => EngineRuntimeState(
    engine: engine,
    activeModelId: model,
    status: EngineRuntimeStatus.ready,
    startedAt: DateTime(2026),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Capacity extends ContextCapacityClient {
  final requests = <Completer<int?>>[];
  @override
  Future<int?> fetchLlamaCapacity({
    required String baseUrl,
    required String apiKey,
  }) {
    final request = Completer<int?>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  late _Chat chat;
  late _Runtime runtime;
  late _Capacity capacity;
  setUp(() {
    chat = _Chat();
    runtime = _Runtime();
    capacity = _Capacity();
  });
  tearDown(() {
    chat.dispose();
    runtime.dispose();
    capacity.dispose();
  });
  Widget app() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatContextIndicator(
        provider: chat,
        runtime: runtime,
        capacityClient: capacity,
      ),
    ),
  );
  testWidgets('late model capacity cannot revive a previous model percentage', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(capacity.requests, hasLength(1));
    chat.model = runtime.model = 'b';
    chat.tokens = 500;
    chat.changed('model-b');
    await tester.pump();
    expect(capacity.requests, hasLength(2));
    capacity.requests[1].complete(2000);
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    capacity.requests[0].complete(1000);
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
  });
  testWidgets(
    'session switch discards delayed usage; draft clears known usage',
    (tester) async {
      final old = chat.pending = Completer<int?>();
      await tester.pumpWidget(app());
      await tester.pump();
      capacity.requests.single.complete(4000);
      chat.pending = null;
      chat.tokens = 2000;
      chat.changed('session-b');
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      old.complete(1000);
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      chat.tokens = null;
      chat.changed('draft-edited');
      await tester.pumpAndSettle();
      expect(find.text('-'), findsOneWidget);
      expect(find.text('50%'), findsNothing);
    },
  );
  testWidgets('MNN and cloud never use llama capacity or invented defaults', (
    tester,
  ) async {
    chat.engine = runtime.engine = InferenceEngine.mnn;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(capacity.requests, isEmpty);
    expect(find.text('-'), findsOneWidget);
    chat.currentTarget = const ChatTarget.remote('provider', 'model');
    chat.engine = runtime.engine = InferenceEngine.llamaCpp;
    chat.changed('remote');
    await tester.pumpAndSettle();
    expect(capacity.requests, isEmpty);
    expect(find.text('-'), findsOneWidget);
  });
}
