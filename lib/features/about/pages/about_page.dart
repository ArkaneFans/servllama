import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/services/app_info_service.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:url_launcher/url_launcher.dart';

const _kGitHubUrl = 'https://github.com/ArkaneFans/servllama';
const _kPendingValue = '\u2014';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _appVersion = _kPendingValue;
  String _llamaCppVersion = _kPendingValue;
  String _mnnVersion = _kPendingValue;

  @override
  void initState() {
    super.initState();
    final service = context.read<AppInfoService?>() ?? AppInfoService();
    final cached = service.cached;
    if (cached != null) {
      _applyInfo(cached);
    } else {
      unawaited(
        service.load().then((info) {
          if (mounted) setState(() => _applyInfo(info));
        }),
      );
    }
  }

  void _applyInfo(AppInfo info) {
    _appVersion = info.app;
    _llamaCppVersion = info.llamaCpp;
    _mnnVersion = info.mnn;
  }

  void _copyAppVersion() {
    if (_appVersion == _kPendingValue) {
      return;
    }
    unawaited(() async {
      try {
        await Clipboard.setData(ClipboardData(text: _appVersion));
      } catch (_) {}
    }());
    AppMessage.show(context, context.l10n.aboutVersionCopied);
  }

  Future<void> _openGitHub() async {
    try {
      await launchUrl(
        Uri.parse(_kGitHubUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _openLicenses() {
    showLicensePage(
      context: context,
      applicationName: 'ServLlama',
      applicationIcon: Padding(
        padding: const EdgeInsets.all(8),
        child: const BundledSvgAsset(
          'assets/app_icon.svg',
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  Widget _trailingValue(String value, {IconData? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (icon != null) ...[
          const SizedBox(width: 4),
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _AboutHero(),
            const SizedBox(height: 18),
            SettingsSection.grouped(
              children: [
                SettingsMenuTile(
                  key: const Key('about_version_tile'),
                  icon: Icons.info_outline_rounded,
                  title: l10n.aboutVersionLabel,
                  subtitle: l10n.aboutVersionSubtitle,
                  onTap: _copyAppVersion,
                  trailing: _trailingValue(
                    _appVersion,
                    icon: Icons.copy_rounded,
                  ),
                ),
                SettingsMenuTile(
                  key: const Key('about_system_tile'),
                  icon: Icons.smartphone_outlined,
                  title: l10n.aboutSystem,
                  subtitle: l10n.aboutSystemSubtitle,
                  value: _systemLabel(),
                ),
                SettingsMenuTile(
                  key: const Key('about_llamacpp_tile'),
                  icon: Icons.memory_outlined,
                  title: l10n.aboutLlamaCppLabel,
                  subtitle: l10n.aboutLlamaCppSubtitle,
                  value: _llamaCppVersion,
                ),
                SettingsMenuTile(
                  key: const Key('about_mnn_tile'),
                  icon: Icons.developer_board_outlined,
                  title: l10n.aboutMnnVersion,
                  subtitle: l10n.aboutMnnSubtitle,
                  value: _mnnVersion,
                ),
              ],
            ),
            const SizedBox(height: 18),
            SettingsSection.grouped(
              children: [
                SettingsMenuTile(
                  key: const Key('about_github_tile'),
                  icon: Icons.star_outline_rounded,
                  title: l10n.aboutStarOnGitHub,
                  subtitle: l10n.aboutGitHubSubtitle,
                  onTap: () => unawaited(_openGitHub()),
                  trailing: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SettingsMenuTile(
                  key: const Key('about_license_tile'),
                  icon: Icons.description_outlined,
                  title: l10n.aboutLicense,
                  subtitle: l10n.aboutLicenseSubtitle,
                  onTap: _openLicenses,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SettingsSection(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          SizedBox(
            key: const Key('about_hero_icon'),
            width: 64,
            height: 64,
            child: const BundledSvgAsset('assets/app_icon.svg'),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ServLlama',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.aboutDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _systemLabel() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'Android';
    case TargetPlatform.iOS:
      return 'iOS';
    case TargetPlatform.macOS:
      return 'macOS';
    case TargetPlatform.windows:
      return 'Windows';
    case TargetPlatform.linux:
      return 'Linux';
    case TargetPlatform.fuchsia:
      return 'Fuchsia';
  }
}
