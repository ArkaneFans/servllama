import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';

class ServerConfigProvider extends ChangeNotifier {
  ServerConfigProvider({
    ServerLaunchSettingsLoader? settingsLoader,
    KvStorage? kvStorage,
  }) : _settingsLoader =
           settingsLoader ??
           ServerLaunchSettingsLoader(
             kvStorage: kvStorage ?? KvStorage.instance,
           );

  final ServerLaunchSettingsLoader _settingsLoader;

  bool _hasCompletedInitialLoad = false;
  bool _isLoading = false;
  bool _disposed = false;
  String? _statusMessage;

  ServerLaunchSettings _settings = const ServerLaunchSettings();

  bool get hasCompletedInitialLoad => _hasCompletedInitialLoad;
  bool get isLoading => _isLoading;
  String? get statusMessage => _statusMessage;

  ServerListenMode get listenMode => _settings.listenMode;
  int get port => _settings.port;
  String get apiKey => _settings.apiKey;
  int get contextSize => _settings.contextSize;
  int get cpuThreads => _settings.cpuThreads;
  int get batchSize => _settings.batchSize;
  int get parallelSlots => _settings.parallelSlots;
  int get imageMaxTokens => _settings.imageMaxTokens;
  FlashAttentionMode get flashAttentionMode => _settings.flashAttentionMode;
  bool get useMmap => _settings.useMmap;
  bool get logEnabled => _settings.logEnabled;
  ServerLogLevel get logLevel => _settings.logLevel;

  String get host => _settings.host;

  String get statusText {
    if (_statusMessage != null && _statusMessage!.isNotEmpty) {
      return _statusMessage!;
    }
    return AppL10nService.instance.current.serverConfigStatusSaved;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Saves can complete after the config page (and this page-scoped provider)
  // has been popped; notifying after dispose trips the debug assertion.
  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _statusMessage = AppL10nService.instance.current.serverConfigStatusLoading;
    notifyListeners();

    try {
      _settings = await _settingsLoader.load();
      _statusMessage = AppL10nService.instance.current.serverConfigStatusLoaded;
    } catch (error) {
      _statusMessage = AppL10nService.instance.current.serverConfigStatusLoadFailed(
        error.toString(),
      );
    } finally {
      _hasCompletedInitialLoad = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetToDefaults() {
    return _apply(const ServerLaunchSettings());
  }

  Future<void> updateListenMode(ServerListenMode value) {
    return _apply(_settings.copyWith(listenMode: value));
  }

  Future<void> updatePort(int value) {
    return _apply(
      _settings.copyWith(
        port: _clamp(
          value,
          ServerLaunchSettings.minPort,
          ServerLaunchSettings.maxPort,
        ),
      ),
    );
  }

  Future<void> updateApiKey(String value) {
    return _apply(_settings.copyWith(apiKey: value.trim()));
  }

  Future<void> updateContextSize(int value) {
    return _apply(
      _settings.copyWith(
        contextSize: _clamp(
          value,
          ServerLaunchSettings.minContextSize,
          ServerLaunchSettings.maxContextSize,
        ),
      ),
    );
  }

  Future<void> updateCpuThreads(int value) {
    return _apply(
      _settings.copyWith(
        cpuThreads: _clamp(
          value,
          ServerLaunchSettings.minCpuThreads,
          ServerLaunchSettings.maxCpuThreads,
        ),
      ),
    );
  }

  Future<void> updateBatchSize(int value) {
    return _apply(
      _settings.copyWith(
        batchSize: _clamp(
          value,
          ServerLaunchSettings.minBatchSize,
          ServerLaunchSettings.maxBatchSize,
        ),
      ),
    );
  }

  Future<void> updateParallelSlots(int value) {
    return _apply(
      _settings.copyWith(
        parallelSlots: _clamp(
          value,
          ServerLaunchSettings.minParallelSlots,
          ServerLaunchSettings.maxParallelSlots,
        ),
      ),
    );
  }

  Future<void> updateImageMaxTokens(int value) {
    return _apply(
      _settings.copyWith(
        imageMaxTokens: _clamp(
          value,
          ServerLaunchSettings.minImageMaxTokens,
          ServerLaunchSettings.maxImageMaxTokens,
        ),
      ),
    );
  }

  Future<void> updateFlashAttentionMode(FlashAttentionMode value) {
    return _apply(_settings.copyWith(flashAttentionMode: value));
  }

  Future<void> updateUseMmap(bool value) {
    return _apply(_settings.copyWith(useMmap: value));
  }

  Future<void> updateLogEnabled(bool value) {
    return _apply(_settings.copyWith(logEnabled: value));
  }

  Future<void> updateLogLevel(ServerLogLevel value) {
    return _apply(_settings.copyWith(logLevel: value));
  }

  /// Applies and persists a settings change. No-ops when nothing changed so
  /// text-field rebuilds don't trigger redundant disk writes.
  Future<void> _apply(ServerLaunchSettings next) async {
    if (_settingsEqual(_settings, next)) {
      return;
    }
    _settings = next;

    _statusMessage = AppL10nService.instance.current.serverConfigStatusSaving;
    notifyListeners();

    try {
      await _settingsLoader.save(_settings);
      _statusMessage = AppL10nService.instance.current.serverConfigStatusSaved;
    } catch (error) {
      _statusMessage = AppL10nService.instance.current.serverConfigStatusSaveFailed(
        error.toString(),
      );
    } finally {
      notifyListeners();
    }
  }

  bool _settingsEqual(ServerLaunchSettings a, ServerLaunchSettings b) {
    return a.listenMode == b.listenMode &&
        a.port == b.port &&
        a.apiKey == b.apiKey &&
        a.contextSize == b.contextSize &&
        a.cpuThreads == b.cpuThreads &&
        a.batchSize == b.batchSize &&
        a.parallelSlots == b.parallelSlots &&
        a.imageMaxTokens == b.imageMaxTokens &&
        a.flashAttentionMode == b.flashAttentionMode &&
        a.useMmap == b.useMmap &&
        a.logEnabled == b.logEnabled &&
        a.logLevel == b.logLevel;
  }

  static int _clamp(int value, int min, int max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }
}
