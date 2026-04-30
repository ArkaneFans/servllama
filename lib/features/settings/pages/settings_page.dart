import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/features/about/pages/about_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer2<AppThemeModeProvider, AppLocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              SettingsSection(
                title: l10n.settingsSectionGeneral,
                child: _SectionItems(
                  children: [
                    _MenuTile(
                      key: const Key('settings_theme_mode_tile'),
                      icon: Icons.palette_outlined,
                      title: l10n.settingsThemeMode,
                      value: _themeModeLabel(l10n, themeProvider.themeMode),
                      onTap: () => _showThemeModeSheet(context, themeProvider),
                    ),
                    _MenuTile(
                      key: const Key('settings_language_tile'),
                      icon: Icons.language_rounded,
                      title: l10n.settingsLanguage,
                      value: _localeModeLabel(
                        l10n,
                        localeProvider.localeMode,
                      ),
                      onTap: () => _showLanguageSheet(context, localeProvider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SettingsSection(
                title: l10n.settingsSectionAbout,
                child: _SectionItems(
                  children: [
                    _MenuTile(
                      icon: Icons.info_outline_rounded,
                      title: l10n.settingsAbout,
                      onTap: () => _push(context, const AboutPage()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  static Future<void> _showThemeModeSheet(
    BuildContext context,
    AppThemeModeProvider provider,
  ) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsThemeModeSheetTitle,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ..._themeModeOptions.map(
                (option) => _ThemeModeSheetOption(
                  themeMode: option,
                  label: _themeModeLabel(l10n, option),
                  isSelected: provider.themeMode == option,
                  onTap: () async {
                    await provider.updateThemeMode(option);
                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showLanguageSheet(
    BuildContext context,
    AppLocaleProvider provider,
  ) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsLanguageSheetTitle,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ..._localeModeOptions.map(
                (option) => _LocaleModeSheetOption(
                  localeMode: option,
                  label: _localeModeLabel(l10n, option),
                  isSelected: provider.localeMode == option,
                  onTap: () async {
                    await provider.updateLocaleMode(option);
                    if (!sheetContext.mounted) {
                      return;
                    }
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const List<ThemeMode> _themeModeOptions = <ThemeMode>[
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];

  static const List<AppLocaleMode> _localeModeOptions = <AppLocaleMode>[
    AppLocaleMode.system,
    AppLocaleMode.zh,
    AppLocaleMode.en,
  ];

  static String _themeModeLabel(AppLocalizations l10n, ThemeMode value) {
    switch (value) {
      case ThemeMode.system:
        return l10n.themeModeSystem;
      case ThemeMode.light:
        return l10n.themeModeLight;
      case ThemeMode.dark:
        return l10n.themeModeDark;
    }
  }

  static String _localeModeLabel(
    AppLocalizations l10n,
    AppLocaleMode value,
  ) {
    switch (value) {
      case AppLocaleMode.system:
        return l10n.languageModeSystem;
      case AppLocaleMode.zh:
        return '简体中文 (ZH)';
      case AppLocaleMode.en:
        return 'English (EN)';
    }
  }
}

class _SectionItems extends StatelessWidget {
  const _SectionItems({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: children[index],
          ),
          if (index != children.length - 1)
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(90),
            ),
        ],
      ],
    );
  }
}

class _MenuTile extends StatefulWidget {
  const _MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final contentOpacity = _isPressed ? 0.58 : 1.0;

    return Semantics(
      button: true,
      enabled: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: contentOpacity,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.value != null) ...[
                const SizedBox(width: 12),
                Text(
                  widget.value!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModeSheetOption extends StatelessWidget {
  const _ThemeModeSheetOption({
    required this.themeMode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final ThemeMode themeMode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_theme_mode_option_${themeMode.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocaleModeSheetOption extends StatelessWidget {
  const _LocaleModeSheetOption({
    required this.localeMode,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final AppLocaleMode localeMode;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('settings_language_option_${localeMode.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
