import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/features/downloads/services/hugging_face_route_resolver.dart';

enum HubSearchSort { downloads, updated }

enum HubFormatFilter { gguf, mnn }

/// Drives the two discovery paths (design decision D3): a curated catalog of
/// models that have been run on real devices, and raw search across both hubs.
class ModelDiscoveryProvider extends ChangeNotifier {
  ModelDiscoveryProvider({
    ModelCatalogService? catalogService,
    DeviceCapabilityService? capabilityService,
    DownloadSettingsStore? settingsStore,
    ModelHubClient? huggingFaceClient,
    ModelHubClient? modelScopeClient,
    AppLogger? logger,
    HuggingFaceRouteResolver? huggingFaceRouteResolver,
  }) : _catalogService = catalogService ?? ModelCatalogService(),
       _capabilityService = capabilityService ?? DeviceCapabilityService(),
       _settingsStore = settingsStore ?? DownloadSettingsStore(),
       _huggingFaceClient = huggingFaceClient ?? HuggingFaceHubClient(),
       _modelScopeClient = modelScopeClient ?? ModelScopeHubClient(),
       _hasInjectedHuggingFaceClient = huggingFaceClient != null,
       _huggingFaceRouteResolver =
           huggingFaceRouteResolver ?? HuggingFaceRouteResolver(),
       _logger = logger ?? AppLogger.instance;

  final ModelCatalogService _catalogService;
  final DeviceCapabilityService _capabilityService;
  final DownloadSettingsStore _settingsStore;
  final ModelHubClient _huggingFaceClient;
  final ModelHubClient _modelScopeClient;
  final bool _hasInjectedHuggingFaceClient;
  final HuggingFaceRouteResolver _huggingFaceRouteResolver;
  final AppLogger _logger;

  List<CatalogEntry> _catalog = <CatalogEntry>[];
  List<HubRepoSummary> _searchResults = <HubRepoSummary>[];
  HubRepoDetail? _repoDetail;
  Map<String, ModelFeasibility> _feasibility = <String, ModelFeasibility>{};
  DeviceMemoryInfo _memory = DeviceMemoryInfo.unknown;
  DownloadSettings _settings = const DownloadSettings();

  bool _disposed = false;
  bool _isLoadingCatalog = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isLoadingRepo = false;
  String _query = '';
  ModelHubSource _activeSource = ModelHubSource.huggingFace;
  HubSearchSort _searchSort = HubSearchSort.downloads;
  HubFormatFilter _formatFilter = HubFormatFilter.gguf;
  ModelHubErrorKind? _lastError;
  ModelHubErrorKind? _loadMoreError;
  Map<HubModelFormat, String> _nextPageTokens = <HubModelFormat, String>{};
  int _searchEpoch = 0;

  List<CatalogEntry> get catalog => List<CatalogEntry>.unmodifiable(_catalog);
  List<HubRepoSummary> get searchResults =>
      List<HubRepoSummary>.unmodifiable(_searchResults);
  HubRepoDetail? get repoDetail => _repoDetail;
  DeviceMemoryInfo get memory => _memory;
  DownloadSettings get settings => _settings;
  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get isLoadingRepo => _isLoadingRepo;
  String get query => _query;
  ModelHubSource get activeSource => _activeSource;
  HubSearchSort get searchSort => _searchSort;
  HubFormatFilter get formatFilter => _formatFilter;
  ModelHubErrorKind? get lastError => _lastError;
  ModelHubErrorKind? get loadMoreError => _loadMoreError;
  bool get hasMore => _nextPageTokens.isNotEmpty;

  List<HubFormatFilter> get availableFormatFilters {
    final formats = _searchableFormatsFor(_activeSource);
    return <HubFormatFilter>[
      if (formats.contains(HubModelFormat.gguf)) HubFormatFilter.gguf,
      if (formats.contains(HubModelFormat.mnn)) HubFormatFilter.mnn,
    ];
  }

  List<HubRepoSummary> get displayedSearchResults {
    final results = _searchResults
        .where((repo) {
          switch (_formatFilter) {
            case HubFormatFilter.gguf:
              return repo.likelyEngine == InferenceEngine.llamaCpp;
            case HubFormatFilter.mnn:
              return repo.likelyEngine == InferenceEngine.mnn;
          }
        })
        .toList(growable: false);
    results.sort((left, right) {
      switch (_searchSort) {
        case HubSearchSort.downloads:
          return right.downloads.compareTo(left.downloads);
        case HubSearchSort.updated:
          final leftTime =
              left.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightTime =
              right.lastModified ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightTime.compareTo(leftTime);
      }
    });
    return results;
  }

  ModelFeasibility feasibilityOf(String filePath) =>
      _feasibility[filePath] ?? ModelFeasibility.unknown;

  Future<void> load() async {
    if (_isLoadingCatalog) {
      return;
    }
    _isLoadingCatalog = true;
    notifyListeners();

    try {
      _settings = await _settingsStore.load();
      _activeSource = _settings.preferredSource;
      _memory = await _capabilityService.readMemory();
      _catalog = await _catalogService.load();
    } catch (error, stackTrace) {
      _logger.error(
        '加载精选模型目录失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoadingCatalog = false;
      notifyListeners();
    }
    if (!_disposed) {
      await search(_query);
    }
  }

  Future<void> setSource(ModelHubSource source) async {
    if (_activeSource == source) {
      return;
    }
    _activeSource = source;
    if (!availableFormatFilters.contains(_formatFilter)) {
      _formatFilter = _preferredFormatFilter(_activeSource);
    }
    await _settingsStore.savePreferredSource(source);
    notifyListeners();
    await search(_query);
  }

  void setSearchSort(HubSearchSort value) {
    if (_searchSort == value) {
      return;
    }
    _searchSort = value;
    notifyListeners();
  }

  Future<void> setFormatFilter(HubFormatFilter value) async {
    if (_formatFilter == value || !availableFormatFilters.contains(value)) {
      return;
    }
    _formatFilter = value;
    notifyListeners();
    await search(_query);
  }

  Future<void> search(String query) async {
    _query = query;
    final searchEpoch = ++_searchEpoch;
    final trimmed = query.trim();

    _isSearching = true;
    _isLoadingMore = false;
    _lastError = null;
    _loadMoreError = null;
    _nextPageTokens = <HubModelFormat, String>{};
    notifyListeners();

    try {
      final pages = await _searchPages(
        source: _activeSource,
        query: trimmed,
        formats: _formatsForSearch(_activeSource),
      );
      if (!_isCurrentSearch(searchEpoch)) {
        return;
      }
      _searchResults = _deduplicate(
        pages.expand((result) => result.page.items),
      );
      _nextPageTokens = _nextTokens(pages);
    } on ModelHubException catch (error) {
      if (!_isCurrentSearch(searchEpoch)) {
        return;
      }
      _searchResults = <HubRepoSummary>[];
      _lastError = error.kind;
    } catch (error) {
      if (!_isCurrentSearch(searchEpoch)) {
        return;
      }
      _searchResults = <HubRepoSummary>[];
      _lastError = ModelHubErrorKind.network;
      _logger.warning('模型搜索失败: $error', channel: LogChannel.model);
    } finally {
      if (_isCurrentSearch(searchEpoch)) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentSearch(int epoch) => !_disposed && epoch == _searchEpoch;

  Future<void> loadMore() async {
    if (_isSearching || _isLoadingMore || _nextPageTokens.isEmpty) {
      return;
    }
    final searchEpoch = _searchEpoch;
    final requestedTokens = Map<HubModelFormat, String>.from(_nextPageTokens);
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();

    try {
      final pages = await _searchPages(
        source: _activeSource,
        query: _query.trim(),
        formats: requestedTokens.keys,
        pageTokens: requestedTokens,
      );
      if (!_isCurrentSearch(searchEpoch)) {
        return;
      }
      _searchResults = _deduplicate(<HubRepoSummary>[
        ..._searchResults,
        ...pages.expand((result) => result.page.items),
      ]);
      for (final format in requestedTokens.keys) {
        _nextPageTokens.remove(format);
      }
      _nextPageTokens.addAll(_nextTokens(pages));
    } on ModelHubException catch (error) {
      if (_isCurrentSearch(searchEpoch)) {
        _loadMoreError = error.kind;
      }
    } catch (error) {
      if (_isCurrentSearch(searchEpoch)) {
        _loadMoreError = ModelHubErrorKind.network;
        _logger.warning('加载更多模型失败: $error', channel: LogChannel.model);
      }
    } finally {
      if (_isCurrentSearch(searchEpoch)) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<List<_FormatSearchPage>> _searchPages({
    required ModelHubSource source,
    required String query,
    required Iterable<HubModelFormat> formats,
    Map<HubModelFormat, String> pageTokens = const <HubModelFormat, String>{},
  }) async {
    final client = await _clientFor(source);
    return Future.wait<_FormatSearchPage>(
      formats.map((format) async {
        final page = await client.search(
          query,
          format: format,
          limit: ModelHubClient.defaultSearchLimit,
          pageToken: pageTokens[format],
        );
        return _FormatSearchPage(format: format, page: page);
      }),
    );
  }

  Map<HubModelFormat, String> _nextTokens(Iterable<_FormatSearchPage> pages) =>
      <HubModelFormat, String>{
        for (final result in pages)
          if (result.page.nextPageToken != null)
            result.format: result.page.nextPageToken!,
      };

  Set<HubModelFormat> _searchableFormatsFor(ModelHubSource source) {
    switch (source) {
      case ModelHubSource.huggingFace:
        return _huggingFaceClient.searchableFormats;
      case ModelHubSource.modelScope:
        return _modelScopeClient.searchableFormats;
    }
  }

  List<HubModelFormat> _formatsForSearch(ModelHubSource source) {
    final supported = _searchableFormatsFor(source);
    final requested = switch (_formatFilter) {
      HubFormatFilter.gguf => HubModelFormat.gguf,
      HubFormatFilter.mnn => HubModelFormat.mnn,
    };
    return supported.contains(requested)
        ? <HubModelFormat>[requested]
        : const <HubModelFormat>[];
  }

  HubFormatFilter _preferredFormatFilter(ModelHubSource source) {
    final supported = _searchableFormatsFor(source);
    if (supported.contains(HubModelFormat.gguf)) {
      return HubFormatFilter.gguf;
    }
    if (supported.contains(HubModelFormat.mnn)) {
      return HubFormatFilter.mnn;
    }
    return HubFormatFilter.gguf;
  }

  List<HubRepoSummary> _deduplicate(Iterable<HubRepoSummary> results) {
    final unique = <String, HubRepoSummary>{};
    for (final repo in results) {
      final key = '${repo.source.storageValue}:${repo.repoId.toLowerCase()}';
      unique.putIfAbsent(key, () => repo);
    }
    return unique.values.toList(growable: false);
  }

  /// Loads a repository's file listing and, in the same pass, works out which
  /// quantization tiers this device can actually run — so the picker can
  /// disable the ones that would OOM instead of failing at load time.
  Future<void> openRepo(
    String repoId, {
    ModelHubSource? source,
    required InferenceEngine engine,
  }) async {
    _isLoadingRepo = true;
    _lastError = null;
    _repoDetail = null;
    _feasibility = <String, ModelFeasibility>{};
    notifyListeners();

    try {
      final detail = await (await _clientFor(
        source ?? _activeSource,
      )).fetchRepo(repoId, expectedFormat: HubModelFormat.fromEngine(engine));
      _repoDetail = detail;
      _feasibility = await _capabilityService.assessAll(detail.files);
    } on ModelHubException catch (error) {
      _lastError = error.kind;
    } catch (error) {
      _lastError = ModelHubErrorKind.network;
      _logger.warning('读取仓库详情失败: $error', channel: LogChannel.model);
    } finally {
      _isLoadingRepo = false;
      notifyListeners();
    }
  }

  void clearRepo() {
    _repoDetail = null;
    _feasibility = <String, ModelFeasibility>{};
    notifyListeners();
  }

  Future<ModelHubClient> _clientFor(ModelHubSource source) async {
    _settings = await _settingsStore.load();
    switch (source) {
      case ModelHubSource.huggingFace:
        if (_hasInjectedHuggingFaceClient) {
          return _huggingFaceClient;
        }
        return HuggingFaceHubClient(
          host: await _huggingFaceRouteResolver.resolve(
            _settings.huggingFaceRoute,
          ),
        );
      case ModelHubSource.modelScope:
        return _modelScopeClient;
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _FormatSearchPage {
  const _FormatSearchPage({required this.format, required this.page});

  final HubModelFormat format;
  final HubSearchPage page;
}
