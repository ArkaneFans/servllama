import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:mnn_engine/mnn_engine_platform_interface.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/engines/inference_engine_adapter.dart';
import 'package:servllama/core/services/engines/mnn_engine_adapter.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MnnEnginePlatform originalPlatform;
  late _FakeMnnPlatform platform;
  late AppDatabase db;
  late UnifiedModelRepository repository;

  setUp(() {
    db = AppDatabase.memory();
    repository = UnifiedModelRepository(database: db);
    originalPlatform = MnnEnginePlatform.instance;
    platform = _FakeMnnPlatform();
    MnnEnginePlatform.instance = platform;
  });

  tearDown(() async {
    MnnEnginePlatform.instance = originalPlatform;
    await db.close();
  });

  test(
    'ownership restore does not initialize native libraries or load a model',
    () async {
      platform.initialModel = _model(MnnBackend.cpu);
      platform.initializeBlocker = Completer<void>();
      final adapter = MnnEngineAdapter(
        modelRepository: repository,
        settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
      );
      addTearDown(adapter.dispose);
      await adapter.prepare();
      await adapter.prepare();
      expect(platform.initializeCalls, 0);
      expect(platform.snapshotCalls, 1);
      expect(adapter.hasResources, isTrue);
      expect(platform.requestedOptions, isEmpty);
      expect(platform.startServerCalls, 0);
    },
  );

  test('uses the configuration supplied by the runtime', () async {
    final adapter = MnnEngineAdapter(
      modelRepository: repository,
      settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
    );
    addTearDown(adapter.dispose);
    final result = await adapter.start(
      modelId: 'local/qwen',
      settings: const ServerLaunchSettings(
        listenMode: ServerListenMode.allInterfaces,
        port: 9091,
        apiKey: 'configured-key',
        mnnBackend: MnnBackend.opencl,
        mnnPrecision: MnnPrecision.high,
        mnnThreadNum: 6,
      ),
      onPhase: (_) {},
    );
    expect(result.host, '0.0.0.0');
    expect(result.port, 9091);
    expect(platform.requestedBindMode, MnnServerBindMode.allInterfaces);
    expect(platform.requestedApiKey, 'configured-key');
    expect(platform.requestedOptions.single.backend, MnnBackend.opencl);
    expect(platform.requestedOptions.single.precision, MnnPrecision.high);
    expect(platform.requestedOptions.single.threadNum, 6);
  });

  test(
    'external MNN loads the SQL path without requiring files to exist',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repository = UnifiedModelRepository(database: db);
      await repository.saveAsset(
        const ModelAsset(
          id: 'external-asset',
          kind: AssetKind.llm,
          engine: 'mnn',
          runtimeId: 'Alias',
          storageOwner: 'external',
          path: '/missing/external-model',
          name: 'Alias',
          revision: 'local',
          manifest: {'importedAt': 0, 'sizeBytes': 2048},
        ),
      );
      final adapter = MnnEngineAdapter(
        modelRepository: repository,
        settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings()),
      );
      addTearDown(adapter.dispose);
      final result = await adapter.start(modelId: 'Alias', onPhase: (_) {});
      expect(platform.externalPaths, ['/missing/external-model']);
      expect(platform.externalNames, ['Alias']);
      expect(platform.externalIds, ['Alias']);
      expect(result.activeModelId, 'Alias');
      expect(result.activeModelName, 'Alias');
      expect(platform.startServerCalls, 1);
    },
  );

  test(
    'stopping HTTP keeps residency until native unloading is acknowledged',
    () async {
      final adapter = MnnEngineAdapter(
        modelRepository: repository,
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
        modelRepository: repository,
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
      modelRepository: repository,
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

  test('maps a real bind conflict to the typed port error', () async {
    platform.startError = const MnnEngineException(
      'port_in_use',
      'Port 8083 is currently unavailable.',
    );
    final adapter = MnnEngineAdapter(
      modelRepository: repository,
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

  test('backend failure is actionable and does not retry with CPU', () async {
    platform.loadError = const MnnEngineException(
      'backend_unavailable',
      'OpenCL driver unavailable',
    );
    final adapter = MnnEngineAdapter(
      modelRepository: repository,
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
  final externalPaths = <String>[];
  final externalNames = <String?>[];
  final externalIds = <String?>[];
  int checkPortCalls = 0;
  int startServerCalls = 0;
  int snapshotCalls = 0;
  int initializeCalls = 0;
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
  MnnServerBindMode? requestedBindMode;
  String? requestedApiKey;

  @override
  Stream<MnnRuntimeEvent> get events => const Stream<MnnRuntimeEvent>.empty();

  @override
  Stream<MnnLogEntry> get logs => const Stream<MnnLogEntry>.empty();

  @override
  Future<MnnEngineInfo> initialize() async {
    initializeCalls++;
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
  Future<MnnModelInfo> loadModelFromPath(
    String directoryPath, {
    String? modelId,
    String? displayName,
    MnnLoadOptions options = const MnnLoadOptions(),
  }) async {
    externalPaths.add(directoryPath);
    externalNames.add(displayName);
    externalIds.add(modelId);
    if (loadError != null) throw loadError!;
    final id = modelId!;
    return MnnModelInfo(
      modelId: id,
      modelKey: id,
      displayName: displayName ?? id,
      modelDirPath: directoryPath,
      configPath: '$directoryPath/config.json',
      sizeBytes: 2048,
      importedAt: 0,
      isActive: true,
      backend: options.backend,
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
    requestedBindMode = bindMode;
    requestedApiKey = apiKey;
    final error = startError;
    if (error != null) {
      throw error;
    }
    return MnnServerInfo(
      running: true,
      host: bindMode == MnnServerBindMode.allInterfaces
          ? '0.0.0.0'
          : '127.0.0.1',
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
