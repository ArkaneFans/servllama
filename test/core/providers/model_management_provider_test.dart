import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  group('ModelManagementProvider', () {
    setUp(() {
      AppL10nService.instance.setLocale(const Locale('en'));
    });

    test('load reads initial model list', () async {
      final repository = FakeLocalModelRepository(
        initialModels: <ModelDescriptor>[
          _descriptor(id: 'a', modelName: 'alpha'),
        ],
      );
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      await provider.load();

      expect(provider.models, hasLength(1));
      expect(provider.models.single.modelName, 'alpha');
      expect(provider.isLoading, isFalse);
    });

    test('importModel keeps list unchanged when picker is cancelled', () async {
      final repository = FakeLocalModelRepository();
      final provider = ModelManagementProvider(
        repository: repository,
        filePicker: FakeGgufFilePicker(),
        logger: AppLogger(),
      );

      final message = await provider.importModel();

      expect(message, isNull);
      expect(provider.models, isEmpty);
      expect(provider.isImporting, isFalse);
    });

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
      );
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

      expect(provider.isImportingMmproj, isTrue);
      expect(provider.importingMmprojModelId, 'm1');

      final message = await future;

      expect(message, 'mmproj imported: vision');
      expect(provider.isImportingMmproj, isFalse);
      expect(provider.importingMmprojModelId, isNull);
      expect(provider.models.single.mmprojFilePath, 'C:\\mock\\mmproj-f16.gguf');
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
      final future = provider.renameModel('m1', 'after');

      expect(provider.isRenaming, isTrue);
      expect(provider.renamingModelId, 'm1');

      final message = await future;

      expect(message, 'Model renamed to: after');
      expect(provider.isRenaming, isFalse);
      expect(provider.renamingModelId, isNull);
      expect(provider.models.single.modelName, 'after');
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
      'formats file picker errors for mmproj import message',
      () async {
        final provider = ModelManagementProvider(
          repository: FakeLocalModelRepository(),
          filePicker: FakeGgufFilePicker(
            error: PlatformException(code: 'FilePicker', message: '文件不可用'),
          ),
          logger: AppLogger(),
        );

        final message = await provider.importMmproj('m1');

        expect(message, 'Failed to import mmproj: 文件不可用');
        expect(provider.isImportingMmproj, isFalse);
        expect(provider.importingMmprojModelId, isNull);
      },
    );

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

    test(
      'formats file picker platform errors for user-facing message',
      () async {
        final provider = ModelManagementProvider(
          repository: FakeLocalModelRepository(),
          filePicker: FakeGgufFilePicker(
            error: PlatformException(code: 'FilePicker', message: '不支持该文件过滤器'),
          ),
          logger: AppLogger(),
        );

        final message = await provider.importModel();

        expect(message, 'Failed to import model: 不支持该文件过滤器');
        expect(provider.isImporting, isFalse);
        expect(provider.models, isEmpty);
      },
    );
  });
}

class FakeLocalModelRepository extends LocalModelRepository {
  FakeLocalModelRepository({List<ModelDescriptor>? initialModels})
    : _models = List<ModelDescriptor>.from(
        initialModels ?? const <ModelDescriptor>[],
      ),
      super(appSupportDirectory: Directory.systemTemp);

  final List<ModelDescriptor> _models;
  Completer<ModelDescriptor>? importCompleter;
  Object? importError;
  Object? deleteError;
  Object? importMmprojError;
  Object? renameError;
  Object? removeMmprojError;

  @override
  Future<List<ModelDescriptor>> listModels() async =>
      List<ModelDescriptor>.from(_models);

  @override
  Future<ModelDescriptor> importModel(PickedGgufFile pickedFile) async {
    if (importError != null) {
      throw importError!;
    }

    if (importCompleter != null) {
      final descriptor = await importCompleter!.future;
      _models.insert(0, descriptor);
      return descriptor;
    }

    final descriptor = _descriptor(
      id: 'generated',
      modelName: _deriveModelName(pickedFile.fileName),
      originalFileName: pickedFile.fileName,
    );
    _models.insert(0, descriptor);
    return descriptor;
  }

  @override
  Future<void> deleteModel(String modelId) async {
    if (deleteError != null) {
      throw deleteError!;
    }
    _models.removeWhere((model) => model.id == modelId);
  }

  @override
  Future<ModelDescriptor> importMmproj(
    String modelId,
    PickedGgufFile pickedFile,
  ) async {
    if (importMmprojError != null) {
      throw importMmprojError!;
    }

    final index = _models.indexWhere((model) => model.id == modelId);
    final updated = _models[index].copyWith(mmprojFilePath: pickedFile.path);
    _models[index] = updated;
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
      storedFilePath: 'C:\\models\\$newName\\${current.storedFilePath.split('\\').last}',
      mmprojFilePath: current.mmprojFilePath == null
          ? null
          : 'C:\\models\\$newName\\${current.mmprojFilePath!.split('\\').last}',
    );
    _models[index] = updated;
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
