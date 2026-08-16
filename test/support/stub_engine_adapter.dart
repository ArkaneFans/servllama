import 'dart:async';

import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/llama_server_control_client.dart';

/// Stands in for an engine that is not under test. The real MNN adapter opens
/// a platform EventChannel on construction, which no widget test can serve.
class StubEngineAdapter implements InferenceEngineAdapter {
  StubEngineAdapter({this.engine = InferenceEngine.mnn});

  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  final InferenceEngine engine;

  bool _isRunning = false;

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  Future<void> prepare() async {}

  @override
  Future<EngineStartResult> start({
    required String modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    _isRunning = true;
    return EngineStartResult(
      host: '127.0.0.1',
      port: 8080,
      activeModelId: modelId,
      activeModelName: modelId,
    );
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    _isRunning = false;
  }

  @override
  Future<void> cancel({required RuntimePhaseCallback onPhase}) async {
    _isRunning = false;
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    return start(modelId: modelId, onPhase: onPhase);
  }

  @override
  void dispose() {
    _runningStateController.close();
  }
}

/// Answers the adapter's health probe immediately.
class StubServerControlClient implements LlamaServerControlClient {
  StubServerControlClient({this.reachable = true});

  final bool reachable;
  @override
  void updateBaseUrl(String baseUrl) {}

  @override
  Future<bool> waitUntilReady({
    Duration timeout = Duration.zero,
    bool Function()? shouldContinue,
  }) async => reachable && (shouldContinue?.call() ?? true);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
