import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EngineRuntimeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'flutter.server.foreground_notification_permission_prompted': true,
      });
    });

    test(
      'model selection enables start and reaches ready with active model',
      () async {
        final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
        final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
        final provider = _provider(llama: llama, mnn: mnn);
        addTearDown(provider.dispose);

        await provider.switchEngine(InferenceEngine.mnn);
        expect(provider.canStart, isFalse);

        await provider.selectModel('mnn-model');
        expect(provider.canStart, isTrue);

        await provider.start();

        expect(provider.status, EngineRuntimeStatus.ready);
        expect(provider.activeModelId, 'mnn-model');
        expect(provider.activeModelName, 'MNN model');
        expect(mnn.startCount, 1);
      },
    );

    for (final publish in [false, true]) {
      test(
        'immediate same and cross engine restarts (publish=$publish)',
        () async {
          final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
          final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
          final provider = _provider(llama: llama, mnn: mnn);
          addTearDown(provider.dispose);
          final engines = [
            InferenceEngine.llamaCpp,
            InferenceEngine.llamaCpp,
            InferenceEngine.mnn,
            InferenceEngine.mnn,
            InferenceEngine.llamaCpp,
          ];
          for (var i = 0; i < engines.length; i++) {
            await provider.switchEngine(engines[i]);
            await provider.selectModel('model-$i');
            await provider.start(publish: publish);
            expect(provider.isRunning, isTrue);
            expect(provider.activeEngine, engines[i]);
            expect(provider.activeModelId, 'model-$i');
            expect(provider.isPublished, publish);
            await provider.stop();
            expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
            expect(provider.canSwitchEngine, isTrue);
            expect(provider.lastError, isNull);
          }
          expect(llama.startCount, 3);
          expect(mnn.startCount, 2);
        },
      );
    }

    test('cancel retains the lease until the pending start settles', () async {
      final startBlocker = Completer<void>();
      final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
      final mnn = _FakeEngineAdapter(
        InferenceEngine.mnn,
        startBlocker: startBlocker,
      );
      final provider = _provider(llama: llama, mnn: mnn);
      addTearDown(provider.dispose);

      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      final startFuture = provider.start();
      await Future<void>.delayed(Duration.zero);

      expect(provider.status, EngineRuntimeStatus.preparing);
      final cancellation = provider.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, EngineRuntimeStatus.stopping);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
      expect(provider.canStart, isFalse);
      expect(provider.canSwitchEngine, isFalse);
      expect(mnn.cancelCount, 1);
      await provider.start();
      expect(mnn.startCount, 1);

      startBlocker.complete();
      await startFuture;
      await cancellation;
      expect(provider.status, EngineRuntimeStatus.idle);
      expect(provider.activeModelId, isNull);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
      expect(mnn.hasResources, isFalse);
    });

    for (final stage in ['settings', 'prepare']) {
      test('cancel during $stage prevents a late adapter start', () async {
        final blocker = Completer<void>();
        final mnn = _FakeEngineAdapter(
          InferenceEngine.mnn,
          prepareBlocker: stage == 'prepare' ? blocker : null,
        );
        final provider = _provider(
          llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
          mnn: mnn,
          settingsLoader: _FixedSettingsLoader(
            loadBlocker: stage == 'settings' ? blocker : null,
          ),
        );
        addTearDown(provider.dispose);
        await provider.switchEngine(InferenceEngine.mnn);
        await provider.selectModel('mnn-model');
        final starting = provider.startPrivate();
        await Future<void>.delayed(Duration.zero);
        final cancellation = provider.cancel();
        await Future<void>.delayed(Duration.zero);

        expect(provider.status, EngineRuntimeStatus.stopping);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
        expect(mnn.startCount, 0);
        blocker.complete();
        await starting;
        await cancellation;
        expect(mnn.startCount, 0);
        expect(mnn.prepareCount, stage == 'settings' ? 0 : 1);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);

        await provider.startPrivate();
        expect(mnn.startCount, 1);
        expect(provider.status, EngineRuntimeStatus.ready);
      });
    }

    test('synchronous preparing listener can cancel before startup', () async {
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: mnn,
      );
      addTearDown(provider.dispose);
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      Future<void>? cancellation;
      provider.addListener(() {
        if (provider.status == EngineRuntimeStatus.preparing) {
          cancellation = provider.cancel();
        }
      });

      await provider.startPrivate();
      expect(cancellation, isNotNull);
      await cancellation;
      expect(mnn.startCount, 0);
      expect(provider.status, EngineRuntimeStatus.idle);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
    });

    test('failed cancellation still waits for startup before retry', () async {
      final blocker = Completer<void>();
      final mnn = _FakeEngineAdapter(
        InferenceEngine.mnn,
        startBlocker: blocker,
        cancelError: const EngineAdapterException(
          EngineRuntimeErrorKind.serverStopFailed,
        ),
      );
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: mnn,
      );
      addTearDown(provider.dispose);
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      final starting = provider.startPrivate();
      await Future<void>.delayed(Duration.zero);
      mnn.resident = true;
      final cancellation = provider.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, EngineRuntimeStatus.stopping);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);

      blocker.complete();
      await starting;
      await cancellation;
      expect(provider.status, EngineRuntimeStatus.error);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
      expect(provider.canStop, isTrue);
      expect(provider.canStart, isFalse);
      await provider.stop();
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
    });

    test('cancel waits for a pending private model replacement', () async {
      final blocker = Completer<void>();
      final mnn = _FakeEngineAdapter(
        InferenceEngine.mnn,
        activateBlocker: blocker,
      );
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: mnn,
      );
      addTearDown(provider.dispose);
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      await provider.startPrivate();
      final changing = provider.activateModel('replacement');
      await Future<void>.delayed(Duration.zero);
      final cancellation = provider.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(mnn.activateCount, 1);
      expect(provider.status, EngineRuntimeStatus.stopping);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);

      blocker.complete();
      await changing;
      await cancellation;
      expect(provider.status, EngineRuntimeStatus.idle);
      expect(provider.activeModelId, isNull);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
    });

    test('activating the resident model is idempotent', () async {
      final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(llama: llama, mnn: mnn);
      addTearDown(provider.dispose);

      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      await provider.start();
      await provider.activateModel('mnn-model');

      expect(mnn.activateCount, 0);
      expect(mnn.startCount, 1);
    });

    test(
      'a stopped listener retains the LLM lease until model unloading finishes',
      () async {
        final unload = Completer<void>();
        final mnn = _FakeEngineAdapter(
          InferenceEngine.mnn,
          stopBlocker: unload,
        );
        final provider = _provider(
          llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
          mnn: mnn,
        );
        addTearDown(provider.dispose);
        await provider.switchEngine(InferenceEngine.mnn);
        await provider.selectModel('mnn-model');
        await provider.startPrivate();

        final stopping = provider.stop();
        await Future<void>.delayed(Duration.zero);
        expect(mnn.isRunning, isFalse);
        expect(provider.status, EngineRuntimeStatus.stopping);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
        final speech = provider.resources.tryAcquire(
          kind: LocalResourceKind.tts,
          assetId: 'voice',
          owner: 'speech',
        );
        expect(speech, isNotNull);
        expect(provider.canSwitchEngine, isFalse);

        unload.complete();
        await stopping;
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
        expect(provider.status, EngineRuntimeStatus.idle);
        expect(
          provider.resources.leaseFor(LocalResourceDomain.speech),
          same(speech),
        );
      },
    );

    test(
      'failed unloading retains residency and the stop action retries cleanup',
      () async {
        final mnn = _FakeEngineAdapter(
          InferenceEngine.mnn,
          stopListenerBeforeFailure: true,
          stopError: const EngineAdapterException(
            EngineRuntimeErrorKind.serverStopFailed,
          ),
        );
        final provider = _provider(
          llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
          mnn: mnn,
        );
        addTearDown(provider.dispose);
        await provider.switchEngine(InferenceEngine.mnn);
        await provider.selectModel('mnn-model');
        await provider.startPrivate();
        await provider.stop();

        expect(mnn.isRunning, isFalse);
        expect(provider.status, EngineRuntimeStatus.error);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
        expect(provider.canStart, isFalse);
        expect(provider.canSwitchEngine, isFalse);
        expect(provider.canStop, isTrue);
        await provider.startPrivate();
        expect(mnn.startCount, 1);

        mnn.stopError = null;
        await provider.toggle();
        expect(provider.status, EngineRuntimeStatus.idle);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
        expect(mnn.startCount, 1);
      },
    );

    test(
      'restore adopts a resident model even when its HTTP listener is stopped',
      () async {
        final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
        final provider = _provider(
          llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
          mnn: mnn,
        );
        addTearDown(provider.dispose);
        await provider.switchEngine(InferenceEngine.mnn);
        await provider.selectModel('mnn-model');
        mnn.resident = true;
        await provider.restore();
        expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
        expect(provider.canStop, isTrue);
        expect(provider.canStart, isFalse);
        await provider.stop();
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
      },
    );

    test('published residency remains owned after a failed stop', () async {
      final mnn = _FakeEngineAdapter(
        InferenceEngine.mnn,
        stopListenerBeforeFailure: true,
        stopError: const EngineAdapterException(
          EngineRuntimeErrorKind.serverStopFailed,
        ),
      );
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: mnn,
      );
      addTearDown(provider.dispose);
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      await provider.start();
      await provider.stop();
      expect(provider.isPublished, isTrue);
      expect(provider.resources.leaseFor(LocalResourceDomain.llm), isNotNull);
      mnn.stopError = null;
      await provider.stop();
      expect(provider.isPublished, isFalse);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
    });

    for (final publish in [false, true]) {
      test(
        'LLM start and stop preserve active speech (publish=$publish)',
        () async {
          final provider = _provider(
            llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
            mnn: _FakeEngineAdapter(InferenceEngine.mnn),
          );
          addTearDown(provider.dispose);
          final speech = provider.resources.tryAcquire(
            kind: LocalResourceKind.asr,
            assetId: 'transcriber',
            owner: 'speech',
          );
          await provider.selectModel('llm');
          await provider.start(publish: publish);
          expect(provider.status, EngineRuntimeStatus.ready);
          expect(provider.isPublished, publish);
          expect(
            provider.resources.leaseFor(LocalResourceDomain.speech),
            same(speech),
          );

          await provider.stop();
          expect(provider.status, EngineRuntimeStatus.idle);
          expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
          expect(
            provider.resources.leaseFor(LocalResourceDomain.speech),
            same(speech),
          );
        },
      );
    }

    test('moves the saved model selection after a rename', () async {
      final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(llama: llama, mnn: mnn);
      addTearDown(provider.dispose);

      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('before');
      await provider.handleModelRenamed(
        engine: InferenceEngine.mnn,
        oldModelId: 'before',
        newModelId: 'after',
      );

      expect(provider.selectedModelId, 'after');
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('engine.mnn.selected_model'), 'after');
    });

    test('allows switching engines after startup failure cleanup', () async {
      final llama = _FakeEngineAdapter(
        InferenceEngine.llamaCpp,
        startError: const EngineAdapterException(
          EngineRuntimeErrorKind.serverStartFailed,
        ),
      );
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(llama: llama, mnn: mnn);
      addTearDown(provider.dispose);

      await provider.selectModel('test-model');
      await provider.start();

      expect(provider.status, EngineRuntimeStatus.error);
      expect(provider.canSwitchEngine, isTrue);

      await provider.switchEngine(InferenceEngine.mnn);

      expect(provider.activeEngine, InferenceEngine.mnn);
      expect(provider.status, EngineRuntimeStatus.idle);
    });

    test(
      'blocks switching while an errored adapter is still running',
      () async {
        final llama = _FakeEngineAdapter(
          InferenceEngine.llamaCpp,
          stopError: const EngineAdapterException(
            EngineRuntimeErrorKind.serverStopFailed,
          ),
        );
        final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
        final provider = _provider(llama: llama, mnn: mnn);
        addTearDown(provider.dispose);

        await provider.selectModel('test-model');
        await provider.start();
        await provider.stop();

        expect(provider.status, EngineRuntimeStatus.error);
        expect(llama.isRunning, isTrue);
        expect(provider.canSwitchEngine, isFalse);

        await provider.switchEngine(InferenceEngine.mnn);
        expect(provider.activeEngine, InferenceEngine.llamaCpp);

        llama.emitRunning(false);
        await Future<void>.delayed(Duration.zero);

        expect(provider.canSwitchEngine, isTrue);
        await provider.switchEngine(InferenceEngine.mnn);
        expect(provider.activeEngine, InferenceEngine.mnn);
      },
    );
  });
}

EngineRuntimeProvider _provider({
  required _FakeEngineAdapter llama,
  required _FakeEngineAdapter mnn,
  ServerLaunchSettingsLoader? settingsLoader,
}) {
  return EngineRuntimeProvider(
    llamaCppAdapter: llama,
    mnnAdapter: mnn,
    settingsLoader: settingsLoader ?? _FixedSettingsLoader(),
    localIpResolver: () async => null,
  );
}

class _FixedSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedSettingsLoader({this.loadBlocker});

  final Completer<void>? loadBlocker;

  @override
  Future<ServerLaunchSettings> load() async {
    await loadBlocker?.future;
    return const ServerLaunchSettings();
  }
}

class _FakeEngineAdapter implements InferenceEngineAdapter {
  _FakeEngineAdapter(
    this.engine, {
    this.startBlocker,
    this.prepareBlocker,
    this.activateBlocker,
    this.startError,
    this.cancelError,
    this.stopError,
    this.stopBlocker,
    this.stopListenerBeforeFailure = false,
  });

  @override
  final InferenceEngine engine;
  final Completer<void>? startBlocker;
  final Completer<void>? prepareBlocker;
  final Completer<void>? activateBlocker;
  final EngineAdapterException? startError;
  final EngineAdapterException? cancelError;
  EngineAdapterException? stopError;
  final Completer<void>? stopBlocker;
  final bool stopListenerBeforeFailure;
  final StreamController<bool> _running = StreamController<bool>.broadcast();

  bool _isRunning = false;
  bool _cancelRequested = false;
  bool resident = false;
  int prepareCount = 0;
  int startCount = 0;
  int activateCount = 0;
  int cancelCount = 0;

  @override
  bool get isRunning => _isRunning;

  @override
  bool get hasResources => _isRunning || resident;

  @override
  Stream<bool> get runningStateStream => _running.stream;

  @override
  Future<void> prepare() async {
    prepareCount += 1;
    await prepareBlocker?.future;
  }

  @override
  Future<EngineStartResult> start({
    required String modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    startCount += 1;
    onPhase(RuntimePhase.loadingModel);
    await startBlocker?.future;
    if (_cancelRequested) throw const EngineOperationCancelledException();
    if (startError != null) {
      throw startError!;
    }
    _isRunning = true;
    resident = true;
    return EngineStartResult(
      host: '127.0.0.1',
      port: 8080,
      activeModelId: modelId,
      activeModelName: engine == InferenceEngine.mnn ? 'MNN model' : modelId,
    );
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    if (stopBlocker != null || stopListenerBeforeFailure) {
      _isRunning = false;
      _running.add(false);
      await stopBlocker?.future;
    }
    if (stopError != null) {
      throw stopError!;
    }
    _isRunning = false;
    resident = false;
  }

  void emitRunning(bool value) {
    _isRunning = value;
    resident = value;
    _running.add(value);
  }

  @override
  Future<void> cancel({required RuntimePhaseCallback onPhase}) async {
    cancelCount += 1;
    _cancelRequested = true;
    if (cancelError != null) throw cancelError!;
    _isRunning = false;
    resident = false;
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    activateCount += 1;
    onPhase(RuntimePhase.unloadingModel);
    await activateBlocker?.future;
    if (_cancelRequested) throw const EngineOperationCancelledException();
    return EngineStartResult(
      host: '127.0.0.1',
      port: 8080,
      activeModelId: modelId,
      activeModelName: modelId,
    );
  }

  @override
  void dispose() {
    _running.close();
  }
}
