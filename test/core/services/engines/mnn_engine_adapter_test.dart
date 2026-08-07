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
      settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings(port: 8083)),
    );
    addTearDown(adapter.dispose);

    final phases = <RuntimePhase>[];
    final result = await adapter.start(
      modelId: 'local/qwen',
      onPhase: phases.add,
    );

    expect(platform.checkPortCalls, 0);
    expect(platform.startServerCalls, 1);
    expect(platform.snapshotCalls, 1, reason: 'prepare reads the initial snapshot once');
    expect(phases, <RuntimePhase>[
      RuntimePhase.loadingModel,
      RuntimePhase.startingServer,
    ]);
    expect(result.port, 8083);
  });

  test('maps a real bind conflict to the typed port error', () async {
    platform.startError = const MnnEngineException(
      'port_in_use',
      'Port 8083 is currently unavailable.',
    );
    final adapter = MnnEngineAdapter(
      settingsLoader: _FixedSettingsLoader(const ServerLaunchSettings(port: 8083)),
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
}

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

  @override
  Stream<MnnRuntimeEvent> get events => const Stream<MnnRuntimeEvent>.empty();

  @override
  Stream<MnnLogEntry> get logs => const Stream<MnnLogEntry>.empty();

  @override
  Future<MnnEngineInfo> initialize() async => const MnnEngineInfo(
    pluginVersion: '0.1.0',
    mnnVersion: '3.6.0',
    mnnCommit: 'test',
    abi: 'arm64-v8a',
    androidApiLevel: 35,
    ndkVersion: '27',
    nativeLibraryLoaded: true,
    testRootPath: '/tmp/mnn',
  );

  @override
  Future<MnnRuntimeSnapshot> getSnapshot() async {
    snapshotCalls++;
    return const MnnRuntimeSnapshot(
      revision: 1,
      engineState: 'ready',
      modelState: 'unloaded',
      serverState: 'stopped',
      generationState: 'idle',
    );
  }

  @override
  Future<List<MnnLogEntry>> getLogSnapshot() async => const <MnnLogEntry>[];

  @override
  Future<MnnModelInfo> loadModel(String modelId) async => const MnnModelInfo(
    modelId: 'local/qwen',
    modelKey: 'qwen',
    displayName: 'Qwen',
    modelDirPath: '/tmp/mnn/qwen',
    configPath: '/tmp/mnn/qwen/config.json',
    sizeBytes: 1,
    importedAt: 1,
    isActive: true,
  );

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
  Future<void> stopServer() async {}

  @override
  Future<void> unloadModel() async {
    unloadModelCalls++;
  }

  @override
  Future<void> cancelGeneration() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
