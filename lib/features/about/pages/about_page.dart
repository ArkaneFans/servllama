import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

const _kGitHubUrl = 'https://github.com/ArkaneFans/servllama';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // App icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SvgPicture.asset('assets/app_icon.svg'),
                ),
                const SizedBox(height: 18),
                // App name
                Text(
                  'ServLlama',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                // Description
                Text(
                  l10n.aboutDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Version (tappable to copy)
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.hasData
                        ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                        : '-';
                    return _VersionChip(
                      version: l10n.aboutVersion(version),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: version));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.aboutVersionCopied),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 28),
                // Star on GitHub
                ListTile(
                  leading: const Icon(Icons.star_outline_rounded),
                  title: Text(l10n.aboutStarOnGitHub),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () => launchUrl(Uri.parse(_kGitHubUrl)),
                ),
                const SizedBox(height: 8),
                // License
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(l10n.aboutLicense),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationIcon: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SvgPicture.asset(
                        'assets/app_icon.svg',
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionChip extends StatefulWidget {
  const _VersionChip({required this.version, this.onTap});

  final String version;
  final VoidCallback? onTap;

  @override
  State<_VersionChip> createState() => _VersionChipState();
}

class _VersionChipState extends State<_VersionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.6 : 1,
        duration: const Duration(milliseconds: 120),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.version,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy_rounded,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
