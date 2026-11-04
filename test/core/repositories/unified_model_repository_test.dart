import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/model_name_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.arkanefans.mnn_engine/methods');
  late AppDatabase db;
  late UnifiedModelRepository repository;
  late List<String> calls;
  setUp(() {
    db = AppDatabase.memory();
    repository = UnifiedModelRepository(
      database: db,
      localModelRepository: _Local(db),
    );
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          throw StateError('Unexpected native inventory read');
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await db.close();
  });
  Future<void> gguf(String name) => GgufModelStore(db).save(_descriptor(name));
  Future<void> mnn(String name) async {
    await repository.registerImportedMnnModel(_mnn(name));
  }

  test(
    'SQL lists missing files without native calls or metadata writes',
    () async {
      await gguf('Vision');
      await mnn('MNN');
      final before = (await db.query(
        'SELECT * FROM model_assets ORDER BY id',
      )).map((r) => r.data).toList();
      final models = await repository.listModels();
      expect(models, hasLength(2));
      expect(
        models.map((m) => m.id).toSet(),
        before.map((r) => r['id']).toSet(),
      );
      expect(models.firstWhere((m) => m.name == 'Vision').hasMmproj, isTrue);
      expect(await repository.listAssets(), hasLength(2));
      expect(calls, isEmpty);
      expect(
        (await db.query(
          'SELECT * FROM model_assets ORDER BY id',
        )).map((r) => r.data).toList(),
        before,
      );
    },
  );
  test(
    'chat and library share ready LLM registrations without old tombstones',
    () async {
      await gguf('Ready GGUF');
      await mnn('Ready MNN');
      for (final a in [
        const ModelAsset(
          id: 'deleted-gguf',
          kind: AssetKind.llm,
          engine: 'llama_cpp',
          runtimeId: 'Deleted GGUF',
          storageOwner: 'app',
          path: '/missing/old.gguf',
          name: 'Deleted GGUF',
          revision: 'local',
          state: 'missing',
        ),
        const ModelAsset(
          id: 'speech',
          kind: AssetKind.tts,
          engine: 'sherpa',
          runtimeId: 'Speech',
          storageOwner: 'app',
          path: '/missing/speech',
          name: 'Speech',
          revision: 'local',
        ),
      ]) {
        await repository.saveAsset(a);
      }
      final before = (await db.query(
        'SELECT * FROM model_assets ORDER BY id',
      )).map((r) => r.data).toList();
      final assets = await repository.listLlmAssets();
      final library = await repository.listModels();
      expect(assets.map((a) => a.name), ['Ready GGUF', 'Ready MNN']);
      expect(assets.map((a) => a.id).toSet(), library.map((m) => m.id).toSet());
      expect(await repository.listAssets(), hasLength(4));
      expect(
        (await db.query(
          'SELECT * FROM model_assets ORDER BY id',
        )).map((r) => r.data).toList(),
        before,
      );
      expect(calls, isEmpty);
    },
  );

  test('rejects names already registered by either engine', () async {
    await gguf('Shared Name');
    await mnn('MNN Name');
    for (final name in ['shared name', 'mnn name']) {
      await expectLater(
        repository.ensureNameAvailable(name),
        throwsA(
          isA<ModelOperationException>().having(
            (e) => e.code,
            'code',
            ModelOperationErrorCode.modelNameExists,
          ),
        ),
      );
    }
    expect(calls, isEmpty);
  });
  test('MNN rename preserves SQL identity and import time', () async {
    await mnn('before');
    final original = (await repository.listModels()).single;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'renameImportedModel');
          expect((call.arguments as Map)['modelId'], 'before');
          return _mnnMap('After model', importedAt: 99999);
        });
    final renamed = await repository.renameModel(original, 'After model');
    expect(renamed.id, original.id);
    expect(renamed.runtimeId, 'After model');
    expect(renamed.importedAt, original.importedAt);
    expect((await repository.asset(original.id))!.path, renamed.storagePath);
  });
  test('SQL rename failure restores the private directory name', () async {
    await mnn('before');
    final original = (await repository.listModels()).single;
    await db.execute(
      "CREATE TRIGGER reject_rename BEFORE UPDATE ON model_assets BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );
    final renames = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final args = call.arguments as Map;
          renames.add('${args['modelId']}->${args['newName']}');
          return _mnnMap(args['newName'] as String);
        });
    await expectLater(
      repository.renameModel(original, 'after'),
      throwsA(anything),
    );
    expect(renames, ['before->after', 'after->before']);
    expect((await repository.asset(original.id))!.runtimeId, 'before');
  });
  test(
    'internal deletion happens before SQL and can retry absent files',
    () async {
      await mnn('remove');
      final original = (await repository.listModels()).single;
      var deletes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'deleteImportedModel');
            expect((call.arguments as Map)['modelId'], 'remove');
            expect(await repository.asset(original.id), isNotNull);
            deletes++;
            return null;
          });
      await db.execute(
        "CREATE TRIGGER reject_delete BEFORE DELETE ON model_assets BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(repository.deleteModel(original), throwsA(anything));
      expect((await repository.asset(original.id))!.state, 'ready');
      await db.execute('DROP TRIGGER reject_delete');
      await repository.deleteModel(original);
      expect(deletes, 2);
      expect(await repository.asset(original.id), isNull);
    },
  );
  test('native deletion failure preserves registration', () async {
    await mnn('keep');
    final original = (await repository.listModels()).single;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'fixture'),
        );
    await expectLater(
      repository.deleteModel(original),
      throwsA(isA<MnnEngineException>()),
    );
    expect((await repository.asset(original.id))!.state, 'ready');
  });
  test(
    'allocates the smallest suffix from SQL and pending reservations',
    () async {
      await gguf('MODEL');
      await mnn('Model (2)');
      await gguf('model (3)');
      final coordinator = ModelNameCoordinator(unifiedRepository: repository);
      expect(
        (await coordinator.reserveAvailable(
          ownerId: 'one',
          requestedName: 'model',
        )).name,
        'model (4)',
      );
      expect(
        (await coordinator.reserveAvailable(
          ownerId: 'two',
          requestedName: 'MODEL',
        )).name,
        'MODEL (5)',
      );
    },
  );
  test('unregistered native commit has no virtual library ID', () async {
    final coordinator = ModelNameCoordinator(unifiedRepository: repository);
    await coordinator.reserveAvailable(
      ownerId: 'download',
      requestedName: 'Qwen',
    );
    final result = await coordinator.reserveCommitted(
      ownerId: 'import',
      requestedName: 'Qwen',
      committedName: 'Qwen',
    );
    expect(result.name, 'Qwen');
    expect(calls, isEmpty);
  });
}

class _Local extends LocalModelRepository {
  _Local(AppDatabase db)
    : super(database: db, appSupportDirectory: Directory.systemTemp);
  @override
  Future<bool> isModelDirectoryOccupied(
    String name, {
    String? excludingModelId,
  }) async => false;
}

ModelDescriptor _descriptor(String name) => ModelDescriptor(
  id: 'gguf-$name',
  modelName: name,
  sizeBytes: 100,
  storedDirectoryPath: '/missing/$name',
  storedFilePath: '/missing/$name/model.gguf',
  mmprojFilePath: '/missing/$name/mmproj.gguf',
  importedAt: DateTime(2026),
);
MnnModelInfo _mnn(String name) => MnnModelInfo.fromMap(_mnnMap(name));
Map<String, Object?> _mnnMap(String name, {int importedAt = 1000}) => {
  'modelId': name,
  'modelKey': name,
  'displayName': name,
  'modelDirPath': '/missing/mnn/$name',
  'configPath': '/missing/mnn/$name/config.json',
  'sizeBytes': 200,
  'importedAt': importedAt,
  'supportsVision': true,
  'validationWarnings': ['fixture'],
  'isActive': false,
};
