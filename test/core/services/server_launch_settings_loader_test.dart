import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late KvStorage kvStorage;
  late ServerLaunchSettingsLoader loader;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    kvStorage = KvStorage();
    loader = ServerLaunchSettingsLoader(kvStorage: kvStorage);
  });

  group('ServerLaunchSettingsLoader', () {
    test('returns defaults when prefs are missing', () async {
      final settings = await loader.load();

      expect(settings.listenMode, ServerListenMode.localhost);
      expect(settings.host, '127.0.0.1');
      expect(settings.port, ServerLaunchSettings.defaultPort);
      expect(settings.apiKey, isEmpty);
      expect(settings.contextSize, ServerLaunchSettings.defaultContextSize);
      expect(settings.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(settings.batchSize, ServerLaunchSettings.defaultBatchSize);
      expect(settings.parallelSlots, ServerLaunchSettings.defaultParallelSlots);
      expect(
        settings.imageMaxTokens,
        ServerLaunchSettings.defaultImageMaxTokens,
      );
      expect(
        settings.flashAttentionMode,
        ServerLaunchSettings.defaultFlashAttentionMode,
      );
      expect(settings.useMmap, isTrue);
      expect(settings.logEnabled, isTrue);
      expect(settings.logLevel, ServerLogLevel.info);
      expect(settings.llamaCppBackend, LlamaCppBackend.cpu);
      expect(settings.mnnBackend, MnnBackend.cpu);
      expect(settings.mnnUseMmap, isFalse);
      expect(settings.mnnPrecision, MnnPrecision.low);
      expect(settings.mnnThreadNum, 4);
    });

    test('reads and sanitizes stored prefs values', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ServerPrefsKeys.listenMode: ServerListenMode.allInterfaces.name,
        ServerPrefsKeys.port: 70000,
        ServerPrefsKeys.apiKey: '  secret  ',
        ServerPrefsKeys.contextSize: 128,
        ServerPrefsKeys.cpuThreads: 128,
        ServerPrefsKeys.batchSize: 5000,
        ServerPrefsKeys.parallelSlots: 99,
        ServerPrefsKeys.imageMaxTokens: 5000,
        ServerPrefsKeys.flashAttentionMode: FlashAttentionMode.enabled.name,
        ServerPrefsKeys.useMmap: false,
        ServerPrefsKeys.logEnabled: false,
        ServerPrefsKeys.logLevel: ServerLogLevel.debug.name,
      });
      kvStorage = KvStorage();
      loader = ServerLaunchSettingsLoader(kvStorage: kvStorage);

      final settings = await loader.load();

      expect(settings.listenMode, ServerListenMode.allInterfaces);
      expect(settings.host, '0.0.0.0');
      expect(settings.port, ServerLaunchSettings.maxPort);
      expect(settings.apiKey, 'secret');
      expect(settings.contextSize, ServerLaunchSettings.minContextSize);
      expect(settings.cpuThreads, ServerLaunchSettings.maxCpuThreads);
      expect(settings.batchSize, ServerLaunchSettings.maxBatchSize);
      expect(settings.parallelSlots, ServerLaunchSettings.maxParallelSlots);
      expect(settings.imageMaxTokens, ServerLaunchSettings.maxImageMaxTokens);
      expect(settings.flashAttentionMode, FlashAttentionMode.enabled);
      expect(settings.useMmap, isFalse);
      expect(settings.logEnabled, isFalse);
      expect(settings.logLevel, ServerLogLevel.debug);
    });

    test('maps legacy auto values to the new defaults', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ServerPrefsKeys.cpuThreads: -1,
        ServerPrefsKeys.parallelSlots: -1,
      });
      kvStorage = KvStorage();
      loader = ServerLaunchSettingsLoader(kvStorage: kvStorage);

      final settings = await loader.load();

      expect(settings.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(settings.parallelSlots, ServerLaunchSettings.defaultParallelSlots);
    });

    test('falls back to defaults for invalid enum names', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ServerPrefsKeys.listenMode: 'invalid',
        ServerPrefsKeys.flashAttentionMode: 'invalid',
        ServerPrefsKeys.logLevel: 'invalid',
        ServerPrefsKeys.mnnBackend: 'auto',
        ServerPrefsKeys.mnnPrecision: 'normal',
        ServerPrefsKeys.mnnThreadNum: 99,
      });
      kvStorage = KvStorage();
      loader = ServerLaunchSettingsLoader(kvStorage: kvStorage);

      final settings = await loader.load();

      expect(settings.listenMode, ServerListenMode.localhost);
      expect(
        settings.flashAttentionMode,
        ServerLaunchSettings.defaultFlashAttentionMode,
      );
      expect(settings.logLevel, ServerLogLevel.info);
      expect(settings.mnnBackend, MnnBackend.cpu);
      expect(settings.mnnPrecision, MnnPrecision.low);
      expect(settings.mnnThreadNum, ServerLaunchSettings.maxMnnThreadNum);
    });

    test(
      'persists supported MNN backends without changing llama settings',
      () async {
        for (final backend in ServerLaunchSettings.supportedMnnBackends) {
          await loader.save(
            ServerLaunchSettings(
              mnnBackend: backend,
              contextSize: 8192,
              cpuThreads: 3,
            ),
          );
          final restored = await ServerLaunchSettingsLoader(
            kvStorage: kvStorage,
          ).load();
          expect(restored.mnnBackend, backend);
          expect(restored.contextSize, 8192);
          expect(restored.cpuThreads, 3);
          expect(restored.useMmap, isTrue);
        }
      },
    );

    test('persists llama.cpp acceleration backend', () async {
      await loader.save(
        const ServerLaunchSettings(
          llamaCppBackend: LlamaCppBackend.opencl,
          llamaCppGpuLayers: 32,
        ),
      );
      final restored = await ServerLaunchSettingsLoader(
        kvStorage: kvStorage,
      ).load();
      expect(restored.llamaCppBackend, LlamaCppBackend.opencl);
      expect(restored.llamaCppGpuLayers, 32);
      expect(
        await kvStorage.getString(ServerPrefsKeys.llamaCppBackend),
        'opencl',
      );
    });

    test('persists MNN mmap, precision and thread settings', () async {
      await loader.save(
        const ServerLaunchSettings(
          mnnUseMmap: true,
          mnnPrecision: MnnPrecision.high,
          mnnThreadNum: 7,
        ),
      );
      final restored = await ServerLaunchSettingsLoader(
        kvStorage: kvStorage,
      ).load();
      expect(restored.mnnUseMmap, isTrue);
      expect(restored.mnnPrecision, MnnPrecision.high);
      expect(restored.mnnThreadNum, 7);
      expect(restored.useMmap, isTrue);
    });

    test(
      'migrates a withdrawn backend and preserves the other settings',
      () async {
        await kvStorage.setString(ServerPrefsKeys.mnnBackend, 'hexagon');
        await kvStorage.setInt(ServerPrefsKeys.port, 9090);
        final restored = await loader.load();
        expect(restored.mnnBackend, MnnBackend.cpu);
        expect(restored.port, 9090);
        expect(await kvStorage.getString(ServerPrefsKeys.mnnBackend), 'cpu');
      },
    );

    test('maps a withdrawn auto backend to CPU', () async {
      await kvStorage.setString(ServerPrefsKeys.llamaCppBackend, 'auto');
      final restored = await loader.load();
      expect(restored.llamaCppBackend, LlamaCppBackend.cpu);
    });

    test('does not persist a hidden backend from a settings object', () async {
      await loader.save(
        const ServerLaunchSettings(mnnBackend: MnnBackend.hexagon),
      );
      expect(await kvStorage.getString(ServerPrefsKeys.mnnBackend), 'cpu');
    });
  });
}
