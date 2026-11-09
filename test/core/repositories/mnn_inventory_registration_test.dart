import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/database/legacy_importer.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory root;
  late UnifiedModelRepository catalog;
  late int reads;
  late List<MnnModelInfo> inventory;
  setUp(() async {
    await Hive.close();
    root = await Directory.systemTemp.createTemp('mnn-inventory-');
    db = AppDatabase.memory();
    catalog = UnifiedModelRepository(database: db);
    reads = 0;
    inventory = [_model('Old MNN')];
  });
  tearDown(() async {
    await Hive.close();
    await db.close();
    await root.delete(recursive: true);
  });
  Future<void> register() => catalog.registerLegacyMnnInventory(
    readInventory: () async {
      reads++;
      return inventory;
    },
  );

  test(
    'startup registers old private inventory once without Hive files',
    () async {
      await register();
      final model = (await catalog.listModels()).single;
      expect(model.name, 'Old MNN');
      expect(model.runtimeId, 'Old MNN');
      expect(model.sizeBytes, 4096);
      expect(model.supportsVision, isTrue);
      expect(await Directory(model.storagePath).exists(), isFalse);
      expect(await db.metadata(UnifiedModelRepository.mnnInventoryMarker), '1');
      expect(await db.metadata(LegacyImporter.chatsMarker), isNull);
      expect(await db.metadata(LegacyImporter.inventoryMarker), isNull);
      await register();
      expect(reads, 1);
      expect((await catalog.listModels()).single.id, model.id);
    },
  );

  test(
    '2.0 startup preserves UUID and leaves migrated Hive untouched',
    () async {
      await db.setMetadata(LegacyImporter.chatsMarker, '1');
      await db.setMetadata(LegacyImporter.inventoryMarker, '1');
      final oldHive = await File(
        '${root.path}/imported_models.hive',
      ).writeAsString('unreadable old Hive');
      await catalog.saveAsset(
        ModelAsset(
          id: 'existing-uuid',
          kind: AssetKind.llm,
          engine: 'mnn',
          runtimeId: 'Old MNN',
          storageOwner: 'mnn_engine',
          path: inventory.single.modelDirPath,
          name: 'Old MNN',
          revision: 'local',
          manifest: {'images': false},
        ),
      );
      await register();
      final registered = (await catalog.listModels()).single;
      expect(registered.id, 'existing-uuid');
      expect(registered.sizeBytes, 4096);
      expect(registered.supportsVision, isTrue);
      expect(await oldHive.readAsString(), 'unreadable old Hive');
      expect(reads, 1);
    },
  );

  test('SQL failure rolls back MNN rows and marker independently', () async {
    await db.setMetadata(LegacyImporter.inventoryMarker, '1');
    await db.execute(
      "CREATE TRIGGER reject_mnn BEFORE INSERT ON model_assets BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    await expectLater(register(), throwsA(anything));
    expect(await db.query('SELECT * FROM model_assets'), isEmpty);
    expect(
      await db.metadata(UnifiedModelRepository.mnnInventoryMarker),
      isNull,
    );
    expect(await db.metadata(LegacyImporter.inventoryMarker), '1');
    await db.execute('DROP TRIGGER reject_mnn');
    await register();
    expect(await db.metadata(UnifiedModelRepository.mnnInventoryMarker), '1');
    expect(reads, 2);
  });

  test(
    'registration neither restores missing rows nor claims external paths',
    () async {
      for (final owner in ['mnn_engine', 'external']) {
        await catalog.saveAsset(
          ModelAsset(
            id: owner,
            kind: AssetKind.llm,
            engine: 'mnn',
            runtimeId: owner,
            storageOwner: owner,
            path: _model(owner).modelDirPath,
            name: owner,
            revision: 'local',
            state: owner == 'mnn_engine' ? 'missing' : 'ready',
          ),
        );
      }
      inventory = [_model('mnn_engine'), _model('external')];
      await register();
      expect((await catalog.asset('mnn_engine'))!.state, 'missing');
      expect((await catalog.asset('external'))!.storageOwner, 'external');
    },
  );
}

MnnModelInfo _model(String name) => MnnModelInfo(
  modelId: name,
  modelKey: name,
  displayName: name,
  modelDirPath: '/missing/private-mnn/$name',
  configPath: '/missing/private-mnn/$name/config.json',
  sizeBytes: 4096,
  importedAt: 1000,
  isActive: false,
  supportsVision: true,
  validationWarnings: ['fixture warning'],
);
