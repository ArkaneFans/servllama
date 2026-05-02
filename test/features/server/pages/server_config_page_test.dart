import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/features/server/pages/server_config_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerConfigPage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('shows loading first and then renders loaded slider value', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final loader = _CompleterServerLaunchSettingsLoader();
      final configProvider = ServerConfigProvider(
        kvStorage: kvStorage,
        settingsLoader: loader,
      );
      final serverService = _FakeLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('上下文长度'), findsNothing);
      expect(find.byType(Slider), findsNothing);

      loader.complete(
        const ServerLaunchSettings(contextSize: 8192, batchSize: 1024),
      );
      await tester.pumpAndSettle();

      expect(find.text('推理参数'), findsOneWidget);
      expect(find.text('上下文长度'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider).first).value, 8192);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is TextField && widget.controller?.text == '8192',
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses fixed 1-8 defaults for performance sliders', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(kvStorage: kvStorage);
      final serverService = _FakeLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();

      expect(sliders, hasLength(4));
      expect(sliders[2].min, 1);
      expect(sliders[2].max, 8);
      expect(sliders[2].divisions, 7);
      expect(sliders[2].value, 2);
      expect(sliders[3].min, 1);
      expect(sliders[3].max, 8);
      expect(sliders[3].divisions, 7);
      expect(sliders[3].value, 1);
      expect(configProvider.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(
        configProvider.parallelSlots,
        ServerLaunchSettings.defaultParallelSlots,
      );
    });

    testWidgets('removes fixed action bar and saves port changes immediately', (
      tester,
    ) async {
      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(kvStorage: kvStorage);
      final serverService = _FakeLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('保存配置'), findsNothing);
      expect(find.textContaining('当前地址：http://'), findsNothing);
      expect(find.text('网络与访问'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '8080'), '9001');
      await tester.pumpAndSettle();

      expect(configProvider.port, 9001);
      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9001);
      expect(await kvStorage.getString(ServerPrefsKeys.listenMode), isNull);
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isNull);
      expect(serverProvider.displayAddress, '127.0.0.1:9001');
    });

    testWidgets('restores defaults only after confirmation', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        ServerPrefsKeys.listenMode: ServerListenMode.allInterfaces.name,
        ServerPrefsKeys.port: 9000,
        ServerPrefsKeys.apiKey: 'secret',
      });

      final kvStorage = KvStorage();
      final configProvider = ServerConfigProvider(kvStorage: kvStorage);
      final serverService = _FakeLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        configProvider.dispose();
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(
        _TestApp(
          serverProvider: serverProvider,
          child: ServerConfigPage(provider: configProvider),
        ),
      );
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.allInterfaces);
      expect(configProvider.port, 9000);
      expect(serverProvider.displayAddress, '0.0.0.0:9000');

      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      final restoreDefaultTile = find.widgetWithText(ListTile, '恢复默认配置');
      expect(restoreDefaultTile, findsOneWidget);
      await tester.tap(restoreDefaultTile);
      await tester.pumpAndSettle();

      expect(find.text('恢复默认配置'), findsNWidgets(2));
      expect(find.text('所有配置项将恢复默认值并立即保存，确定继续吗？'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.allInterfaces);
      expect(configProvider.port, 9000);
      expect(await kvStorage.getInt(ServerPrefsKeys.port), 9000);

      await tester.ensureVisible(restoreDefaultTile);
      await tester.tap(restoreDefaultTile);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '恢复默认'));
      await tester.pumpAndSettle();

      expect(configProvider.listenMode, ServerListenMode.localhost);
      expect(configProvider.port, ServerLaunchSettings.defaultPort);
      expect(configProvider.apiKey, isEmpty);
      expect(configProvider.cpuThreads, ServerLaunchSettings.defaultCpuThreads);
      expect(
        configProvider.parallelSlots,
        ServerLaunchSettings.defaultParallelSlots,
      );
      expect(
        await kvStorage.getString(ServerPrefsKeys.listenMode),
        'localhost',
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.port),
        ServerLaunchSettings.defaultPort,
      );
      expect(await kvStorage.getString(ServerPrefsKeys.apiKey), isEmpty);
      expect(
        await kvStorage.getInt(ServerPrefsKeys.cpuThreads),
        ServerLaunchSettings.defaultCpuThreads,
      );
      expect(
        await kvStorage.getInt(ServerPrefsKeys.parallelSlots),
        ServerLaunchSettings.defaultParallelSlots,
      );
      expect(serverProvider.displayAddress, '127.0.0.1:8080');
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.serverProvider, required this.child});

  final ServerProvider serverProvider;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ServerProvider>.value(value: serverProvider),
      ],
      child: MaterialApp(home: child),
    );
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _CompleterServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  final Completer<ServerLaunchSettings> _completer =
      Completer<ServerLaunchSettings>();

  @override
  Future<ServerLaunchSettings> load() => _completer.future;

  void complete(ServerLaunchSettings settings) {
    _completer.complete(settings);
  }
}

class _FakeLlamaServerService implements LlamaServerService {
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => false;

  @override
  Future<bool> copyBinaryFromAssets() async => true;

  @override
  void dispose() {
    _runningStateController.close();
  }

  @override
  void initForegroundTask() {}

  @override
  Future<bool> startServer({List<String>? args}) async => true;

  @override
  Future<bool> stopServer() async => true;
}

class _FixedModelStoragePaths extends ModelStoragePaths {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
}
