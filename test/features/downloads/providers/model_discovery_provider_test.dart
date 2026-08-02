import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';

void main() {
  group('ModelDiscoveryProvider', () {
    test(
      'merges both hubs and applies local sort and format filters',
      () async {
        final huggingFace = _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (_) async => <HubRepoSummary>[
            HubRepoSummary(
              source: ModelHubSource.huggingFace,
              repoId: 'owner/gguf-model',
              owner: 'owner',
              name: 'gguf-model',
              downloads: 10,
              lastModified: DateTime(2026, 7, 31),
              fileCount: 4,
              tags: const <String>['gguf'],
            ),
          ],
        );
        final modelScope = _FakeHubClient(
          source: ModelHubSource.modelScope,
          onSearch: (_) async => <HubRepoSummary>[
            HubRepoSummary(
              source: ModelHubSource.modelScope,
              repoId: 'MNN/mnn-model',
              owner: 'MNN',
              name: 'mnn-model',
              downloads: 30,
              lastModified: DateTime(2026, 7, 30),
              fileCount: 7,
              tags: const <String>['mnn'],
            ),
          ],
        );
        final provider = ModelDiscoveryProvider(
          settingsStore: _MemoryDownloadSettingsStore(),
          huggingFaceClient: huggingFace,
          modelScopeClient: modelScope,
        );
        addTearDown(provider.dispose);

        await provider.search('model');

        expect(provider.searchAllSources, isTrue);
        expect(provider.searchResults, hasLength(2));
        expect(
          provider.displayedSearchResults.map((repo) => repo.repoId),
          <String>['MNN/mnn-model', 'owner/gguf-model'],
        );

        provider.setSearchSort(HubSearchSort.updated);
        expect(
          provider.displayedSearchResults.map((repo) => repo.repoId),
          <String>['owner/gguf-model', 'MNN/mnn-model'],
        );

        provider.setFormatFilter(HubFormatFilter.gguf);
        expect(
          provider.displayedSearchResults.single.repoId,
          'owner/gguf-model',
        );

        provider.setFormatFilter(HubFormatFilter.mnn);
        expect(provider.displayedSearchResults.single.repoId, 'MNN/mnn-model');
      },
    );

    test('keeps the newest query result when searches overlap', () async {
      final firstSearch = Completer<List<HubRepoSummary>>();
      final huggingFace = _FakeHubClient(
        source: ModelHubSource.huggingFace,
        onSearch: (query) {
          if (query == 'first') {
            return firstSearch.future;
          }
          return Future<List<HubRepoSummary>>.value(<HubRepoSummary>[
            const HubRepoSummary(
              source: ModelHubSource.huggingFace,
              repoId: 'owner/second',
              owner: 'owner',
              name: 'second',
            ),
          ]);
        },
      );
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: huggingFace,
        modelScopeClient: _FakeHubClient(
          source: ModelHubSource.modelScope,
          onSearch: (_) async => const <HubRepoSummary>[],
        ),
      );
      addTearDown(provider.dispose);
      await provider.setSource(ModelHubSource.huggingFace);

      final staleFuture = provider.search('first');
      await Future<void>.delayed(Duration.zero);
      await provider.search('second');
      firstSearch.complete(<HubRepoSummary>[
        const HubRepoSummary(
          source: ModelHubSource.huggingFace,
          repoId: 'owner/first',
          owner: 'owner',
          name: 'first',
        ),
      ]);
      await staleFuture;

      expect(provider.query, 'second');
      expect(provider.searchResults.single.repoId, 'owner/second');
      expect(provider.isSearching, isFalse);
    });
  });
}

class _MemoryDownloadSettingsStore extends DownloadSettingsStore {
  DownloadSettings _settings = const DownloadSettings();

  @override
  Future<DownloadSettings> load() async => _settings;

  @override
  Future<void> savePreferredSource(ModelHubSource source) async {
    _settings = _settings.copyWith(preferredSource: source);
  }
}

class _FakeHubClient implements ModelHubClient {
  _FakeHubClient({required this.source, required this.onSearch});

  @override
  final ModelHubSource source;
  final Future<List<HubRepoSummary>> Function(String query) onSearch;

  @override
  Map<String, String> authHeaders(String? token) => const <String, String>{};

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) => '';

  @override
  Future<HubRepoDetail> fetchRepo(String repoId) => throw UnimplementedError();

  @override
  Future<List<HubRepoSummary>> search(String query, {int limit = 20}) =>
      onSearch(query);
}
