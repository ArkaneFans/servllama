import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/model_storage_paths.dart';

void main() {
  group('ModelStoragePaths', () {
    late Directory appSupportDirectory;
    late ModelStoragePaths storagePaths;

    setUp(() async {
      appSupportDirectory = await Directory.systemTemp.createTemp(
        'servllama_model_paths_',
      );
      storagePaths = ModelStoragePaths(
        appSupportDirectory: appSupportDirectory,
      );
    });

    tearDown(() async {
      if (await appSupportDirectory.exists()) {
        await appSupportDirectory.delete(recursive: true);
      }
    });

    test('returns models root directory under app support directory', () async {
      final modelsDirectory = await storagePaths.getModelsDirectory();

      expect(
        modelsDirectory.path,
        '${appSupportDirectory.path}${Platform.pathSeparator}${ModelStoragePaths.modelsFolderName}',
      );
      expect(await modelsDirectory.exists(), isTrue);
    });

    test('returns model directory under models root', () async {
      final modelDirectory = await storagePaths.getModelDirectory('tiny');

      expect(
        modelDirectory.path,
        '${appSupportDirectory.path}${Platform.pathSeparator}${ModelStoragePaths.modelsFolderName}${Platform.pathSeparator}tiny',
      );
    });
  });
}
