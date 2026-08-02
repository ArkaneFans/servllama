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

enum HubFormatFilter { all, gguf, mnn }

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
  bool _isLoadingRepo = false;
  String _query = '';
  ModelHubSource _activeSource = ModelHubSource.huggingFace;
  bool _searchAllSources = true;
  HubSearchSort _searchSort = HubSearchSort.downloads;
  HubFormatFilter _formatFilter = HubFormatFilter.all;
  ModelHubErrorKind? _lastError;
  int _searchEpoch = 0;

  List<CatalogEntry> get catalog => List<CatalogEntry>.unmodifiable(_catalog);
  List<HubRepoSummary> get searchResults =>
      List<HubRepoSummary>.unmodifiable(_searchResults);
  HubRepoDetail? get repoDetail => _repoDetail;
  DeviceMemoryInfo get memory => _memory;
  DownloadSettings get settings => _settings;
  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isSearching => _isSearching;
  bool get isLoadingRepo => _isLoadingRepo;
  String get query => _query;
  ModelHubSource get activeSource => _activeSource;
  bool get searchAllSources => _searchAllSources;
  HubSearchSort get searchSort => _searchSort;
  HubFormatFilter get formatFilter => _formatFilter;
  ModelHubErrorKind? get lastError => _lastError;

  List<HubRepoSummary> get displayedSearchResults {
    final results = _searchResults
        .where((repo) {
          switch (_formatFilter) {
            case HubFormatFilter.all:
              return true;
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
  }

  Future<void> setSource(ModelHubSource source) async {
    if (_activeSource == source && !_searchAllSources) {
      return;
    }
    _activeSource = source;
    _searchAllSources = false;
    await _settingsStore.savePreferredSource(source);
    notifyListeners();
    if (_query.trim().isNotEmpty) {
      await search(_query);
    }
  }

  Future<void> setSearchAllSources() async {
    if (_searchAllSources) {
      return;
    }
    _searchAllSources = true;
    notifyListeners();
    if (_query.trim().isNotEmpty) {
      await search(_query);
    }
  }

  void setSearchSort(HubSearchSort value) {
    if (_searchSort == value) {
      return;
    }
    _searchSort = value;
    notifyListeners();
  }

  void setFormatFilter(HubFormatFilter value) {
    if (_formatFilter == value) {
      return;
    }
    _formatFilter = value;
    notifyListeners();
  }

  Future<void> search(String query) async {
    _query = query;
    final searchEpoch = ++_searchEpoch;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _searchResults = <HubRepoSummary>[];
      _lastError = null;
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _lastError = null;
    notifyListeners();

    try {
      if (_searchAllSources) {
        final results = await Future.wait<List<HubRepoSummary>>(
          ModelHubSource.values.map((source) => _searchSource(source, trimmed)),
        );
        if (!_isCurrentSearch(searchEpoch)) {
          return;
        }
        _searchResults = results
            .expand((items) => items)
            .toList(growable: false);
      } else {
        final results = await (await _clientFor(_activeSource)).search(trimmed);
        if (!_isCurrentSearch(searchEpoch)) {
          return;
        }
        _searchResults = results;
      }
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

  Future<List<HubRepoSummary>> _searchSource(
    ModelHubSource source,
    String query,
  ) async {
    try {
      return await (await _clientFor(source)).search(query);
    } catch (error) {
      _logger.warning(
        '${source.displayName} 搜索失败: $error',
        channel: LogChannel.model,
      );
      return const <HubRepoSummary>[];
    }
  }

  /// Loads a repository's file listing and, in the same pass, works out which
  /// quantization tiers this device can actually run — so the picker can
  /// disable the ones that would OOM instead of failing at load time.
  Future<void> openRepo(String repoId, {ModelHubSource? source}) async {
    _isLoadingRepo = true;
    _lastError = null;
    _repoDetail = null;
    _feasibility = <String, ModelFeasibility>{};
    notifyListeners();

    try {
      final detail = await (await _clientFor(
        source ?? _activeSource,
      )).fetchRepo(repoId);
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
