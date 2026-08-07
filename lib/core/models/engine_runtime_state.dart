import 'package:servllama/core/models/inference_engine.dart';

/// Coarse runtime status the whole app reasons about, regardless of engine.
enum EngineRuntimeStatus { idle, preparing, ready, stopping, error }

/// Steps the orchestrator walks through while bringing a runtime up or
/// swapping its model. The two engines run these in different orders; the
/// orchestrator emits them so the UI can render one progress list either way.
enum RuntimePhase {
  loadingModel,
  checkingPort,
  startingServer,
  verifying,
  unloadingModel,
  stoppingServer,
}

/// Why a runtime operation failed, kept typed so the page layer maps it to
/// localized text (AGENTS.md forbids display strings below the UI layer).
enum EngineRuntimeErrorKind {
  portInUse,
  modelLoadFailed,
  serverStartFailed,
  serverStopFailed,
  modelRequired,
  engineUnavailable,
  unknown,
}

class EngineRuntimeError {
  const EngineRuntimeError({required this.kind, this.detail});

  final EngineRuntimeErrorKind kind;
  final String? detail;
}

class EngineRuntimeState {
  const EngineRuntimeState({
    required this.engine,
    this.status = EngineRuntimeStatus.idle,
    this.phase,
    this.completedPhases = const <RuntimePhase>[],
    this.activeModelId,
    this.activeModelName,
    this.startedAt,
    this.error,
  });

  final InferenceEngine engine;
  final EngineRuntimeStatus status;

  /// Phase currently in flight; null unless [status] is
  /// [EngineRuntimeStatus.preparing].
  final RuntimePhase? phase;

  /// Phases already done in the current operation, in execution order.
  final List<RuntimePhase> completedPhases;

  final String? activeModelId;
  final String? activeModelName;
  final DateTime? startedAt;
  final EngineRuntimeError? error;

  bool get isRunning => status == EngineRuntimeStatus.ready;
  bool get isBusy =>
      status == EngineRuntimeStatus.preparing ||
      status == EngineRuntimeStatus.stopping;

  /// Busy and ready states own runtime resources. An error may be switchable
  /// once the provider confirms the adapter is no longer running.
  bool get canSwitchEngine =>
      status == EngineRuntimeStatus.idle || status == EngineRuntimeStatus.error;

  /// MNN refuses to start without a resident model; llama.cpp does not.
  bool get canStart =>
      status == EngineRuntimeStatus.idle &&
      (!engine.requiresModelBeforeStart || activeModelId != null);

  static const Object _unset = Object();

  EngineRuntimeState copyWith({
    InferenceEngine? engine,
    EngineRuntimeStatus? status,
    Object? phase = _unset,
    List<RuntimePhase>? completedPhases,
    Object? activeModelId = _unset,
    Object? activeModelName = _unset,
    Object? startedAt = _unset,
    Object? error = _unset,
  }) {
    return EngineRuntimeState(
      engine: engine ?? this.engine,
      status: status ?? this.status,
      phase: identical(phase, _unset) ? this.phase : phase as RuntimePhase?,
      completedPhases: completedPhases ?? this.completedPhases,
      activeModelId: identical(activeModelId, _unset)
          ? this.activeModelId
          : activeModelId as String?,
      activeModelName: identical(activeModelName, _unset)
          ? this.activeModelName
          : activeModelName as String?,
      startedAt: identical(startedAt, _unset)
          ? this.startedAt
          : startedAt as DateTime?,
      error: identical(error, _unset)
          ? this.error
          : error as EngineRuntimeError?,
    );
  }
}
