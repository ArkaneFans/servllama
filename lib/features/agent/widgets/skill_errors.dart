import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

String skillFormatErrorMessage(AppLocalizations l, Object error) {
  if (error is SkillFormatException) {
    return switch (error.error) {
      SkillFormatError.missingName => l.v2SkillNameRequired,
      SkillFormatError.missingDescription => l.v2SkillDescriptionRequired,
      SkillFormatError.invalidMetadata => l.v2SkillMetadataInvalid,
    };
  }
  return l.v2SkillImportInvalid;
}
