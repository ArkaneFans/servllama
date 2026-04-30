import 'package:flutter/widgets.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

extension AppL10nBuildContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ??
      lookupAppLocalizations(const Locale('zh'));
}
