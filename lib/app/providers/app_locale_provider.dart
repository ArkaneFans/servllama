import 'package:flutter/material.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

enum AppLocaleMode { system, zh, en }

class AppLocaleProvider extends ChangeNotifier {
  AppLocaleProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  AppLocaleMode _localeMode = AppLocaleMode.system;
  bool _hasLoaded = false;

  AppLocaleMode get localeMode => _localeMode;
  bool get hasLoaded => _hasLoaded;

  Locale? get locale {
    switch (_localeMode) {
      case AppLocaleMode.system:
        return null;
      case AppLocaleMode.zh:
        return const Locale('zh');
      case AppLocaleMode.en:
        return const Locale('en');
    }
  }

  Future<void> load() async {
    if (_hasLoaded) {
      return;
    }

    final storedValue = await _kvStorage.getString(AppPrefsKeys.localeMode);
    _localeMode = _localeModeFromStorage(storedValue);
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateLocaleMode(AppLocaleMode value) async {
    if (_localeMode == value) {
      return;
    }

    _localeMode = value;
    await _kvStorage.setString(
      AppPrefsKeys.localeMode,
      _localeModeToStorage(value),
    );
    notifyListeners();
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
