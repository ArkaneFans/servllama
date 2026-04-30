import 'package:flutter/material.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';

class AppThemeModeProvider extends ChangeNotifier {
  AppThemeModeProvider({KvStorage? kvStorage})
    : _kvStorage = kvStorage ?? KvStorage.instance;

  final KvStorage _kvStorage;

  ThemeMode _themeMode = ThemeMode.system;
  bool _hasLoaded = false;

  ThemeMode get themeMode => _themeMode;
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    if (_hasLoaded) {
      return;
    }

    final storedValue = await _kvStorage.getString(AppPrefsKeys.themeMode);
    _themeMode = _themeModeFromStorage(storedValue);
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode value) async {
    if (_themeMode == value) {
      return;
    }

    _themeMode = value;
    await _kvStorage.setString(AppPrefsKeys.themeMode, _themeModeToStorage(value));
    notifyListeners();
  }

  static String _themeModeToStorage(ThemeMode value) {
    switch (value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}
