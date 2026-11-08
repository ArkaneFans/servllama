import 'package:mnn_engine/mnn_engine.dart' show MnnBackend, MnnPrecision;
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

class ServerLaunchSettingsLoader {
  ServerLaunchSettingsLoader({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  Future<ServerLaunchSettings> load() async {
    final savedMnnBackend = await _kvStorage.getString(
      ServerPrefsKeys.mnnBackend,
    );
    final mnnBackend = _readMnnBackend(savedMnnBackend);
    if (savedMnnBackend != null && savedMnnBackend != mnnBackend.name) {
      // Migrate withdrawn/unknown choices so a hidden backend cannot be
      // started from preferences left by an earlier installation.
      await _kvStorage.setString(ServerPrefsKeys.mnnBackend, mnnBackend.name);
    }
    final savedLlamaCppBackend = await _kvStorage.getString(
      ServerPrefsKeys.llamaCppBackend,
    );
    final llamaCppBackend = ServerLaunchSettings.llamaCppBackendFromStorage(
      savedLlamaCppBackend,
    );
    if (savedLlamaCppBackend != null &&
        savedLlamaCppBackend != llamaCppBackend.name) {
      await _kvStorage.setString(
        ServerPrefsKeys.llamaCppBackend,
        llamaCppBackend.name,
      );
    }
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
      llamaCppBackend: llamaCppBackend,
      llamaCppGpuLayers: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.llamaCppGpuLayers) ??
            ServerLaunchSettings.defaultLlamaCppGpuLayers,
        ServerLaunchSettings.minLlamaCppGpuLayers,
        ServerLaunchSettings.maxLlamaCppGpuLayers,
      ),
      mnnBackend: mnnBackend,
      mnnUseMmap:
          await _kvStorage.getBool(ServerPrefsKeys.mnnUseMmap) ??
          ServerLaunchSettings.defaultMnnUseMmap,
      mnnPrecision: _readMnnPrecision(
        await _kvStorage.getString(ServerPrefsKeys.mnnPrecision),
      ),
      mnnThreadNum: _clamp(
        await _kvStorage.getInt(ServerPrefsKeys.mnnThreadNum) ??
            ServerLaunchSettings.defaultMnnThreadNum,
        ServerLaunchSettings.minMnnThreadNum,
        ServerLaunchSettings.maxMnnThreadNum,
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
    await _kvStorage.setString(
      ServerPrefsKeys.llamaCppBackend,
      ServerLaunchSettings.llamaCppBackendFromStorage(
        settings.llamaCppBackend.name,
      ).name,
    );
    await _kvStorage.setInt(
      ServerPrefsKeys.llamaCppGpuLayers,
      settings.llamaCppGpuLayers,
    );
    await _kvStorage.setString(
      ServerPrefsKeys.mnnBackend,
      _readMnnBackend(settings.mnnBackend.name).name,
    );
    await _kvStorage.setBool(ServerPrefsKeys.mnnUseMmap, settings.mnnUseMmap);
    await _kvStorage.setString(
      ServerPrefsKeys.mnnPrecision,
      _readMnnPrecision(settings.mnnPrecision.name).name,
    );
    await _kvStorage.setInt(
      ServerPrefsKeys.mnnThreadNum,
      settings.mnnThreadNum,
    );
  }

  MnnBackend _readMnnBackend(String? value) =>
      ServerLaunchSettings.supportedMnnBackends.firstWhere(
        (backend) => backend.name == value,
        orElse: () => MnnBackend.cpu,
      );

  MnnPrecision _readMnnPrecision(String? value) =>
      MnnPrecision.values.firstWhere(
        (precision) => precision.name == value,
        orElse: () => ServerLaunchSettings.defaultMnnPrecision,
      );

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
