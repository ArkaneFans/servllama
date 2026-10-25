import 'package:flutter/material.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

enum AppLocaleMode { system, zh, en }

class AppLocaleProvider extends ChangeNotifier {
  AppLocaleProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance {
    _syncGlobalL10n();
  }

  final KvStorage _kvStorage;

  AppLocaleMode _localeMode = AppLocaleMode.system;
  bool _hasLoaded = false;

  AppLocaleMode get localeMode => _localeMode;
  bool get hasLoaded => _hasLoaded;

  Locale? get locale {
    switch (_localeMode) {
      case AppLocaleMode.system:
        // if system language not supported, use the first supported language
        return null;
      case AppLocaleMode.zh:
        return const Locale('zh');
      case AppLocaleMode.en:
        return const Locale('en');
    }
  }

  Future<void>? _loadFuture;
  bool _disposed = false;

  Future<void> load() => _hasLoaded
      ? Future<void>.value()
      : _loadFuture ??= _load().whenComplete(() => _loadFuture = null);

  Future<void> _load() async {
    if (_hasLoaded) {
      return;
    }

    final storedValue = await _kvStorage.getString(AppPrefsKeys.localeMode);
    if (_disposed) return;
    _localeMode = _localeModeFromStorage(storedValue);
    _syncGlobalL10n();
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateLocaleMode(AppLocaleMode value) async {
    await load();
    if (_disposed) return;
    if (_localeMode == value) {
      return;
    }

    _localeMode = value;
    await _kvStorage.setString(
      AppPrefsKeys.localeMode,
      _localeModeToStorage(value),
    );
    _syncGlobalL10n();
    notifyListeners();
  }

  void _syncGlobalL10n() {
    AppL10nService.instance.setLocale(locale);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  static String _localeModeToStorage(AppLocaleMode value) {
    switch (value) {
      case AppLocaleMode.system:
        return 'system';
      case AppLocaleMode.zh:
        return 'zh';
      case AppLocaleMode.en:
        return 'en';
    }
  }

  static AppLocaleMode _localeModeFromStorage(String? value) {
    switch (value) {
      case 'zh':
        return AppLocaleMode.zh;
      case 'en':
        return AppLocaleMode.en;
      case 'system':
      default:
        return AppLocaleMode.system;
    }
  }
}
