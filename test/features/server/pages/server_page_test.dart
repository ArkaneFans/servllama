import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/server/pages/server_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerPage', () {
    testWidgets('shows grouped layout, API Base URL and copies it', (
      tester,
    ) async {
      final serverService = _ControllableLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      serverProvider.setEndpoint(host: '0.0.0.0', port: 9000);
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('server_page_status_card')), findsOneWidget);
      expect(find.byKey(const Key('server_page_menu_group')), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('已停止'), findsOneWidget);
      expect(find.text('API Base URL'), findsOneWidget);
      expect(find.text('http://0.0.0.0:9000'), findsOneWidget);
      expect(find.text('服务器配置'), findsOneWidget);
      expect(find.text('日志'), findsOneWidget);
      expect(find.text('模型管理'), findsOneWidget);

      await tester.tap(find.byTooltip('复制 API Base URL'));
      await tester.pump();

      expect(clipboardText, 'http://0.0.0.0:9000');
      expect(find.text('API Base URL 已复制'), findsOneWidget);
    });

    testWidgets('shows last error when server startup fails', (tester) async {
      final serverService = _FailingLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(
            listenMode: ServerListenMode.allInterfaces,
            port: 11434,
          ),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await serverProvider.start();

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      expect(find.text('API Base URL'), findsOneWidget);
      expect(find.text('http://0.0.0.0:11434'), findsOneWidget);
      expect(find.textContaining('启动失败:'), findsOneWidget);
    });

    testWidgets('shows running state and stop action when server is running', (
      tester,
    ) async {
      final stopCompleter = Completer<bool>()..complete(true);
      final serverService = _ControllableLlamaServerService(
        initiallyRunning: true,
        stopCompleter: stopCompleter,
      );
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      expect(find.text('运行中'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '停止'), findsOneWidget);
    });

    testWidgets('shows busy loading state while starting server', (
      tester,
    ) async {
      final completer = Completer<bool>();
      final serverService = _ControllableLlamaServerService(
        startCompleter: completer,
      );
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() async {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('server_page_toggle_button')));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('server_page_toggle_button')),
      );
      expect(button.onPressed, isNull);
      expect(
        find.descendant(
          of: find.byKey(const Key('server_page_toggle_button')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete(false);
      await tester.pumpAndSettle();
    });

    testWidgets('opens logs page from grouped menu', (tester) async {
      final serverService = _ControllableLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日志'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('日志')),
        findsOneWidget,
      );
    });

    testWidgets('menu item pressed state dims content and clears on cancel', (
      tester,
    ) async {
      final serverService = _ControllableLlamaServerService();
      final serverProvider = ServerProvider(
        serverService: serverService,
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(),
        ),
        modelStoragePaths: _FixedModelStoragePaths('C:\\app\\models'),
      );
      addTearDown(() {
        serverProvider.dispose();
        serverService.dispose();
      });

      await tester.pumpWidget(_TestApp(serverProvider: serverProvider));
      await tester.pumpAndSettle();

      const targetKey = ValueKey<String>('server_page_menu_item_日志');
      final targetFinder = find.byKey(targetKey);

      double opacityOf(Finder finder) {
        final widget = tester.widget<AnimatedOpacity>(finder);
        return widget.opacity;
      }

      expect(opacityOf(targetFinder), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(targetFinder));
      await tester.pump(const Duration(milliseconds: 60));

      expect(opacityOf(targetFinder), lessThan(1.0));

      await gesture.cancel();
      await tester.pumpAndSettle();

      expect(opacityOf(targetFinder), 1.0);
    });
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.serverProvider});

  final ServerProvider serverProvider;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ServerProvider>.value(
      value: serverProvider,
      child: const MaterialApp(home: ServerPage()),
    );
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _ControllableLlamaServerService implements LlamaServerService {
  _ControllableLlamaServerService({
    this.initiallyRunning = false,
    this.startCompleter,
    this.stopCompleter,
  }) : _isRunning = initiallyRunning;

  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();
  final bool initiallyRunning;
  final Completer<bool>? startCompleter;
  final Completer<bool>? stopCompleter;
  bool _isRunning;

  @override
  Stream<String> get logStream => const Stream<String>.empty();

  @override
  Stream<bool> get runningStateStream => _runningStateController.stream;

  @override
  bool get isRunning => _isRunning;

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
    final started = await (startCompleter?.future ?? Future<bool>.value(true));
    if (started) {
      _isRunning = true;
      _runningStateController.add(true);
    }
    return started;
  }

  @override
  Future<bool> stopServer() async {
    final stopped = await (stopCompleter?.future ?? Future<bool>.value(true));
    if (stopped) {
      _isRunning = false;
      _runningStateController.add(false);
    }
    return stopped;
  }
}

class _FailingLlamaServerService extends _ControllableLlamaServerService {
  @override
  Future<bool> startServer({List<String>? args}) {
    throw StateError('boom');
  }
}

class _FixedModelStoragePaths extends ModelStoragePaths {
  _FixedModelStoragePaths(this.modelsDirectoryPath);

  final String modelsDirectoryPath;

  @override
  Future<String> getModelsDirectoryPath() async => modelsDirectoryPath;
}
