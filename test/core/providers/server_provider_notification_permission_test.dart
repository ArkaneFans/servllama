import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _foregroundTaskMethodsChannel = MethodChannel(
  'flutter_foreground_task/methods',
);

void main() {
  group('ServerProvider notification permission prompt', () {
    test(
      'continues starting when notification permission request is cancelled',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final kvStorage = KvStorage();
        final service = FakeLlamaServerService();
        final methodCalls = <String>[];

        _setUpAndroidForegroundTaskHandler((call) async {
          methodCalls.add(call.method);
          switch (call.method) {
            case 'checkNotificationPermission':
              return NotificationPermission.denied.index;
            case 'requestNotificationPermission':
              throw PlatformException(
                code: 'a',
                message:
                    'The permission request dialog was closed or the request was cancelled.',
              );
            default:
              return null;
          }
        });

        final provider = ServerProvider(
          serverService: service,
          settingsLoader: FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
          kvStorage: kvStorage,
        );

        await provider.start();

        expect(methodCalls, <String>[
          'checkNotificationPermission',
          'requestNotificationPermission',
        ]);
        expect(
          await kvStorage.getBool(
            ServerPrefsKeys.foregroundNotificationPermissionPrompted,
          ),
          isTrue,
        );
        expect(service.startedArgs, isNotNull);
        expect(provider.isRunning, isTrue);
        expect(provider.lastError, isNull);
        provider.dispose();
        service.dispose();
      },
    );

    test(
      'skips notification permission request after prompt marker exists',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          ServerPrefsKeys.foregroundNotificationPermissionPrompted: true,
        });
        final kvStorage = KvStorage();
        final service = FakeLlamaServerService();
        final methodCalls = <String>[];

        _setUpAndroidForegroundTaskHandler((call) async {
          methodCalls.add(call.method);
          switch (call.method) {
            case 'checkNotificationPermission':
              return NotificationPermission.denied.index;
            case 'requestNotificationPermission':
              return NotificationPermission.granted.index;
            default:
              return null;
          }
        });

        final provider = ServerProvider(
          serverService: service,
          settingsLoader: FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
          kvStorage: kvStorage,
        );

        await provider.start();

        expect(methodCalls, isEmpty);
        expect(service.startedArgs, isNotNull);
        expect(provider.isRunning, isTrue);
        expect(provider.lastError, isNull);
        provider.dispose();
        service.dispose();
      },
    );

    test(
      'records marker when notification permission is already granted',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final kvStorage = KvStorage();
        final service = FakeLlamaServerService();
        final methodCalls = <String>[];

        _setUpAndroidForegroundTaskHandler((call) async {
          methodCalls.add(call.method);
          switch (call.method) {
            case 'checkNotificationPermission':
              return NotificationPermission.granted.index;
            case 'requestNotificationPermission':
              return NotificationPermission.granted.index;
            default:
              return null;
          }
        });

        final provider = ServerProvider(
          serverService: service,
          settingsLoader: FixedServerLaunchSettingsLoader(
            const ServerLaunchSettings(),
          ),
          modelStoragePaths: FixedModelStoragePaths('C:\\app\\models'),
          kvStorage: kvStorage,
        );

        await provider.start();

        expect(methodCalls, <String>['checkNotificationPermission']);
        expect(
          await kvStorage.getBool(
            ServerPrefsKeys.foregroundNotificationPermissionPrompted,
          ),
          isTrue,
        );
        expect(service.startedArgs, isNotNull);
        expect(provider.isRunning, isTrue);
        expect(provider.lastError, isNull);
        provider.dispose();
        service.dispose();
      },
    );
  });
}

void _setUpAndroidForegroundTaskHandler(
  Future<Object?> Function(MethodCall call) handler,
) {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_foregroundTaskMethodsChannel, handler);
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_foregroundTaskMethodsChannel, null);
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
  Future<String> loadBundledVersion() async => 'b9830';

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
}

class FixedModelStoragePaths extends ModelStoragePaths {
  FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
}
