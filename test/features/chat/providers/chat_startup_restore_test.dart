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
import 'package:servllama/features/chat/repositories/chat_draft_repository.dart';

import '../../../support/stub_engine_adapter.dart';

class _Assets extends UnifiedModelRepository {
  final pending = Completer<List<ModelAsset>>();

  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) =>
      pending.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final draftsFirst in [false, true]) {
    test(
      'typing survives draft/assistant restore (draftsFirst=$draftsFirst)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final db = AppDatabase.current = AppDatabase.memory();
        final repository = AssistantRepository(db, preferences: KvStorage());
        await repository.saveAssistant(const Assistant(id: 'a', name: 'A'));
        final drafts = ChatDraftRepository(db);
        await drafts.saveChanges({'draft:a': 'older saved input'});
        final models = _Assets();
        final assistants = AssistantProvider(
          repository: repository,
          models: models,
        );
        final runtime = EngineRuntimeProvider(
          llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
          mnnAdapter: StubEngineAdapter(),
        );
        final chat = ChatProvider();
        void bind() => chat.bind(assistants, runtime);
        assistants.addListener(bind);
        bind();
        final restoring = assistants.ensureLoaded();
        final draftLoad = chat.prepareDrafts();
        if (draftsFirst) await draftLoad;
        chat.updateDraft('newly typed input');
        expect(chat.canSubmitInput, isFalse);
        await draftLoad;
        models.pending.complete([]);
        await restoring;
        expect(chat.currentAssistantId, 'a');
        expect(chat.currentDraft, 'newly typed input');
        await chat.flushDrafts();
        expect((await drafts.load())['draft:a'], 'newly typed input');
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
