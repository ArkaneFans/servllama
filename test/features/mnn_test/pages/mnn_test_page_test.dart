import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/features/mnn_test/controllers/mnn_test_controller.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';
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
    expect(find.text('工具调用全流程'), findsOneWidget);
    expect(find.text('apple.jpg 图片问答（SSE）'), findsOneWidget);
    expect(find.text('System Prompt（可选）'), findsOneWidget);
    expect(find.text('max_tokens'), findsOneWidget);
  });

  testWidgets('renders tool-flow statuses, checks, and API exchanges', (
    tester,
  ) async {
    final controller = _FakeMnnTestController(
      initialSnapshot: _snapshot(serverRunning: true),
      initialModels: const <MnnModelInfo>[_model],
    );
    controller.toolFlowSteps = const <MnnApiTestStep>[
      MnnApiTestStep(
        id: 'prepare_initial_request',
        title: '构建首次请求',
        status: MnnApiTestStepStatus.succeeded,
        checks: <MnnApiValidationCheck>[
          MnnApiValidationCheck(
            id: 'prompt',
            label: '中文 Prompt 非空',
            succeeded: true,
          ),
        ],
        input: '{"messages":[]}',
      ),
      MnnApiTestStep(
        id: 'request_tool_call',
        title: '请求 LLM 工具调用',
        status: MnnApiTestStepStatus.running,
      ),
      MnnApiTestStep(
        id: 'validate_tool_call',
        title: '校验工具调用格式',
        status: MnnApiTestStepStatus.pending,
      ),
    ];
    controller.apiResult = const MnnApiTestResult(
      label: 'GET /health',
      output: '{"status":"ready"}',
      succeeded: true,
      elapsedMs: 2,
      exchanges: <MnnApiExchange>[
        MnnApiExchange(
          method: 'GET',
          url: 'http://127.0.0.1:8081/health',
          requestDisplay: '{"method":"GET"}',
          responseDisplay: '{"status":"ready"}',
          succeeded: true,
          elapsedMs: 2,
          statusCode: 200,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: MnnTestPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('工具调用全流程'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('工具调用全流程'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('apple.jpg 图片问答（SSE）'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNotNull,
    );
    await tester.scrollUntilVisible(
      find.text('工具调用全流程（每步状态）'),
      600,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('构建首次请求 · 成功'), findsOneWidget);
    expect(find.textContaining('请求 LLM 工具调用 · 执行中'), findsOneWidget);
    expect(find.textContaining('校验工具调用格式 · 待执行'), findsOneWidget);
    expect(find.text('格式检查'), findsOneWidget);
    expect(find.text('API 请求与响应'), findsOneWidget);
    expect(find.text('响应结构'), findsOneWidget);
    expect(find.byTooltip('复制内容'), findsWidgets);
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

  testWidgets('allows unauthenticated all-interface server with a warning', (
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
    controller.setBindMode(MnnServerBindMode.allInterfaces);
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('启动 Server'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('API Key 留空时，任何能够访问设备端口的客户端'), findsOneWidget);
    expect(find.text('API Key（可选，留空关闭认证）'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '启动 Server'))
          .onPressed,
      isNotNull,
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
  supportsVision: true,
  supportsToolCalling: true,
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
          bindMode: MnnServerBindMode.loopback,
          bindAddress: '127.0.0.1',
          port: 8081,
          baseUrl: 'http://127.0.0.1:8081',
          localBaseUrl: 'http://127.0.0.1:8081',
        )
      : null,
);
