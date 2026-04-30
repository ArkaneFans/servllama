import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

class ServerLaunchSettingsLoader {
  ServerLaunchSettingsLoader({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  Future<ServerLaunchSettings> load() async {
    return ServerLaunchSettings(
      listenMode: _readListenMode(
        await _kvStorage.getString(ServerPrefsKeys.listenMode),
      ),
      port: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.port) ??
            ServerLaunchSettings.defaultPort,
        ServerLaunchSettings.minPort,
        ServerLaunchSettings.maxPort,
      ),
      apiKey: (await _kvStorage.getString(ServerPrefsKeys.apiKey) ?? '').trim(),
      contextSize: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.contextSize) ??
            ServerLaunchSettings.defaultContextSize,
        ServerLaunchSettings.minContextSize,
        ServerLaunchSettings.maxContextSize,
      ),
      cpuThreads: _clampStoredOrDefault(
        await _kvStorage.getInt(ServerPrefsKeys.cpuThreads) ??
            ServerLaunchSettings.defaultCpuThreads,
        ServerLaunchSettings.defaultCpuThreads,
        ServerLaunchSettings.minCpuThreads,
        ServerLaunchSettings.maxCpuThreads,
      ),
      batchSize: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.batchSize) ??
            ServerLaunchSettings.defaultBatchSize,
        ServerLaunchSettings.minBatchSize,
        ServerLaunchSettings.maxBatchSize,
      ),
      parallelSlots: _clampStoredOrDefault(
        await _kvStorage.getInt(ServerPrefsKeys.parallelSlots) ??
            ServerLaunchSettings.defaultParallelSlots,
        ServerLaunchSettings.defaultParallelSlots,
        ServerLaunchSettings.minParallelSlots,
        ServerLaunchSettings.maxParallelSlots,
      ),
      flashAttentionMode: _readFlashAttentionMode(
        await _kvStorage.getString(ServerPrefsKeys.flashAttentionMode),
      ),
      useMmap: await _kvStorage.getBool(ServerPrefsKeys.useMmap) ?? true,
    );
  }

  ServerListenMode _readListenMode(String? savedMode) {
    if (savedMode == null) {
      return ServerListenMode.localhost;
    }

    try {
      return ServerListenMode.values.byName(savedMode);
    } catch (_) {
      return ServerListenMode.localhost;
    }
  }

  FlashAttentionMode _readFlashAttentionMode(String? savedMode) {
    if (savedMode == null) {
      return ServerLaunchSettings.defaultFlashAttentionMode;
    }

    try {
      return FlashAttentionMode.values.byName(savedMode);
    } catch (_) {
      return ServerLaunchSettings.defaultFlashAttentionMode;
    }
  }

  int _clamp(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  int _clampStoredOrDefault(int value, int defaultValue, int min, int max) {
    if (value < min) {
      return defaultValue;
    }
    return _clamp(value, min, max);
  }
}
