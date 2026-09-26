import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';

class LlamaCppBackendSettings extends StatefulWidget {
  const LlamaCppBackendSettings({super.key});

  @override
  State<LlamaCppBackendSettings> createState() =>
      _LlamaCppBackendSettingsState();
}

class _LlamaCppBackendSettingsState extends State<LlamaCppBackendSettings> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final running = context.read<EngineRuntimeProvider>().isRunning;
      context.read<ServerConfigProvider>().loadLlamaCppBackends(
        allowProcess: !running,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerConfigProvider>();
    final running = context.select<EngineRuntimeProvider, bool>(
      (runtime) => runtime.isRunning,
    );
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final probe = provider.llamaCppProbe;
    final probeKnown =
        provider.llamaCppBackendsResolved && !provider.loadingLlamaCppBackends;
    final savedUnavailable =
        probeKnown &&
        provider.llamaCppBackendError == null &&
        ServerLaunchSettings.supportedLlamaCppBackends.contains(
          provider.llamaCppBackend,
        ) &&
        switch (provider.llamaCppBackend) {
          LlamaCppBackend.opencl => !probe.openclAvailable,
          LlamaCppBackend.hexagon => !probe.hexagonAvailable,
          _ => false,
        };
    return SettingsSection(
      key: const Key('llama_cpp_backend_settings'),
      title: l10n.llamaCppBackendTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.llamaCppBackendNextStart,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                key: const Key('llama_cpp_backend_refresh'),
                tooltip: l10n.llamaCppBackendRefresh,
                onPressed: provider.loadingLlamaCppBackends || running
                    ? null
                    : () => provider.loadLlamaCppBackends(force: true),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (running)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.llamaCppBackendStopServer,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (provider.loadingLlamaCppBackends) const LinearProgressIndicator(),
          if (provider.llamaCppBackendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.llamaCppBackendProbeFailed,
                style: TextStyle(color: colors.error),
              ),
            ),
          if (savedUnavailable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.llamaCppBackendSavedUnavailable,
                style: TextStyle(color: colors.error),
              ),
            ),
          for (final backend
              in ServerLaunchSettings.supportedLlamaCppBackends) ...[
            if (backend != LlamaCppBackend.cpu) const Divider(height: 1),
            _backendTile(context, provider, backend, probe, probeKnown),
          ],
          if (provider.llamaCppBackend != LlamaCppBackend.cpu) ...[
            const Divider(height: 1),
            SliderNumberSetting(
              key: const Key('llama_cpp_gpu_layers'),
              label: l10n.llamaCppGpuLayers,
              description: l10n.llamaCppGpuLayersDescription,
              value: provider.llamaCppGpuLayers,
              min: ServerLaunchSettings.minLlamaCppGpuLayers,
              max: ServerLaunchSettings.maxLlamaCppGpuLayers,
              divisions:
                  ServerLaunchSettings.maxLlamaCppGpuLayers -
                  ServerLaunchSettings.minLlamaCppGpuLayers,
              onChanged: provider.updateLlamaCppGpuLayers,
            ),
          ],
        ],
      ),
    );
  }

  Widget _backendTile(
    BuildContext context,
    ServerConfigProvider provider,
    LlamaCppBackend backend,
    LlamaCppDeviceProbeResult probe,
    bool probeKnown,
  ) {
    final l10n = context.l10n;
    final selectable = switch (backend) {
      LlamaCppBackend.cpu => true,
      LlamaCppBackend.opencl => probeKnown && probe.openclAvailable,
      LlamaCppBackend.hexagon => probeKnown && probe.hexagonAvailable,
    };
    final selected = provider.llamaCppBackend == backend;
    return ListTile(
      key: Key('llama_cpp_backend_${backend.name}'),
      contentPadding: EdgeInsets.zero,
      enabled: selectable,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(_name(l10n, backend)),
      subtitle: Text(_description(l10n, backend, selectable, probeKnown)),
      onTap: selectable ? () => provider.updateLlamaCppBackend(backend) : null,
    );
  }

  String _name(AppLocalizations l10n, LlamaCppBackend backend) {
    return switch (backend) {
      LlamaCppBackend.cpu => l10n.llamaCppBackendCpu,
      LlamaCppBackend.opencl => l10n.llamaCppBackendOpencl,
      LlamaCppBackend.hexagon => l10n.llamaCppBackendHexagon,
    };
  }

  String _description(
    AppLocalizations l10n,
    LlamaCppBackend backend,
    bool selectable,
    bool probeKnown,
  ) {
    if (probeKnown && !selectable) {
      return l10n.llamaCppBackendUnavailable;
    }
    return switch (backend) {
      LlamaCppBackend.cpu => l10n.llamaCppBackendCpuDescription,
      LlamaCppBackend.opencl => l10n.llamaCppBackendOpenclDescription,
      LlamaCppBackend.hexagon => l10n.llamaCppBackendHexagonDescription,
    };
  }
}
