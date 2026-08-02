import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
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
      'MNN selection enables start and reaches ready with active model',
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

    test(
      'cancel invalidates a late start result and returns to idle',
      () async {
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
        await provider.cancel();
        expect(provider.status, EngineRuntimeStatus.idle);
        expect(mnn.cancelCount, 1);

        startBlocker.complete();
        await startFuture;
        expect(provider.status, EngineRuntimeStatus.idle);
        expect(provider.activeModelId, isNull);
      },
    );

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
  });
}

EngineRuntimeProvider _provider({
  required _FakeEngineAdapter llama,
  required _FakeEngineAdapter mnn,
}) {
  return EngineRuntimeProvider(
    llamaCppAdapter: llama,
    mnnAdapter: mnn,
    settingsLoader: _FixedSettingsLoader(),
    localIpResolver: () async => null,
  );
}

class _FixedSettingsLoader extends ServerLaunchSettingsLoader {
  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();
}

class _FakeEngineAdapter implements InferenceEngineAdapter {
  _FakeEngineAdapter(this.engine, {this.startBlocker});

  @override
  final InferenceEngine engine;
  final Completer<void>? startBlocker;
  final StreamController<bool> _running = StreamController<bool>.broadcast();

  bool _isRunning = false;
  int startCount = 0;
  int activateCount = 0;
  int cancelCount = 0;

  @override
  bool get isRunning => _isRunning;

  @override
  Stream<bool> get runningStateStream => _running.stream;

  @override
  Future<void> prepare() async {}

  @override
  Future<EngineStartResult> start({
    String? modelId,
    required RuntimePhaseCallback onPhase,
  }) async {
    startCount += 1;
    onPhase(RuntimePhase.loadingModel);
    await startBlocker?.future;
    _isRunning = true;
    return EngineStartResult(
      host: '127.0.0.1',
      port: 8080,
      activeModelId: modelId,
      activeModelName: engine == InferenceEngine.mnn ? 'MNN model' : modelId,
    );
  }

  @override
  Future<void> stop({required RuntimePhaseCallback onPhase}) async {
    _isRunning = false;
  }

  @override
  Future<void> cancel({required RuntimePhaseCallback onPhase}) async {
    cancelCount += 1;
    _isRunning = false;
  }

  @override
  Future<EngineStartResult> activateModel(
    String modelId, {
    required RuntimePhaseCallback onPhase,
  }) async {
    activateCount += 1;
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
