import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/features/mnn_test/controllers/mnn_test_controller.dart';
import 'package:servllama/features/mnn_test/pages/mnn_test_page.dart';

void main() {
  testWidgets('shows independent MNN engine and server state', (tester) async {
    final controller = _FakeMnnTestController();

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('MNN 测试'), findsOneWidget);
    expect(find.textContaining('MNN: 3.6.0'), findsOneWidget);
    expect(find.textContaining('Engine: ready'), findsOneWidget);
    expect(find.text('导入完整目录'), findsOneWidget);
    expect(find.text('启动 Server'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('SSE Chat'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('SSE Chat'), findsOneWidget);
    expect(find.text('System Prompt（可选）'), findsOneWidget);
    expect(find.text('max_tokens'), findsOneWidget);
  });

  testWidgets('locks model operations while the server is running', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialSnapshot: _snapshot(serverRunning: true),
      initialModels: const <MnnModelInfo>[_model],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('导入完整目录'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('导入完整目录'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.stop),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.stop))
          .onPressed,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.text('停止 Server'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '停止 Server'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('locks server and chat mutations while generating', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialSnapshot: _snapshot(serverRunning: true, generating: true),
      initialModels: const <MnnModelInfo>[_model],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('取消生成'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '停止 Server'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '非流式 Chat'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '取消生成'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('requires a valid port before starting the server', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialSnapshot: _snapshot(),
      initialModels: const <MnnModelInfo>[_model],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('启动 Server'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(find.byType(TextField).first, '80');
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '启动 Server'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '检测端口'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('requires a non-empty prompt before sending chat', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialSnapshot: _snapshot(serverRunning: true),
      initialModels: const <MnnModelInfo>[_model],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('非流式 Chat'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Prompt',
      ),
      '   ',
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '非流式 Chat'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('filters logs by level and exposes auto-scroll control', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialLogs: const <MnnLogEntry>[
        MnnLogEntry(
          sequence: 1,
          timestamp: 1,
          level: 'info',
          tag: 'runtime',
          message: 'loaded',
        ),
        MnnLogEntry(
          sequence: 2,
          timestamp: 2,
          level: 'error',
          tag: 'request',
          message: 'failed',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Logs ('),
      600,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('runtime: loaded'), findsOneWidget);
    expect(find.textContaining('request: failed'), findsOneWidget);
    expect(find.byTooltip('暂停自动滚动'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('筛选日志级别'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选日志级别'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Error').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('runtime: loaded'), findsNothing);
    expect(find.textContaining('request: failed'), findsOneWidget);
  });
}

class _FakeMnnTestController extends MnnTestController {
  _FakeMnnTestController({
    MnnRuntimeSnapshot? initialSnapshot,
    List<MnnModelInfo> initialModels = const [],
    List<MnnLogEntry> initialLogs = const [],
  }) {
    snapshot = initialSnapshot;
    models = initialModels;
    logs.addAll(initialLogs);
  }

  @override
  Future<void> initialize() async {
    engineInfo = const MnnEngineInfo(
      pluginVersion: '0.0.1',
      mnnVersion: '3.6.0',
      mnnCommit: 'cc20f672',
      abi: 'arm64-v8a',
      androidApiLevel: 35,
      ndkVersion: '27.3.13750724',
      nativeLibraryLoaded: true,
      testRootPath: '/data/user/0/app/files/mnn_test',
    );
    snapshot ??= const MnnRuntimeSnapshot(
      revision: 1,
      engineState: 'ready',
      modelState: 'unloaded',
      serverState: 'stopped',
      generationState: 'idle',
    );
    initializing = false;
    notifyListeners();
  }
}

const _model = MnnModelInfo(
  modelId: 'local/qwen3-0-6b-mnn',
  modelKey: 'qwen3-0-6b-mnn',
  displayName: 'Qwen3-0.6B-MNN',
  modelDirPath: '/data/user/0/app/files/mnn_test/models/qwen3-0-6b-mnn',
  configPath:
      '/data/user/0/app/files/mnn_test/models/qwen3-0-6b-mnn/config.json',
  sizeBytes: 454473462,
  importedAt: 1,
  isActive: true,
);

MnnRuntimeSnapshot _snapshot({
  bool serverRunning = false,
  bool generating = false,
}) => MnnRuntimeSnapshot(
  revision: 2,
  engineState: 'ready',
  modelState: 'loaded',
  serverState: serverRunning ? 'running' : 'stopped',
  generationState: generating ? 'generating' : 'idle',
  activeModel: _model,
  server: serverRunning
      ? const MnnServerInfo(
          running: true,
          host: '127.0.0.1',
          port: 8081,
          baseUrl: 'http://127.0.0.1:8081',
        )
      : null,
);
