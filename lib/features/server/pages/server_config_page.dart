import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/shared/widgets/outlined_text_setting.dart';
import 'package:servllama/shared/widgets/segmented_setting.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';
import 'package:servllama/l10n/l10n.dart';

class ServerConfigPage extends StatelessWidget {
  const ServerConfigPage({super.key, this.provider});

  final ServerConfigProvider? provider;

  @override
  Widget build(BuildContext context) {
    final provider = this.provider;
    if (provider != null) {
      return ChangeNotifierProvider<ServerConfigProvider>.value(
        value: provider,
        child: const _ServerConfigView(),
      );
    }

    return ChangeNotifierProvider<ServerConfigProvider>(
      create: (_) => ServerConfigProvider(),
      child: const _ServerConfigView(),
    );
  }
}

class _ServerConfigView extends StatefulWidget {
  const _ServerConfigView();

  @override
  State<_ServerConfigView> createState() => _ServerConfigViewState();
}

class _ServerConfigViewState extends State<_ServerConfigView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final configProvider = context.read<ServerConfigProvider>();
      if (!configProvider.hasCompletedInitialLoad) {
        await configProvider.load();
      }
      if (!mounted) {
        return;
      }
      context.read<ServerProvider>().setEndpoint(
        host: configProvider.host,
        port: configProvider.port,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerConfigProvider>(
      builder: (context, provider, _) {
        final l10n = context.l10n;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.serverConfigTitle)),
          body: !provider.hasCompletedInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    if (provider.isSaving)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          SettingsSection(
                            title: l10n.serverConfigSectionNetwork,
                            child: _SectionItems(
                              children: [
                                SegmentedSetting<ServerListenMode>(
                                  label: l10n.serverConfigListenMode,
                                  description:
                                      l10n.serverConfigListenModeDescription,
                                  value: provider.listenMode,
                                  options: [
                                    SegmentedSettingOption(
                                      value: ServerListenMode.localhost,
                                      label: l10n.serverConfigListenLocalhost,
                                    ),
                                    SegmentedSettingOption(
                                      value: ServerListenMode.allInterfaces,
                                      label:
                                          l10n.serverConfigListenAllInterfaces,
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    await provider.updateListenMode(value);
                                    if (!context.mounted) {
                                      return;
                                    }
                                    _syncEndpoint(context);
                                  },
                                ),
                                OutlinedTextSetting(
                                  label: l10n.serverConfigPort,
                                  description: l10n.serverConfigPortDescription,
                                  hintText: '8080',
                                  value: '${provider.port}',
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) async {
                                    final parsedValue = int.tryParse(value);
                                    if (parsedValue != null) {
                                      await provider.updatePort(parsedValue);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      _syncEndpoint(context);
                                    }
                                  },
                                ),
                                OutlinedTextSetting(
                                  label: l10n.serverConfigApiKey,
                                  description:
                                      l10n.serverConfigApiKeyDescription,
                                  hintText: l10n.commonOptional,
                                  value: provider.apiKey,
                                  onChanged: provider.updateApiKey,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SettingsSection(
                            title: l10n.serverConfigSectionInference,
                            child: _SectionItems(
                              children: [
                                SliderNumberSetting(
                                  label: l10n.serverConfigContextSize,
                                  description:
                                      l10n.serverConfigContextSizeDescription,
                                  value: provider.contextSize,
                                  min: 512,
                                  max: 32768,
                                  divisions: 63,
                                  onChanged: (value) =>
                                      provider.updateContextSize(
                                        _roundToStep(value, 512),
                                      ),
                                ),
                                SliderNumberSetting(
                                  label: l10n.serverConfigBatchSize,
                                  description:
                                      l10n.serverConfigBatchSizeDescription,
                                  value: provider.batchSize,
                                  min: 32,
                                  max: 4096,
                                  divisions: 127,
                                  onChanged: (value) => provider
                                      .updateBatchSize(_roundToStep(value, 32)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SettingsSection(
                            title: l10n.serverConfigSectionPerformance,
                            child: _SectionItems(
                              children: [
                                SliderNumberSetting(
                                  label: l10n.serverConfigCpuThreads,
                                  description:
                                      l10n.serverConfigCpuThreadsDescription,
                                  value: provider.cpuThreads,
                                  min: 1,
                                  max: 8,
                                  divisions: 7,
                                  onChanged: provider.updateCpuThreads,
                                ),
                                SliderNumberSetting(
                                  label: l10n.serverConfigParallelSlots,
                                  description:
                                      l10n.serverConfigParallelSlotsDescription,
                                  value: provider.parallelSlots,
                                  min: 1,
                                  max: 8,
                                  divisions: 7,
                                  onChanged: provider.updateParallelSlots,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SettingsSection(
                            title: l10n.serverConfigSectionAdvanced,
                            child: _SectionItems(
                              children: [
                                SegmentedSetting<FlashAttentionMode>(
                                  label: l10n.serverConfigFlashAttention,
                                  description: l10n
                                      .serverConfigFlashAttentionDescription,
                                  value: provider.flashAttentionMode,
                                  options: [
                                    SegmentedSettingOption(
                                      value: FlashAttentionMode.auto,
                                      label: l10n.commonAuto,
                                    ),
                                    SegmentedSettingOption(
                                      value: FlashAttentionMode.enabled,
                                      label: l10n.commonEnable,
                                    ),
                                    SegmentedSettingOption(
                                      value: FlashAttentionMode.disabled,
                                      label: l10n.commonDisable,
                                    ),
                                  ],
                                  onChanged: provider.updateFlashAttentionMode,
                                ),
                                SwitchSettingTile(
                                  title: l10n.serverConfigUseMmap,
                                  subtitle: l10n.serverConfigUseMmapSubtitle,
                                  value: provider.useMmap,
                                  onChanged: provider.updateUseMmap,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          SettingsSection(
                            title: l10n.serverConfigSectionReset,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.restore_outlined),
                              title: Text(l10n.serverConfigResetTitle),
                              subtitle: Text(l10n.serverConfigResetSubtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: provider.isLoading || provider.isSaving
                                  ? null
                                  : () => _confirmResetToDefaults(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmResetToDefaults(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.serverConfigResetDialogTitle),
          content: Text(l10n.serverConfigResetDialogContent),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.serverConfigResetAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final configProvider = context.read<ServerConfigProvider>();
    await configProvider.resetToDefaults();
    if (!context.mounted) {
      return;
    }
    _syncEndpoint(context);
  }

  void _syncEndpoint(BuildContext context) {
    final configProvider = context.read<ServerConfigProvider>();
    if (!context.mounted) {
      return;
    }
    context.read<ServerProvider>().setEndpoint(
      host: configProvider.host,
      port: configProvider.port,
    );
  }

  static int _roundToStep(int value, int step) {
    final roundedValue = (value / step).round() * step;
    return roundedValue < step ? step : roundedValue;
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
            Divider(height: 1, color: colorScheme.outlineVariant.withAlpha(90)),
        ],
      ],
    );
  }
}
