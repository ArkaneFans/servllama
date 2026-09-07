import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/models/model_descriptor.dart';

void main() {
  group('ModelDescriptor.hasHubSource', () {
    test('is true only when both source and repo are present', () {
      expect(
        _descriptor(
          sourceValue: 'huggingface',
          repoId: 'owner/qwen',
        ).hasHubSource,
        isTrue,
      );
      expect(_descriptor().hasHubSource, isFalse);
      expect(
        _descriptor(sourceValue: 'huggingface', repoId: '  ').hasHubSource,
        isFalse,
      );
      expect(
        _descriptor(sourceValue: '', repoId: 'owner/qwen').hasHubSource,
        isFalse,
      );
    });
  });

  group('LibraryModel.canDownloadMmproj', () {
    test('is true for downloaded GGUF models with a hub source', () {
      expect(
        _library(
          sourceValue: 'huggingface',
          repoId: 'owner/qwen',
        ).canDownloadMmproj,
        isTrue,
      );
    });

    test('is false for local imports, MNN models, and incomplete source', () {
      expect(_library().canDownloadMmproj, isFalse);
      expect(
        _library(
          engine: InferenceEngine.mnn,
          sourceValue: 'huggingface',
          repoId: 'owner/qwen',
        ).canDownloadMmproj,
        isFalse,
      );
      expect(_library(sourceValue: 'huggingface').canDownloadMmproj, isFalse);
    });
  });
}

ModelDescriptor _descriptor({String? sourceValue, String? repoId}) {
  return ModelDescriptor(
    id: 'm1',
    modelName: 'qwen',
    sizeBytes: 10,
    storedDirectoryPath: '/models/qwen',
    storedFilePath: '/models/qwen/qwen.gguf',
    importedAt: DateTime(2026),
    sourceValue: sourceValue,
    repoId: repoId,
    revision: 'main',
  );
}

LibraryModel _library({
  InferenceEngine engine = InferenceEngine.llamaCpp,
  String? sourceValue,
  String? repoId,
}) {
  return LibraryModel(
    id: 'gguf:m1',
    runtimeId: 'qwen',
    engine: engine,
    name: 'qwen',
    sizeBytes: 10,
    importedAt: DateTime(2026),
    storagePath: '/models/qwen/qwen.gguf',
    sourceValue: sourceValue,
    repoId: repoId,
    revision: 'main',
  );
}
