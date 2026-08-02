import 'dart:async';

import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/llama_server_control_client.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

/// Server-first lifecycle: spawn `llama-server` with `--models-dir`, wait for
/// it to answer, then optionally load a model. Models can be swapped without
/// restarting the process.
class LlamaCppEngineAdapter implements InferenceEngineAdapter {
  LlamaCppEngineAdapter({
    LlamaServerService? serverService,
    ServerLaunchSettingsLoader? settingsLoader,
    ServerLaunchArgsBuilder? launchArgsBuilder,
    ModelStoragePaths? modelStoragePaths,
    LlamaServerControlClient? controlClient,
  }) : _serverService = serverService ?? LlamaServerService(),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _launchArgsBuilder =
           launchArgsBuilder ?? const ServerLaunchArgsBuilder(),
       _modelStoragePaths = modelStoragePaths ?? ModelStoragePaths(),
       _controlClient = controlClient ?? LlamaServerControlClient();

  final LlamaServerService _serverService;
  final ServerLaunchSettingsLoader _settingsLoader;
  final ServerLaunchArgsBuilder _launchArgsBuilder;
  final ModelStoragePaths _modelStoragePaths;
  final LlamaServerControlClient _controlClient;
  bool _cancelRequested = false;

  @override
  InferenceEngine get engine => InferenceEngine.llamaCpp;

  @override
  bool get isRunning => _serverService.isRunning;

  @override
  Stream<bool> get runningStateStream => _serverService.runningStateStream;

  @override
  Future<void> prepare() async {
    _serverService.initForegroundTask();
  }

  @override
  Future<EngineStartResult> start({
    String? modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    try {
      final settings = await _settingsLoader.load();
      final modelsDirectoryPath = await _modelStoragePaths
          .getModelsDirectoryPath();

      onPhase(RuntimePhase.startingServer);
      final started = await _serverService.startServer(
        args: _launchArgsBuilder.build(
          settings,
          modelsDirectoryPath: modelsDirectoryPath,
        ),
      );
      _throwIfCancelled();
      if (!started && !_serverService.isRunning) {
        throw const EngineAdapterException(
          EngineRuntimeErrorKind.serverStartFailed,
        );
      }

      _controlClient.updateBaseUrl('http://127.0.0.1:${settings.port}');

      onPhase(RuntimePhase.verifying);
      final reachable = await _controlClient.waitUntilReachable();
      _throwIfCancelled();
      if (!reachable) {
        throw const EngineAdapterException(
          EngineRuntimeErrorKind.serverStartFailed,
        );
      }

      // Loading a model is optional here (design decision D6): llama-server
      // serves `/models` fine while empty and loads on first use.
      if (modelId != null) {
        onPhase(RuntimePhase.loadingModel);
        final loaded = await _controlClient.loadModel(modelId);
        _throwIfCancelled();
        if (!loaded) {
          throw EngineAdapterException(
            EngineRuntimeErrorKind.modelLoadFailed,
            detail: modelId,
          );
        }
      }

      return EngineStartResult(
        host: settings.host,
        port: settings.port,
        activeModelId: modelId,
        activeModelName: modelId,
      );
    } catch (_) {
      if (_serverService.isRunning) {
        await _serverService.stopServer();
      }
      rethrow;
    }
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    onPhase(RuntimePhase.stoppingServer);
    await _serverService.stopServer();
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    final settings = await _settingsLoader.load();
    _controlClient.updateBaseUrl('http://127.0.0.1:${settings.port}');

    onPhase(RuntimePhase.loadingModel);
    final loaded = await _controlClient.loadModel(modelId);
    _throwIfCancelled();
    if (!loaded) {
      throw EngineAdapterException(
        EngineRuntimeErrorKind.modelLoadFailed,
        detail: modelId,
      );
    }

    return EngineStartResult(
      host: settings.host,
      port: settings.port,
      activeModelId: modelId,
      activeModelName: modelId,
    );
  }

  @override
  Future<void> cancel({required RuntimePhaseCallback onPhase}) async {
    _cancelRequested = true;
    if (_serverService.isRunning) {
      onPhase(RuntimePhase.stoppingServer);
      await _serverService.stopServer();
    }
  }

  void _throwIfCancelled() {
    if (_cancelRequested) {
      throw const EngineOperationCancelledException();
    }
  }

  @override
  void dispose() {}
}
