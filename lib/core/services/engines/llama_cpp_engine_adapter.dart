import 'dart:async';

import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/repositories/local_model_repository.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/llama_server_control_client.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

/// Runs one model-specific `llama-server` process. Since Android builds do not
/// support llama.cpp's subprocess router, changing models means replacing the
/// process with one launched using the new model path.
class LlamaCppEngineAdapter implements InferenceEngineAdapter {
  LlamaCppEngineAdapter({
    LlamaServerProcessService? serverService,
    ServerLaunchSettingsLoader? settingsLoader,
    ServerLaunchArgsBuilder? launchArgsBuilder,
    LocalModelRepository? modelRepository,
    LlamaServerControlClient? controlClient,
  }) : _serverService = serverService ?? LlamaServerService(),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _launchArgsBuilder =
           launchArgsBuilder ?? const ServerLaunchArgsBuilder(),
       _modelRepository = modelRepository ?? LocalModelRepository(),
       _controlClient = controlClient ?? LlamaServerControlClient();

  final LlamaServerProcessService _serverService;
  final ServerLaunchSettingsLoader _settingsLoader;
  final ServerLaunchArgsBuilder _launchArgsBuilder;
  final LocalModelRepository _modelRepository;
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
    required String modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    return _startInternal(modelId: modelId, onPhase: onPhase);
  }

  Future<EngineStartResult> _startInternal({
    required String modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    try {
      await prepare();
      final model = await _findModel(modelId);
      _throwIfCancelled();
      final settings = await _settingsLoader.load();
      _throwIfCancelled();

      onPhase(RuntimePhase.startingServer);
      final started = await _serverService.startServer(
        args: _launchArgsBuilder.build(
          settings,
          modelPath: model.storedFilePath,
          modelAlias: model.modelName,
          mmprojPath: model.mmprojFilePath,
        ),
      );
      _throwIfCancelled();
      if (!started) {
        throw const EngineAdapterException(
          EngineRuntimeErrorKind.serverStartFailed,
        );
      }

      _controlClient.updateBaseUrl('http://127.0.0.1:${settings.port}');

      onPhase(RuntimePhase.loadingModel);
      final ready = await _controlClient.waitUntilReady(
        shouldContinue: () => !_cancelRequested && _serverService.isRunning,
      );
      _throwIfCancelled();
      if (!ready) {
        throw EngineAdapterException(
          _serverService.isRunning
              ? EngineRuntimeErrorKind.modelLoadFailed
              : EngineRuntimeErrorKind.serverStartFailed,
          detail: modelId,
        );
      }

      return EngineStartResult(
        host: settings.host,
        port: settings.port,
        activeModelId: modelId,
        activeModelName: model.modelName,
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
    if (!_serverService.isRunning) {
      return;
    }
    onPhase(RuntimePhase.stoppingServer);
    final stopped = await _serverService.stopServer();
    if (!stopped) {
      throw const EngineAdapterException(
        EngineRuntimeErrorKind.serverStopFailed,
      );
    }
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    if (_serverService.isRunning) {
      onPhase(RuntimePhase.stoppingServer);
      final stopped = await _serverService.stopServer();
      if (!stopped) {
        throw const EngineAdapterException(
          EngineRuntimeErrorKind.serverStopFailed,
        );
      }
      _throwIfCancelled();
    }
    return _startInternal(modelId: modelId, onPhase: onPhase);
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

  Future<ModelDescriptor> _findModel(String modelId) async {
    for (final model in await _modelRepository.listModels()) {
      if (model.modelName == modelId) {
        return model;
      }
    }
    throw EngineAdapterException(
      EngineRuntimeErrorKind.modelLoadFailed,
      detail: modelId,
    );
  }

  @override
  void dispose() {}
}
