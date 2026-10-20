import 'package:servllama/shared/widgets/app_message.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openModelRepository(
  BuildContext context, {
  required ModelHubSource source,
  required String repoId,
}) async {
  var opened = false;
  try {
    opened = await launchUrl(
      source.repositoryUri(repoId),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    // The platform may have no application registered for web links.
  }
  if (!opened && context.mounted) {
    AppMessage.show(
      context,
      context.l10n.modelSettingsRepositoryOpenFailed,
      tone: AppMessageTone.error,
    );
  }
}
