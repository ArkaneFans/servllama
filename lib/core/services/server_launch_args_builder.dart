import 'package:servllama/core/models/server_launch_settings.dart';

class ServerLaunchArgsBuilder {
  const ServerLaunchArgsBuilder();

  List<String> build(
    ServerLaunchSettings settings, {
    required String modelsDirectoryPath,
  }) {
    final args = <String>[
      '--host',
      settings.host,
      '--port',
      '${settings.port}',
      '--models-dir',
      modelsDirectoryPath,
      // Accelerator backends are dlopen'd automatically and -ngl defaults to
      // auto-offload, so CPU-only inference must be pinned explicitly with
      // "none".
      '--device',
      settings.isCpuDevice ? 'none' : settings.device,
      '--ctx-size',
      '${settings.contextSize}',
      '--batch-size',
      '${settings.batchSize}',
      '--threads',
      '${settings.cpuThreads}',
      '--parallel',
      '${settings.parallelSlots}',
      '--image-max-tokens',
      '${settings.imageMaxTokens}',
      '--flash-attn',
      settings.flashAttentionMode.cliValue,
    ];
    if (!settings.isCpuDevice &&
        settings.gpuLayers != ServerLaunchSettings.autoGpuLayers) {
      args
        ..add('--gpu-layers')
        ..add('${settings.gpuLayers}');
    }
    if (!settings.useMmap) {
      args.add('--no-mmap');
    }
    if (settings.apiKey.isNotEmpty) {
      args
        ..add('--api-key')
        ..add(settings.apiKey);
    }
    if (settings.logEnabled) {
      args
        ..add('--log-verbosity')
        ..add('${settings.logLevel.cliValue}');
    } else {
      args.add('--log-disable');
    }

    return args;
  }
}
