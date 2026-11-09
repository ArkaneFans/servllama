import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KvStorage storage;
  late ServerLaunchSettingsLoader loader;
  setUp(() {
    storage = KvStorage();
    loader = ServerLaunchSettingsLoader(kvStorage: storage);
  });

  test('fresh configuration uses the application defaults', () async {
    final settings = await loader.load();
    expect(settings.host, '127.0.0.1');
    expect(settings.port, ServerLaunchSettings.defaultPort);
    expect(settings.apiKey, isEmpty);
    expect(settings.contextSize, ServerLaunchSettings.defaultContextSize);
    expect(settings.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
    expect(settings.mnnBackend, MnnBackend.cpu);
    expect(settings.llamaCppBackend, LlamaCppBackend.cpu);
  });

  test(
    'one settings snapshot restores endpoint, inference and logging options',
    () async {
      await loader.save(
        const ServerLaunchSettings(
          listenMode: ServerListenMode.allInterfaces,
          port: 9091,
          apiKey: 'configured-key',
          contextSize: 8192,
          cpuThreads: 6,
          batchSize: 512,
          parallelSlots: 2,
          imageMaxTokens: 768,
          flashAttentionMode: FlashAttentionMode.enabled,
          useMmap: false,
          logEnabled: false,
          logLevel: ServerLogLevel.debug,
          llamaCppBackend: LlamaCppBackend.hexagon,
          llamaCppGpuLayers: 32,
          mnnBackend: MnnBackend.opencl,
          mnnUseMmap: true,
          mnnPrecision: MnnPrecision.high,
          mnnThreadNum: 7,
        ),
      );
      final restored = await ServerLaunchSettingsLoader(
        kvStorage: storage,
      ).load();
      expect(restored.host, '0.0.0.0');
      expect(restored.port, 9091);
      expect(restored.apiKey, 'configured-key');
      expect(restored.contextSize, 8192);
      expect(restored.cpuThreads, 6);
      expect(restored.batchSize, 512);
      expect(restored.parallelSlots, 2);
      expect(restored.imageMaxTokens, 768);
      expect(restored.flashAttentionMode, FlashAttentionMode.enabled);
      expect(restored.useMmap, isFalse);
      expect(restored.logEnabled, isFalse);
      expect(restored.logLevel, ServerLogLevel.debug);
      expect(restored.llamaCppBackend, LlamaCppBackend.hexagon);
      expect(restored.llamaCppGpuLayers, 32);
      expect(restored.mnnBackend, MnnBackend.opencl);
      expect(restored.mnnUseMmap, isTrue);
      expect(restored.mnnPrecision, MnnPrecision.high);
      expect(restored.mnnThreadNum, 7);
    },
  );

  test('stored configuration is normalized to supported values', () async {
    SharedPreferences.setMockInitialValues({
      ServerPrefsKeys.port: 70000,
      ServerPrefsKeys.apiKey: '  key  ',
      ServerPrefsKeys.contextSize: 1,
      ServerPrefsKeys.cpuThreads: -1,
      ServerPrefsKeys.mnnBackend: 'withdrawn',
      ServerPrefsKeys.llamaCppBackend: 'withdrawn',
    });
    final storage = KvStorage();
    final settings = await ServerLaunchSettingsLoader(
      kvStorage: storage,
    ).load();
    expect(settings.port, ServerLaunchSettings.maxPort);
    expect(settings.apiKey, 'key');
    expect(settings.contextSize, ServerLaunchSettings.minContextSize);
    expect(settings.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
    expect(settings.mnnBackend, MnnBackend.cpu);
    expect(settings.llamaCppBackend, LlamaCppBackend.cpu);
    expect(await storage.getString(ServerPrefsKeys.mnnBackend), 'cpu');
    expect(await storage.getString(ServerPrefsKeys.llamaCppBackend), 'cpu');
  });
}
