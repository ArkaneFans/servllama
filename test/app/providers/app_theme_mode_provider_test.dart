import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppThemeModeProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to system theme mode', () async {
      final provider = AppThemeModeProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.themeMode, ThemeMode.system);
      expect(provider.hasLoaded, isTrue);
    });

    test('loads stored theme mode from local storage', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPrefsKeys.themeMode: 'dark',
      });
      final provider = AppThemeModeProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.themeMode, ThemeMode.dark);
    });

    test('persists updated theme mode', () async {
      final storage = KvStorage();
      final provider = AppThemeModeProvider(kvStorage: storage);

      await provider.updateThemeMode(ThemeMode.light);

      expect(provider.themeMode, ThemeMode.light);
      expect(await storage.getString(AppPrefsKeys.themeMode), 'light');
    });
  });
}
