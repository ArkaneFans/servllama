import 'package:flutter_test/flutter_test.dart';
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
        settings.flashAttentionMode,
        ServerLaunchSettings.defaultFlashAttentionMode,
      );
      expect(settings.useMmap, isTrue);
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
        ServerPrefsKeys.flashAttentionMode: FlashAttentionMode.enabled.name,
        ServerPrefsKeys.useMmap: false,
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
      expect(settings.flashAttentionMode, FlashAttentionMode.enabled);
      expect(settings.useMmap, isFalse);
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
      });
      kvStorage = KvStorage();
      loader = ServerLaunchSettingsLoader(kvStorage: kvStorage);

      final settings = await loader.load();

      expect(settings.listenMode, ServerListenMode.localhost);
      expect(
        settings.flashAttentionMode,
        ServerLaunchSettings.defaultFlashAttentionMode,
      );
    });
  });
}
