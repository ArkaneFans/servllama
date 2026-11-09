import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ModelManagementProvider', () {
    setUp(() {
      AppL10nService.instance.setLocale(const Locale('en'));
    });

    for (final rejectSql in [false, true]) {
      test(
        'MNN import commits SQL before notification (rejectSql=$rejectSql)',
        () async {
          const channel = MethodChannel('com.arkanefans.mnn_engine/methods');
          var deleted = '', changes = 0;
          final local = FakeLocalModelRepository();
          final catalog = UnifiedModelRepository(localModelRepository: local);
          if (rejectSql) {
            await local.db.execute(
              "CREATE TRIGGER reject_model BEFORE INSERT ON model_assets BEGIN SELECT RAISE(ABORT,'fixture'); END",
            );
          }
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'deleteImportedModel') {
                  deleted = (call.arguments as Map)['modelId'] as String;
                  return null;
                }
                expect(call.method, 'importModelDirectoryWithResult');
                return {
                  'requestedModelName': 'MNN',
                  'model': {
                    'modelId': 'MNN',
                    'modelKey': 'MNN',
                    'displayName': 'MNN',
                    'modelDirPath': '/models/MNN',
                    'configPath': '/models/MNN/config.json',
                    'sizeBytes': 4096,
                    'importedAt': 1,
                    'isActive': false,
                    'supportsVision': true,
                  },
                };
              });
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          final provider = ModelManagementProvider(
            repository: local,
            unifiedRepository: catalog,
            onAssetsChanged: () async {
              expect((await catalog.listModels()).single.sizeBytes, 4096);
              changes++;
            },
          );
          addTearDown(provider.dispose);
          final result = await provider.importMnnModelDirectory();
          if (rejectSql) {
            expect(result, contains('fixture'));
            expect(deleted, 'MNN');
            expect(changes, 0);
            expect(await catalog.listModels(), isEmpty);
          } else {
            expect(result, 'Model imported: MNN');
            expect(deleted, isEmpty);
            expect(changes, 1);
            expect(provider.libraryModels.single.supportsVision, isTrue);
          }
          expect(provider.isImporting, isFalse);
        },
      );
    }

    test(
      'initial loads share completion and route visits reuse the snapshot',
      () async {
        final repository = _StrictUnifiedRepository();
        final provider = ModelManagementProvider(
          repository: FakeLocalModelRepository(),
          unifiedRepository: repository,
        );
        addTearDown(provider.dispose);
        final first = provider.load();
        final second = provider.load();
        expect(identical(first, second), isTrue);
        await second;
        expect(provider.libraryModels, hasLength(2));
        var notifications = 0;
        provider.addListener(() => notifications++);
        await provider.load();
        expect(notifications, 0);
        await provider.refresh();
        expect(notifications, 1);
      },
    );

    test('importModel updates list and importing state on success', () async {
      final repository = FakeLocalModelRepository();
      final completer = Completer<ModelDescriptor>();
      repository.importCompleter = completer;
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(
          pickedFile: const PickedGgufFile(
            path: 'C:\\mock\\model.gguf',
            fileName: 'model.gguf',
          ),
        ),
        logger: AppLogger(),
      );

      final future = provider.importModel();

      expect(provider.isImporting, isTrue);

      completer.complete(_descriptor(id: 'm1', modelName: 'model'));
      final message = await future;

      expect(message, 'Model imported: model');
      expect(provider.isImporting, isFalse);
      expect(provider.models, hasLength(1));
      expect(provider.models.single.modelName, 'model');
    });

    test('importModel auto-renames a duplicate name', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(id: 'existing', modelName: 'model'),
        ],
      );
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(
          pickedFile: const PickedGgufFile(
            path: 'C:\\mock\\model.gguf',
            fileName: 'model.gguf',
          ),
        ),
        logger: AppLogger(),
      );

      final message = await provider.importModel();

      expect(
        message,
        'Model imported: model (2)\n'
        '“model” already exists and was renamed automatically.',
      );
      expect(
        provider.models.map((model) => model.modelName),
        containsAll(<String>['model', 'model (2)']),
      );
    });

    test('deleteModel removes item and clears deleting state', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(id: 'm1', modelName: 'model'),
        ],
      );
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await provider.load();
      final future = provider.deleteModel('m1');

      expect(provider.deletingModelId, 'm1');

      final message = await future;

      expect(message, 'Model deleted: model');
      expect(provider.deletingModelId, isNull);
      expect(provider.models, isEmpty);
    });

    test('importMmproj updates list and importing state on success', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(id: 'm1', modelName: 'vision'),
        ],
      )..importMmprojGate = Completer<void>();
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(
          pickedMmprojFile: const PickedGgufFile(
            path: 'C:\\mock\\mmproj-f16.gguf',
            fileName: 'mmproj-f16.gguf',
          ),
        ),
        logger: AppLogger(),
      );

      await provider.load();
      final future = provider.importMmproj('m1');
      await Future<void>.delayed(Duration.zero);

      expect(provider.isImportingMmproj, isTrue);
      expect(provider.importingMmprojModelId, 'm1');

      repository.importMmprojGate!.complete();
      final message = await future;

      expect(message, 'mmproj imported: vision');
      expect(provider.isImportingMmproj, isFalse);
      expect(provider.importingMmprojModelId, isNull);
      expect(
        provider.models.single.mmprojFilePath,
        'C:\\mock\\mmproj-f16.gguf',
      );
    });

    test('renameModel updates list and clears renaming state', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(id: 'm1', modelName: 'before'),
        ],
      );
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await provider.load();
      final assetId = provider.libraryModels.single.id;
      final future = provider.renameModel('m1', 'after');

      expect(provider.isRenaming, isTrue);
      expect(provider.renamingModelId, assetId);

      final message = await future;

      expect(message, 'Model renamed to: after');
      expect(provider.isRenaming, isFalse);
      expect(provider.renamingModelId, isNull);
      expect(provider.models.single.modelName, 'after');
      expect(provider.libraryModels.single.id, assetId);
    });

    test('manual rename still rejects a duplicate name', () async {
      final unifiedRepository = _StrictUnifiedRepository();
      final provider = ModelManagementProvider(
        repository: FakeLocalModelRepository(),
        unifiedRepository: unifiedRepository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );
      await provider.load();

      final message = await provider.renameLibraryModel(
        unifiedRepository.models.first,
        'second',
      );

      expect(message, 'Failed to rename model: The model name already exists.');
      expect(unifiedRepository.renameCalls, 0);
    });

    test('removeMmproj clears mmproj metadata', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(
            id: 'm1',
            modelName: 'vision',
            mmprojFilePath: 'C:\\models\\vision\\mmproj-f16.gguf',
          ),
        ],
      );
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await provider.load();
      final message = await provider.removeMmproj('m1');

      expect(message, 'mmproj removed: vision');
      expect(provider.models.single.mmprojFilePath, isNull);
    });

    test(
      'returns error message and resets state when repository throws',
      () async {
        final repository = FakeLocalModelRepository()
          ..importError = const ModelOperationException(
            ModelOperationErrorCode.invalidModelName,
          );
        final provider = ModelManagementProvider(
          repository: repository,
          filePicker: FakeGgufFilePicker(
            pickedFile: const PickedGgufFile(
              path: 'C:\\mock\\broken.gguf',
              fileName: 'broken.gguf',
            ),
          ),
          logger: AppLogger(),
        );

        final message = await provider.importModel();

        expect(message, 'Failed to import model: The model name is invalid.');
        expect(provider.isImporting, isFalse);
        expect(provider.models, isEmpty);
      },
    );
  });
}

class FakeLocalModelRepository extends LocalModelRepository {
  factory FakeLocalModelRepository({List<ModelDescriptor>? initialModels}) =>
      FakeLocalModelRepository._(initialModels ?? [], AppDatabase.memory());
  FakeLocalModelRepository._(List<ModelDescriptor> initial, this.db)
    : _models = List<ModelDescriptor>.from(initial),
      super(database: db, appSupportDirectory: Directory.systemTemp) {
    _seed = Future.wait(
      initial.map((model) => GgufModelStore(db).save(model)),
    ).then((_) {});
    addTearDown(db.close);
  }
  final AppDatabase db;
  late final Future<void> _seed;

  final List<ModelDescriptor> _models;
  Completer<ModelDescriptor>? importCompleter;
  Object? importError;
  Object? deleteError;
  Object? importMmprojError;
  Completer<void>? importMmprojGate;
  Object? renameError;
  Object? removeMmprojError;

  @override
  Future<List<ModelDescriptor>> listModels() async {
    await _seed;
    return List<ModelDescriptor>.from(_models);
  }

  @override
  Future<bool> isModelDirectoryOccupied(
    String modelName, {
    String? excludingModelId,
  }) async => _models.any(
    (model) =>
        model.id != excludingModelId &&
        model.modelName.toLowerCase() == modelName.toLowerCase(),
  );

  @override
  Future<ModelDescriptor> importModel(
    PickedGgufFile pickedFile, {
    String? modelName,
  }) async {
    if (importError != null) {
      throw importError!;
    }

    if (importCompleter != null) {
      final descriptor = await importCompleter!.future;
      _models.insert(0, descriptor);
      await GgufModelStore(db).save(descriptor);
      return descriptor;
    }

    final descriptor = _descriptor(
      id: 'generated',
      modelName: modelName ?? _deriveModelName(pickedFile.fileName),
      originalFileName: pickedFile.fileName,
    );
    _models.insert(0, descriptor);
    await GgufModelStore(db).save(descriptor);
    return descriptor;
  }

  @override
  Future<void> deleteModel(String modelId) async {
    if (deleteError != null) {
      throw deleteError!;
    }
    _models.removeWhere((model) => model.id == modelId);
    await GgufModelStore(db).remove(modelId);
  }

  @override
  Future<ModelDescriptor> importMmproj(
    String modelId,
    PickedGgufFile pickedFile,
  ) async {
    if (importMmprojError != null) {
      throw importMmprojError!;
    }
    if (importMmprojGate != null) {
      await importMmprojGate!.future;
    }

    final index = _models.indexWhere((model) => model.id == modelId);
    final updated = _models[index].copyWith(mmprojFilePath: pickedFile.path);
    _models[index] = updated;
    await GgufModelStore(db).save(updated);
    return updated;
  }

  @override
  Future<ModelDescriptor> removeMmproj(String modelId) async {
    if (removeMmprojError != null) {
      throw removeMmprojError!;
    }

    final index = _models.indexWhere((model) => model.id == modelId);
    final updated = _models[index].copyWith(mmprojFilePath: null);
    _models[index] = updated;
    await GgufModelStore(db).save(updated);
    return updated;
  }

  @override
  Future<ModelDescriptor> renameModel(String modelId, String newName) async {
    if (renameError != null) {
      throw renameError!;
    }

    final index = _models.indexWhere((model) => model.id == modelId);
    final current = _models[index];
    final updated = current.copyWith(
      modelName: newName,
      storedDirectoryPath: 'C:\\models\\$newName',
      storedFilePath:
          'C:\\models\\$newName\\${current.storedFilePath.split('\\').last}',
      mmprojFilePath: current.mmprojFilePath == null
          ? null
          : 'C:\\models\\$newName\\${current.mmprojFilePath!.split('\\').last}',
    );
    _models[index] = updated;
    await GgufModelStore(db).save(updated);
    return updated;
  }

  String _deriveModelName(String fileName) {
    const suffix = '.gguf';
    if (fileName.toLowerCase().endsWith(suffix)) {
      return fileName.substring(0, fileName.length - suffix.length);
    }
    return fileName;
  }
}

class _StrictUnifiedRepository extends UnifiedModelRepository {
  _StrictUnifiedRepository()
    : super(localModelRepository: FakeLocalModelRepository());

  final List<LibraryModel> models = <LibraryModel>[
    LibraryModel(
      id: 'gguf:first',
      runtimeId: 'first',
      engine: InferenceEngine.llamaCpp,
      name: 'first',
      sizeBytes: 1,
      importedAt: DateTime(2026),
      storagePath: 'C:\\models\\first\\model.gguf',
    ),
    LibraryModel(
      id: 'mnn:second',
      runtimeId: 'second',
      engine: InferenceEngine.mnn,
      name: 'second',
      sizeBytes: 1,
      importedAt: DateTime(2026),
      storagePath: 'C:\\mnn\\second',
    ),
  ];
  int renameCalls = 0;

  @override
  Future<List<LibraryModel>> listModels() async => models;

  @override
  Future<bool> isStorageNameOccupied(
    String name, {
    String? excludingLibraryId,
  }) async => models.any(
    (model) =>
        model.id != excludingLibraryId &&
        model.name.toLowerCase() == name.toLowerCase(),
  );

  @override
  Future<LibraryModel> renameModel(LibraryModel model, String newName) async {
    renameCalls += 1;
    return model;
  }
}

class FakeGgufFilePicker extends GgufFilePicker {
  FakeGgufFilePicker({this.pickedFile, this.pickedMmprojFile, this.error});

  final PickedGgufFile? pickedFile;
  final PickedGgufFile? pickedMmprojFile;
  final Object? error;

  @override
  Future<PickedGgufFile?> pickSingle() async {
    if (error != null) {
      throw error!;
    }
    return pickedFile;
  }

  @override
  Future<PickedGgufFile?> pickSingleMmproj() async {
    if (error != null) {
      throw error!;
    }
    return pickedMmprojFile;
  }
}

ModelDescriptor _descriptor({
  required String id,
  required String modelName,
  String? originalFileName,
  String? mmprojFilePath,
  int sizeBytes = 1073741824,
}) {
  final fileName = originalFileName ?? '$modelName.gguf';
  return ModelDescriptor(
    id: id,
    modelName: modelName,
    sizeBytes: sizeBytes,
    storedDirectoryPath: 'C:\\models\\$modelName',
    storedFilePath: 'C:\\models\\$modelName\\$fileName',
    importedAt: DateTime(2026, 1, 1),
    mmprojFilePath: mmprojFilePath,
  );
}
