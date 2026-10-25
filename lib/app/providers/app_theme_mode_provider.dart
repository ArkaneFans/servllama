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

  Future<void>? _loadFuture;
  bool _disposed = false;

  Future<void> load() => _hasLoaded
      ? Future<void>.value()
      : _loadFuture ??= _load().whenComplete(() => _loadFuture = null);

  Future<void> _load() async {
    if (_hasLoaded) {
      return;
    }

    final storedValue = await _kvStorage.getString(AppPrefsKeys.themeMode);
    if (_disposed) return;
    _themeMode = _themeModeFromStorage(storedValue);
    _hasLoaded = true;
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode value) async {
    await load();
    if (_disposed) return;
    if (_themeMode == value) {
      return;
    }

    _themeMode = value;
    await _kvStorage.setString(
      AppPrefsKeys.themeMode,
      _themeModeToStorage(value),
    );
    notifyListeners();
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
