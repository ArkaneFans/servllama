import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';

void main() {
  group('ServerLaunchArgsBuilder', () {
    const builder = ServerLaunchArgsBuilder();
    const modelsDirectoryPath = '/app/models';

    test('builds default args without optional flags', () {
      expect(
        builder.build(
          const ServerLaunchSettings(),
          modelsDirectoryPath: modelsDirectoryPath,
        ),
        <String>[
          '--host',
          '127.0.0.1',
          '--port',
          '8080',
          '--models-dir',
          modelsDirectoryPath,
          '--ctx-size',
          '4096',
          '--batch-size',
          '2048',
          '--threads',
          '2',
          '--parallel',
          '1',
          '--flash-attn',
          'off',
        ],
      );
    });

    test('includes optional flags when configured', () {
      final settings = ServerLaunchSettings(
        listenMode: ServerListenMode.allInterfaces,
        port: 11434,
        apiKey: 'secret',
        contextSize: 8192,
        cpuThreads: 8,
        batchSize: 1024,
        parallelSlots: 4,
        flashAttentionMode: FlashAttentionMode.enabled,
        useMmap: false,
      );

      expect(
        builder.build(settings, modelsDirectoryPath: modelsDirectoryPath),
        <String>[
          '--host',
          '0.0.0.0',
          '--port',
          '11434',
          '--models-dir',
          modelsDirectoryPath,
          '--ctx-size',
          '8192',
          '--batch-size',
          '1024',
          '--threads',
          '8',
          '--parallel',
          '4',
          '--flash-attn',
          'on',
          '--no-mmap',
          '--api-key',
          'secret',
        ],
      );
    });
  });
}
