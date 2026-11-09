import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/repositories/gguf_model_store.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalModelRepository', () {
    late Directory appSupportDirectory;
    late Directory sourceDirectory;
    late LocalModelRepository repository;
    late AppDatabase db;

    setUp(() async {
      appSupportDirectory = await Directory.systemTemp.createTemp(
        'servllama_models_app_',
      );
      sourceDirectory = await Directory.systemTemp.createTemp(
        'servllama_models_source_',
      );
      db = AppDatabase.at(appSupportDirectory);
      repository = LocalModelRepository(
        appSupportDirectory: appSupportDirectory,
        database: db,
        logger: AppLogger(),
      );
    });

    tearDown(() async {
      await db.close();
      if (await appSupportDirectory.exists()) {
        await appSupportDirectory.delete(recursive: true);
      }
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
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
        (await db.query(
          "SELECT id FROM model_assets WHERE json_type(manifest,'\$.gguf')='object'",
        )).isEmpty,
        isTrue,
      );
    });

    test('SQL delete failure keeps registration and retry skips files', () async {
      final sourceFile = await _createSourceFile(sourceDirectory, 'retry.gguf');
      final descriptor = await repository.importModel(
        PickedGgufFile(path: sourceFile.path, fileName: 'retry.gguf'),
      );
      await db.execute(
        "CREATE TRIGGER reject_model BEFORE DELETE ON model_assets BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.deleteModel(descriptor.id),
        throwsA(anything),
      );
      expect(await Directory(descriptor.storedDirectoryPath).exists(), isFalse);
      expect((await repository.listModels()).single.id, descriptor.id);
      await db.execute('DROP TRIGGER reject_model');
      await repository.deleteModel(descriptor.id);
      expect(await repository.listModels(), isEmpty);
    });

    test('deletion rejects an owned path outside private models', () async {
      final sourceFile = await _createSourceFile(
        sourceDirectory,
        'outside.gguf',
      );
      final descriptor = await repository.importModel(
        PickedGgufFile(path: sourceFile.path, fileName: 'outside.gguf'),
      );
      await GgufModelStore(db).save(
        descriptor.copyWith(
          storedDirectoryPath: sourceDirectory.path,
          storedFilePath: sourceFile.path,
        ),
      );
      await expectLater(
        repository.deleteModel(descriptor.id),
        throwsStateError,
      );
      expect(await sourceFile.exists(), isTrue);
      expect(await repository.listModels(), hasLength(1));
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
          database: db,
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
        final assetId = (await db.query(
          'SELECT id FROM model_assets',
        )).single.read<String>('id');
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
        await db.close();
        db = AppDatabase.at(appSupportDirectory);
        repository = LocalModelRepository(
          appSupportDirectory: appSupportDirectory,
          database: db,
        );
        installed = (await repository.listModels()).single;
        expect(installed.isVisionEnabled, isFalse);
        expect(installed.activeMmprojFilePath, isNull);
        expect(installed.mmprojFilePath, isNotNull);

        installed = await repository.renameModel(model.id, 'renamed');
        final renamedAsset = (await db.query(
          'SELECT id,name,path FROM model_assets',
        )).single;
        expect(renamedAsset.read<String>('id'), assetId);
        expect(renamedAsset.read<String>('name'), 'renamed');
        expect(renamedAsset.read<String>('path'), installed.storedFilePath);
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
