import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ServerConfigProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      AppL10nService.instance.setLocale(const Locale('en'));
    });

    test(
      'warmup and route await one load; prepared reads preserve edits',
      () async {
        final loader = _BlockingLoadLoader();
        final provider = ServerConfigProvider(settingsLoader: loader);
        final first = provider.ensureLoaded();
        final route = provider.ensureLoaded();
        expect(identical(first, route), isTrue);
        expect(loader.calls, 1);
        loader.pending.complete(const ServerLaunchSettings(port: 9002));
        await Future.wait([first, route]);
        await provider.updatePort(9003);
        await provider.ensureLoaded();
        expect(loader.calls, 1);
        expect(provider.port, 9003);
        provider.dispose();
      },
    );

    test('sequential updates accumulate into the persisted snapshot', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateListenMode(ServerListenMode.allInterfaces);
      await provider.updateApiKey('secret');

      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'allInterfaces',
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), 'secret');
      expect(
        await kvStorage.getInt(ServerPrefsKeys.port),
        ServerLaunchSettings.defaultPort,
      );
      expect(provider.statusText, 'Configuration saved');
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
      await provider.updateLogEnabled(false);
      await provider.updateLogLevel(ServerLogLevel.debug);
      await provider.updateMnnUseMmap(true);
      await provider.updateMnnPrecision(MnnPrecision.high);
      await provider.updateMnnThreadNum(7);

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
      expect(provider.logEnabled, isTrue);
      expect(provider.logLevel, ServerLogLevel.info);
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
      expect(await kvStorage.getBool(ServerPrefsKeys.logEnabled), isTrue);
      expect(
        await kvStorage.getString(ServerPrefsKeys.logLevel),
        ServerLogLevel.info.name,
      );
      expect(provider.statusText, 'Configuration saved');
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

class _BlockingLoadLoader extends ServerLaunchSettingsLoader {
  final pending = Completer<ServerLaunchSettings>();
  int calls = 0;
  @override
  Future<ServerLaunchSettings> load() {
    calls++;
    return pending.future;
  }

  @override
  Future<void> save(ServerLaunchSettings settings) async {}
}
