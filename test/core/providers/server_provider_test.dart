import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

void main() {
  group('ServerProvider', () {
    test(
      'start loads saved settings and passes args to server service',
      () async {
        final service = FakeLlamaServerService();
        final provider = ServerProvider(
          serverService: service,
          settingsLoader: FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(
              listenMode: ServerListenMode.allInterfaces,
              port: 11434,
              apiKey: 'secret',
              contextSize: 8192,
              cpuThreads: 8,
              batchSize: 1024,
              parallelSlots: 4,
              flashAttentionMode: FlashAttentionMode.auto,
              useMmap: false,
            ),
          ),
          launchArgsBuilder: const ServerLaunchArgsBuilder(),
          modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
        );

        await provider.start();

        expect(service.startedArgs, <String>[
          '--host',
          '0.0.0.0',
          '--port',
          '11434',
          '--models-dir',
          'C:\\app\\models',
          '--ctx-size',
          '8192',
          '--batch-size',
          '1024',
          '--threads',
          '8',
          '--parallel',
          '4',
          '--flash-attn',
          'auto',
          '--no-mmap',
          '--api-key',
          'secret',
        ]);
        expect(provider.host, '0.0.0.0');
        expect(provider.port, 11434);
        expect(provider.isRunning, isTrue);
        expect(provider.lastError, isNull);
        provider.dispose();
        service.dispose();
      },
    );

    test('loadSavedEndpoint updates display endpoint', () async {
      final service = FakeLlamaServerService();
      final provider = ServerProvider(
        serverService: service,
        settingsLoader: FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(
            listenMode: ServerListenMode.allInterfaces,
            port: 9000,
          ),
        ),
        modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
      );

      await provider.loadSavedEndpoint();

      expect(provider.displayAddress, '0.0.0.0:9000');
      expect(provider.baseUrl, 'http://0.0.0.0:9000');
      provider.dispose();
      service.dispose();
    });

    test('updates panel status when service stops unexpectedly', () async {
      final service = FakeLlamaServerService();
      final provider = ServerProvider(
        serverService: service,
        settingsLoader: FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
      );

      await provider.start();
      expect(provider.isRunning, isTrue);

      service.simulateUnexpectedStop();
      await Future<void>.delayed(Duration.zero);

      expect(provider.isRunning, isFalse);
      expect(provider.lastError, isNull);
      provider.dispose();
      service.dispose();
    });

    test(
      'stop keeps state synchronized through running state stream',
      () async {
        final service = FakeLlamaServerService();
        final provider = ServerProvider(
          serverService: service,
          settingsLoader: FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
        );

        await provider.start();
        expect(provider.isRunning, isTrue);

        await provider.stop();

        expect(provider.isRunning, isFalse);
        expect(provider.lastError, isNull);
        provider.dispose();
        service.dispose();
      },
    );
  });
}

class FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class FakeLlamaServerService implements LlamaServerService {
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => _isRunning;

  bool _isRunning = false;
  List<String>? startedArgs;

  @override
  Future<bool> copyBinaryFromAssets() async => true;

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async {
    startedArgs = args;
    _isRunning = true;
    _runningStateController.add(true);
    return true;
  }

  @override
  Future<bool> stopServer() async {
    _isRunning = false;
    _runningStateController.add(false);
    return true;
  }

  void simulateUnexpectedStop() {
    _isRunning = false;
    _runningStateController.add(false);
  }
}

class FixedModelStoragePaths extends ModelStoragePaths {
  FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
}
