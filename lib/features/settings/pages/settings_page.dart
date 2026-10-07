import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/features/about/pages/about_page.dart';
import 'package:servllama/features/agent/pages/mcp_servers_page.dart';
import 'package:servllama/features/agent/pages/skills_page.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/pages/connections_page.dart';
import 'package:servllama/features/assistants/pages/profile_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/features/logs/pages/app_logs_page.dart';
import 'package:servllama/features/mnn_test/pages/mnn_test_page.dart';
import 'package:servllama/features/server/pages/debug_page.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/settings/pages/download_settings_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer3<
      AppThemeModeProvider,
      AppLocaleProvider,
      ChatTimeoutProvider
    >(
      builder:
          (context, themeProvider, localeProvider, chatTimeoutProvider, _) {
            return AppScaffold(
              appBar: AppBar(title: Text(l10n.settingsTitle)),
              body: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    const _ProfileSettingsCard(),
                    const SizedBox(height: 24),
                    SettingsSection(
                      title: l10n.settingsSectionGeneral,
                      child: SettingsTileList(
                        children: [
                          SettingsMenuTile(
                            key: const Key('settings_theme_mode_tile'),
                            icon: Icons.palette_outlined,
                            title: l10n.settingsThemeMode,
                            value: _themeModeLabel(
                              l10n,
                              themeProvider.themeMode,
                            ),
                            onTap: () =>
                                _showThemeModeSheet(context, themeProvider),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_downloads_tile'),
                            icon: Icons.download_outlined,
                            title: l10n.settingsSectionDownload,
                            onTap: () =>
                                _push(context, const DownloadSettingsPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_language_tile'),
                            icon: Icons.language_rounded,
                            title: l10n.settingsLanguage,
                            value: _localeModeLabel(
                              l10n,
                              localeProvider.localeMode,
                            ),
                            onTap: () =>
                                _showLanguageSheet(context, localeProvider),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SettingsSection(
                      title: l10n.settingsSectionChat,
                      child: SettingsTileList(
                        children: [
                          SettingsMenuTile(
                            key: const Key('settings_assistants_tile'),
                            icon: Icons.smart_toy_outlined,
                            title: l10n.v2AssistantManagement,
                            onTap: () => _push(context, const AssistantsPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_providers_tile'),
                            icon: Icons.cloud_outlined,
                            title: l10n.v2Connections,
                            onTap: () =>
                                _push(context, const ConnectionsPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_skills_tile'),
                            icon: Icons.extension_outlined,
                            title: l10n.v2Skills,
                            onTap: () => _push(context, const SkillsPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_mcp_tile'),
                            icon: Icons.hub_outlined,
                            title: l10n.v2Mcp,
                            onTap: () => _push(context, const McpServersPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_chat_timeout_tile'),
                            icon: Icons.timer_outlined,
                            title: l10n.settingsChatTimeout,
                            value: l10n.settingsChatTimeoutValue(
                              chatTimeoutProvider.timeoutSeconds,
                            ),
                            onTap: () => _showChatTimeoutSheet(
                              context,
                              chatTimeoutProvider,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SettingsSection(
                      title: l10n.settingsSectionServices,
                      child: SettingsTileList(
                        children: [
                          SettingsMenuTile(
                            key: const Key('settings_server_tile'),
                            icon: Icons.dns_outlined,
                            title: l10n.drawerServer,
                            onTap: () => _push(context, const ServerPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_speech_tile'),
                            icon: Icons.graphic_eq_rounded,
                            title: l10n.v2Speech,
                            onTap: () => _push(context, const SpeechPage()),
                          ),
                          SettingsMenuTile(
                            key: const Key('settings_logs_tile'),
                            icon: Icons.receipt_long_outlined,
                            title: l10n.appLogsTitle,
                            onTap: () => _push(context, const AppLogsPage()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SettingsSection(
                      title: l10n.settingsSectionAbout,
                      child: SettingsTileList(
                        children: [
                          SettingsMenuTile(
                            icon: Icons.info_outline_rounded,
                            key: const Key('settings_about_tile'),
                            title: l10n.settingsAbout,
                            onTap: () => _push(context, const AboutPage()),
                          ),
                        ],
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 18),
                      SettingsSection(
                        title: l10n.settingsSectionDeveloper,
                        child: SettingsTileList(
                          children: [
                            SettingsMenuTile(
                              key: const Key('settings_mnn_test_tile'),
                              icon: Icons.memory_outlined,
                              title: l10n.settingsMnnTest,
                              onTap: () => _push(context, const MnnTestPage()),
                            ),
                            SettingsMenuTile(
                              key: const Key('settings_debug_tile'),
                              icon: Icons.bug_report_outlined,
                              title: l10n.settingsDebug,
                              onTap: () => _push(context, const DebugPage()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
    );
  }

  static Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
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

  static Future<void> _showChatTimeoutSheet(
    BuildContext context,
    ChatTimeoutProvider provider,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _ChatTimeoutSheet(provider: provider),
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

  static String _localeModeLabel(AppLocalizations l10n, AppLocaleMode value) {
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

class _ProfileSettingsCard extends StatelessWidget {
  const _ProfileSettingsCard();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AssistantProvider>().profile;
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('settings_profile_tile'),
        onTap: () => SettingsPage._push(context, const ProfilePage()),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              IdentityAvatar(
                value: profile.avatar,
                name: profile.name,
                size: 52,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isEmpty ? l.settingsUser : profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.name.isEmpty ? l.v2ProfileHelp : l.settingsUser,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
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

/// Owns the timeout field's controller so it lives exactly as long as the
/// sheet does — disposing it right after `showModalBottomSheet` returns tears
/// it down while the closing animation is still rebuilding the field.
class _ChatTimeoutSheet extends StatefulWidget {
  const _ChatTimeoutSheet({required this.provider});

  final ChatTimeoutProvider provider;

  @override
  State<_ChatTimeoutSheet> createState() => _ChatTimeoutSheetState();
}

class _ChatTimeoutSheetState extends State<_ChatTimeoutSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.provider.timeoutSeconds.toString(),
  );
  late int _draftValue = widget.provider.timeoutSeconds;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _clampedInput {
    final parsed = int.tryParse(_controller.text.trim());
    return (parsed ?? _draftValue).clamp(
      ChatTimeoutProvider.minTimeoutSeconds,
      ChatTimeoutProvider.maxTimeoutSeconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          28 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsChatTimeoutSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsChatTimeoutDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('settings_chat_timeout_input'),
              controller: _controller,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed == null) {
                  return;
                }
                setState(() {
                  _draftValue = parsed.clamp(
                    ChatTimeoutProvider.minTimeoutSeconds,
                    ChatTimeoutProvider.maxTimeoutSeconds,
                  );
                });
              },
              decoration: InputDecoration(
                labelText: l10n.settingsChatTimeoutFieldLabel,
                suffixText: l10n.settingsChatTimeoutUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsChatTimeoutRange(
                ChatTimeoutProvider.minTimeoutSeconds,
                ChatTimeoutProvider.maxTimeoutSeconds,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('settings_chat_timeout_save_button'),
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await widget.provider.updateTimeoutSeconds(_clampedInput);
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                  },
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
