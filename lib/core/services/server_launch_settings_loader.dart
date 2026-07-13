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
      imageMaxTokens: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.imageMaxTokens) ??
            ServerLaunchSettings.defaultImageMaxTokens,
        ServerLaunchSettings.minImageMaxTokens,
        ServerLaunchSettings.maxImageMaxTokens,
      ),
      flashAttentionMode: _readFlashAttentionMode(
        await _kvStorage.getString(ServerPrefsKeys.flashAttentionMode),
      ),
      useMmap: await _kvStorage.getBool(ServerPrefsKeys.useMmap) ?? true,
      logEnabled: await _kvStorage.getBool(ServerPrefsKeys.logEnabled) ?? true,
      logLevel: _readLogLevel(
        await _kvStorage.getString(ServerPrefsKeys.logLevel),
      ),
    );
  }

  /// Persists every field. The field-to-key mapping lives only here and in
  /// [load]; callers hand over a complete settings object.
  Future<void> save(ServerLaunchSettings settings) async {
    await _kvStorage.setString(
      ServerPrefsKeys.listenMode,
      settings.listenMode.name,
    );
    await _kvStorage.setInt(ServerPrefsKeys.port, settings.port);
    await _kvStorage.setString(ServerPrefsKeys.apiKey, settings.apiKey);
    await _kvStorage.setInt(ServerPrefsKeys.contextSize, settings.contextSize);
    await _kvStorage.setInt(ServerPrefsKeys.cpuThreads, settings.cpuThreads);
    await _kvStorage.setInt(ServerPrefsKeys.batchSize, settings.batchSize);
    await _kvStorage.setInt(
      ServerPrefsKeys.parallelSlots,
      settings.parallelSlots,
    );
    await _kvStorage.setInt(
      ServerPrefsKeys.imageMaxTokens,
      settings.imageMaxTokens,
    );
    await _kvStorage.setString(
      ServerPrefsKeys.flashAttentionMode,
      settings.flashAttentionMode.name,
    );
    await _kvStorage.setBool(ServerPrefsKeys.useMmap, settings.useMmap);
    await _kvStorage.setBool(ServerPrefsKeys.logEnabled, settings.logEnabled);
    await _kvStorage.setString(
      ServerPrefsKeys.logLevel,
      settings.logLevel.name,
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

  ServerLogLevel _readLogLevel(String? savedLevel) {
    if (savedLevel == null) {
      return ServerLaunchSettings.defaultLogLevel;
    }

    try {
      return ServerLogLevel.values.byName(savedLevel);
    } catch (_) {
      return ServerLaunchSettings.defaultLogLevel;
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
