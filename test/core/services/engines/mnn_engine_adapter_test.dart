import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:mnn_engine/mnn_engine_platform_interface.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/engines/mnn_engine_adapter.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MnnEnginePlatform originalPlatform;
  late _FakeMnnPlatform platform;

  setUp(() {
    originalPlatform = MnnEnginePlatform.instance;
    platform = _FakeMnnPlatform();
    MnnEnginePlatform.instance = platform;
  });

  tearDown(() {
    MnnEnginePlatform.instance = originalPlatform;
  });

  test('uses the native bind as the only port decision', () async {
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(port: 8083),
      ),
    );
    addTearDown(adapter.dispose);

    final phases = <RuntimePhase>[];
    final result = await adapter.start(
      modelId: 'local/qwen',
      onPhase: phases.add,
    );

    expect(platform.checkPortCalls, 0);
    expect(platform.startServerCalls, 1);
    expect(
      platform.snapshotCalls,
      1,
      reason: 'prepare reads the initial snapshot once',
    );
    expect(phases, <RuntimePhase>[
      RuntimePhase.loadingModel,
      RuntimePhase.startingServer,
    ]);
    expect(result.port, 8083);
  });

  test(
    'stopping HTTP keeps residency until native unloading is acknowledged',
    () async {
      final adapter = MnnEngineAdapter(
        settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
      );
      addTearDown(adapter.dispose);
      await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
      platform.unloadBlocker = Completer<void>();
      final stopping = adapter.stop(onPhase: (_) {});
      await Future<void>.delayed(Duration.zero);
      expect(adapter.isRunning, isFalse);
      expect(adapter.hasResources, isTrue);
      platform.unloadBlocker!.complete();
      await stopping;
      expect(adapter.hasResources, isFalse);
    },
  );

  test(
    'failed unloading retains residency until an explicit retry succeeds',
    () async {
      final adapter = MnnEngineAdapter(
        settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
      );
      addTearDown(adapter.dispose);
      await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
      platform.unloadError = const MnnEngineException(
        'model_busy',
        'Native generation is still stopping',
      );
      await expectLater(
        adapter.stop(onPhase: (_) {}),
        throwsA(isA<EngineAdapterException>()),
      );
      expect(adapter.isRunning, isFalse);
      expect(adapter.hasResources, isTrue);
      platform.unloadError = null;
      await adapter.stop(onPhase: (_) {});
      expect(adapter.hasResources, isFalse);
    },
  );

  test('a server stop timeout prevents model unloading', () async {
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
    );
    addTearDown(adapter.dispose);
    await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
    platform.stopError = const MnnEngineException(
      'server_stop_timeout',
      'Native generation is still stopping',
    );
    await expectLater(
      adapter.stop(onPhase: (_) {}),
      throwsA(isA<EngineAdapterException>()),
    );
    expect(platform.unloadModelCalls, 0);
    expect(adapter.hasResources, isTrue);
  });

  test('startup failure cannot hide a failed cleanup', () async {
    platform.startError = const MnnEngineException(
      'port_in_use',
      'Port unavailable',
    );
    platform.unloadError = const MnnEngineException(
      'runtime_release_failed',
      'Unloading failed',
    );
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
    );
    addTearDown(adapter.dispose);
    await expectLater(
      adapter.start(modelId: 'local/qwen', onPhase: (_) {}),
      throwsA(
        isA<EngineAdapterException>().having(
          (e) => e.kind,
          'kind',
          EngineRuntimeErrorKind.serverStopFailed,
        ),
      ),
    );
    expect(adapter.hasResources, isTrue);
    platform.unloadError = null;
    await adapter.stop(onPhase: (_) {});
    expect(adapter.hasResources, isFalse);
  });

  test(
    'cancelling preparation cannot load a model after cleanup has finished',
    () async {
      platform.initializeBlocker = Completer<void>();
      final adapter = MnnEngineAdapter(
        settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
      );
      addTearDown(adapter.dispose);
      final starting = expectLater(
        adapter.start(modelId: 'local/qwen', onPhase: (_) {}),
        throwsA(isA<EngineOperationCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);
      await adapter.cancel(onPhase: (_) {});
      platform.initializeBlocker!.complete();
      await starting;
      expect(platform.requestedBackends, isEmpty);
      expect(platform.startServerCalls, 0);
      expect(adapter.hasResources, isFalse);
    },
  );

  test('maps a real bind conflict to the typed port error', () async {
    platform.startError = const MnnEngineException(
      'port_in_use',
      'Port 8083 is currently unavailable.',
    );
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(port: 8083),
      ),
    );
    addTearDown(adapter.dispose);

    await expectLater(
      adapter.start(modelId: 'local/qwen', onPhase: (_) {}),
      throwsA(
        isA<EngineAdapterException>().having(
          (error) => error.kind,
          'kind',
          EngineRuntimeErrorKind.portInUse,
        ),
      ),
    );
    expect(platform.checkPortCalls, 0);
    expect(platform.unloadModelCalls, 1);
  });

  test('passes the saved backend when loading a model', () async {
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(mnnBackend: MnnBackend.vulkan),
      ),
    );
    addTearDown(adapter.dispose);
    await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
    expect(platform.requestedBackends, [MnnBackend.vulkan]);
  });

  test('reloads a resident model when its requested backend changes', () async {
    platform.initialModel = _model(MnnBackend.cpu);
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(mnnBackend: MnnBackend.opencl),
      ),
    );
    addTearDown(adapter.dispose);
    await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
    expect(platform.requestedBackends, [MnnBackend.opencl]);
  });

  test(
    'passes mmap, precision and thread settings when loading a model',
    () async {
      final adapter = MnnEngineAdapter(
        settingsLoader: _FixedSettingsLoader(
          const ServerLaunchSettings(
            mnnUseMmap: true,
            mnnPrecision: MnnPrecision.high,
            mnnThreadNum: 6,
          ),
        ),
      );
      addTearDown(adapter.dispose);
      await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
      expect(platform.requestedOptions, [
        const MnnLoadOptions(
          useMmap: true,
          precision: MnnPrecision.high,
          threadNum: 6,
        ),
      ]);
    },
  );

  test('reloads a resident model when mmap settings change', () async {
    platform.initialModel = _model(MnnBackend.cpu);
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(mnnUseMmap: true),
      ),
    );
    addTearDown(adapter.dispose);
    await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
    expect(platform.requestedOptions.single.useMmap, isTrue);
  });

  test('reuses a resident model only when its backend also matches', () async {
    platform.initialModel = _model(MnnBackend.opencl);
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(mnnBackend: MnnBackend.opencl),
      ),
    );
    addTearDown(adapter.dispose);
    await adapter.start(modelId: 'local/qwen', onPhase: (_) {});
    expect(platform.requestedBackends, isEmpty);
  });

  test('backend failure is actionable and does not retry with CPU', () async {
    platform.loadError = const MnnEngineException(
      'backend_unavailable',
      'OpenCL driver unavailable',
    );
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(
        const ServerLaunchSettings(mnnBackend: MnnBackend.opencl),
      ),
    );
    addTearDown(adapter.dispose);
    await expectLater(
      adapter.start(modelId: 'local/qwen', onPhase: (_) {}),
      throwsA(
        isA<EngineAdapterException>().having(
          (error) => error.kind,
          'kind',
          EngineRuntimeErrorKind.backendUnavailable,
        ),
      ),
    );
    expect(platform.requestedBackends, [MnnBackend.opencl]);
    expect(platform.startServerCalls, 0);
    expect(platform.unloadModelCalls, 1);
  });

  test(
    'incompatible Hexagon model does not start a server or retry with CPU',
    () async {
      platform.loadError = const MnnEngineException(
        'model_backend_incompatible',
        'Transformer C4 export required',
      );
      final adapter = MnnEngineAdapter(
        settingsLoader: _FixedSettingsLoader(
          const ServerLaunchSettings(mnnBackend: MnnBackend.hexagon),
        ),
      );
      addTearDown(adapter.dispose);
      await expectLater(
        adapter.start(modelId: 'local/qwen', onPhase: (_) {}),
        throwsA(
          isA<EngineAdapterException>().having(
            (error) => error.kind,
            'kind',
            EngineRuntimeErrorKind.modelBackendIncompatible,
          ),
        ),
      );
      expect(platform.requestedBackends, [MnnBackend.hexagon]);
      expect(platform.startServerCalls, 0);
      expect(platform.unloadModelCalls, 1);
    },
  );
}

MnnModelInfo _model(
  MnnBackend backend, {
  bool useMmap = false,
  MnnPrecision precision = MnnPrecision.low,
  int threadNum = 4,
}) => MnnModelInfo(
  modelId: 'local/qwen',
  modelKey: 'qwen',
  displayName: 'Qwen',
  modelDirPath: '/tmp/mnn/qwen',
  configPath: '/tmp/mnn/qwen/config.json',
  sizeBytes: 1,
  importedAt: 1,
  isActive: true,
  backend: backend,
  useMmap: useMmap,
  precision: precision,
  threadNum: threadNum,
);

class _FixedSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _FakeMnnPlatform extends MnnEnginePlatform {
  int checkPortCalls = 0;
  int startServerCalls = 0;
  int snapshotCalls = 0;
  int unloadModelCalls = 0;
  MnnEngineException? startError;
  MnnEngineException? loadError;
  MnnEngineException? stopError;
  MnnEngineException? unloadError;
  Completer<void>? initializeBlocker;
  Completer<void>? unloadBlocker;
  MnnModelInfo? initialModel;
  final requestedBackends = <MnnBackend>[];
  final requestedOptions = <MnnLoadOptions>[];

  @override
  Stream<MnnRuntimeEvent> get events => const Stream<MnnRuntimeEvent>.empty();

  @override
  Stream<MnnLogEntry> get logs => const Stream<MnnLogEntry>.empty();

  @override
  Future<MnnEngineInfo> initialize() async {
    await initializeBlocker?.future;
    return const MnnEngineInfo(
      pluginVersion: '0.1.0',
      mnnVersion: '3.6.0',
      mnnCommit: 'test',
      abi: 'arm64-v8a',
      androidApiLevel: 35,
      ndkVersion: '27',
      nativeLibraryLoaded: true,
      testRootPath: '/tmp/mnn',
    );
  }

  @override
  Future<MnnRuntimeSnapshot> getSnapshot() async {
    snapshotCalls++;
    return MnnRuntimeSnapshot(
      revision: 1,
      engineState: 'ready',
      modelState: 'unloaded',
      serverState: 'stopped',
      generationState: 'idle',
      activeModel: initialModel,
    );
  }

  @override
  Future<List<MnnLogEntry>> getLogSnapshot() async => const <MnnLogEntry>[];

  @override
  Future<MnnModelInfo> renameImportedModel(
    String modelId,
    String newName,
  ) async => throw UnimplementedError();

  @override
  Future<MnnModelInfo> loadModel(
    String modelId, {
    MnnLoadOptions options = const MnnLoadOptions(),
  }) async {
    requestedBackends.add(options.backend);
    requestedOptions.add(options);
    if (loadError != null) throw loadError!;
    return _model(
      options.backend,
      useMmap: options.useMmap,
      precision: options.precision,
      threadNum: options.threadNum,
    );
  }

  @override
  Future<MnnServerInfo> startServer({
    required MnnServerBindMode bindMode,
    required int port,
    String? apiKey,
  }) async {
    startServerCalls++;
    final error = startError;
    if (error != null) {
      throw error;
    }
    return MnnServerInfo(
      running: true,
      host: '127.0.0.1',
      bindMode: bindMode,
      bindAddress: '127.0.0.1',
      port: port,
      baseUrl: 'http://127.0.0.1:$port',
      localBaseUrl: 'http://127.0.0.1:$port',
    );
  }

  @override
  Future<MnnPortCheckResult> checkPort({
    required MnnServerBindMode bindMode,
    required int port,
  }) async {
    checkPortCalls++;
    return const MnnPortCheckResult(available: true, ownedByMnn: false);
  }

  @override
  Future<void> stopServer() async {
    if (stopError != null) throw stopError!;
  }

  @override
  Future<void> unloadModel() async {
    unloadModelCalls++;
    await unloadBlocker?.future;
    if (unloadError != null) throw unloadError!;
  }

  @override
  Future<void> cancelGeneration() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
