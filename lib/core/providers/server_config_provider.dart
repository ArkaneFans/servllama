import 'package:flutter/foundation.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

class ServerConfigProvider extends ChangeNotifier {
  ServerConfigProvider({
    ServerLaunchSettingsLoader? settingsLoader,
    KvStorage? kvStorage,
  }) : _kvStorage = kvStorage ?? KvStorage.instance,
       _settingsLoader =
           settingsLoader ??
           ServerLaunchSettingsLoader(
             kvStorage: kvStorage ?? KvStorage.instance,
           );

  final KvStorage _kvStorage;
  final ServerLaunchSettingsLoader _settingsLoader;

  bool _hasCompletedInitialLoad = false;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _statusMessage;

  ServerListenMode _listenMode = ServerListenMode.localhost;
  int _port = ServerLaunchSettings.defaultPort;
  String _apiKey = '';
  int _contextSize = ServerLaunchSettings.defaultContextSize;
  int _cpuThreads = ServerLaunchSettings.defaultCpuThreads;
  int _batchSize = ServerLaunchSettings.defaultBatchSize;
  int _parallelSlots = ServerLaunchSettings.defaultParallelSlots;
  FlashAttentionMode _flashAttentionMode =
      ServerLaunchSettings.defaultFlashAttentionMode;
  bool _useMmap = true;

  bool get hasCompletedInitialLoad => _hasCompletedInitialLoad;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get statusMessage => _statusMessage;

  ServerListenMode get listenMode => _listenMode;
  int get port => _port;
  String get apiKey => _apiKey;
  int get contextSize => _contextSize;
  int get cpuThreads => _cpuThreads;
  int get batchSize => _batchSize;
  int get parallelSlots => _parallelSlots;
  FlashAttentionMode get flashAttentionMode => _flashAttentionMode;
  bool get useMmap => _useMmap;

  String get host =>
      _listenMode == ServerListenMode.localhost ? '127.0.0.1' : '0.0.0.0';

  String get statusText {
    if (_statusMessage != null && _statusMessage!.isNotEmpty) {
      return _statusMessage!;
    }
    return '配置已保存';
  }

  Future<void> load() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _statusMessage = '正在加载配置...';
    notifyListeners();

    try {
      _applySettings(await _settingsLoader.load());
      _statusMessage = '配置已加载';
    } catch (error) {
      _statusMessage = '加载失败: $error';
    } finally {
      _hasCompletedInitialLoad = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetToDefaults() async {
    _applySettings(const ServerLaunchSettings());
    notifyListeners();
    await _saveAllFields();
  }

  Future<void> updateListenMode(ServerListenMode value) async {
    if (_listenMode == value) {
      return;
    }
    _listenMode = value;
    await _saveString(ServerPrefsKeys.listenMode, _listenMode.name);
  }

  Future<void> updatePort(int value) async {
    final nextValue = _clamp(
      value,
      ServerLaunchSettings.minPort,
      ServerLaunchSettings.maxPort,
    );
    if (_port == nextValue) {
      return;
    }
    _port = nextValue;
    await _saveInt(ServerPrefsKeys.port, _port);
  }

  Future<void> updateApiKey(String value) async {
    final nextValue = value.trim();
    if (_apiKey == nextValue) {
      return;
    }
    _apiKey = nextValue;
    await _saveString(ServerPrefsKeys.apiKey, _apiKey);
  }

  Future<void> updateContextSize(int value) async {
    final nextValue = _clamp(
      value,
      ServerLaunchSettings.minContextSize,
      ServerLaunchSettings.maxContextSize,
    );
    if (_contextSize == nextValue) {
      return;
    }
    _contextSize = nextValue;
    await _saveInt(ServerPrefsKeys.contextSize, _contextSize);
  }

  Future<void> updateCpuThreads(int value) async {
    final nextValue = _clamp(
      value,
      ServerLaunchSettings.minCpuThreads,
      ServerLaunchSettings.maxCpuThreads,
    );
    if (_cpuThreads == nextValue) {
      return;
    }
    _cpuThreads = nextValue;
    await _saveInt(ServerPrefsKeys.cpuThreads, _cpuThreads);
  }

  Future<void> updateBatchSize(int value) async {
    final nextValue = _clamp(
      value,
      ServerLaunchSettings.minBatchSize,
      ServerLaunchSettings.maxBatchSize,
    );
    if (_batchSize == nextValue) {
      return;
    }
    _batchSize = nextValue;
    await _saveInt(ServerPrefsKeys.batchSize, _batchSize);
  }

  Future<void> updateParallelSlots(int value) async {
    final nextValue = _clamp(
      value,
      ServerLaunchSettings.minParallelSlots,
      ServerLaunchSettings.maxParallelSlots,
    );
    if (_parallelSlots == nextValue) {
      return;
    }
    _parallelSlots = nextValue;
    await _saveInt(ServerPrefsKeys.parallelSlots, _parallelSlots);
  }

  Future<void> updateFlashAttentionMode(FlashAttentionMode value) async {
    if (_flashAttentionMode == value) {
      return;
    }
    _flashAttentionMode = value;
    await _saveString(
      ServerPrefsKeys.flashAttentionMode,
      _flashAttentionMode.name,
    );
  }

  Future<void> updateUseMmap(bool value) async {
    if (_useMmap == value) {
      return;
    }
    _useMmap = value;
    await _saveBool(ServerPrefsKeys.useMmap, _useMmap);
  }

  void _applySettings(ServerLaunchSettings settings) {
    _listenMode = settings.listenMode;
    _port = settings.port;
    _apiKey = settings.apiKey;
    _contextSize = settings.contextSize;
    _cpuThreads = settings.cpuThreads;
    _batchSize = settings.batchSize;
    _parallelSlots = settings.parallelSlots;
    _flashAttentionMode = settings.flashAttentionMode;
    _useMmap = settings.useMmap;
  }

  Future<void> _saveString(String key, String value) {
    return _runSave(() => _kvStorage.setString(key, value));
  }

  Future<void> _saveInt(String key, int value) {
    return _runSave(() => _kvStorage.setInt(key, value));
  }

  Future<void> _saveBool(String key, bool value) {
    return _runSave(() => _kvStorage.setBool(key, value));
  }

  Future<void> _saveAllFields() {
    return _runSave(() async {
      await _kvStorage.setString(ServerPrefsKeys.listenMode, _listenMode.name);
      await _kvStorage.setInt(ServerPrefsKeys.port, _port);
      await _kvStorage.setString(ServerPrefsKeys.apiKey, _apiKey);
      await _kvStorage.setInt(ServerPrefsKeys.contextSize, _contextSize);
      await _kvStorage.setInt(ServerPrefsKeys.cpuThreads, _cpuThreads);
      await _kvStorage.setInt(ServerPrefsKeys.batchSize, _batchSize);
      await _kvStorage.setInt(ServerPrefsKeys.parallelSlots, _parallelSlots);
      await _kvStorage.setString(
        ServerPrefsKeys.flashAttentionMode,
        _flashAttentionMode.name,
      );
      await _kvStorage.setBool(ServerPrefsKeys.useMmap, _useMmap);
    });
  }

  Future<void> _runSave(Future<void> Function() operation) async {
    _isSaving = true;
    _statusMessage = '正在保存配置...';
    notifyListeners();

    try {
      await operation();
      _statusMessage = '配置已保存';
    } catch (error) {
      _statusMessage = '保存失败: $error';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
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
