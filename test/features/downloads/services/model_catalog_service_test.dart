import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';

void main() {
  test('featured catalog lists current GGUF and MNN picks with both hubs', () async {
    final json = File('assets/catalog/model_catalog.json').readAsStringSync();
    final catalog = ModelCatalogService(assetBundle: _StringAssetBundle(json));
    final entries = await catalog.load();

    expect(
      entries.map((entry) => entry.id).toList(),
      <String>[
        'qwen3.5-0.8b-gguf',
        'qwen3.5-2b-gguf',
        'qwen3.5-4b-gguf',
        'lfm2.5-2.6b-gguf',
        'qwen3.5-0.8b-mnn',
        'qwen3.5-2b-mnn',
        'qwen3.5-4b-mnn',
        'gemma-4-e2b-it-mnn',
        'gemma-4-e4b-it-mnn',
      ],
    );

    final gguf = entries.where((entry) => entry.engine == InferenceEngine.llamaCpp);
    final mnn = entries.where((entry) => entry.engine == InferenceEngine.mnn);
    expect(gguf, hasLength(4));
    expect(mnn, hasLength(5));

    expect(
      {for (final entry in entries) entry.id: entry.summaryKey},
      <String, String>{
        'qwen3.5-0.8b-gguf': 'verifiedSmallGeneralist',
        'qwen3.5-2b-gguf': 'verifiedBalanced',
        'qwen3.5-4b-gguf': 'verifiedStrong',
        'lfm2.5-2.6b-gguf': 'verifiedLfm25',
        'qwen3.5-0.8b-mnn': 'verifiedMnnSmall',
        'qwen3.5-2b-mnn': 'verifiedMnnEveryday',
        'qwen3.5-4b-mnn': 'verifiedMnnBalanced',
        'gemma-4-e2b-it-mnn': 'verifiedGemma4E2B',
        'gemma-4-e4b-it-mnn': 'verifiedGemma4E4B',
      },
    );

    for (final entry in entries) {
      expect(entry.sources[ModelHubSource.huggingFace], isNotEmpty);
      expect(entry.sources[ModelHubSource.modelScope], isNotEmpty);
    }

    expect(
      entries.firstWhere((entry) => entry.id == 'qwen3.5-0.8b-gguf').sources,
      <ModelHubSource, String>{
        ModelHubSource.huggingFace: 'unsloth/Qwen3.5-0.8B-GGUF',
        ModelHubSource.modelScope: 'unsloth/Qwen3.5-0.8B-GGUF',
      },
    );
    expect(
      entries.firstWhere((entry) => entry.id == 'lfm2.5-2.6b-gguf').sources,
      <ModelHubSource, String>{
        ModelHubSource.huggingFace: 'LiquidAI/LFM2.5-2.6B-GGUF',
        ModelHubSource.modelScope: 'LiquidAI/LFM2.5-2.6B-GGUF',
      },
    );
    expect(
      entries.firstWhere((entry) => entry.id == 'qwen3.5-0.8b-mnn').sources,
      <ModelHubSource, String>{
        ModelHubSource.huggingFace: 'taobao-mnn/Qwen3.5-0.8B-MNN',
        ModelHubSource.modelScope: 'MNN/Qwen3.5-0.8B-MNN',
      },
    );
    expect(
      entries.firstWhere((entry) => entry.id == 'gemma-4-e2b-it-mnn').sources,
      <ModelHubSource, String>{
        ModelHubSource.huggingFace: 'taobao-mnn/gemma-4-E2B-it-MNN',
        ModelHubSource.modelScope: 'MNN/gemma-4-E2B-it-MNN',
      },
    );
  });
}

class _StringAssetBundle extends AssetBundle {
  _StringAssetBundle(this.contents);

  final String contents;

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async => contents;
}
