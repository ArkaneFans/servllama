import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';

void main() {
  group('ServerLaunchArgsBuilder', () {
    const builder = ServerLaunchArgsBuilder();
    const modelPath = '/app/models/qwen/model.gguf';
    const modelAlias = 'qwen';

    test('builds default args without optional flags', () {
      expect(
        builder.build(
          const ServerLaunchSettings(),
          modelPath: modelPath,
          modelAlias: modelAlias,
        ),
        <String>[
          '--host',
          '127.0.0.1',
          '--port',
          '8080',
          '--model',
          modelPath,
          '--alias',
          modelAlias,
          '--ctx-size',
          '4096',
          '--batch-size',
          '2048',
          '--threads',
          '2',
          '--parallel',
          '1',
          '--image-max-tokens',
          '${ServerLaunchSettings.defaultImageMaxTokens}',
          '--flash-attn',
          'off',
          '--log-verbosity',
          '3',
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
        imageMaxTokens: 2048,
        flashAttentionMode: FlashAttentionMode.enabled,
        useMmap: false,
        logLevel: ServerLogLevel.debug,
      );

      expect(
        builder.build(
          settings,
          modelPath: modelPath,
          modelAlias: modelAlias,
          mmprojPath: '/app/models/qwen/mmproj.gguf',
        ),
        <String>[
          '--host',
          '0.0.0.0',
          '--port',
          '11434',
          '--model',
          modelPath,
          '--alias',
          modelAlias,
          '--ctx-size',
          '8192',
          '--batch-size',
          '1024',
          '--threads',
          '8',
          '--parallel',
          '4',
          '--image-max-tokens',
          '2048',
          '--flash-attn',
          'on',
          '--mmproj',
          '/app/models/qwen/mmproj.gguf',
          '--no-mmap',
          '--api-key',
          'secret',
          '--log-verbosity',
          '4',
        ],
      );
    });

    test(
      'disables llama-server logs without passing a verbosity threshold',
      () {
        const settings = ServerLaunchSettings(logEnabled: false);

        expect(
          builder.build(settings, modelPath: modelPath, modelAlias: modelAlias),
          <String>[
            '--host',
            '127.0.0.1',
            '--port',
            '8080',
            '--model',
            modelPath,
            '--alias',
            modelAlias,
            '--ctx-size',
            '4096',
            '--batch-size',
            '2048',
            '--threads',
            '2',
            '--parallel',
            '1',
            '--image-max-tokens',
            '${ServerLaunchSettings.defaultImageMaxTokens}',
            '--flash-attn',
            'off',
            '--log-disable',
          ],
        );
      },
    );
  });
}
