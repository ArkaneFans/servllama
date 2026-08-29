import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';
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
    unawaited(_loadAppVersion());
    unawaited(_loadLlamaCppVersion());
    unawaited(_loadMnnVersion());
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      final label = [
        if (version.isNotEmpty) version,
        if (buildNumber.isNotEmpty) buildNumber,
      ].join(' / ');
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = label.isEmpty ? _kPendingValue : label;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _appVersion = _kPendingValue;
      });
    }
  }

  Future<void> _loadLlamaCppVersion() async {
    try {
      final version = (await LlamaServerService().loadBundledVersion()).trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _llamaCppVersion = version.isEmpty ? _kPendingValue : version;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _llamaCppVersion = _kPendingValue;
      });
    }
  }

  Future<void> _loadMnnVersion() async {
    try {
      final info = await MnnEngine.instance.initialize();
      final commit = info.mnnCommit.trim();
      final shortCommit = commit.length > 10 ? commit.substring(0, 10) : commit;
      final detail = shortCommit.isEmpty || shortCommit == 'unknown'
          ? info.mnnVersion
          : '${info.mnnVersion} \u00b7 $shortCommit';
      if (!mounted) {
        return;
      }
      setState(() {
        _mnnVersion = detail.trim().isEmpty ? _kPendingValue : detail;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mnnVersion = _kPendingValue;
      });
    }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.aboutVersionCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
        child: SvgPicture.asset('assets/app_icon.svg', width: 48, height: 48),
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const _AboutHero(),
            const SizedBox(height: 18),
            SettingsSection(
              child: SettingsTileList(
                children: [
                  SettingsMenuTile(
                    key: const Key('about_version_tile'),
                    icon: Icons.info_outline_rounded,
                    title: l10n.aboutVersionLabel,
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
                    value: _systemLabel(),
                  ),
                  SettingsMenuTile(
                    key: const Key('about_llamacpp_tile'),
                    icon: Icons.memory_outlined,
                    title: l10n.aboutLlamaCppLabel,
                    value: _llamaCppVersion,
                  ),
                  SettingsMenuTile(
                    key: const Key('about_mnn_tile'),
                    icon: Icons.developer_board_outlined,
                    title: l10n.aboutMnnVersion,
                    value: _mnnVersion,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSection(
              child: SettingsTileList(
                children: [
                  SettingsMenuTile(
                    key: const Key('about_github_tile'),
                    icon: Icons.star_outline_rounded,
                    title: l10n.aboutStarOnGitHub,
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
                    onTap: _openLicenses,
                  ),
                ],
              ),
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
            child: SvgPicture.asset('assets/app_icon.svg'),
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
