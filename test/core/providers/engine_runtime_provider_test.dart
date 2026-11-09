import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/storage/kv_storage.dart';
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

    for (final resident in [false, true]) {
      test(
        'early start joins restoration and respects ownership (resident=$resident)',
        () async {
          SharedPreferences.setMockInitialValues({
            'engine.active': 'mnn',
            'engine.mnn.selected_model': 'saved-model',
          });
          final blocker = Completer<void>();
          final mnn = _FakeEngineAdapter(
            InferenceEngine.mnn,
            prepareBlocker: blocker,
          )..resident = resident;
          final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
          final provider = _provider(llama: llama, mnn: mnn);
          addTearDown(provider.dispose);
          final restored = provider.ensureRestored();
          expect(identical(restored, provider.ensureRestored()), isTrue);
          final starting = provider.start();
          await Future<void>.delayed(Duration.zero);
          expect(mnn.startCount, 0);
          expect(llama.startCount, 0);
          blocker.complete();
          await Future.wait([restored, starting]);
          expect(provider.activeEngine, InferenceEngine.mnn);
          expect(provider.selectedModelId, 'saved-model');
          expect(mnn.startCount, resident ? 0 : 1);
          expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
          await provider.stop();
          expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
        },
      );
    }

    test(
      'same and cross engine model switches share the configured startup',
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
          await provider.activateModel('model-$i', engine: engines[i]);
          expect(provider.isRunning, isTrue);
          expect(provider.activeEngine, engines[i]);
          expect(provider.activeModelId, 'model-$i');
          expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
          expect(provider.lastError, isNull);
        }
        expect(llama.startCount, 3);
        expect(mnn.startCount, 2);
        expect(llama.stopCount, 2);
        expect(mnn.stopCount, 2);
        await provider.stop();
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
      },
    );

    for (final engine in InferenceEngine.values) {
      test(
        'server and model-picker starts use saved settings (${engine.name})',
        () async {
          final settingsLoader = _FixedSettingsLoader()
            ..settings = const ServerLaunchSettings(
              listenMode: ServerListenMode.allInterfaces,
              port: 9091,
              apiKey: 'configured-key',
              contextSize: 8192,
              mnnThreadNum: 6,
            );
          final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
          final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
          final adapter = engine == InferenceEngine.mnn ? mnn : llama;
          final provider = _provider(
            llama: llama,
            mnn: mnn,
            settingsLoader: settingsLoader,
          );
          addTearDown(provider.dispose);
          await provider.switchEngine(engine);
          await provider.selectModel('first');
          await provider.toggle();
          expect(adapter.startSettings, same(settingsLoader.settings));
          expect(provider.host, '0.0.0.0');
          expect(provider.port, 9091);
          expect(provider.apiKey, 'configured-key');

          settingsLoader.settings = settingsLoader.settings.copyWith(
            port: 9092,
            apiKey: 'changed-key',
          );
          await provider.activateModel('first', engine: engine);
          expect(adapter.startCount, 1);
          expect(provider.apiKey, 'configured-key');
          await provider.activateModel('second', engine: engine);
          expect(adapter.startCount, 2);
          expect(adapter.stopCount, 1);
          expect(adapter.startSettings, same(settingsLoader.settings));
          expect(provider.host, '0.0.0.0');
          expect(provider.port, 9092);
          expect(provider.apiKey, 'changed-key');
        },
      );
    }

    test('concurrent model choices cannot start two engines', () async {
      final llama = _FakeEngineAdapter(InferenceEngine.llamaCpp);
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(llama: llama, mnn: mnn);
      addTearDown(provider.dispose);
      await provider.ensureRestored();
      await Future.wait([
        provider.activateModel('first', engine: InferenceEngine.mnn),
        provider.activateModel('second', engine: InferenceEngine.llamaCpp),
      ]);
      expect(provider.activeEngine, InferenceEngine.mnn);
      expect(provider.activeModelId, 'first');
      expect(mnn.startCount, 1);
      expect(llama.startCount, 0);
      expect(provider.isBusy, isFalse);
    });

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

    test('cancel waits for a pending model replacement', () async {
      final blocker = Completer<void>();
      final mnn = _FakeEngineAdapter(InferenceEngine.mnn);
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: mnn,
      );
      addTearDown(provider.dispose);
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('mnn-model');
      await provider.start();
      mnn.startBlocker = blocker;
      final changing = provider.activateModel('replacement');
      await Future<void>.delayed(Duration.zero);
      final cancellation = provider.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(mnn.startCount, 2);
      expect(mnn.stopCount, 1);
      expect(provider.status, EngineRuntimeStatus.stopping);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);

      blocker.complete();
      await changing;
      await cancellation;
      expect(provider.status, EngineRuntimeStatus.idle);
      expect(provider.activeModelId, isNull);
      expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
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
        await provider.start();

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
        await provider.start();
        await provider.stop();

        expect(mnn.isRunning, isFalse);
        expect(provider.status, EngineRuntimeStatus.error);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isFalse);
        expect(provider.canStart, isFalse);
        expect(provider.canSwitchEngine, isFalse);
        expect(provider.canStop, isTrue);
        await provider.start();
        expect(mnn.startCount, 1);

        mnn.stopError = null;
        await provider.toggle();
        expect(provider.status, EngineRuntimeStatus.idle);
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
        expect(mnn.startCount, 1);
      },
    );

    test(
      'failed stop keeps ownership and prevents model replacement',
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
        await provider.start();
        await provider.activateModel(
          'another-model',
          engine: InferenceEngine.llamaCpp,
        );
        expect(provider.activeEngine, InferenceEngine.mnn);
        expect(mnn.startCount, 1);
        expect(
          provider.lastError?.kind,
          EngineRuntimeErrorKind.serverStopFailed,
        );
        expect(provider.resources.leaseFor(LocalResourceDomain.llm), isNotNull);
        mnn.stopError = null;
        await provider.stop();
        expect(provider.resources.isFree(LocalResourceDomain.llm), isTrue);
      },
    );

    test('LLM start, model switch and stop preserve active speech', () async {
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
      await provider.start();
      expect(provider.status, EngineRuntimeStatus.ready);
      await provider.activateModel('other-llm', engine: InferenceEngine.mnn);
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
    });

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

    test('deletion clears only the matching saved engine selection', () async {
      final provider = _provider(
        llama: _FakeEngineAdapter(InferenceEngine.llamaCpp),
        mnn: _FakeEngineAdapter(InferenceEngine.mnn),
      );
      addTearDown(provider.dispose);
      await provider.selectModel('GGUF');
      await provider.switchEngine(InferenceEngine.mnn);
      await provider.selectModel('MNN');
      await provider.handleModelDeleted(
        engine: InferenceEngine.mnn,
        modelId: 'other',
      );
      expect(provider.selectedModelId, 'MNN');
      await provider.handleModelDeleted(
        engine: InferenceEngine.llamaCpp,
        modelId: 'GGUF',
      );
      expect(provider.selectedModelId, 'MNN');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('engine.llama_cpp.selected_model'), isNull);
      expect(prefs.getString('engine.mnn.selected_model'), 'MNN');
      await provider.handleModelDeleted(
        engine: InferenceEngine.mnn,
        modelId: 'MNN',
      );
      expect(provider.selectedModelId, isNull);
      expect(prefs.getString('engine.mnn.selected_model'), isNull);
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
  });
}

EngineRuntimeProvider _provider({
  required _FakeEngineAdapter llama,
  required _FakeEngineAdapter mnn,
  ServerLaunchSettingsLoader? settingsLoader,
}) {
  return EngineRuntimeProvider(
    kvStorage: KvStorage(),
    llamaCppAdapter: llama,
    mnnAdapter: mnn,
    settingsLoader: settingsLoader ?? _FixedSettingsLoader(),
    localIpResolver: () async => null,
  );
}

class _FixedSettingsLoader extends ServerLaunchSettingsLoader {
  ServerLaunchSettings settings = const ServerLaunchSettings();

  @override
  Future<ServerLaunchSettings> load() async {
    return settings;
  }
}

class _FakeEngineAdapter implements InferenceEngineAdapter {
  _FakeEngineAdapter(
    this.engine, {
    this.startBlocker,
    this.prepareBlocker,
    this.startError,
    this.stopError,
    this.stopBlocker,
    this.stopListenerBeforeFailure = false,
  });

  @override
  final InferenceEngine engine;
  Completer<void>? startBlocker;
  final Completer<void>? prepareBlocker;
  final EngineAdapterException? startError;
  EngineAdapterException? stopError;
  final Completer<void>? stopBlocker;
  final bool stopListenerBeforeFailure;
  final StreamController<bool> _running = StreamController<bool>.broadcast();

  bool _isRunning = false;
  bool _cancelRequested = false;
  bool resident = false;
  int prepareCount = 0;
  int startCount = 0;
  int stopCount = 0;
  ServerLaunchSettings? startSettings;
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
    ServerLaunchSettings? settings,
    required RuntimePhaseCallback onPhase,
  }) async {
    _cancelRequested = false;
    startCount += 1;
    startSettings = settings;
    onPhase(RuntimePhase.loadingModel);
    await startBlocker?.future;
    if (_cancelRequested) throw const EngineOperationCancelledException();
    if (startError != null) {
      throw startError!;
    }
    _isRunning = true;
    resident = true;
    return EngineStartResult(
      host: settings?.host ?? '127.0.0.1',
      port: settings?.port ?? 8080,
      activeModelId: modelId,
      activeModelName: engine == InferenceEngine.mnn ? 'MNN model' : modelId,
    );
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    stopCount += 1;
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
    _isRunning = false;
    resident = false;
  }

  @override
  void dispose() {
    _running.close();
  }
}
