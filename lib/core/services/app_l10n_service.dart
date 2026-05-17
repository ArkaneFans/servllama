import 'dart:ui';

import 'package:servllama/l10n/generated/app_localizations.dart';

class AppL10nService {
  AppL10nService._();

  static final AppL10nService instance = AppL10nService._();

  Locale? _appLocale;

  AppLocalizations get current => lookupAppLocalizations(effectiveLocale);

  Locale? get appLocale => _appLocale;

  Locale get effectiveLocale =>
      _resolveSupportedLocale(_appLocale ?? PlatformDispatcher.instance.locale);

  void setLocale(Locale? locale) {
    _appLocale = locale;
  }

  static Locale _resolveSupportedLocale(Locale locale) {
    for (final supportedLocale in AppLocalizations.supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return const Locale('zh');
  }
}
