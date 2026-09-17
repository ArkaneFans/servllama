import 'package:flutter/material.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/segmented_setting.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';

class MnnBackendSettings extends StatefulWidget {
  const MnnBackendSettings({super.key});

  @override
  State<MnnBackendSettings> createState() => _MnnBackendSettingsState();
}

class _MnnBackendSettingsState extends State<MnnBackendSettings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ServerConfigProvider>();
      provider.loadMnnBackends();
      provider.loadMnnMmapCache();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerConfigProvider>();
    final runtime = context.watch<EngineRuntimeProvider>();
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final active = provider.activeMnnBackend;
    final savedUnavailable =
        provider.mnnBackend != MnnBackend.cpu &&
        !provider.loadingMnnBackends &&
        provider.mnnCapabilities.isNotEmpty &&
        !provider.mnnCapabilities.any(
          (item) => item.backend == provider.mnnBackend && item.available,
        );
    final cacheBusy = runtime.isRunning || runtime.isBusy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          key: const Key('mnn_backend_settings'),
          title: l10n.mnnBackendTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      active == null
                          ? l10n.mnnBackendNextStart
                          : l10n.mnnBackendActive(_name(l10n, active)),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('mnn_backend_refresh'),
                    tooltip: l10n.mnnBackendRefresh,
                    onPressed: provider.loadingMnnBackends
                        ? null
                        : provider.loadMnnBackends,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (active != null)
                Text(
                  l10n.mnnBackendNextStart,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (provider.loadingMnnBackends) const LinearProgressIndicator(),
              if (provider.mnnBackendError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.mnnBackendProbeFailed,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              if (savedUnavailable)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.mnnBackendSavedUnavailable,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              for (final backend
                  in ServerLaunchSettings.supportedMnnBackends) ...[
                if (backend != MnnBackend.cpu) const Divider(height: 1),
                _backendTile(context, provider, backend),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        SettingsSection(
          key: const Key('mnn_runtime_settings'),
          title: l10n.mnnRuntimeTitle,
          child: SettingsTileList(
            children: [
              SegmentedSetting<MnnPrecision>(
                key: const Key('mnn_precision'),
                label: l10n.mnnPrecision,
                description: l10n.mnnPrecisionDescription,
                value: provider.mnnPrecision,
                options: [
                  SegmentedSettingOption(
                    value: MnnPrecision.low,
                    label: l10n.mnnPrecisionLow,
                  ),
                  SegmentedSettingOption(
                    value: MnnPrecision.high,
                    label: l10n.mnnPrecisionHigh,
                  ),
                ],
                onChanged: provider.updateMnnPrecision,
              ),
              SliderNumberSetting(
                key: const Key('mnn_thread_num'),
                label: l10n.mnnThreadNum,
                description: l10n.mnnThreadNumDescription,
                value: provider.mnnThreadNum,
                min: ServerLaunchSettings.minMnnThreadNum,
                max: ServerLaunchSettings.maxMnnThreadNum,
                divisions:
                    ServerLaunchSettings.maxMnnThreadNum -
                    ServerLaunchSettings.minMnnThreadNum,
                onChanged: provider.updateMnnThreadNum,
              ),
              SwitchSettingTile(
                key: const Key('mnn_use_mmap'),
                title: l10n.mnnUseMmap,
                subtitle: l10n.mnnUseMmapSubtitle,
                value: provider.mnnUseMmap,
                onChanged: provider.updateMnnUseMmap,
              ),
              ListTile(
                key: const Key('mnn_clear_mmap_cache'),
                contentPadding: EdgeInsets.zero,
                enabled:
                    !cacheBusy &&
                    !provider.clearingMnnMmapCache &&
                    !provider.loadingMnnMmapCache &&
                    provider.mnnMmapCacheBytes > 0,
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(l10n.mnnMmapCache),
                subtitle: Text(_cacheSubtitle(l10n, provider, cacheBusy)),
                trailing: provider.clearingMnnMmapCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap:
                    cacheBusy ||
                        provider.clearingMnnMmapCache ||
                        provider.loadingMnnMmapCache ||
                        provider.mnnMmapCacheBytes <= 0
                    ? null
                    : () => _confirmClearMmapCache(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _cacheSubtitle(
    AppLocalizations l10n,
    ServerConfigProvider provider,
    bool cacheBusy,
  ) {
    if (cacheBusy) {
      return l10n.mnnMmapCacheStopServer;
    }
    if (provider.mnnMmapCacheBytes <= 0) {
      return l10n.mnnMmapCacheEmpty;
    }
    return l10n.mnnMmapCacheSubtitle(
      FormatUtils.bytes(provider.mnnMmapCacheBytes),
    );
  }

  Future<void> _confirmClearMmapCache(BuildContext context) async {
    final provider = context.read<ServerConfigProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(dialogL10n.mnnMmapCacheDialogTitle),
          content: Text(
            dialogL10n.mnnMmapCacheDialogContent(
              FormatUtils.bytes(provider.mnnMmapCacheBytes),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogL10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogL10n.mnnMmapCacheClearAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final sizeLabel = FormatUtils.bytes(provider.mnnMmapCacheBytes);
    final cleared = await provider.clearMnnMmapCache();
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? context.l10n.mnnMmapCacheCleared(sizeLabel)
              : context.l10n.mnnMmapCacheClearFailed,
        ),
      ),
    );
  }

  Widget _backendTile(
    BuildContext context,
    ServerConfigProvider provider,
    MnnBackend backend,
  ) {
    final l10n = context.l10n;
    final capability = provider.mnnCapabilities
        .where((item) => item.backend == backend)
        .firstOrNull;
    final selectable =
        backend == MnnBackend.cpu ||
        (!provider.loadingMnnBackends && capability?.available == true);
    final selected = provider.mnnBackend == backend;
    final status = capability?.status ?? MnnBackendStatus.unknown;
    final description =
        capability?.available == true ||
            (backend == MnnBackend.cpu && capability == null)
        ? switch (backend) {
            MnnBackend.cpu => l10n.mnnBackendCpuDescription,
            MnnBackend.opencl ||
            MnnBackend.vulkan => l10n.mnnBackendGpuDescription,
            MnnBackend.hexagon => l10n.mnnBackendHexagonDescription,
          }
        : _status(l10n, status);
    final matchedArchitecture =
        backend == MnnBackend.hexagon && capability?.available == true
        ? capability?.dspArchitecture
        : null;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        key: Key('mnn_backend_${backend.name}'),
        contentPadding: EdgeInsets.zero,
        enabled: selectable,
        leading: Icon(switch (backend) {
          MnnBackend.cpu => Icons.memory_outlined,
          MnnBackend.opencl ||
          MnnBackend.vulkan => Icons.developer_board_outlined,
          MnnBackend.hexagon => Icons.bolt_outlined,
        }),
        title: Text(_name(l10n, backend)),
        subtitle: Text(
          matchedArchitecture == null
              ? description
              : '${l10n.mnnBackendHexagonArchitecture(matchedArchitecture)}\n$description',
        ),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
        ),
        onTap: selectable ? () => provider.updateMnnBackend(backend) : null,
      ),
    );
  }

  String _name(AppLocalizations l10n, MnnBackend backend) => switch (backend) {
    MnnBackend.cpu => l10n.mnnBackendCpu,
    MnnBackend.opencl => l10n.mnnBackendOpencl,
    MnnBackend.vulkan => l10n.mnnBackendVulkan,
    MnnBackend.hexagon => l10n.mnnBackendHexagon,
  };

  String _status(AppLocalizations l10n, MnnBackendStatus status) =>
      switch (status) {
        MnnBackendStatus.notBuilt => l10n.mnnBackendNotBuilt,
        MnnBackendStatus.nativeUnavailable => l10n.mnnBackendNativeUnavailable,
        MnnBackendStatus.runtimeLibrariesMissing =>
          l10n.mnnBackendLibrariesMissing,
        MnnBackendStatus.driverUnavailable => l10n.mnnBackendDriverUnavailable,
        MnnBackendStatus.deviceUnsupported => l10n.mnnBackendDeviceUnsupported,
        MnnBackendStatus.available ||
        MnnBackendStatus.unknown => l10n.mnnBackendNotChecked,
      };
}
