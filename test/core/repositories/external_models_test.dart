import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.arkanefans.mnn_engine/methods');
  late AppDatabase db;
  late Directory root;
  late LocalModelRepository local;
  late UnifiedModelRepository unified;
  late List<String> calls;
  late List<String> clearedCaches;
  PlatformException? cacheError;

  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('external_models_');
    local = LocalModelRepository(
      database: db,
      appSupportDirectory: Directory('${root.path}/app'),
    );
    unified = UnifiedModelRepository(database: db, localModelRepository: local);
    calls = [];
    clearedCaches = [];
    cacheError = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'listImportedModels') return <Object?>[];
          if (call.method == 'getModelInfoFromPath') {
            return {
              'modelId': 'source-folder',
              'sizeBytes': 2048,
              'supportsVision': true,
              'supportsToolCalling': true,
            };
          }
          if (call.method == 'clearMmapCache') {
            clearedCaches.add((call.arguments as Map)['modelId'] as String);
            if (cacheError != null) throw cacheError!;
            return {'sizeBytes': 0, 'cleared': true};
          }
          throw StateError('Unexpected native operation: ${call.method}');
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'GGUF registration stores its original path and survives a missing file',
    () async {
      final path = '${root.path}/never-created.gguf';
      final model = await local.addExternalModel(
        PickedGgufFile(path: path, fileName: 'never-created.gguf'),
        modelName: 'External',
      );
      expect(model.isExternal, isTrue);
      expect((await local.listModels()).single.storedFilePath, path);
      final assets = await unified.listAssets();
      expect(assets.single.storageOwner, 'external');
      expect(assets.single.isReady, isTrue);
      expect(assets.single.runtimeId, assets.single.name);
      expect(await Directory('${root.path}/app/models').exists(), isFalse);
      final duplicate = await local.addExternalModel(
        PickedGgufFile(path: path, fileName: 'never-created.gguf'),
        modelName: 'Other',
      );
      expect(duplicate.id, model.id);
    },
  );

  test(
    'external GGUF rename and projector removal never modify source files',
    () async {
      final source = await File(
        '${root.path}/model.gguf',
      ).writeAsString('weights');
      final projector = await File(
        '${root.path}/mmproj.gguf',
      ).writeAsString('projector');
      final model = await local.addExternalModel(
        PickedGgufFile(path: source.path, fileName: 'model.gguf'),
        modelName: 'Original',
      );
      await local.importMmproj(
        model.id,
        PickedGgufFile(path: projector.path, fileName: 'mmproj.gguf'),
      );
      final renamed = await local.renameModel(model.id, 'Alias');
      expect(renamed.storedFilePath, source.path);
      expect(renamed.mmprojFilePath, projector.path);
      await projector.delete();
      expect((await local.listModels()).single.mmprojFilePath, projector.path);
      await local.selectMmproj(model.id, projector.path);
      await projector.writeAsString('projector');
      await local.removeMmproj(model.id);
      await local.deleteModel(model.id);
      expect(await source.readAsString(), 'weights');
      expect(await projector.readAsString(), 'projector');
      expect(await local.listModels(), isEmpty);
    },
  );

  test(
    'external MNN is SQL-owned, survives missing paths and renames only its alias',
    () async {
      final path = '${root.path}/missing-mnn';
      final model = await unified.addExternalMnnModel(path, 'MNN');
      expect(model.isExternal, isTrue);
      expect(model.runtimeId, 'MNN');
      expect(model.sizeBytes, 2048);
      expect(model.supportsVision, isTrue);
      expect(model.supportsToolCalling, isTrue);
      expect((await unified.listModels()).single.storagePath, path);
      final asset = (await unified.listAssets()).single;
      expect(asset.isReady, isTrue);
      expect(asset.runtimeId, asset.name);
      expect(asset.manifest['sizeBytes'], 2048);
      final renamed = await unified.renameModel(model, 'Alias');
      expect(renamed.runtimeId, 'Alias');
      expect(renamed.id, asset.id);
      expect((await unified.asset(asset.id))!.id, asset.id);
      expect((await unified.asset(asset.id))!.runtimeId, 'Alias');
      expect((await unified.asset(asset.id))!.name, 'Alias');
      expect(renamed.storagePath, path);
      expect(renamed.name, 'Alias');
      expect(renamed.sizeBytes, 2048);
      expect(await unified.externalMnnModel('MNN'), isNull);
      expect(clearedCaches, ['MNN']);
      await unified.deleteModel(renamed);
      expect(await unified.listModels(), isEmpty);
      expect(await unified.asset(asset.id), isNull);
      expect(calls, isNot(contains('renameImportedModel')));
      expect(calls, isNot(contains('deleteImportedModel')));
      expect(calls, isNot(contains('importModelFromPath')));
      expect(clearedCaches, ['MNN', 'Alias']);
    },
  );
}
