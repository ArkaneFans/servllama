import 'dart:async';

import 'package:flutter/material.dart';
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
      expect(provider.logEnabled, isTrue);
      expect(provider.logLevel, ServerLogLevel.info);
      expect(provider.statusText, 'Configuration loaded');
    });

    test('updatePort persists the full settings snapshot', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updatePort(9001);

      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9001);
      // Saves write the whole settings object; untouched fields persist
      // their defaults.
      expect(await kvStorage.getString(ServerPrefsKeys.listenMode), 'localhost');
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isEmpty);
      expect(
        await kvStorage.getInt(ServerPrefsKeys.contextSize),
        ServerLaunchSettings.defaultContextSize,
      );
      expect(
        await kvStorage.getBool(ServerPrefsKeys.useMmap),
        isTrue,
      );
      expect(provider.statusText, 'Configuration saved');
    });

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

    test('updates log settings independently', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateLogEnabled(false);
      await provider.updateLogLevel(ServerLogLevel.debug);

      expect(provider.logEnabled, isFalse);
      expect(provider.logLevel, ServerLogLevel.debug);
      expect(await kvStorage.getBool(ServerPrefsKeys.logEnabled), isFalse);
      expect(
        await kvStorage.getString(ServerPrefsKeys.logLevel),
        ServerLogLevel.debug.name,
      );
      expect(provider.statusText, 'Configuration saved');
    });

    test('resetToDefaults writes default values immediately', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(kvStorage: kvStorage);

      await provider.updateListenMode(ServerListenMode.allInterfaces);
      await provider.updatePort(9001);
      await provider.updateApiKey('secret');
      await provider.updateDevice('Vulkan0');
      await provider.updateGpuLayers(32);
      await provider.updateContextSize(8192);
      await provider.updateCpuThreads(8);
      await provider.updateBatchSize(1024);
      await provider.updateParallelSlots(4);
      await provider.updateFlashAttentionMode(FlashAttentionMode.auto);
      await provider.updateUseMmap(false);
      await provider.updateLogEnabled(false);
      await provider.updateLogLevel(ServerLogLevel.debug);

      await provider.resetToDefaults();

      expect(provider.listenMode, ServerListenMode.localhost);
      expect(provider.port, ServerLaunchSettings.defaultPort);
      expect(provider.apiKey, isEmpty);
      expect(provider.device, ServerLaunchSettings.defaultDevice);
      expect(provider.gpuLayers, ServerLaunchSettings.autoGpuLayers);
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

    test('detectDevices keeps a still-listed device selected', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(
        kvStorage: kvStorage,
        deviceLister: () async => <String>['GPUOpenCL', 'HTP0'],
      );
      await provider.updateDevice('HTP0');

      expect(provider.hasCompletedDeviceDetection, isFalse);

      await provider.detectDevices();

      expect(provider.availableDevices, <String>['GPUOpenCL', 'HTP0']);
      expect(provider.hasCompletedDeviceDetection, isTrue);
      expect(provider.isDetectingDevices, isFalse);
      expect(provider.device, 'HTP0');
      expect(provider.deviceOptions, <String>['GPUOpenCL', 'HTP0']);
      expect(await kvStorage.getString(ServerPrefsKeys.device), 'HTP0');
    });

    test('detectDevices resets a vanished device to CPU and persists it', () async {
      final kvStorage = KvStorage();
      final provider = ServerConfigProvider(
        kvStorage: kvStorage,
        deviceLister: () async => const <String>[],
      );
      await provider.updateDevice('Vulkan0');

      await provider.detectDevices();

      expect(provider.availableDevices, isEmpty);
      expect(provider.device, ServerLaunchSettings.defaultDevice);
      expect(provider.deviceOptions, isEmpty);
      expect(await kvStorage.getString(ServerPrefsKeys.device), isEmpty);
    });

    test('deviceOptions keeps the persisted device visible before detection', () async {
      final provider = ServerConfigProvider(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(device: 'HTP0'),
        ),
      );

      await provider.load();

      expect(provider.deviceOptions, <String>['HTP0']);
    });

    test('updateGpuLayers clamps custom values and collapses negatives to auto', () async {
      final provider = ServerConfigProvider(kvStorage: KvStorage());

      await provider.updateGpuLayers(500);
      expect(provider.gpuLayers, ServerLaunchSettings.maxGpuLayers);

      await provider.updateGpuLayers(-7);
      expect(provider.gpuLayers, ServerLaunchSettings.autoGpuLayers);
    });

    test('does not notify after dispose when a save completes late', () async {
      final loader = _BlockingSaveLoader();
      final provider = ServerConfigProvider(settingsLoader: loader);

      final pendingUpdate = provider.updatePort(9001);
      provider.dispose();
      loader.gate.complete();

      // Must not throw "used after being disposed".
      await pendingUpdate;
    });
  });
}

class _BlockingSaveLoader extends ServerLaunchSettingsLoader {
  final Completer<void> gate = Completer<void>();

  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();

  @override
  Future<void> save(ServerLaunchSettings settings) => gate.future;
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}
