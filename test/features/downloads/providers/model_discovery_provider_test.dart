import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';

void main() {
  group('ModelDiscoveryProvider', () {
    test(
      'load performs an empty-query search for the current source',
      () async {
        final calls = <_SearchCall>[];
        final provider = ModelDiscoveryProvider(
          catalogService: _EmptyCatalogService(),
          capabilityService: _UnknownCapabilityService(),
          settingsStore: _MemoryDownloadSettingsStore(),
          huggingFaceClient: _FakeHubClient(
            source: ModelHubSource.huggingFace,
            onSearch: (query, format, pageToken, sort) async {
              calls.add(_SearchCall(query, format, pageToken));
              return HubSearchPage(
                items: <HubRepoSummary>[
                  _summary(
                    source: ModelHubSource.huggingFace,
                    format: format,
                    repoId: 'owner/default-model',
                  ),
                ],
              );
            },
          ),
          modelScopeClient: _emptyModelScopeClient(),
        );
        addTearDown(provider.dispose);

        await provider.load();

        expect(calls, hasLength(1));
        expect(calls.single.query, '');
        expect(calls.single.format, HubModelFormat.gguf);
        expect(calls.single.pageToken, isNull);
        expect(provider.query, '');
        expect(provider.searchResults.single.repoId, 'owner/default-model');
      },
    );

    test('searches only the active source and its supported formats', () async {
      final calls = <String>[];
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (query, format, _, sort) async {
            calls.add('hf:$query:${format.name}:${sort.name}');
            return HubSearchPage(
              items: <HubRepoSummary>[
                _summary(
                  source: ModelHubSource.huggingFace,
                  format: format,
                  repoId: 'owner/hf-gguf-model',
                  downloads: 20,
                  lastModified: DateTime(2026, 7, 31),
                ),
              ],
            );
          },
        ),
        modelScopeClient: _FakeHubClient(
          source: ModelHubSource.modelScope,
          onSearch: (query, format, _, sort) async {
            calls.add('ms:$query:${format.name}:${sort.name}');
            return HubSearchPage(
              items: <HubRepoSummary>[
                _summary(
                  source: ModelHubSource.modelScope,
                  format: format,
                  repoId: format == HubModelFormat.gguf
                      ? 'owner/ms-gguf-model'
                      : 'MNN/mnn-model',
                  downloads: format == HubModelFormat.gguf ? 10 : 30,
                  lastModified: format == HubModelFormat.gguf
                      ? DateTime(2026, 7, 29)
                      : DateTime(2026, 7, 30),
                ),
              ],
            );
          },
        ),
      );
      addTearDown(provider.dispose);

      await provider.search('model');

      expect(calls, <String>['hf:model:gguf:trending']);
      expect(provider.searchResults.single.repoId, 'owner/hf-gguf-model');

      calls.clear();
      await provider.setSource(ModelHubSource.modelScope);

      expect(provider.formatFilter, HubFormatFilter.gguf);
      expect(provider.searchSort, HubSearchSort.trending);
      expect(calls, <String>['ms:model:gguf:trending']);
      expect(
        provider.displayedSearchResults.map((repo) => repo.repoId),
        <String>['owner/ms-gguf-model'],
      );

      calls.clear();
      await provider.setSearchSort(HubSearchSort.likes);
      expect(provider.searchSort, HubSearchSort.likes);
      expect(calls, <String>['ms:model:gguf:likes']);
      expect(
        provider.displayedSearchResults.map((repo) => repo.repoId),
        <String>['owner/ms-gguf-model'],
      );

      calls.clear();
      await provider.setFormatFilter(HubFormatFilter.mnn);
      expect(calls, <String>['ms:model:mnn:likes']);
      expect(provider.searchResults.single.repoId, 'MNN/mnn-model');

      calls.clear();
      await provider.setSource(ModelHubSource.huggingFace);
      expect(provider.formatFilter, HubFormatFilter.gguf);
      expect(calls, <String>['hf:model:gguf:likes']);
      expect(provider.availableFormatFilters, <HubFormatFilter>[
        HubFormatFilter.gguf,
      ]);
    });

    test(
      'loadMore advances the active format token and appends results',
      () async {
        final calls = <_SearchCall>[];
        final provider = ModelDiscoveryProvider(
          settingsStore: _MemoryDownloadSettingsStore(),
          huggingFaceClient: _FakeHubClient(
            source: ModelHubSource.huggingFace,
            onSearch: (_, _, _, sort) async =>
                const HubSearchPage(items: <HubRepoSummary>[]),
          ),
          modelScopeClient: _FakeHubClient(
            source: ModelHubSource.modelScope,
            onSearch: (query, format, pageToken, sort) async {
              calls.add(_SearchCall(query, format, pageToken));
              final pageName = pageToken ?? '1';
              return HubSearchPage(
                items: <HubRepoSummary>[
                  _summary(
                    source: ModelHubSource.modelScope,
                    format: format,
                    repoId: 'owner/${format.name}-$pageName',
                  ),
                ],
                nextPageToken: pageToken == null ? '${format.name}-2' : null,
              );
            },
          ),
        );
        addTearDown(provider.dispose);

        await provider.setSource(ModelHubSource.modelScope);

        expect(provider.formatFilter, HubFormatFilter.gguf);
        expect(provider.searchResults, hasLength(1));
        expect(provider.hasMore, isTrue);
        expect(calls.map((call) => call.pageToken), everyElement(isNull));
        expect(calls.map((call) => call.format), <HubModelFormat>[
          HubModelFormat.gguf,
        ]);

        calls.clear();
        await provider.loadMore();

        expect(
          calls.map((call) => '${call.format.name}:${call.pageToken}'),
          <String>['gguf:gguf-2'],
        );
        expect(provider.searchResults, hasLength(2));
        expect(provider.hasMore, isFalse);

        final callCount = calls.length;
        await provider.loadMore();
        expect(calls, hasLength(callCount));
      },
    );

    test('loadMore keeps previously loaded result order', () async {
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (_, format, pageToken, sort) async {
            if (pageToken == null) {
              return HubSearchPage(
                items: <HubRepoSummary>[
                  _summary(
                    source: ModelHubSource.huggingFace,
                    format: format,
                    repoId: 'owner/low-downloads',
                    downloads: 1,
                  ),
                  _summary(
                    source: ModelHubSource.huggingFace,
                    format: format,
                    repoId: 'owner/high-downloads',
                    downloads: 100,
                  ),
                ],
                nextPageToken: '2',
              );
            }
            return HubSearchPage(
              items: <HubRepoSummary>[
                _summary(
                  source: ModelHubSource.huggingFace,
                  format: format,
                  repoId: 'owner/mid-downloads',
                  downloads: 50,
                ),
              ],
            );
          },
        ),
        modelScopeClient: _emptyModelScopeClient(),
      );
      addTearDown(provider.dispose);

      await provider.search('q');
      expect(
        provider.displayedSearchResults.map((repo) => repo.repoId),
        <String>['owner/low-downloads', 'owner/high-downloads'],
      );

      await provider.loadMore();
      expect(
        provider.displayedSearchResults.map((repo) => repo.repoId),
        <String>[
          'owner/low-downloads',
          'owner/high-downloads',
          'owner/mid-downloads',
        ],
      );
    });

    test('deduplicates duplicate repositories in one search page', () async {
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (_, _, _, sort) async =>
              const HubSearchPage(items: <HubRepoSummary>[]),
        ),
        modelScopeClient: _FakeHubClient(
          source: ModelHubSource.modelScope,
          onSearch: (_, format, _, sort) async => HubSearchPage(
            items: <HubRepoSummary>[
              _summary(
                source: ModelHubSource.modelScope,
                format: format,
                repoId: 'owner/shared-repo',
              ),
              _summary(
                source: ModelHubSource.modelScope,
                format: format,
                repoId: 'owner/shared-repo',
              ),
            ],
          ),
        ),
      );
      addTearDown(provider.dispose);

      await provider.setSource(ModelHubSource.modelScope);

      expect(provider.searchResults, hasLength(1));
      expect(provider.searchResults.single.format, HubModelFormat.gguf);
    });

    test('ignores a late loadMore result after a new search', () async {
      final latePage = Completer<HubSearchPage>();
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (query, format, pageToken, sort) {
            if (pageToken != null) {
              return latePage.future;
            }
            return Future<HubSearchPage>.value(
              HubSearchPage(
                items: <HubRepoSummary>[
                  _summary(
                    source: ModelHubSource.huggingFace,
                    format: format,
                    repoId: 'owner/$query',
                  ),
                ],
                nextPageToken: query == 'first' ? 'next' : null,
              ),
            );
          },
        ),
        modelScopeClient: _emptyModelScopeClient(),
      );
      addTearDown(provider.dispose);

      await provider.search('first');
      final staleLoadMore = provider.loadMore();
      await Future<void>.delayed(Duration.zero);
      await provider.search('second');
      latePage.complete(
        HubSearchPage(
          items: <HubRepoSummary>[
            _summary(
              source: ModelHubSource.huggingFace,
              format: HubModelFormat.gguf,
              repoId: 'owner/stale-page',
            ),
          ],
        ),
      );
      await staleLoadMore;

      expect(provider.query, 'second');
      expect(provider.searchResults.single.repoId, 'owner/second');
      expect(provider.isLoadingMore, isFalse);
    });

    test('keeps the newest query result when searches overlap', () async {
      final firstSearch = Completer<HubSearchPage>();
      final provider = ModelDiscoveryProvider(
        settingsStore: _MemoryDownloadSettingsStore(),
        huggingFaceClient: _FakeHubClient(
          source: ModelHubSource.huggingFace,
          onSearch: (query, format, _, sort) {
            if (query == 'first') {
              return firstSearch.future;
            }
            return Future<HubSearchPage>.value(
              HubSearchPage(
                items: <HubRepoSummary>[
                  _summary(
                    source: ModelHubSource.huggingFace,
                    format: format,
                    repoId: 'owner/second',
                  ),
                ],
              ),
            );
          },
        ),
        modelScopeClient: _emptyModelScopeClient(),
      );
      addTearDown(provider.dispose);

      final staleFuture = provider.search('first');
      await Future<void>.delayed(Duration.zero);
      await provider.search('second');
      firstSearch.complete(
        HubSearchPage(
          items: <HubRepoSummary>[
            _summary(
              source: ModelHubSource.huggingFace,
              format: HubModelFormat.gguf,
              repoId: 'owner/first',
            ),
          ],
        ),
      );
      await staleFuture;

      expect(provider.query, 'second');
      expect(provider.searchResults.single.repoId, 'owner/second');
      expect(provider.isSearching, isFalse);
    });

    test('uses explicit format instead of guessing from repository name', () {
      const namedMnnButGguf = HubRepoSummary(
        source: ModelHubSource.modelScope,
        format: HubModelFormat.gguf,
        repoId: 'owner/model-mnn-experiment',
        owner: 'owner',
        name: 'model-mnn-experiment',
      );
      const plainNameButMnn = HubRepoSummary(
        source: ModelHubSource.modelScope,
        format: HubModelFormat.mnn,
        repoId: 'owner/plain-model',
        owner: 'owner',
        name: 'plain-model',
      );

      expect(namedMnnButGguf.likelyEngine.name, 'llamaCpp');
      expect(plainNameButMnn.likelyEngine.name, 'mnn');
    });
  });
}

HubRepoSummary _summary({
  required ModelHubSource source,
  required HubModelFormat format,
  required String repoId,
  int downloads = 0,
  DateTime? lastModified,
}) {
  final segments = repoId.split('/');
  return HubRepoSummary(
    source: source,
    format: format,
    repoId: repoId,
    owner: segments.length > 1 ? segments.first : '',
    name: segments.last,
    downloads: downloads,
    lastModified: lastModified,
  );
}

_FakeHubClient _emptyModelScopeClient() => _FakeHubClient(
  source: ModelHubSource.modelScope,
  onSearch: (_, _, _, sort) async => const HubSearchPage(items: <HubRepoSummary>[]),
);

class _SearchCall {
  const _SearchCall(this.query, this.format, this.pageToken);

  final String query;
  final HubModelFormat format;
  final String? pageToken;
}

class _EmptyCatalogService extends ModelCatalogService {
  @override
  Future<List<CatalogEntry>> load() async => const <CatalogEntry>[];
}

class _UnknownCapabilityService extends DeviceCapabilityService {
  @override
  Future<DeviceMemoryInfo> readMemory() async => DeviceMemoryInfo.unknown;
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
  _FakeHubClient({
    required this.source,
    required this.onSearch,
    Set<HubModelFormat>? searchableFormats,
  }) : searchableFormats =
           searchableFormats ??
           (source == ModelHubSource.huggingFace
               ? const <HubModelFormat>{HubModelFormat.gguf}
               : const <HubModelFormat>{
                   HubModelFormat.gguf,
                   HubModelFormat.mnn,
                 });

  @override
  final ModelHubSource source;
  final Future<HubSearchPage> Function(
    String query,
    HubModelFormat format,
    String? pageToken,
    HubSearchSort sort,
  )
  onSearch;

  @override
  final Set<HubModelFormat> searchableFormats;

  @override
  Map<String, String> authHeaders(String? token) => const <String, String>{};

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) => '';

  @override
  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  }) => throw UnimplementedError();

  @override
  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    HubSearchSort sort = HubSearchSort.trending,
    int limit = ModelHubClient.defaultSearchLimit,
    String? pageToken,
  }) => onSearch(query, format, pageToken, sort);
}
