import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  group('ModelManagementProvider', () {
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

      expect(message, '模型导入成功: model');
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

      expect(message, '模型已删除: model');
      expect(provider.deletingModelId, isNull);
      expect(provider.models, isEmpty);
    });

    test(
      'returns error message and resets state when repository throws',
      () async {
        final repository = FakeLocalModelRepository()
          ..importError = StateError('模型名称无效。');
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

        expect(message, '导入模型失败: 模型名称无效。');
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

        expect(message, '导入模型失败: 不支持该文件过滤器');
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

  String _deriveModelName(String fileName) {
    const suffix = '.gguf';
    if (fileName.toLowerCase().endsWith(suffix)) {
      return fileName.substring(0, fileName.length - suffix.length);
    }
    return fileName;
  }
}

class FakeGgufFilePicker extends GgufFilePicker {
  FakeGgufFilePicker({this.pickedFile, this.error});

  final PickedGgufFile? pickedFile;
  final Object? error;

  @override
  Future<PickedGgufFile?> pickSingle() async {
    if (error != null) {
      throw error!;
    }
    return pickedFile;
  }
}

ModelDescriptor _descriptor({
  required String id,
  required String modelName,
  String? originalFileName,
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
  );
}
