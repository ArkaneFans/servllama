import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';

/// Download route, credentials and storage cleanup. Tokens live here rather
/// than on the discovery page because they are account settings, not part of
/// the browse flow.
class DownloadSettingsSection extends StatelessWidget {
  const DownloadSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<DownloadProvider>(
      builder: (context, downloads, _) {
        final settings = downloads.settings;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSection(
              title: l10n.settingsSectionDownload,
              child: SettingsTileList(
                children: [
                  SettingsMenuTile(
                    key: const Key('settings_hf_route_tile'),
                    icon: Icons.alt_route_rounded,
                    title: l10n.settingsHuggingFaceRoute,
                    value: _routeLabel(context, settings.huggingFaceRoute),
                    onTap: () => _showRouteSheet(context, downloads),
                  ),
                  SettingsMenuTile(
                    key: const Key('settings_hf_token_tile'),
                    icon: Icons.key_outlined,
                    title: l10n.settingsHuggingFaceToken,
                    value: _maskToken(context, settings.huggingFaceToken),
                    onTap: () => _showTokenSheet(
                      context,
                      downloads,
                      ModelHubSource.huggingFace,
                      settings.huggingFaceToken,
                    ),
                  ),
                  SettingsMenuTile(
                    key: const Key('settings_ms_token_tile'),
                    icon: Icons.key_outlined,
                    title: l10n.settingsModelScopeToken,
                    value: _maskToken(context, settings.modelScopeToken),
                    onTap: () => _showTokenSheet(
                      context,
                      downloads,
                      ModelHubSource.modelScope,
                      settings.modelScopeToken,
                    ),
                  ),
                  SettingsMenuTile(
                    key: const Key('settings_wifi_only_tile'),
                    icon: Icons.wifi_rounded,
                    title: l10n.settingsWifiOnly,
                    trailing: Switch.adaptive(
                      value: settings.wifiOnly,
                      onChanged: downloads.setWifiOnly,
                    ),
                    onTap: () => downloads.setWifiOnly(!settings.wifiOnly),
                  ),
                  SettingsMenuTile(
                    key: const Key('settings_max_concurrent_tile'),
                    icon: Icons.layers_outlined,
                    title: l10n.settingsMaxConcurrentDownloads,
                    value: '${settings.maxConcurrentTasks}',
                    onTap: () => _showConcurrencySheet(context, downloads),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SettingsSection(
              title: l10n.settingsSectionStorage,
              child: SettingsTileList(
                children: [_StorageTile(downloads: downloads)],
              ),
            ),
          ],
        );
      },
    );
  }

  String _routeLabel(BuildContext context, HuggingFaceRoute route) {
    final l10n = context.l10n;
    switch (route) {
      case HuggingFaceRoute.auto:
        return l10n.settingsRouteAuto;
      case HuggingFaceRoute.official:
        return l10n.settingsRouteOfficial;
      case HuggingFaceRoute.mirror:
        return l10n.settingsRouteMirror;
    }
  }

  /// Credentials are only ever shown masked; the full value never leaves the
  /// text field it was typed into.
  String _maskToken(BuildContext context, String token) {
    if (token.isEmpty) {
      return context.l10n.settingsTokenNotSet;
    }
    if (token.length <= 6) {
      return '••••••';
    }
    return '${token.substring(0, 3)}••••${token.substring(token.length - 3)}';
  }

  Future<void> _showRouteSheet(
    BuildContext context,
    DownloadProvider downloads,
  ) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<HuggingFaceRoute>(
          groupValue: downloads.settings.huggingFaceRoute,
          onChanged: (value) {
            if (value != null) {
              downloads.setHuggingFaceRoute(value);
            }
            Navigator.of(sheetContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final route in HuggingFaceRoute.values)
                RadioListTile<HuggingFaceRoute>(
                  value: route,
                  title: Text(_routeLabel(sheetContext, route)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Text(
                  l10n.settingsHuggingFaceRouteDescription,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTokenSheet(
    BuildContext context,
    DownloadProvider downloads,
    ModelHubSource source,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final l10n = context.l10n;
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${l10n.settingsTokenSheetTitle} · ${source.displayName}',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.settingsTokenDescription,
                  style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(sheetContext).pop(controller.text.trim()),
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
    if (token != null) {
      await downloads.setToken(source, token);
    }
  }

  Future<void> _showConcurrencySheet(
    BuildContext context,
    DownloadProvider downloads,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: RadioGroup<int>(
          groupValue: downloads.settings.maxConcurrentTasks,
          onChanged: (selected) {
            if (selected != null) {
              downloads.setMaxConcurrentTasks(selected);
            }
            Navigator.of(sheetContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var value = DownloadSettings.minConcurrentTasksValue;
                value <= DownloadSettings.maxConcurrentTasksValue;
                value++
              )
                RadioListTile<int>(value: value, title: Text('$value')),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageTile extends StatefulWidget {
  const _StorageTile({required this.downloads});

  final DownloadProvider downloads;

  @override
  State<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends State<_StorageTile> {
  int? _orphanedBytes;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final bytes = await widget.downloads.orphanedStagingBytes();
    if (mounted) {
      setState(() => _orphanedBytes = bytes);
    }
  }

  Future<void> _clear() async {
    await widget.downloads.clearOrphanedStaging();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsClearStagingDone)),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bytes = _orphanedBytes;
    final hasOrphans = bytes != null && bytes > 0;

    return SettingsMenuTile(
      key: const Key('settings_clear_staging_tile'),
      icon: Icons.cleaning_services_outlined,
      title: l10n.settingsClearStaging,
      value: bytes == null ? '' : FormatUtils.bytes(bytes),
      enabled: hasOrphans,
      onTap: hasOrphans ? _clear : null,
    );
  }
}
