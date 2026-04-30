import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppLocaleProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('defaults to system locale mode', () async {
      final provider = AppLocaleProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.localeMode, AppLocaleMode.system);
      expect(provider.locale, isNull);
      expect(provider.hasLoaded, isTrue);
    });

    test('loads stored locale mode from local storage', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        AppPrefsKeys.localeMode: 'en',
      });
      final provider = AppLocaleProvider(kvStorage: KvStorage());

      await provider.load();

      expect(provider.localeMode, AppLocaleMode.en);
      expect(provider.locale, const Locale('en'));
    });

    test('persists updated locale mode', () async {
      final storage = KvStorage();
      final provider = AppLocaleProvider(kvStorage: storage);

      await provider.updateLocaleMode(AppLocaleMode.zh);

      expect(provider.localeMode, AppLocaleMode.zh);
      expect(await storage.getString(AppPrefsKeys.localeMode), 'zh');
    });
  });
}
