import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

import '../../../support/stub_engine_adapter.dart';

class _Assets extends UnifiedModelRepository {
  final pending = Completer<List<ModelAsset>>();

  @override
  Future<List<ModelAsset>> listLlmAssets() => pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final historyFirst in [false, true]) {
    test(
      'typing survives metadata restoration without persistence (historyFirst=$historyFirst)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final db = AppDatabase.current = AppDatabase.memory();
        final repository = AssistantRepository(db, preferences: KvStorage());
        await repository.saveAssistant(const Assistant(id: 'a', name: 'A'));
        final models = _Assets();
        final assistants = AssistantProvider(
          repository: repository,
          models: models,
        );
        final runtime = EngineRuntimeProvider(
          llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
          mnnAdapter: StubEngineAdapter(),
        );
        final chat = ChatProvider(
          repository: ChatSessionRepository(database: db),
        );
        void bind() => chat.bind(assistants, runtime);
        assistants.addListener(bind);
        bind();
        final restoring = assistants.ensureLoaded();
        final historyLoad = chat.load(preloadMessages: false);
        if (historyFirst) await historyLoad;
        chat.updateInputText('newly typed input');
        expect(chat.canSubmitInput, isFalse);
        await historyLoad;
        models.pending.complete([]);
        await restoring;
        expect(chat.currentAssistantId, 'a');
        expect(chat.inputText, 'newly typed input');
        final restarted = ChatProvider(
          repository: ChatSessionRepository(database: db),
        );
        restarted.bind(assistants, runtime);
        await restarted.load(preloadMessages: false);
        expect(restarted.inputText, isEmpty);
        restarted.dispose();
        assistants.removeListener(bind);
        chat.dispose();
        assistants.dispose();
        runtime.dispose();
        AppDatabase.current = null;
        await db.close();
      },
    );
  }
}
