import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/repositories/download_task_repository.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/download_environment_service.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';
import 'package:servllama/features/downloads/services/hugging_face_route_resolver.dart';

/// Owns the download queue: which tasks exist, which are running, and what
/// happens to the bytes once they land. A finished task is committed into the
/// unified model library — as a GGUF file for llama.cpp, or by handing the
/// staged directory to the MNN plugin's `importModelFromPath`.
class DownloadProvider extends ChangeNotifier {
  DownloadProvider({
    DownloadTaskRepository? taskRepository,
    ModelDownloadService? downloadService,
    DownloadSettingsStore? settingsStore,
    LocalModelRepository? localModelRepository,
    MnnEngine? mnnEngine,
    AppLogger? logger,
    DownloadEnvironmentService? environmentService,
    ForegroundTaskService? foregroundTaskService,
    Future<void> Function(Duration) retryDelay = Future<void>.delayed,
    HuggingFaceRouteResolver? huggingFaceRouteResolver,
    Future<void> Function()? onLibraryChanged,
  }) : _taskRepository = taskRepository ?? DownloadTaskRepository(),
       _downloadService = downloadService ?? ModelDownloadService(),
       _settingsStore = settingsStore ?? DownloadSettingsStore(),
       _localModelRepository = localModelRepository ?? LocalModelRepository(),
       _mnnEngine = mnnEngine ?? MnnEngine.instance,
       _logger = logger ?? AppLogger.instance,
       _environmentService =
           environmentService ?? const DownloadEnvironmentService(),
       _foregroundTaskService =
           foregroundTaskService ?? ForegroundTaskService(),
       _retryDelay = retryDelay,
       _huggingFaceRouteResolver =
           huggingFaceRouteResolver ?? HuggingFaceRouteResolver(),
       _onLibraryChanged = onLibraryChanged;

  final DownloadTaskRepository _taskRepository;
  final ModelDownloadService _downloadService;
  final DownloadSettingsStore _settingsStore;
  final LocalModelRepository _localModelRepository;
  final MnnEngine _mnnEngine;
  final AppLogger _logger;
  final DownloadEnvironmentService _environmentService;
  final ForegroundTaskService _foregroundTaskService;
  final Future<void> Function(Duration) _retryDelay;
  final HuggingFaceRouteResolver _huggingFaceRouteResolver;
  final Future<void> Function()? _onLibraryChanged;

  final Map<String, DownloadTaskRecord> _tasks = <String, DownloadTaskRecord>{};
  final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};
  final Map<String, double> _throughput = <String, double>{};
  final Map<String, _ThroughputSample> _samples = <String, _ThroughputSample>{};
  final Random _random = Random();

  DownloadSettings _settings = const DownloadSettings();
  bool _disposed = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isPumping = false;
  bool _downloadForegroundActive = false;
  bool _isSyncingDownloadForeground = false;
  bool _downloadForegroundSyncRequested = false;
  Future<void>? _loadFuture;
  Timer? _environmentTimer;

  static const List<Duration> _retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static const int _storageReserveBytes = 64 * 1024 * 1024;

  DownloadSettings get settings => _settings;
  bool get isLoading => _isLoading;

  List<DownloadTaskView> get tasks {
    final views = _tasks.values
        .map(
          (record) => DownloadTaskView(
            record,
            bytesPerSecond: _throughput[record.id] ?? 0,
          ),
        )
        .toList(growable: true);
    views.sort(
      (left, right) => right.record.createdAt.compareTo(left.record.createdAt),
    );
    return views;
  }

  List<DownloadTaskView> get activeTasks =>
      tasks.where((task) => task.status.isActive).toList(growable: false);

  int get activeTaskCount => activeTasks.length;

  Future<void> load() {
    if (_hasLoaded) {
      return Future<void>.value();
    }
    return _loadFuture ??= _loadOnce().whenComplete(() {
      _loadFuture = null;
    });
  }

  Future<void> _loadOnce() async {
    _isLoading = true;
    _foregroundTaskService.init();
    notifyListeners();

    try {
      _settings = await _settingsStore.load();
      final records = await _taskRepository.listTasks();
      _tasks
        ..clear()
        ..addEntries(records.map((record) => MapEntry(record.id, record)));

      // Transfers are range-resumable, so work that was interrupted by a
      // process death returns to the queue instead of requiring a manual tap.
      for (final record in _tasks.values) {
        final status = DownloadStatus.fromName(record.statusValue);
        if (status.isActive) {
          record.statusValue = DownloadStatus.queued.name;
          record.pausedByNetwork = false;
          await _taskRepository.save(record);
        }
      }
      _hasLoaded = true;
    } catch (error, stackTrace) {
      _logger.error(
        '加载下载任务失败',
        channel: LogChannel.model,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
      _ensureEnvironmentMonitor();
      unawaited(_pump());
    }
  }

  Future<void> reloadSettings() async {
    _settings = await _settingsStore.load();
    notifyListeners();
  }

  Future<void> setHuggingFaceRoute(HuggingFaceRoute route) async {
    await _settingsStore.saveHuggingFaceRoute(route);
    _settings = _settings.copyWith(huggingFaceRoute: route);
    notifyListeners();
  }

  Future<void> setToken(ModelHubSource source, String token) async {
    switch (source) {
      case ModelHubSource.huggingFace:
        await _settingsStore.saveHuggingFaceToken(token);
        _settings = _settings.copyWith(huggingFaceToken: token);
      case ModelHubSource.modelScope:
        await _settingsStore.saveModelScopeToken(token);
        _settings = _settings.copyWith(modelScopeToken: token);
    }
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    await _settingsStore.saveWifiOnly(value);
    _settings = _settings.copyWith(wifiOnly: value);
    notifyListeners();
    unawaited(_pump());
  }

  Future<void> setMaxConcurrentTasks(int value) async {
    await _settingsStore.saveMaxConcurrentTasks(value);
    _settings = _settings.copyWith(maxConcurrentTasks: value);
    notifyListeners();
    unawaited(_pump());
  }

  /// Bytes left behind by downloads that were cancelled or orphaned by a
  /// crash. Surfaced in settings so the user can reclaim them.
  Future<int> orphanedStagingBytes() => _taskRepository.orphanedStagingBytes();

  Future<void> clearOrphanedStaging() async {
    await _taskRepository.clearOrphanedStaging();
    notifyListeners();
  }

  /// Queues a download. [files] is the full set of remote files for one
  /// model: a single GGUF (plus optional mmproj) for llama.cpp, or every file
  /// of an MNN model directory.
  Future<DownloadTaskView> enqueue({
    required InferenceEngine engine,
    required ModelHubSource source,
    required String repoId,
    required String revision,
    required String modelName,
    required List<HubRepoFile> files,
    String? quantLabel,
  }) async {
    await _ensureStorageCapacity(engine, files);
    final taskId =
        'dl_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 20)}';
    final staging = await _taskRepository.createStagingDirectory(taskId);

    final record = DownloadTaskRecord(
      id: taskId,
      engineValue: engine.storageValue,
      sourceValue: source.storageValue,
      repoId: repoId,
      revision: revision,
      modelName: modelName,
      quantLabel: quantLabel,
      stagingDirPath: staging.path,
      statusValue: DownloadStatus.queued.name,
      createdAt: DateTime.now(),
      files: files
          .map(
            (file) => DownloadFileRecord(
              remotePath: file.path,
              // MNN repos nest files in subdirectories; flattening would
              // collide, so the relative layout is preserved on disk.
              fileName: file.path,
              totalBytes: file.sizeBytes,
              sha256: file.sha256,
            ),
          )
          .toList(growable: false),
    );

    _tasks[taskId] = record;
    await _taskRepository.save(record);
    notifyListeners();

    unawaited(_pump());
    return DownloadTaskView(record);
  }

  Future<void> pause(String taskId) async {
    final record = _tasks[taskId];
    if (record == null ||
        !DownloadStatus.fromName(record.statusValue).canPause) {
      return;
    }
    _cancelTokens[taskId]?.cancel('paused');
    record.statusValue = DownloadStatus.paused.name;
    record.pausedByNetwork = false;
    _throughput.remove(taskId);
    await _taskRepository.save(record);
    notifyListeners();
    _scheduleDownloadForegroundSync();
    unawaited(_pump());
  }

  Future<void> resume(String taskId) async {
    final record = _tasks[taskId];
    if (record == null ||
        !DownloadStatus.fromName(record.statusValue).isResumable) {
      return;
    }
    record.statusValue = DownloadStatus.queued.name;
    record.pausedByNetwork = false;
    record.errorDetail = null;
    await _taskRepository.save(record);
    notifyListeners();
    unawaited(_pump());
  }

  Future<void> cancel(String taskId) async {
    final record = _tasks[taskId];
    if (record == null ||
        !DownloadStatus.fromName(record.statusValue).canCancel) {
      return;
    }
    _cancelTokens[taskId]?.cancel('cancelled');
    _tasks.remove(taskId);
    _throughput.remove(taskId);
    _samples.remove(taskId);
    await _taskRepository.delete(taskId);
    try {
      await _taskRepository.deleteStagingDirectory(record.stagingDirPath);
    } catch (error, stackTrace) {
      _logger.warning(
        '清理已取消任务的暂存目录失败: ${record.modelName}',
        channel: LogChannel.download,
        inMemory: true,
        error: error,
        stackTrace: stackTrace,
      );
    }
    notifyListeners();
    _scheduleDownloadForegroundSync();
    unawaited(_pump());
  }

  /// Retries a failed task from the other hub, keeping whatever bytes are
  /// already on disk — the two hubs serve byte-identical files.
  Future<void> switchSource(String taskId, ModelHubSource source) async {
    final record = _tasks[taskId];
    if (record == null ||
        !DownloadStatus.fromName(record.statusValue).isResumable) {
      return;
    }
    record.sourceValue = source.storageValue;
    record.revision = source == ModelHubSource.modelScope
        ? ModelScopeHubClient.defaultRevision
        : 'main';
    record.statusValue = DownloadStatus.queued.name;
    record.errorDetail = null;
    await _taskRepository.save(record);
    notifyListeners();
    unawaited(_pump());
  }

  /// Starts queued tasks up to the configured concurrency limit.
  Future<void> _pump() async {
    if (_isPumping || _disposed) {
      return;
    }
    _isPumping = true;
    try {
      if (!await _applyNetworkPolicy()) {
        return;
      }
      final running = _tasks.values.where((record) {
        final status = DownloadStatus.fromName(record.statusValue);
        return status == DownloadStatus.running ||
            status == DownloadStatus.downloaded;
      }).length;
      var slots = _settings.maxConcurrentTasks - running;
      if (slots <= 0) {
        return;
      }

      for (final record in _tasks.values.toList(growable: false)) {
        if (slots <= 0) {
          return;
        }
        if (DownloadStatus.fromName(record.statusValue) !=
            DownloadStatus.queued) {
          continue;
        }
        if (_cancelTokens.containsKey(record.id)) {
          continue;
        }
        slots -= 1;
        unawaited(_runTask(record));
      }
    } finally {
      _isPumping = false;
    }
  }

  Future<void> _runTask(DownloadTaskRecord record) async {
    if (_disposed ||
        !identical(_tasks[record.id], record) ||
        DownloadStatus.fromName(record.statusValue) != DownloadStatus.queued ||
        _cancelTokens.containsKey(record.id)) {
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[record.id] = cancelToken;
    record.statusValue = DownloadStatus.running.name;
    record.errorDetail = null;
    _samples[record.id] = _ThroughputSample(DateTime.now());
    notifyListeners();
    _scheduleDownloadForegroundSync();

    try {
      await _taskRepository.save(record);
      final source = ModelHubSource.fromStorageValue(record.sourceValue);
      final client = await _clientFor(source);
      final headers = client.authHeaders(_settings.tokenFor(source));
      final staging = Directory(record.stagingDirPath);

      for (final file in record.files) {
        _ensureCurrentRun(record, cancelToken);
        if (file.completed) {
          continue;
        }
        await _downloadFileWithRetry(
          record: record,
          file: file,
          staging: staging,
          client: client,
          headers: headers,
          cancelToken: cancelToken,
        );
        _ensureCurrentRun(record, cancelToken);
        await _taskRepository.save(record);
        notifyListeners();
      }

      _ensureCurrentRun(record, cancelToken);
      record.statusValue = DownloadStatus.downloaded.name;
      await _taskRepository.save(record);
      notifyListeners();
      _scheduleDownloadForegroundSync();

      await _commit(record, staging);
    } on DownloadException catch (error) {
      if (error.kind == DownloadErrorKind.cancelled ||
          cancelToken.isCancelled ||
          !_ownsRun(record, cancelToken)) {
        // pause()/cancel() already set the terminal state.
        return;
      }
      record.statusValue = DownloadStatus.failed.name;
      record.errorDetail = error.kind.name;
      await _taskRepository.save(record);
      _logger.warning(
        '下载失败: ${record.modelName} (${error.kind.name})',
        channel: LogChannel.download,
        inMemory: true,
      );
    } catch (error, stackTrace) {
      if (cancelToken.isCancelled || !_ownsRun(record, cancelToken)) {
        return;
      }
      record.statusValue = DownloadStatus.failed.name;
      record.errorDetail = error.toString();
      await _taskRepository.save(record);
      _logger.error(
        '下载任务异常: ${record.modelName}',
        channel: LogChannel.download,
        inMemory: true,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (identical(_cancelTokens[record.id], cancelToken)) {
        _cancelTokens.remove(record.id);
        _throughput.remove(record.id);
        _samples.remove(record.id);
        notifyListeners();
        _scheduleDownloadForegroundSync();
        unawaited(_pump());
      }
    }
  }

  /// Moves the staged bytes into whichever store owns this engine's format.
  Future<void> _commit(DownloadTaskRecord record, Directory staging) async {
    final engine = InferenceEngine.fromStorageValue(record.engineValue);
    switch (engine) {
      case InferenceEngine.llamaCpp:
        File? modelFile;
        File? mmprojFile;
        for (final file in record.files) {
          final path =
              '${staging.path}${Platform.pathSeparator}'
              '${file.fileName.replaceAll('/', Platform.pathSeparator)}';
          final name = file.fileName.split('/').last.toLowerCase();
          if (name.startsWith('mmproj')) {
            mmprojFile = File(path);
          } else {
            modelFile = File(path);
          }
        }
        if (modelFile == null) {
          throw StateError('download produced no model file');
        }
        await _localModelRepository.adoptDownloadedModel(
          modelName: record.modelName,
          modelFile: modelFile,
          mmprojFile: mmprojFile,
        );
      case InferenceEngine.mnn:
        await _ensureMnnDisplayMetadata(record, staging);
        // The plugin re-validates and takes ownership of the directory.
        await _mnnEngine.importModelFromPath(staging.path);
    }

    try {
      await _taskRepository.deleteStagingDirectory(record.stagingDirPath);
    } catch (error, stackTrace) {
      _logger.warning(
        '清理下载暂存目录失败: ${record.modelName}',
        channel: LogChannel.download,
        inMemory: true,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final onLibraryChanged = _onLibraryChanged;
    if (onLibraryChanged != null) {
      try {
        await onLibraryChanged();
      } catch (error, stackTrace) {
        _logger.warning(
          '刷新模型库失败: ${record.modelName}',
          channel: LogChannel.download,
          inMemory: true,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    record.statusValue = DownloadStatus.completed.name;
    await _taskRepository.save(record);
    _logger.info(
      '模型下载完成并入库: ${record.modelName}',
      channel: LogChannel.download,
      inMemory: true,
    );
    notifyListeners();
    _scheduleDownloadForegroundSync();
  }

  Future<void> _ensureMnnDisplayMetadata(
    DownloadTaskRecord record,
    Directory staging,
  ) async {
    final metadataFile = File(
      '${staging.path}${Platform.pathSeparator}market_config.json',
    );
    Map<String, dynamic> metadata = <String, dynamic>{};
    if (await metadataFile.exists()) {
      try {
        final decoded = jsonDecode(await metadataFile.readAsString());
        if (decoded is Map) {
          metadata = Map<String, dynamic>.from(decoded);
        }
      } on FormatException catch (_) {
        // The plugin also treats malformed optional metadata as absent.
      }
    }

    const displayNameKeys = <String>['modelName', 'model_name', 'name'];
    final hasDisplayName = displayNameKeys.any((key) {
      final value = metadata[key];
      return value is String && value.trim().isNotEmpty;
    });
    if (hasDisplayName) {
      return;
    }

    metadata['modelName'] = record.modelName;
    await metadataFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(metadata),
      flush: true,
    );
  }

  Future<void> _downloadFileWithRetry({
    required DownloadTaskRecord record,
    required DownloadFileRecord file,
    required Directory staging,
    required ModelHubClient client,
    required Map<String, String> headers,
    required CancelToken cancelToken,
  }) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        await _downloadService.downloadFile(
          url: client.downloadUrl(
            record.repoId,
            file.remotePath,
            revision: record.revision,
          ),
          file: file,
          targetDirectory: staging,
          headers: headers,
          cancelToken: cancelToken,
          onProgress: (_, delta) => _reportProgress(record.id, delta),
        );
        return;
      } on DownloadException catch (error) {
        final retryable =
            error.isRetryable &&
            (error.kind == DownloadErrorKind.network ||
                error.kind == DownloadErrorKind.integrity);
        if (!retryable || attempt >= _retryBackoff.length) {
          rethrow;
        }
        if (error.restartRequired) {
          await _downloadService.discardPartial(
            file: file,
            targetDirectory: staging,
          );
        }
        _logger.warning(
          '下载重试 ${attempt + 1}/${_retryBackoff.length}: '
          '${record.modelName}/${file.fileName}',
          channel: LogChannel.download,
          inMemory: true,
          error: error.detail,
        );
        await _retryDelay(_retryBackoff[attempt]);
        if (cancelToken.isCancelled) {
          throw const DownloadException(DownloadErrorKind.cancelled);
        }
      }
    }
  }

  bool _ownsRun(DownloadTaskRecord record, CancelToken cancelToken) =>
      identical(_tasks[record.id], record) &&
      identical(_cancelTokens[record.id], cancelToken);

  void _ensureCurrentRun(DownloadTaskRecord record, CancelToken cancelToken) {
    if (cancelToken.isCancelled || !_ownsRun(record, cancelToken)) {
      throw const DownloadException(DownloadErrorKind.cancelled);
    }
  }

  Future<void> _ensureStorageCapacity(
    InferenceEngine engine,
    List<HubRepoFile> files,
  ) async {
    final expectedBytes = files.fold<int>(
      0,
      (total, file) => total + file.sizeBytes,
    );
    if (expectedBytes <= 0) {
      return;
    }
    final available = await _environmentService.availableStorageBytes();
    if (available == null) {
      return;
    }
    // MNN imports through plugin-owned staging and temporarily needs a second
    // copy. GGUF commits by rename and therefore only needs the download bytes.
    final requiredBytes =
        expectedBytes * (engine == InferenceEngine.mnn ? 2 : 1) +
        _storageReserveBytes;
    if (available < requiredBytes) {
      throw DownloadException(
        DownloadErrorKind.diskFull,
        detail: '$requiredBytes',
      );
    }
  }

  void _ensureEnvironmentMonitor() {
    _environmentTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pump());
    });
  }

  Future<bool> _applyNetworkPolicy() async {
    final transport = await _environmentService.networkTransport();
    final allowed = _environmentService.allowsDownload(
      wifiOnly: _settings.wifiOnly,
      transport: transport,
    );
    var changed = false;
    if (!allowed) {
      for (final record in _tasks.values) {
        final status = DownloadStatus.fromName(record.statusValue);
        if (!status.isTransferActive) {
          continue;
        }
        _cancelTokens[record.id]?.cancel('network policy');
        record.statusValue = DownloadStatus.paused.name;
        record.pausedByNetwork = true;
        await _taskRepository.save(record);
        changed = true;
      }
    } else {
      for (final record in _tasks.values) {
        if (DownloadStatus.fromName(record.statusValue) !=
                DownloadStatus.paused ||
            !record.pausedByNetwork) {
          continue;
        }
        record.statusValue = DownloadStatus.queued.name;
        record.pausedByNetwork = false;
        await _taskRepository.save(record);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      _scheduleDownloadForegroundSync();
    }
    return allowed;
  }

  void _scheduleDownloadForegroundSync() {
    if (_disposed) {
      return;
    }
    _downloadForegroundSyncRequested = true;
    if (_isSyncingDownloadForeground) {
      return;
    }
    unawaited(_drainDownloadForegroundSync());
  }

  Future<void> _drainDownloadForegroundSync() async {
    _isSyncingDownloadForeground = true;
    try {
      while (_downloadForegroundSyncRequested && !_disposed) {
        _downloadForegroundSyncRequested = false;
        await _syncDownloadForeground();
      }
    } catch (error, stackTrace) {
      _logger.warning(
        '更新下载前台通知失败',
        channel: LogChannel.download,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _isSyncingDownloadForeground = false;
      if (_downloadForegroundSyncRequested && !_disposed) {
        _scheduleDownloadForegroundSync();
      }
    }
  }

  Future<void> _syncDownloadForeground() async {
    final running = _tasks.values
        .where((record) {
          final status = DownloadStatus.fromName(record.statusValue);
          return status == DownloadStatus.running ||
              status == DownloadStatus.downloaded;
        })
        .toList(growable: false);
    if (running.isEmpty) {
      if (_downloadForegroundActive) {
        _downloadForegroundActive = false;
        await _foregroundTaskService.release(
          ForegroundTaskService.downloadsOwner,
        );
      }
      return;
    }

    final total = running.fold<int>(
      0,
      (sum, record) =>
          sum +
          record.files.fold<int>(0, (value, file) => value + file.totalBytes),
    );
    final received = running.fold<int>(
      0,
      (sum, record) =>
          sum +
          record.files.fold<int>(
            0,
            (value, file) => value + file.receivedBytes,
          ),
    );
    final percent = total <= 0
        ? 0
        : ((received / total) * 100).round().clamp(0, 100);
    final l10n = AppL10nService.instance.current;
    if (_downloadForegroundActive) {
      await _foregroundTaskService.updateOwner(
        owner: ForegroundTaskService.downloadsOwner,
        title: l10n.downloadForegroundTitle,
        text: l10n.downloadForegroundText(running.length, percent),
      );
    } else {
      final acquired = await _foregroundTaskService.acquire(
        owner: ForegroundTaskService.downloadsOwner,
        notificationTitle: l10n.downloadForegroundTitle,
        notificationText: l10n.downloadForegroundText(running.length, percent),
      );
      if (_disposed) {
        if (acquired) {
          await _foregroundTaskService.release(
            ForegroundTaskService.downloadsOwner,
          );
        }
        _downloadForegroundActive = false;
        return;
      }
      _downloadForegroundActive = acquired;
    }
  }

  void _reportProgress(String taskId, int delta) {
    final sample = _samples[taskId];
    if (sample == null) {
      return;
    }
    if (delta <= 0) {
      notifyListeners();
      _scheduleDownloadForegroundSync();
      return;
    }
    sample.bytes += delta;
    final elapsed = DateTime.now().difference(sample.since);
    if (elapsed < const Duration(milliseconds: 600)) {
      return;
    }
    _throughput[taskId] = sample.bytes / elapsed.inMilliseconds * 1000;
    sample
      ..bytes = 0
      ..since = DateTime.now();
    notifyListeners();
    _scheduleDownloadForegroundSync();
  }

  Future<ModelHubClient> _clientFor(ModelHubSource source) async {
    switch (source) {
      case ModelHubSource.huggingFace:
        return HuggingFaceHubClient(
          host: await _huggingFaceRouteResolver.resolve(
            _settings.huggingFaceRoute,
          ),
        );
      case ModelHubSource.modelScope:
        return ModelScopeHubClient();
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
    _downloadForegroundSyncRequested = false;
    _environmentTimer?.cancel();
    _environmentTimer = null;
    for (final token in _cancelTokens.values) {
      token.cancel('disposed');
    }
    _cancelTokens.clear();
    if (_downloadForegroundActive) {
      unawaited(
        _foregroundTaskService.release(ForegroundTaskService.downloadsOwner),
      );
    }
    super.dispose();
  }
}

class _ThroughputSample {
  _ThroughputSample(this.since);

  DateTime since;
  int bytes = 0;
}
