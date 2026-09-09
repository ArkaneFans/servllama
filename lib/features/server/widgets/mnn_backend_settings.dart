import 'package:flutter/material.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

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
      if (mounted) context.read<ServerConfigProvider>().loadMnnBackends();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerConfigProvider>();
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
    return SettingsSection(
      key: const Key('mnn_backend_settings'),
      title: l10n.mnnBackendTitle,
      subtitle: l10n.mnnBackendDescription,
      child: Column(
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
          for (final backend in MnnBackend.values) ...[
            if (backend != MnnBackend.cpu) const Divider(height: 1),
            _backendTile(context, provider, backend),
          ],
        ],
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
