import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/settings/widgets/download_settings_section.dart';
import 'package:servllama/l10n/l10n.dart';

class DownloadSettingsPage extends StatelessWidget {
  const DownloadSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: Text(context.l10n.settingsSectionDownload)),
    body: const SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: DownloadSettingsSection(),
      ),
    ),
  );
}
