import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'preferences use defaults, save edits and restore them on the next load',
    () async {
      final storage = KvStorage();
      final theme = AppThemeModeProvider(kvStorage: storage);
      final locale = AppLocaleProvider(kvStorage: storage);
      final timeout = ChatTimeoutProvider(kvStorage: storage);
      addTearDown(theme.dispose);
      addTearDown(locale.dispose);
      addTearDown(timeout.dispose);
      await Future.wait([theme.load(), locale.load(), timeout.load()]);
      expect(theme.themeMode, ThemeMode.system);
      expect(locale.localeMode, AppLocaleMode.system);
      expect(timeout.timeoutSeconds, ChatTimeoutProvider.defaultTimeoutSeconds);
      await theme.updateThemeMode(ThemeMode.dark);
      await locale.updateLocaleMode(AppLocaleMode.en);
      await timeout.updateTimeoutSeconds(300);

      final restoredTheme = AppThemeModeProvider(kvStorage: storage);
      final restoredLocale = AppLocaleProvider(kvStorage: storage);
      final restoredTimeout = ChatTimeoutProvider(kvStorage: storage);
      addTearDown(restoredTheme.dispose);
      addTearDown(restoredLocale.dispose);
      addTearDown(restoredTimeout.dispose);
      await Future.wait([
        restoredTheme.load(),
        restoredLocale.load(),
        restoredTimeout.load(),
      ]);
      expect(restoredTheme.themeMode, ThemeMode.dark);
      expect(restoredLocale.locale, const Locale('en'));
      expect(AppL10nService.instance.appLocale, const Locale('en'));
      expect(restoredTimeout.timeout, const Duration(seconds: 300));
    },
  );
}
