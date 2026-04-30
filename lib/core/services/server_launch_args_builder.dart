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
      '--ctx-size',
      '${settings.contextSize}',
      '--batch-size',
      '${settings.batchSize}',
      '--threads',
      '${settings.cpuThreads}',
      '--parallel',
      '${settings.parallelSlots}',
      '--flash-attn',
      settings.flashAttentionMode.cliValue,
    ];
    if (!settings.useMmap) {
      args.add('--no-mmap');
    }
    if (settings.apiKey.isNotEmpty) {
      args
        ..add('--api-key')
        ..add(settings.apiKey);
    }

    return args;
  }
}
