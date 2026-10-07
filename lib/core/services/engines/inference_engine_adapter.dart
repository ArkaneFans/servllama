import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';

typedef RuntimePhaseCallback = void Function(RuntimePhase phase);

/// Thrown by adapters so the orchestrator can attach a typed reason to the
/// runtime state without knowing which engine produced it.
class EngineAdapterException implements Exception {
  const EngineAdapterException(this.kind, {this.detail});

  final EngineRuntimeErrorKind kind;
  final String? detail;

  @override
  String toString() => detail ?? kind.name;
}

/// Internal control-flow signal used when the user cancels an in-flight
/// orchestration. It is intentionally not exposed as a runtime error because
/// cancellation returns the UI to the normal idle state.
class EngineOperationCancelledException implements Exception {
  const EngineOperationCancelledException();
}

/// Result of a successful bring-up. The port is what the adapter actually
/// bound, which the orchestrator publishes as the app-wide base URL.
class EngineStartResult {
  const EngineStartResult({
    required this.host,
    required this.port,
    this.activeModelId,
    this.activeModelName,
  });

  final String host;
  final int port;
  final String? activeModelId;
  final String? activeModelName;
}

/// Hides the engine-specific process and model-loading details behind one
/// model-first lifecycle. Each adapter reports its current phase through
/// [RuntimePhaseCallback] so the UI can show one concise status component.
abstract class InferenceEngineAdapter {
  InferenceEngine get engine;

  /// True when this engine's server process/service is currently serving.
  bool get isRunning;

  /// Includes a resident/loading model or cleanup that has not been confirmed.
  /// A stopped HTTP listener does not imply that native resources are released.
  bool get hasResources;

  /// Emits on serving or residency changes, including changes outside an
  /// orchestrated call (process crash, service killed by the system).
  /// The bool describes serving; consult [hasResources] before releasing a lease.
  Stream<bool> get runningStateStream;

  /// One-time initialization. Safe to call repeatedly.
  Future<void> prepare();

  Future<EngineStartResult> start({
    required String modelId,
    required RuntimePhaseCallback onPhase,
  });

  Future<void> stop({required RuntimePhaseCallback onPhase});

  /// Cancels an in-flight start/model-swap and releases any partially acquired
  /// resources. Safe to call even if the operation has not reached the server
  /// start phase yet.
  Future<void> cancel({required RuntimePhaseCallback onPhase});

  /// Switches the active model within this engine while it is running.
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  });

  void dispose();
}
