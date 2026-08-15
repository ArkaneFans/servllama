import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:servllama/core/storage/download_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';

/// Which Hugging Face origin to fetch from. The mirror exists because the
/// official host is frequently unreachable from mainland China.
enum HuggingFaceRoute {
  auto,
  official,
  mirror;

  static HuggingFaceRoute fromStorageValue(String? value) {
    for (final route in HuggingFaceRoute.values) {
      if (route.name == value) {
        return route;
      }
    }
    return HuggingFaceRoute.auto;
  }
}

class DownloadSettings {
  const DownloadSettings({
    this.huggingFaceRoute = HuggingFaceRoute.auto,
    this.huggingFaceToken = '',
    this.modelScopeToken = '',
    this.wifiOnly = true,
    this.maxConcurrentTasks = defaultMaxConcurrentTasks,
    this.preferredSource = ModelHubSource.huggingFace,
  });

  static const int defaultMaxConcurrentTasks = 1;
  static const int minConcurrentTasksValue = 1;
  static const int maxConcurrentTasksValue = 2;

  final HuggingFaceRoute huggingFaceRoute;
  final String huggingFaceToken;
  final String modelScopeToken;
  final bool wifiOnly;
  final int maxConcurrentTasks;
  final ModelHubSource preferredSource;

  String? tokenFor(ModelHubSource source) {
    switch (source) {
      case ModelHubSource.huggingFace:
        return huggingFaceToken.isEmpty ? null : huggingFaceToken;
      case ModelHubSource.modelScope:
        return modelScopeToken.isEmpty ? null : modelScopeToken;
    }
  }

  DownloadSettings copyWith({
    HuggingFaceRoute? huggingFaceRoute,
    String? huggingFaceToken,
    String? modelScopeToken,
    bool? wifiOnly,
    int? maxConcurrentTasks,
    ModelHubSource? preferredSource,
  }) {
    return DownloadSettings(
      huggingFaceRoute: huggingFaceRoute ?? this.huggingFaceRoute,
      huggingFaceToken: huggingFaceToken ?? this.huggingFaceToken,
      modelScopeToken: modelScopeToken ?? this.modelScopeToken,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      maxConcurrentTasks: maxConcurrentTasks ?? this.maxConcurrentTasks,
      preferredSource: preferredSource ?? this.preferredSource,
    );
  }
}

/// Reads and writes download preferences. Tokens are credentials: they are
/// never logged and never included in exported log files.
class DownloadSettingsStore {
  DownloadSettingsStore({
    KvStorage? kvStorage,
    FlutterSecureStorage? secureStorage,
  }) : _kvStorage = kvStorage ?? KvStorage.instance,
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           );

  final KvStorage _kvStorage;
  final FlutterSecureStorage _secureStorage;

  static const String _hfTokenKey = 'servllama.download.hf_token';
  static const String _modelScopeTokenKey = 'servllama.download.ms_token';

  Future<DownloadSettings> load() async {
    return DownloadSettings(
      huggingFaceRoute: HuggingFaceRoute.fromStorageValue(
        await _kvStorage.getString(DownloadPrefsKeys.huggingFaceRoute),
      ),
      huggingFaceToken: await _loadCredential(
        _hfTokenKey,
        DownloadPrefsKeys.huggingFaceToken,
      ),
      modelScopeToken: await _loadCredential(
        _modelScopeTokenKey,
        DownloadPrefsKeys.modelScopeToken,
      ),
      wifiOnly: await _kvStorage.getBool(DownloadPrefsKeys.wifiOnly) ?? true,
      maxConcurrentTasks:
          await _kvStorage.getInt(DownloadPrefsKeys.maxConcurrentTasks) ??
          DownloadSettings.defaultMaxConcurrentTasks,
      preferredSource: ModelHubSource.fromStorageValue(
        await _kvStorage.getString(DownloadPrefsKeys.preferredSource),
      ),
    );
  }

  Future<void> saveHuggingFaceRoute(HuggingFaceRoute route) =>
      _kvStorage.setString(DownloadPrefsKeys.huggingFaceRoute, route.name);

  Future<void> saveHuggingFaceToken(String token) =>
      _saveCredential(_hfTokenKey, DownloadPrefsKeys.huggingFaceToken, token);

  Future<void> saveModelScopeToken(String token) => _saveCredential(
    _modelScopeTokenKey,
    DownloadPrefsKeys.modelScopeToken,
    token,
  );

  Future<void> saveWifiOnly(bool value) =>
      _kvStorage.setBool(DownloadPrefsKeys.wifiOnly, value);

  Future<void> saveMaxConcurrentTasks(int value) =>
      _kvStorage.setInt(DownloadPrefsKeys.maxConcurrentTasks, value);

  Future<void> savePreferredSource(ModelHubSource source) => _kvStorage
      .setString(DownloadPrefsKeys.preferredSource, source.storageValue);

  Future<String> _loadCredential(String key, String legacyKey) async {
    try {
      final value = await _secureStorage.read(key: key);
      if (value != null) {
        return value;
      }
    } on MissingPluginException catch (_) {
      return '';
    } on PlatformException catch (_) {}

    final legacy = await _kvStorage.getString(legacyKey) ?? '';
    if (legacy.isEmpty) {
      return '';
    }
    try {
      await _secureStorage.write(key: key, value: legacy);
      await _kvStorage.remove(legacyKey);
    } on MissingPluginException catch (_) {
    } on PlatformException catch (_) {}
    return legacy;
  }

  Future<void> _saveCredential(
    String key,
    String legacyKey,
    String value,
  ) async {
    try {
      if (value.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
      await _kvStorage.remove(legacyKey);
    } on MissingPluginException catch (_) {
      // Widget tests and unsupported platforms keep the in-memory provider
      // value without falling back to plaintext preferences.
    }
  }
}
