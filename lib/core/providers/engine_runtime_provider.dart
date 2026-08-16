import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/engines/llama_cpp_engine_adapter.dart';
import 'package:servllama/core/services/engines/mnn_engine_adapter.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/engine_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/core/utils/network_utils.dart';

/// Single owner of "which engine is running, with which model". Both engines
/// bind the same configured port, so the base URL external clients use never
/// changes when the active engine does.
///
/// Engine switching is only allowed while idle (design decision D5), which is
/// what keeps this class free of cross-engine rollback logic.
class EngineRuntimeProvider extends ChangeNotifier {
  EngineRuntimeProvider({
    InferenceEngineAdapter? llamaCppAdapter,
    InferenceEngineAdapter? mnnAdapter,
    ServerLaunchSettingsLoader? settingsLoader,
    KvStorage? kvStorage,
    AppLogger? logger,
    Future<String?> Function() localIpResolver = NetworkUtils.getLocalIpAddress,
  }) : _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _kvStorage = kvStorage ?? KvStorage.instance,
       _logger = logger ?? AppLogger.instance,
       _localIpResolver = localIpResolver {
    _adapters = <InferenceEngine, InferenceEngineAdapter>{
      InferenceEngine.llamaCpp: llamaCppAdapter ?? LlamaCppEngineAdapter(),
      InferenceEngine.mnn: mnnAdapter ?? MnnEngineAdapter(),
    };
    for (final adapter in _adapters.values) {
      _runningSubscriptions.add(
        adapter.runningStateStream.listen(
          (running) => _handleExternalRunningChange(adapter.engine, running),
        ),
      );
    }
    _state = EngineRuntimeState(engine: InferenceEngine.llamaCpp);
  }

  final ServerLaunchSettingsLoader _settingsLoader;
  final KvStorage _kvStorage;
  final AppLogger _logger;
  final Future<String?> Function() _localIpResolver;

  late final Map<InferenceEngine, InferenceEngineAdapter> _adapters;
  final List<StreamSubscription<bool>> _runningSubscriptions =
      <StreamSubscription<bool>>[];

  late EngineRuntimeState _state;
  final Map<InferenceEngine, String?> _selectedModelIds =
      <InferenceEngine, String?>{};

  bool _disposed = false;
  int _operationEpoch = 0;
  String _host = '127.0.0.1';
  int _port = 8080;
  String _apiKey = '';
  String? _pendingDisplayHost;

  EngineRuntimeState get state => _state;
  InferenceEngine get activeEngine => _state.engine;
  EngineRuntimeStatus get status => _state.status;
  bool get isRunning => _state.isRunning;
  bool get isBusy => _state.isBusy;
  bool get canSwitchEngine =>
      _state.canSwitchEngine && !_adapters[_state.engine]!.isRunning;
  bool get canStart =>
      (_state.status == EngineRuntimeStatus.idle ||
          _state.status == EngineRuntimeStatus.error) &&
      selectedModelId != null;
  EngineRuntimeError? get lastError => _state.error;
  RuntimePhase? get currentPhase => _state.phase;
  String? get activeModelId => _state.activeModelId;
  String? get activeModelName => _state.activeModelName;

  /// Model the user has picked for [activeEngine], whether or not it is
  /// loaded yet. Null means the engine cannot be started yet.
  String? get selectedModelId => selectedModelIdFor(_state.engine);

  /// The saved default model for [engine], including engines that are not
  /// currently active. A running engine reports its resident model first.
  String? selectedModelIdFor(InferenceEngine engine) {
    if (engine == _state.engine && _state.activeModelId != null) {
      return _state.activeModelId;
    }
    return _selectedModelIds[engine];
  }

  String get host => _host;
  int get port => _port;
  bool get exposesLanWithoutApiKey =>
      _host == '0.0.0.0' && _apiKey.trim().isEmpty;

  /// Address other devices on the LAN can reach when listening on all
  /// interfaces. Falls back to the raw host until the local IP resolves.
  String get displayAddress {
    if (_host == '0.0.0.0') {
      return '${_pendingDisplayHost ?? _host}:$_port';
    }
    return '$_host:$_port';
  }

  String get displayUrl => 'http://$displayAddress';

  /// The app always talks to loopback, regardless of which interfaces the
  /// active engine listens on.
  String get baseUrl => 'http://127.0.0.1:$_port';

  Future<void> restore() async {
    final storedEngine = await _kvStorage.getString(
      EnginePrefsKeys.activeEngine,
    );
    final engine = InferenceEngine.fromStorageValue(storedEngine);

    for (final candidate in InferenceEngine.values) {
      _selectedModelIds[candidate] = await _kvStorage.getString(
        EnginePrefsKeys.selectedModel(candidate.storageValue),
      );
    }

    await _loadEndpoint();

    final adapter = _adapters[engine]!;
    try {
      await adapter.prepare();
    } on EngineAdapterException catch (error) {
      _state = EngineRuntimeState(
        engine: engine,
        status: EngineRuntimeStatus.error,
        error: EngineRuntimeError(kind: error.kind, detail: error.detail),
      );
      notifyListeners();
      return;
    }
    final running = adapter.isRunning;
    _state = EngineRuntimeState(
      engine: engine,
      status: running ? EngineRuntimeStatus.ready : EngineRuntimeStatus.idle,
      activeModelId: running ? _selectedModelIds[engine] : null,
      activeModelName: running ? _selectedModelIds[engine] : null,
      startedAt: running ? DateTime.now() : null,
    );
    notifyListeners();
  }

  Future<void> _loadEndpoint() async {
    try {
      final settings = await _settingsLoader.load();
      _host = settings.host;
      _port = settings.port;
      _apiKey = settings.apiKey;
    } catch (_) {}
    _scheduleDisplayHostRefresh();
  }

  /// Re-reads the configured endpoint. The server config page persists
  /// immediately, so the runtime picks the change up on the next visit.
  Future<void> refresh() async {
    await _loadEndpoint();
    final adapter = _adapters[_state.engine]!;
    if (!_state.isBusy && adapter.isRunning != _state.isRunning) {
      _state = _state.copyWith(
        status: adapter.isRunning
            ? EngineRuntimeStatus.ready
            : EngineRuntimeStatus.idle,
      );
    }
    notifyListeners();
  }

  /// Applies an endpoint the config page just persisted, so the base URL row
  /// reflects it without waiting for the next restart.
  void setEndpoint({String? host, int? port, String? apiKey}) {
    var changed = false;
    if (host != null && host != _host) {
      _host = host;
      changed = true;
    }
    if (port != null && port != _port) {
      _port = port;
      changed = true;
    }
    if (apiKey != null && apiKey != _apiKey) {
      _apiKey = apiKey;
      changed = true;
    }
    if (changed) {
      _scheduleDisplayHostRefresh();
      notifyListeners();
    }
  }

  Future<void> switchEngine(InferenceEngine engine) async {
    if (engine == _state.engine) {
      return;
    }
    // Guarded rather than orchestrated: switching while running would need a
    // stop/unload/start rollback path, which D5 exists to avoid.
    if (!canSwitchEngine) {
      return;
    }

    await _kvStorage.setString(
      EnginePrefsKeys.activeEngine,
      engine.storageValue,
    );
    _state = EngineRuntimeState(
      engine: engine,
      activeModelId: null,
      activeModelName: null,
    );
    _logger.info('切换推理引擎: ${engine.displayName}', channel: LogChannel.server);
    notifyListeners();
  }

  /// Records the model to use without touching the runtime. Used by the
  /// server page while idle; while running, use [activateModel].
  Future<void> selectModel(String? modelId) async {
    final engine = _state.engine;
    _selectedModelIds[engine] = modelId;
    final key = EnginePrefsKeys.selectedModel(engine.storageValue);
    if (modelId == null) {
      await _kvStorage.remove(key);
    } else {
      await _kvStorage.setString(key, modelId);
    }
    if (_state.status == EngineRuntimeStatus.error) {
      _state = EngineRuntimeState(engine: engine);
    }
    notifyListeners();
  }

  /// Moves a saved model selection when a directory rename changes the
  /// engine-facing runtime id. Renames are only allowed while the runtime is
  /// stopped, so no active session needs to be migrated here.
  Future<void> handleModelRenamed({
    required InferenceEngine engine,
    required String oldModelId,
    required String newModelId,
  }) async {
    if (_selectedModelIds[engine] != oldModelId) {
      return;
    }
    _selectedModelIds[engine] = newModelId;
    await _kvStorage.setString(
      EnginePrefsKeys.selectedModel(engine.storageValue),
      newModelId,
    );
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_state.status == EngineRuntimeStatus.preparing) {
      await cancel();
      return;
    }
    if (_state.status == EngineRuntimeStatus.stopping) {
      return;
    }
    if (_state.isRunning) {
      await stop();
      return;
    }
    await start();
  }

  Future<void> start() async {
    if (_state.isBusy || _state.isRunning) {
      return;
    }

    final engine = _state.engine;
    final modelId = _selectedModelIds[engine];
    if (modelId == null) {
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        error: const EngineRuntimeError(
          kind: EngineRuntimeErrorKind.modelRequired,
        ),
      );
      notifyListeners();
      return;
    }

    await _runOrchestrated(() async {
      await _requestNotificationPermissionOnce();
      await _loadEndpoint();
      final adapter = _adapters[engine]!;
      await adapter.prepare();
      return adapter.start(modelId: modelId, onPhase: _emitPhase);
    });
  }

  Future<void> stop() async {
    if (_state.isBusy || !_state.isRunning) {
      return;
    }

    final adapter = _adapters[_state.engine]!;
    _state = _state.copyWith(
      status: EngineRuntimeStatus.stopping,
      phase: RuntimePhase.stoppingServer,
      error: null,
    );
    notifyListeners();

    try {
      await adapter.stop(onPhase: (_) {});
      _state = EngineRuntimeState(
        engine: _state.engine,
        activeModelId: null,
        activeModelName: null,
      );
    } on EngineAdapterException catch (error) {
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(kind: error.kind, detail: error.detail),
      );
    } catch (error) {
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(
          kind: EngineRuntimeErrorKind.serverStopFailed,
          detail: error.toString(),
        ),
      );
    } finally {
      notifyListeners();
    }
  }

  /// Cancels a start/model-swap operation and invalidates its eventual async
  /// result before asking the adapter to release partial resources.
  Future<void> cancel() async {
    if (_state.status != EngineRuntimeStatus.preparing) {
      return;
    }

    final engine = _state.engine;
    _operationEpoch += 1;
    _state = _state.copyWith(
      status: EngineRuntimeStatus.stopping,
      phase: RuntimePhase.stoppingServer,
      error: null,
    );
    notifyListeners();

    try {
      await _adapters[engine]!.cancel(onPhase: (_) {});
      if (_state.engine == engine) {
        _state = EngineRuntimeState(engine: engine);
      }
    } on EngineAdapterException catch (error) {
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(kind: error.kind, detail: error.detail),
      );
    } catch (error) {
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(
          kind: EngineRuntimeErrorKind.serverStopFailed,
          detail: error.toString(),
        ),
      );
    } finally {
      notifyListeners();
    }
  }

  /// Makes [modelId] the serving model for the active engine. Starts the
  /// runtime if it is down; otherwise replaces the running engine's resident
  /// model using the lifecycle its adapter owns.
  Future<void> activateModel(String modelId) async {
    if (_state.isBusy) {
      return;
    }

    await selectModel(modelId);

    if (_state.isRunning && _state.activeModelId == modelId) {
      return;
    }

    if (!_state.isRunning) {
      await start();
      return;
    }

    final adapter = _adapters[_state.engine]!;
    await _runOrchestrated(
      () => adapter.activateModel(modelId, onPhase: _emitPhase),
    );
  }

  Future<void> _runOrchestrated(
    Future<EngineStartResult> Function() operation,
  ) async {
    final operationEpoch = ++_operationEpoch;
    _state = _state.copyWith(
      status: EngineRuntimeStatus.preparing,
      phase: null,
      error: null,
    );
    notifyListeners();

    try {
      final result = await operation();
      if (_disposed || operationEpoch != _operationEpoch) {
        return;
      }
      _host = result.host;
      _port = result.port;
      _scheduleDisplayHostRefresh();
      _state = _state.copyWith(
        status: EngineRuntimeStatus.ready,
        phase: null,
        activeModelId: result.activeModelId,
        activeModelName: result.activeModelName,
        startedAt: _state.startedAt ?? DateTime.now(),
        error: null,
      );
    } on EngineOperationCancelledException {
      if (_disposed || operationEpoch != _operationEpoch) {
        return;
      }
      _state = EngineRuntimeState(engine: _state.engine);
    } on EngineAdapterException catch (error) {
      if (_disposed || operationEpoch != _operationEpoch) {
        return;
      }
      _logger.error(
        '引擎编排失败: ${error.kind.name}',
        channel: LogChannel.server,
        inMemory: true,
        error: error.detail,
      );
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(kind: error.kind, detail: error.detail),
      );
    } catch (error, stackTrace) {
      if (_disposed || operationEpoch != _operationEpoch) {
        return;
      }
      _logger.error(
        '引擎编排异常',
        channel: LogChannel.server,
        inMemory: true,
        error: error,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        status: EngineRuntimeStatus.error,
        phase: null,
        error: EngineRuntimeError(
          kind: EngineRuntimeErrorKind.unknown,
          detail: error.toString(),
        ),
      );
    } finally {
      if (operationEpoch == _operationEpoch) {
        notifyListeners();
      }
    }
  }

  void _emitPhase(RuntimePhase phase) {
    if (_state.status != EngineRuntimeStatus.preparing) {
      return;
    }
    _state = _state.copyWith(phase: phase);
    notifyListeners();
  }

  void _handleExternalRunningChange(InferenceEngine engine, bool running) {
    if (_disposed || engine != _state.engine || _state.isBusy) {
      return;
    }
    if (_state.status == EngineRuntimeStatus.error) {
      // Keep the error visible, but rebuild consumers because engine
      // switching becomes safe as soon as the adapter finishes cleanup.
      notifyListeners();
      return;
    }
    if (running == _state.isRunning) {
      return;
    }
    // The process died on its own (OOM kill, system reclaim). Fall back to
    // idle rather than leaving the UI claiming a live service.
    _state = running
        ? _state.copyWith(
            status: EngineRuntimeStatus.ready,
            startedAt: DateTime.now(),
          )
        : EngineRuntimeState(engine: engine);
    notifyListeners();
  }

  void _scheduleDisplayHostRefresh() {
    if (_host != '0.0.0.0') {
      return;
    }
    _localIpResolver().then((ip) {
      if (_disposed) {
        return;
      }
      if (ip != null && ip != _pendingDisplayHost) {
        _pendingDisplayHost = ip;
        notifyListeners();
      }
    });
  }

  Future<void> _requestNotificationPermissionOnce() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final hasPrompted = await _kvStorage.getBool(
        ServerPrefsKeys.foregroundNotificationPermissionPrompted,
      );
      if (hasPrompted != null) {
        return;
      }

      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission == NotificationPermission.granted) {
        await _kvStorage.setBool(
          ServerPrefsKeys.foregroundNotificationPermissionPrompted,
          true,
        );
        return;
      }

      if (notificationPermission != NotificationPermission.denied) {
        return;
      }

      await _kvStorage.setBool(
        ServerPrefsKeys.foregroundNotificationPermissionPrompted,
        true,
      );
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (_) {
      // Notification permission is best-effort and must not block start.
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
    _operationEpoch += 1;
    for (final subscription in _runningSubscriptions) {
      subscription.cancel();
    }
    for (final adapter in _adapters.values) {
      adapter.dispose();
    }
    super.dispose();
  }
}
