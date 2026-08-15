import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/model_name_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.arkanefans.mnn_engine/methods');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('rejects an MNN name already used by a GGUF model', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listImportedModels') {
            return <Object?>[_mnnModelMap('mnn-model')];
          }
          return null;
        });
    final repository = UnifiedModelRepository(
      localModelRepository: _FakeLocalModelRepository(<ModelDescriptor>[
        _descriptor('Shared Name'),
      ]),
    );

    await expectLater(
      repository.ensureNameAvailable('shared name'),
      throwsA(
        isA<ModelOperationException>().having(
          (error) => error.code,
          'code',
          ModelOperationErrorCode.modelNameExists,
        ),
      ),
    );
  });

  test('rejects a GGUF name already used by an MNN model', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listImportedModels') {
            return <Object?>[_mnnModelMap('MNN Name')];
          }
          return null;
        });
    final repository = UnifiedModelRepository(
      localModelRepository: _FakeLocalModelRepository(
        const <ModelDescriptor>[],
      ),
    );

    await expectLater(
      repository.ensureNameAvailable('mnn name'),
      throwsA(isA<ModelOperationException>()),
    );
  });

  test('updates the library id when an MNN directory is renamed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'listImportedModels':
              return <Object?>[_mnnModelMap('before')];
            case 'renameImportedModel':
              final arguments = Map<Object?, Object?>.from(
                call.arguments! as Map,
              );
              expect(arguments['modelId'], 'before');
              expect(arguments['newName'], 'After model');
              return _mnnModelMap('After model');
          }
          return null;
        });
    final repository = UnifiedModelRepository(
      localModelRepository: _FakeLocalModelRepository(
        const <ModelDescriptor>[],
      ),
    );
    final model = (await repository.listModels()).single;

    final renamed = await repository.renameModel(model, 'After model');

    expect(renamed.id, 'mnn:After model');
    expect(renamed.runtimeId, 'After model');
    expect(renamed.name, 'After model');
  });

  test(
    'allocates the smallest case-insensitive suffix across stores',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'listImportedModels') {
              return <Object?>[_mnnModelMap('Model (2)')];
            }
            return null;
          });
      final repository = UnifiedModelRepository(
        localModelRepository: _FakeLocalModelRepository(<ModelDescriptor>[
          _descriptor('MODEL'),
          _descriptor('model (3)'),
        ]),
      );
      final coordinator = ModelNameCoordinator(unifiedRepository: repository);

      final allocation = await coordinator.reserveAvailable(
        ownerId: 'import',
        requestedName: 'model',
      );

      expect(allocation.name, 'model (4)');
      expect(allocation.wasRenamed, isTrue);
    },
  );

  test('reservations share the same namespace', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listImportedModels') {
            return const <Object?>[];
          }
          return null;
        });
    final coordinator = ModelNameCoordinator(
      unifiedRepository: UnifiedModelRepository(
        localModelRepository: _FakeLocalModelRepository(
          const <ModelDescriptor>[],
        ),
      ),
    );

    await coordinator.reserveAvailable(
      ownerId: 'download-1',
      requestedName: 'Qwen',
    );
    final second = await coordinator.reserveAvailable(
      ownerId: 'download-2',
      requestedName: 'qwen',
    );

    expect(second.name, 'qwen (2)');
  });

  test('a committed name keeps priority over a pending reservation', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'listImportedModels') {
            return <Object?>[_mnnModelMap('Qwen')];
          }
          return null;
        });
    final coordinator = ModelNameCoordinator(
      unifiedRepository: UnifiedModelRepository(
        localModelRepository: _FakeLocalModelRepository(
          const <ModelDescriptor>[],
        ),
      ),
    );
    await coordinator.reserveAvailable(
      ownerId: 'download',
      requestedName: 'Qwen',
    );

    final allocation = await coordinator.reserveCommitted(
      ownerId: 'import',
      requestedName: 'Qwen',
      committedName: 'Qwen',
      excludingLibraryId: 'mnn:Qwen',
    );

    expect(allocation.name, 'Qwen');
  });
}

class _FakeLocalModelRepository extends LocalModelRepository {
  _FakeLocalModelRepository(this.models)
    : super(appSupportDirectory: Directory.systemTemp);

  final List<ModelDescriptor> models;

  @override
  Future<List<ModelDescriptor>> listModels() async => models;

  @override
  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async => false;
}

ModelDescriptor _descriptor(String name) => ModelDescriptor(
  id: 'gguf-id',
  modelName: name,
  sizeBytes: 1,
  storedDirectoryPath: 'C:\\models\\$name',
  storedFilePath: 'C:\\models\\$name\\model.gguf',
  importedAt: DateTime(2026),
);

Map<String, Object?> _mnnModelMap(String name) => <String, Object?>{
  'modelId': name,
  'modelKey': name,
  'displayName': name,
  'modelDirPath': 'C:\\mnn\\models\\$name',
  'configPath': 'C:\\mnn\\models\\$name\\config.json',
  'sizeBytes': 1,
  'importedAt': DateTime(2026).millisecondsSinceEpoch,
  'isActive': false,
};
