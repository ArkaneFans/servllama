import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';

/// Capabilities surfaced as chips on catalog cards. Localized in the page
/// layer; the asset only carries the key.
enum ModelCapability {
  chinese,
  english,
  vision,
  toolCalling;

  static ModelCapability? fromKey(String key) {
    for (final capability in ModelCapability.values) {
      if (capability.name == key) {
        return capability;
      }
    }
    return null;
  }
}

/// One hand-verified model in the curated catalog (design decision D3).
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.engine,
    required this.displayName,
    required this.vendor,
    required this.parameterLabel,
    required this.summaryKey,
    required this.capabilities,
    required this.sources,
    this.recommendedQuant,
  });

  final String id;
  final InferenceEngine engine;
  final String displayName;
  final String vendor;
  final String parameterLabel;

  /// ARB key for the one-line description, so the catalog asset stays
  /// language-neutral.
  final String summaryKey;

  final List<ModelCapability> capabilities;

  /// Repo id per hub. A model missing from one hub simply has no entry.
  final Map<ModelHubSource, String> sources;

  final String? recommendedQuant;

  String? repoIdFor(ModelHubSource source) => sources[source];
}

/// Loads the bundled curated catalog. These entries are the ones that have
/// been run on real devices, which is what makes the "featured" tab safe to
/// recommend from, unlike raw hub search results.
class ModelCatalogService {
  ModelCatalogService({AssetBundle? assetBundle}) : _assetBundle = assetBundle;

  static const String assetPath = 'assets/catalog/model_catalog.json';

  final AssetBundle? _assetBundle;
  List<CatalogEntry>? _cached;

  Future<List<CatalogEntry>> load() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }

    final bundle = _assetBundle ?? rootBundle;
    final raw = await bundle.loadString(assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['entries'] is! List) {
      throw const FormatException('model catalog must be a JSON object with entries');
    }

    final entries = <CatalogEntry>[];
    for (final item in decoded['entries'] as List) {
      if (item is! Map) {
        continue;
      }
      final sources = <ModelHubSource, String>{};
      final rawSources = item['sources'];
      if (rawSources is Map) {
        for (final source in ModelHubSource.values) {
          final repoId = rawSources[source.storageValue];
          if (repoId is String && repoId.trim().isNotEmpty) {
            sources[source] = repoId.trim();
          }
        }
      }
      if (sources.isEmpty) {
        continue;
      }

      entries.add(
        CatalogEntry(
          id: '${item['id']}',
          engine: InferenceEngine.fromStorageValue(item['engine'] as String?),
          displayName: '${item['displayName']}',
          vendor: '${item['vendor'] ?? ''}',
          parameterLabel: '${item['parameterLabel'] ?? ''}',
          summaryKey: '${item['summary'] ?? ''}',
          capabilities:
              (item['capabilities'] as List?)
                  ?.whereType<String>()
                  .map(ModelCapability.fromKey)
                  .whereType<ModelCapability>()
                  .toList(growable: false) ??
              const <ModelCapability>[],
          sources: sources,
          recommendedQuant: item['recommendedQuant'] as String?,
        ),
      );
    }

    _cached = entries;
    return entries;
  }
}
