import 'dart:async';

import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

/// Model-first lifecycle: MNN has to have a model resident before its Ktor
/// server can bind, and it cannot swap models while serving. Swapping
/// therefore means stop → unload → load → start. The native start call owns
/// the bind operation; there is no separate, race-prone port preflight.
class MnnEngineAdapter implements InferenceEngineAdapter {
  MnnEngineAdapter({
    MnnEngine? mnnEngine,
    ServerLaunchSettingsLoader? settingsLoader,
    AppLogger? logger,
  }) : _engine = mnnEngine ?? MnnEngine.instance,
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _logger = logger ?? AppLogger.instance {
    _eventSubscription = _engine.events.listen((event) {
      final running = event.snapshot.serverState == 'running';
      _activeModel = event.snapshot.activeModel;
      if (running != _lastRunningState) {
        _lastRunningState = running;
        _runningStateController.add(running);
      }
    });
    _logSubscription = _engine.logs.listen(_recordLog);
  }

  final MnnEngine _engine;
  final ServerLaunchSettingsLoader _settingsLoader;
  final AppLogger _logger;
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  StreamSubscription<MnnRuntimeEvent>? _eventSubscription;
  StreamSubscription<MnnLogEntry>? _logSubscription;
  bool _initialized = false;
  bool _lastRunningState = false;
  bool _cancelRequested = false;
  bool _logsEnabled = true;
  ServerLogLevel _minimumLogLevel = ServerLogLevel.info;
  int _lastLogSequence = -1;
  MnnModelInfo? _activeModel;

  @override
  InferenceEngine get engine => InferenceEngine.mnn;

  @override
  bool get isRunning => _lastRunningState;

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  Future<void> prepare() async {
    if (_initialized) {
      return;
    }
    try {
      final settings = await _settingsLoader.load();
      _logsEnabled = settings.logEnabled;
      _minimumLogLevel = settings.logLevel;
      await _engine.initialize();
      for (final entry in await _engine.getLogSnapshot()) {
        _recordLog(entry);
      }
      final snapshot = await _engine.getSnapshot();
      _lastRunningState = snapshot.serverState == 'running';
      _activeModel = snapshot.activeModel;
      _initialized = true;
    } on MnnEngineException catch (error) {
      throw EngineAdapterException(
        EngineRuntimeErrorKind.engineUnavailable,
        detail: error.message,
      );
    }
  }

  @override
  Future<EngineStartResult> start({
    String? modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    return _startInternal(modelId: modelId, onPhase: onPhase);
  }

  Future<EngineStartResult> _startInternal({
    required String? modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    await prepare();
    if (modelId == null) {
      throw const EngineAdapterException(EngineRuntimeErrorKind.modelRequired);
    }

    final settings = await _settingsLoader.load();
    _logsEnabled = settings.logEnabled;
    _minimumLogLevel = settings.logLevel;
    final bindMode = settings.host == '0.0.0.0'
        ? MnnServerBindMode.allInterfaces
        : MnnServerBindMode.loopback;

    try {
      onPhase(RuntimePhase.loadingModel);
      final model = await _loadModel(modelId);
      _throwIfCancelled();

      onPhase(RuntimePhase.startingServer);
      final MnnServerInfo server;
      try {
        server = await _engine.startServer(
          bindMode: bindMode,
          port: settings.port,
          apiKey: settings.apiKey.trim().isEmpty
              ? null
              : settings.apiKey.trim(),
        );
      } on MnnEngineException catch (error) {
        throw EngineAdapterException(
          _serverStartErrorKind(error),
          detail: error.message,
        );
      }
      _throwIfCancelled();
      _lastRunningState = true;

      return EngineStartResult(
        host: server.host,
        port: server.port,
        activeModelId: model.modelId,
        activeModelName: model.displayName,
      );
    } catch (_) {
      await _releaseRuntime();
      rethrow;
    }
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    onPhase(RuntimePhase.stoppingServer);
    try {
      await _engine.stopServer();
    } on MnnEngineException catch (error) {
      throw EngineAdapterException(
        EngineRuntimeErrorKind.serverStopFailed,
        detail: error.message,
      );
    }
    _lastRunningState = false;
    onPhase(RuntimePhase.unloadingModel);
    try {
      await _engine.unloadModel();
    } on MnnEngineException catch (error) {
      throw EngineAdapterException(
        EngineRuntimeErrorKind.serverStopFailed,
        detail: error.message,
      );
    }
    _activeModel = null;
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    // MNN cannot hot-swap: the server has to come down before the resident
    // model can be released.
    if (_lastRunningState) {
      onPhase(RuntimePhase.stoppingServer);
      await _engine.stopServer();
      _lastRunningState = false;
    }

    onPhase(RuntimePhase.unloadingModel);
    try {
      await _engine.unloadModel();
    } on MnnEngineException catch (_) {
      // Nothing resident is not an error for a swap.
    }
    _activeModel = null;

    return _startInternal(modelId: modelId, onPhase: onPhase);
  }

  @override
  Future<void> cancel({required RuntimePhaseCallback onPhase}) async {
    _cancelRequested = true;
    try {
      await _engine.cancelGeneration();
    } on MnnEngineException catch (_) {}
    await _releaseRuntime(onPhase: onPhase);
  }

  EngineRuntimeErrorKind _serverStartErrorKind(MnnEngineException error) {
    switch (error.code) {
      case 'port_in_use':
        return EngineRuntimeErrorKind.portInUse;
      default:
        return EngineRuntimeErrorKind.serverStartFailed;
    }
  }

  Future<void> _releaseRuntime({RuntimePhaseCallback? onPhase}) async {
    try {
      onPhase?.call(RuntimePhase.stoppingServer);
      await _engine.stopServer();
    } on MnnEngineException catch (_) {
    } finally {
      _lastRunningState = false;
    }
    try {
      onPhase?.call(RuntimePhase.unloadingModel);
      await _engine.unloadModel();
    } on MnnEngineException catch (_) {
    } finally {
      _activeModel = null;
    }
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const EngineOperationCancelledException();
    }
  }

  void _recordLog(MnnLogEntry entry) {
    if (!_logsEnabled || entry.sequence <= _lastLogSequence) {
      return;
    }
    _lastLogSequence = entry.sequence;
    final level = entry.level.toLowerCase();
    if (!_allowsLogLevel(level)) {
      return;
    }
    final message = '[MNN][${entry.tag}] ${entry.message}';
    switch (level) {
      case 'debug':
      case 'verbose':
        _logger.debug(message, channel: LogChannel.engine, inMemory: true);
        return;
      case 'warn':
      case 'warning':
        _logger.warning(message, channel: LogChannel.engine, inMemory: true);
        return;
      case 'error':
      case 'fatal':
        _logger.error(message, channel: LogChannel.engine, inMemory: true);
        return;
      default:
        _logger.info(message, channel: LogChannel.engine, inMemory: true);
        return;
    }
  }

  bool _allowsLogLevel(String level) {
    final value = switch (level) {
      'error' || 'fatal' => 0,
      'warn' || 'warning' => 1,
      'info' => 2,
      _ => 3,
    };
    final threshold = switch (_minimumLogLevel) {
      ServerLogLevel.error => 0,
      ServerLogLevel.warning => 1,
      ServerLogLevel.info => 2,
      ServerLogLevel.debug => 3,
    };
    return value <= threshold;
  }

  Future<MnnModelInfo> _loadModel(String modelId) async {
    final current = _activeModel;
    if (current != null && current.modelId == modelId) {
      return current;
    }
    try {
      final model = await _engine.loadModel(modelId);
      _activeModel = model;
      return model;
    } on MnnEngineException catch (error) {
      throw EngineAdapterException(
        EngineRuntimeErrorKind.modelLoadFailed,
        detail: error.message,
      );
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _logSubscription?.cancel();
    _logSubscription = null;
    _runningStateController.close();
  }
}
