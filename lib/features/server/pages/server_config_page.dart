import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/shared/widgets/outlined_text_setting.dart';
import 'package:servllama/shared/widgets/segmented_setting.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';
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
      context.read<EngineRuntimeProvider>().setEndpoint(
        host: configProvider.host,
        port: configProvider.port,
        apiKey: configProvider.apiKey,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerConfigProvider>(
      builder: (context, provider, _) {
        final l10n = context.l10n;
        final activeEngine = context
            .select<EngineRuntimeProvider, InferenceEngine>(
              (runtime) => runtime.activeEngine,
            );
        return Scaffold(
          appBar: AppBar(title: Text(l10n.serverConfigTitle)),
          body: !provider.hasCompletedInitialLoad
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: EngineBadge(engine: activeEngine),
                                ),
                                if (provider.listenMode ==
                                        ServerListenMode.allInterfaces &&
                                    provider.apiKey.trim().isEmpty) ...[
                                  const SizedBox(height: 10),
                                  NoticeBanner(
                                    key: const Key(
                                      'server_config_open_access_warning',
                                    ),
                                    tone: StatusTone.warning,
                                    icon: Icons.security_rounded,
                                    message: l10n.serverOpenAccessWarning,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SettingsSection(
                            title: l10n.serverConfigSectionNetwork,
                            child: SettingsTileList(
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
                                  onChanged: (value) async {
                                    await provider.updateApiKey(value);
                                    if (context.mounted) {
                                      _syncEndpoint(context);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          if (activeEngine == InferenceEngine.llamaCpp) ...[
                            const SizedBox(height: 18),
                            SettingsSection(
                              title: l10n.serverConfigSectionInference,
                              child: SettingsTileList(
                                children: [
                                  SliderNumberSetting(
                                    label: l10n.serverConfigContextSize,
                                    description:
                                        l10n.serverConfigContextSizeDescription,
                                    value: provider.contextSize,
                                    min: ServerLaunchSettings.minContextSize,
                                    max: ServerLaunchSettings.maxContextSize,
                                    divisions: _contextSizeDivisions,
                                    onChanged: (value) =>
                                        provider.updateContextSize(
                                          _roundToStep(value, _contextSizeStep),
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
                                    onChanged: (value) =>
                                        provider.updateBatchSize(
                                          _roundToStep(value, 32),
                                        ),
                                  ),
                                  SliderNumberSetting(
                                    label: l10n.serverConfigImageMaxTokens,
                                    description: l10n
                                        .serverConfigImageMaxTokensDescription,
                                    value: provider.imageMaxTokens,
                                    min: 128,
                                    max: 4096,
                                    divisions: 31,
                                    onChanged: (value) =>
                                        provider.updateImageMaxTokens(
                                          _roundToStep(value, 128),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            SettingsSection(
                              title: l10n.serverConfigSectionPerformance,
                              child: SettingsTileList(
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
                                    description: l10n
                                        .serverConfigParallelSlotsDescription,
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
                              child: SettingsTileList(
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
                                    onChanged:
                                        provider.updateFlashAttentionMode,
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
                          ],
                          const SizedBox(height: 18),
                          SettingsSection(
                            title: l10n.serverConfigSectionLogging,
                            child: SettingsTileList(
                              children: [
                                SwitchSettingTile(
                                  title: l10n.serverConfigLogEnabled,
                                  subtitle: l10n.serverConfigLogEnabledSubtitle,
                                  value: provider.logEnabled,
                                  onChanged: provider.updateLogEnabled,
                                ),
                                SegmentedSetting<ServerLogLevel>(
                                  label: l10n.serverConfigLogLevel,
                                  description:
                                      l10n.serverConfigLogLevelDescription,
                                  value: provider.logLevel,
                                  options: [
                                    SegmentedSettingOption(
                                      value: ServerLogLevel.error,
                                      label: l10n.serverConfigLogLevelError,
                                    ),
                                    SegmentedSettingOption(
                                      value: ServerLogLevel.warning,
                                      label: l10n.serverConfigLogLevelWarning,
                                    ),
                                    SegmentedSettingOption(
                                      value: ServerLogLevel.info,
                                      label: l10n.serverConfigLogLevelInfo,
                                    ),
                                    SegmentedSettingOption(
                                      value: ServerLogLevel.debug,
                                      label: l10n.serverConfigLogLevelDebug,
                                    ),
                                  ],
                                  onChanged: provider.updateLogLevel,
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
                              onTap: provider.isLoading
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
    context.read<EngineRuntimeProvider>().setEndpoint(
      host: configProvider.host,
      port: configProvider.port,
      apiKey: configProvider.apiKey,
    );
  }

  static const int _contextSizeStep = 512;

  static int get _contextSizeDivisions =>
      (ServerLaunchSettings.maxContextSize -
          ServerLaunchSettings.minContextSize) ~/
      _contextSizeStep;

  static int _roundToStep(int value, int step) {
    final roundedValue = (value / step).round() * step;
    return roundedValue < step ? step : roundedValue;
  }
}
