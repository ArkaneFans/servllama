import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
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
        throwsA(
          isA<ModelOperationException>().having(
            (error) => error.code,
            'code',
            ModelOperationErrorCode.duplicateModelName,
          ),
        ),
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
          isA<ModelOperationException>().having(
            (error) => error.code,
            'code',
            ModelOperationErrorCode.invalidModelName,
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

    test('imports mmproj into existing model directory', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'vision.gguf');
      final mmprojFile = await _createSourceFile(
        sourceDirectory,
        'mmproj-projector-f16.gguf',
        content: 'mmproj-data',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
      );

      final updated = await repository.importMmproj(
        descriptor.id,
        PickedGgufFile(
          path: mmprojFile.path,
          fileName: 'mmproj-projector-f16.gguf',
        ),
      );

      expect(updated.mmprojFilePath, isNotNull);
      expect(await File(updated.mmprojFilePath!).exists(), isTrue);
      expect(
        updated.mmprojFilePath,
        endsWith(
          '${LocalModelRepository.modelsFolderName}${Platform.pathSeparator}vision${Platform.pathSeparator}mmproj-projector-f16.gguf',
        ),
      );
    });

    test('imports mmproj when the file name contains mmproj', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'vision.gguf');
      final mmprojFile = await _createSourceFile(
        sourceDirectory,
        'Qwen3.5-0.8B-mmproj-f16.gguf',
        content: 'mmproj-data',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
      );

      final updated = await repository.importMmproj(
        descriptor.id,
        PickedGgufFile(
          path: mmprojFile.path,
          fileName: 'Qwen3.5-0.8B-mmproj-f16.gguf',
        ),
      );

      expect(updated.mmprojFilePath, isNotNull);
      expect(await File(updated.mmprojFilePath!).exists(), isTrue);
      expect(
        updated.mmprojFilePath,
        endsWith(
          '${LocalModelRepository.modelsFolderName}${Platform.pathSeparator}vision${Platform.pathSeparator}Qwen3.5-0.8B-mmproj-f16.gguf',
        ),
      );
    });

    test(
      'rejects mmproj import when file name does not contain mmproj',
      () async {
        final modelFile = await _createSourceFile(
          sourceDirectory,
          'vision.gguf',
        );
        final invalidMmproj = await _createSourceFile(
          sourceDirectory,
          'projector.gguf',
          content: 'invalid-mmproj',
        );
        final descriptor = await repository.importModel(
          PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
        );

        expect(
          () => repository.importMmproj(
            descriptor.id,
            PickedGgufFile(
              path: invalidMmproj.path,
              fileName: 'projector.gguf',
            ),
          ),
          throwsA(
            isA<ModelOperationException>().having(
              (error) => error.code,
              'code',
              ModelOperationErrorCode.unsupportedMmprojFile,
            ),
          ),
        );
      },
    );

    test('removeMmproj deletes file and clears metadata', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'vision.gguf');
      final mmprojFile = await _createSourceFile(
        sourceDirectory,
        'mmproj-f16.gguf',
        content: 'mmproj-data',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
      );
      final withMmproj = await repository.importMmproj(
        descriptor.id,
        PickedGgufFile(path: mmprojFile.path, fileName: 'mmproj-f16.gguf'),
      );

      final updated = await repository.removeMmproj(descriptor.id);

      expect(updated.mmprojFilePath, isNull);
      expect(await File(withMmproj.mmprojFilePath!).exists(), isFalse);
    });

    test('renameModel updates model directory and mmproj path', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'vision.gguf');
      final mmprojFile = await _createSourceFile(
        sourceDirectory,
        'mmproj-f16.gguf',
        content: 'mmproj-data',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
      );
      await repository.importMmproj(
        descriptor.id,
        PickedGgufFile(path: mmprojFile.path, fileName: 'mmproj-f16.gguf'),
      );

      final renamed = await repository.renameModel(descriptor.id, 'vision-v2');

      expect(renamed.modelName, 'vision-v2');
      expect(await Directory(renamed.storedDirectoryPath).exists(), isTrue);
      expect(await File(renamed.storedFilePath).exists(), isTrue);
      expect(await File(renamed.mmprojFilePath!).exists(), isTrue);
      expect(
        renamed.storedFilePath,
        contains('${Platform.pathSeparator}vision-v2${Platform.pathSeparator}'),
      );
      expect(
        renamed.mmprojFilePath,
        contains('${Platform.pathSeparator}vision-v2${Platform.pathSeparator}'),
      );
    });

    test(
      'renameModel rejects names that could escape the models directory',
      () async {
        final modelFile = await _createSourceFile(sourceDirectory, 'tiny.gguf');
        final descriptor = await repository.importModel(
          PickedGgufFile(path: modelFile.path, fileName: 'tiny.gguf'),
        );

        const invalidNames = <String>[
          '../escape',
          '..',
          '.',
          'a/b',
          'a\\b',
          'bad\x00name',
        ];
        for (final name in invalidNames) {
          await expectLater(
            repository.renameModel(descriptor.id, name),
            throwsA(
              isA<ModelOperationException>().having(
                (error) => error.code,
                'code',
                ModelOperationErrorCode.invalidModelName,
              ),
            ),
            reason: 'name "$name" should be rejected',
          );
        }

        // The model itself must be untouched after rejected renames.
        final models = await repository.listModels();
        expect(models.single.modelName, 'tiny');
        expect(await File(models.single.storedFilePath).exists(), isTrue);
      },
    );

    test('listModels clears missing mmproj metadata', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'vision.gguf');
      final mmprojFile = await _createSourceFile(
        sourceDirectory,
        'mmproj-f16.gguf',
        content: 'mmproj-data',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: modelFile.path, fileName: 'vision.gguf'),
      );
      final withMmproj = await repository.importMmproj(
        descriptor.id,
        PickedGgufFile(path: mmprojFile.path, fileName: 'mmproj-f16.gguf'),
      );

      await File(withMmproj.mmprojFilePath!).delete();
      final models = await repository.listModels();

      expect(models.single.mmprojFilePath, isNull);
    });

    test('adoptDownloadedModel persists hub source metadata', () async {
      final modelFile = await _createSourceFile(sourceDirectory, 'qwen.gguf');

      final descriptor = await repository.adoptDownloadedModel(
        modelName: 'qwen',
        modelFile: modelFile,
        sourceValue: 'huggingface',
        repoId: 'owner/qwen',
        revision: 'main',
      );

      expect(descriptor.sourceValue, 'huggingface');
      expect(descriptor.repoId, 'owner/qwen');
      expect(descriptor.revision, 'main');
      expect(descriptor.hasHubSource, isTrue);

      final models = await repository.listModels();
      expect(models.single.sourceValue, 'huggingface');
      expect(models.single.repoId, 'owner/qwen');
      expect(models.single.revision, 'main');
    });

    test(
      'adoptDownloadedMmproj selects the download and keeps other versions',
      () async {
        final modelFile = await _createSourceFile(
          sourceDirectory,
          'vision.gguf',
        );
        final firstMmproj = await _createSourceFile(
          sourceDirectory,
          'mmproj-f16.gguf',
          content: 'old-mmproj',
        );
        final descriptor = await repository.adoptDownloadedModel(
          modelName: 'vision',
          modelFile: modelFile,
          mmprojFile: firstMmproj,
          sourceValue: 'huggingface',
          repoId: 'owner/qwen',
          revision: 'main',
        );
        final previousPath = descriptor.mmprojFilePath!;

        final staging = await Directory.systemTemp.createTemp(
          'servllama_mmproj_staging_',
        );
        addTearDown(() async {
          if (await staging.exists()) {
            await staging.delete(recursive: true);
          }
        });
        final replacement = await _createSourceFile(
          staging,
          'Qwen3.5-0.8B-mmproj-f16.gguf',
          content: 'new-mmproj',
        );

        final updated = await repository.adoptDownloadedMmproj(
          modelId: descriptor.id,
          mmprojFile: replacement,
        );

        expect(updated.sourceValue, 'huggingface');
        expect(updated.repoId, 'owner/qwen');
        expect(updated.revision, 'main');
        expect(
          updated.mmprojFilePath,
          endsWith(
            '${LocalModelRepository.modelsFolderName}${Platform.pathSeparator}vision${Platform.pathSeparator}projectors${Platform.pathSeparator}Qwen3.5-0.8B-mmproj-f16.gguf',
          ),
        );
        expect(await File(updated.mmprojFilePath!).exists(), isTrue);
        expect(await File(previousPath).exists(), isTrue);
        expect(updated.availableMmprojs, hasLength(2));
      },
    );
    test(
      'projector versions survive concurrent downloads, reload and rename',
      () async {
        final model = await repository.adoptDownloadedModel(
          modelName: 'vision',
          modelFile: await _createSourceFile(sourceDirectory, 'vision.gguf'),
          sourceValue: 'huggingface',
          repoId: 'owner/vision',
        );
        final secondRepository = LocalModelRepository(
          appSupportDirectory: appSupportDirectory,
        );
        final first = await _createSourceFile(
          sourceDirectory,
          'mmproj-f16.gguf',
          content: 'f16',
        );
        final second = await _createSourceFile(
          sourceDirectory,
          'mmproj-f32.gguf',
          content: 'f32',
        );
        await Future.wait([
          repository.adoptDownloadedMmproj(
            modelId: model.id,
            mmprojFile: first,
            remotePath: 'f16/mmproj.gguf',
          ),
          secondRepository.adoptDownloadedMmproj(
            modelId: model.id,
            mmprojFile: second,
            remotePath: 'f32/mmproj.gguf',
          ),
        ]);
        var installed = (await repository.listModels()).single;
        expect(installed.availableMmprojs, hasLength(2));
        expect(
          await File(installed.mmprojFiles['f16/mmproj.gguf']!).readAsString(),
          'f16',
        );
        expect(
          await File(installed.mmprojFiles['f32/mmproj.gguf']!).readAsString(),
          'f32',
        );

        await repository.setVisionEnabled(model.id, false);
        await Hive.close();
        repository = LocalModelRepository(
          appSupportDirectory: appSupportDirectory,
        );
        installed = (await repository.listModels()).single;
        expect(installed.isVisionEnabled, isFalse);
        expect(installed.activeMmprojFilePath, isNull);
        expect(installed.mmprojFilePath, isNotNull);

        installed = await repository.renameModel(model.id, 'renamed');
        final firstPath = installed.mmprojFiles['f16/mmproj.gguf']!;
        final secondPath = installed.mmprojFiles['f32/mmproj.gguf']!;
        expect(firstPath, startsWith(installed.storedDirectoryPath));
        expect(secondPath, startsWith(installed.storedDirectoryPath));
        expect(await File(firstPath).readAsString(), 'f16');
        expect(await File(secondPath).readAsString(), 'f32');
        await repository.selectMmproj(model.id, firstPath);
        installed = await repository.setVisionEnabled(model.id, true);
        expect(installed.activeMmprojFilePath, firstPath);

        installed = await repository.removeMmprojFile(model.id, firstPath);
        expect(installed.activeMmprojFilePath, secondPath);
        expect(await File(firstPath).exists(), isFalse);
        installed = await repository.removeMmprojFile(model.id, secondPath);
        expect(installed.isVisionEnabled, isFalse);
        expect(installed.mmprojFilePath, isNull);
        expect(installed.availableMmprojs, isEmpty);
        expect(await File(installed.storedFilePath).exists(), isTrue);
      },
    );
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
