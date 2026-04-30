import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalModelRepository', () {
    late Directory appSupportDirectory;
    late Directory sourceDirectory;
    late LocalModelRepository repository;

    setUp(() async {
      await Hive.close();
      appSupportDirectory = await Directory.systemTemp.createTemp(
        'servllama_models_app_',
      );
      sourceDirectory = await Directory.systemTemp.createTemp(
        'servllama_models_source_',
      );
      Hive.init(appSupportDirectory.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ModelDescriptorAdapter());
      }
      repository = LocalModelRepository(
        appSupportDirectory: appSupportDirectory,
        logger: AppLogger(),
      );
    });

    tearDown(() async {
      await Hive.close();
      if (await appSupportDirectory.exists()) {
        await appSupportDirectory.delete(recursive: true);
      }
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
    });

    test('returns empty list when repository has no models', () async {
      final models = await repository.listModels();

      expect(models, isEmpty);
    });

    test('imports model into modelName directory and persists metadata', () async {
      final sourceFile = await _createSourceFile(sourceDirectory, 'tiny.gguf');

      final descriptor = await repository.importModel(
        PickedGgufFile(path: sourceFile.path, fileName: 'tiny.gguf'),
      );

      final models = await repository.listModels();

      expect(models, hasLength(1));
      expect(models.single.id, descriptor.id);
      expect(models.single.modelName, 'tiny');
      expect(models.single.sizeBytes, sourceFile.lengthSync());
      expect(await File(descriptor.storedFilePath).exists(), isTrue);
      expect(await Directory(descriptor.storedDirectoryPath).exists(), isTrue);
      expect(
        descriptor.storedDirectoryPath,
        endsWith(
          '${LocalModelRepository.modelsFolderName}${Platform.pathSeparator}tiny',
        ),
      );
      expect(
        descriptor.storedFilePath,
        endsWith(
          '${LocalModelRepository.modelsFolderName}${Platform.pathSeparator}tiny${Platform.pathSeparator}tiny.gguf',
        ),
      );
    });

    test('rejects duplicate import when modelName already exists', () async {
      final firstFile = await _createSourceFile(sourceDirectory, 'dup.gguf');
      final secondFile = await _createSourceFile(
        sourceDirectory,
        'dup_copy.gguf',
        content: 'another',
      );

      await repository.importModel(
        PickedGgufFile(path: firstFile.path, fileName: 'dup.gguf'),
      );

      expect(
        () => repository.importModel(
          PickedGgufFile(path: secondFile.path, fileName: 'DUP.GGUF'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects import when derived modelName is empty', () async {
      final sourceFile = await _createSourceFile(
        sourceDirectory,
        'placeholder.gguf',
      );

      expect(
        () => repository.importModel(
          PickedGgufFile(path: sourceFile.path, fileName: '.gguf'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            '模型名称无效。',
          ),
        ),
      );
    });

    test('delete removes model directory and metadata', () async {
      final sourceFile = await _createSourceFile(
        sourceDirectory,
        'remove.gguf',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: sourceFile.path, fileName: 'remove.gguf'),
      );

      await repository.deleteModel(descriptor.id);

      final models = await repository.listModels();
      expect(models, isEmpty);
      expect(await Directory(descriptor.storedDirectoryPath).exists(), isFalse);
      expect(
        Hive.box<ModelDescriptor>(LocalModelRepository.boxName).isEmpty,
        isTrue,
      );
    });

    test('returns models sorted by imported time descending', () async {
      final firstFile = await _createSourceFile(sourceDirectory, 'first.gguf');
      final secondFile = await _createSourceFile(
        sourceDirectory,
        'second.gguf',
      );

      await repository.importModel(
        PickedGgufFile(path: firstFile.path, fileName: 'first.gguf'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repository.importModel(
        PickedGgufFile(path: secondFile.path, fileName: 'second.gguf'),
      );

      final models = await repository.listModels();

      expect(models.map((model) => model.modelName).toList(), <String>[
        'second',
        'first',
      ]);
    });

    test('cleans stale metadata when backing file no longer exists', () async {
      final sourceFile = await _createSourceFile(sourceDirectory, 'stale.gguf');
      final descriptor = await repository.importModel(
        PickedGgufFile(path: sourceFile.path, fileName: 'stale.gguf'),
      );

      await File(descriptor.storedFilePath).delete();

      final models = await repository.listModels();

      expect(models, isEmpty);
      expect(await Directory(descriptor.storedDirectoryPath).exists(), isFalse);
      expect(
        Hive.box<ModelDescriptor>(LocalModelRepository.boxName).isEmpty,
        isTrue,
      );
    });
  });
}

Future<File> _createSourceFile(
  Directory directory,
  String fileName, {
  String content = 'model-data',
}) async {
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
  return file;
}
