import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ServerConfigProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('load marks initial load as completed', () async {
      final provider = ServerConfigProvider(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(contextSize: 8192, batchSize: 1024),
        ),
      );

      expect(provider.hasCompletedInitialLoad, isFalse);

      await provider.load();

      expect(provider.hasCompletedInitialLoad, isTrue);
      expect(provider.contextSize, 8192);
      expect(provider.batchSize, 1024);
      expect(provider.statusText, '配置已加载');
    });

    test('updatePort saves only the changed key', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updatePort(9001);

      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9001);
      expect(await kvStorage.getString(ServerPrefsKeys.listenMode), isNull);
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.contextSize), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.cpuThreads), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.batchSize), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.parallelSlots), isNull);
      expect(
        await kvStorage.getString(ServerPrefsKeys.flashAttentionMode),
        isNull,
      );
      expect(await kvStorage.getBool(ServerPrefsKeys.useMmap), isNull);
      expect(provider.statusText, '配置已保存');
    });

    test('multiple updates save only the changed keys', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateListenMode(ServerListenMode.allInterfaces);
      await provider.updateApiKey('secret');

      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'allInterfaces',
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), 'secret');
      expect(await kvStorage.getInt(ServerPrefsKeys.port), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.contextSize), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.cpuThreads), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.batchSize), isNull);
      expect(await kvStorage.getInt(ServerPrefsKeys.parallelSlots), isNull);
      expect(
        await kvStorage.getString(ServerPrefsKeys.flashAttentionMode),
        isNull,
      );
      expect(await kvStorage.getBool(ServerPrefsKeys.useMmap), isNull);
      expect(provider.statusText, '配置已保存');
    });

    test('resetToDefaults writes default values immediately', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateListenMode(ServerListenMode.allInterfaces);
      await provider.updatePort(9001);
      await provider.updateApiKey('secret');
      await provider.updateContextSize(8192);
      await provider.updateCpuThreads(8);
      await provider.updateBatchSize(1024);
      await provider.updateParallelSlots(4);
      await provider.updateFlashAttentionMode(FlashAttentionMode.auto);
      await provider.updateUseMmap(false);

      await provider.resetToDefaults();

      expect(provider.listenMode, ServerListenMode.localhost);
      expect(provider.port, ServerLaunchSettings.defaultPort);
      expect(provider.apiKey, isEmpty);
      expect(provider.contextSize, ServerLaunchSettings.defaultContextSize);
      expect(provider.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(provider.batchSize, ServerLaunchSettings.defaultBatchSize);
      expect(provider.parallelSlots, ServerLaunchSettings.defaultParallelSlots);
      expect(
        provider.flashAttentionMode,
        ServerLaunchSettings.defaultFlashAttentionMode,
      );
      expect(provider.useMmap, isTrue);
      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'localhost',
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.port),
        ServerLaunchSettings.defaultPort,
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isEmpty);
      expect(
        await kvStorage.getInt(ServerPrefsKeys.contextSize),
        ServerLaunchSettings.defaultContextSize,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.cpuThreads),
        ServerLaunchSettings.defaultCpuThreads,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.batchSize),
        ServerLaunchSettings.defaultBatchSize,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.parallelSlots),
        ServerLaunchSettings.defaultParallelSlots,
      );
      expect(
        await kvStorage.getString(ServerPrefsKeys.flashAttentionMode),
        ServerLaunchSettings.defaultFlashAttentionMode.name,
      );
      expect(await kvStorage.getBool(ServerPrefsKeys.useMmap), isTrue);
      expect(provider.statusText, '配置已保存');
    });

    test('thread and parallel updates clamp to 1-8', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateCpuThreads(0);
      await provider.updateParallelSlots(99);

      expect(provider.cpuThreads, ServerLaunchSettings.minCpuThreads);
      expect(provider.parallelSlots, ServerLaunchSettings.maxParallelSlots);
      expect(
        await kvStorage.getInt(ServerPrefsKeys.cpuThreads),
        ServerLaunchSettings.minCpuThreads,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.parallelSlots),
        ServerLaunchSettings.maxParallelSlots,
      );
    });
  });
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}
