import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late UnifiedModelRepository catalog;
  late AssistantRepository assistants;
  late Directory root;
  setUp(() async {
    db = AppDatabase.memory();
    catalog = UnifiedModelRepository(database: db);
    assistants = AssistantRepository(db);
    root = await Directory.systemTemp.createTemp('legacy-model-cleanup-');
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<void> seed(
    String id, {
    String engine = 'mnn',
    AssetKind kind = AssetKind.llm,
    String state = 'missing',
  }) => catalog.saveAsset(
    ModelAsset(
      id: id,
      kind: kind,
      engine: engine,
      runtimeId: id,
      storageOwner: engine == 'mnn' ? 'mnn_engine' : 'app',
      path: '${root.path}/$id',
      name: id,
      revision: 'local',
      state: state,
    ),
  );

  test(
    'cleanup removes old LLM rows and targets once, preserving files and history',
    () async {
      await seed('deleted-mnn');
      await seed('deleted-gguf', engine: 'llama_cpp');
      await seed('ready', state: 'ready');
      await seed('speech', kind: AssetKind.tts);
      final file = await File('${root.path}/deleted-mnn').writeAsString('keep');
      await assistants.saveAssistant(
        const Assistant(
          id: 'old',
          name: 'Old',
          chatTarget: ChatTarget.local('deleted-mnn'),
        ),
      );
      await assistants.saveAssistant(
        const Assistant(
          id: 'active',
          name: 'Active',
          chatTarget: ChatTarget.local('ready'),
        ),
      );
      await db.execute(
        "INSERT INTO conversations(id,title,assistant_id,created_at,updated_at) VALUES('history','History','old',0,0)",
      );
      await db.execute(
        "INSERT INTO generation_runs(id,conversation_id,state,snapshot,checkpoint,updated_at) VALUES('run','history','completed',?, '{}',0)",
        ['{"assetId":"deleted-mnn","model":"Deleted MNN"}'],
      );
      final history = (await db.query(
        'SELECT * FROM generation_runs',
      )).single.data;
      await db.setMetadata(LegacyImporter.inventoryMarker, '1');
      await db.setMetadata(UnifiedModelRepository.mnnInventoryMarker, '1');

      await catalog.cleanupLegacyMissingModels();
      expect((await catalog.listAssets()).map((a) => a.id).toSet(), {
        'ready',
        'speech',
      });
      final current = await assistants.assistants();
      expect(current.firstWhere((a) => a.id == 'old').chatTarget, isNull);
      expect(
        current.firstWhere((a) => a.id == 'active').chatTarget,
        const ChatTarget.local('ready'),
      );
      expect(
        (await db.query('SELECT * FROM generation_runs')).single.data,
        history,
      );
      expect(await db.query('SELECT * FROM conversations'), hasLength(1));
      expect(await file.readAsString(), 'keep');
      expect(
        await db.metadata(UnifiedModelRepository.missingModelsCleanupMarker),
        '1',
      );
      expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
      expect(await db.metadata(UnifiedModelRepository.mnnInventoryMarker), '1');
      await catalog.cleanupLegacyMissingModels();
      expect(
        (await assistants.assistants())
            .firstWhere((a) => a.id == 'old')
            .revision,
        2,
      );
    },
  );

  test(
    'marker failure rolls back rows and references, allowing startup retry',
    () async {
      await seed('deleted');
      await assistants.saveAssistant(
        const Assistant(
          id: 'old',
          name: 'Old',
          chatTarget: ChatTarget.local('deleted'),
        ),
      );
      await db.execute(
        "CREATE TRIGGER reject_cleanup BEFORE INSERT ON app_metadata WHEN NEW.key='legacyMissingLlmAssetsRemoved' BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        catalog.cleanupLegacyMissingModels(),
        throwsA(anything),
      );
      expect(await catalog.asset('deleted'), isNotNull);
      expect(
        (await assistants.assistants()).single.chatTarget,
        const ChatTarget.local('deleted'),
      );
      expect(
        await db.metadata(UnifiedModelRepository.missingModelsCleanupMarker),
        isNull,
      );
      await db.execute('DROP TRIGGER reject_cleanup');
      await catalog.cleanupLegacyMissingModels();
      expect(await catalog.asset('deleted'), isNull);
      expect((await assistants.assistants()).single.chatTarget, isNull);
    },
  );
}
