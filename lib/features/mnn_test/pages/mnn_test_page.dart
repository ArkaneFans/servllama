import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnn_engine/mnn_engine.dart' show MnnLogEntry, MnnServerBindMode;
import 'package:provider/provider.dart';
import 'package:servllama/features/mnn_test/controllers/mnn_test_controller.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';

class MnnTestPage extends StatefulWidget {
  const MnnTestPage({super.key, this.controller});

  final MnnTestController? controller;

  @override
  State<MnnTestPage> createState() => _MnnTestPageState();
}

class _MnnTestPageState extends State<MnnTestPage> {
  late final MnnTestController _controller;
  final _portController = TextEditingController(text: '8081');
  final _apiKeyController = TextEditingController();
  final _systemPromptController = TextEditingController();
  final _promptController = TextEditingController(text: '你好，请用中文简要介绍一下你自己。');
  final _temperatureController = TextEditingController(text: '0.7');
  final _topPController = TextEditingController(text: '0.9');
  final _maxTokensController = TextEditingController(text: '512');

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MnnTestController();
    _portController.addListener(_handleInputChanged);
    _apiKeyController.addListener(_handleInputChanged);
    _systemPromptController.addListener(_handleInputChanged);
    _promptController.addListener(_handleInputChanged);
    _temperatureController.addListener(_handleInputChanged);
    _topPController.addListener(_handleInputChanged);
    _maxTokensController.addListener(_handleInputChanged);
    _controller.initialize();
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    _systemPromptController.dispose();
    _promptController.dispose();
    _temperatureController.dispose();
    _topPController.dispose();
    _maxTokensController.dispose();
    super.dispose();
  }

  int? get _port => int.tryParse(_portController.text.trim());
  bool get _portValid {
    final port = _port;
    return port != null && port >= 1024 && port <= 65535;
  }

  String? get _apiKey => _apiKeyController.text.trim().isEmpty
      ? null
      : _apiKeyController.text.trim();
  double? get _temperature =>
      double.tryParse(_temperatureController.text.trim());
  double? get _topP => double.tryParse(_topPController.text.trim());
  int? get _maxTokens => int.tryParse(_maxTokensController.text.trim());
  bool get _chatParametersValid {
    final temperature = _temperature;
    final topP = _topP;
    final maxTokens = _maxTokens;
    return temperature != null &&
        temperature >= 0 &&
        temperature <= 2 &&
        topP != null &&
        topP >= 0 &&
        topP <= 1 &&
        maxTokens != null &&
        maxTokens >= 1 &&
        maxTokens <= 8192;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MnnTestController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('MNN 测试')),
        body: Consumer<MnnTestController>(
          builder: (context, controller, _) {
            if (controller.initializing) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (controller.error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(controller.error!),
                    ),
                  ),
                _EngineCard(controller: controller),
                const SizedBox(height: 12),
                _ModelCard(controller: controller),
                const SizedBox(height: 12),
                _ServerCard(
                  controller: controller,
                  portController: _portController,
                  apiKeyController: _apiKeyController,
                  portValid: _portValid,
                  onCheckPort: () {
                    final port = _port;
                    if (port != null) controller.checkPort(port);
                  },
                  onStart: () {
                    final port = _port;
                    if (port != null) {
                      controller.startServer(port: port, apiKey: _apiKey);
                    }
                  },
                  onGenerateApiKey: () {
                    _apiKeyController.text = controller.generateApiKey();
                  },
                ),
                const SizedBox(height: 12),
                _ApiCard(
                  controller: controller,
                  systemPromptController: _systemPromptController,
                  promptController: _promptController,
                  temperatureController: _temperatureController,
                  topPController: _topPController,
                  maxTokensController: _maxTokensController,
                  apiKey: _apiKey,
                  temperature: _temperature,
                  topP: _topP,
                  maxTokens: _maxTokens,
                  parametersValid: _chatParametersValid,
                ),
                const SizedBox(height: 12),
                _LogsCard(controller: controller),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.controller});

  final MnnTestController controller;

  @override
  Widget build(BuildContext context) {
    final info = controller.engineInfo;
    final snapshot = controller.snapshot;
    return _SectionCard(
      title: 'Engine',
      actions: [
        IconButton(
          onPressed: controller.operationRunning
              ? null
              : controller.refreshRuntime,
          tooltip: '刷新 Runtime 状态',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: info?.testRootPath.isNotEmpty == true
              ? () => Clipboard.setData(ClipboardData(text: info!.testRootPath))
              : null,
          tooltip: '复制测试目录',
          icon: const Icon(Icons.copy),
        ),
      ],
      child: SelectableText(
        'Plugin: ${info?.pluginVersion ?? '-'}\n'
        'MNN: ${info?.mnnVersion ?? '-'} (${info?.mnnCommit ?? '-'})\n'
        'ABI: ${info?.abi ?? '-'} · NDK ${info?.ndkVersion ?? '-'}\n'
        'Native loaded: ${info?.nativeLibraryLoaded ?? false}\n'
        'Engine: ${snapshot?.engineState ?? '-'} · Model: ${snapshot?.modelState ?? '-'}\n'
        'Server: ${snapshot?.serverState ?? '-'} · Generation: ${snapshot?.generationState ?? '-'}\n'
        'Test root: ${info?.testRootPath ?? '-'}',
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({required this.controller});

  final MnnTestController controller;

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.snapshot;
    final runtimeBusy =
        snapshot?.modelState == 'loading' ||
        snapshot?.generationState == 'generating';
    final canChangeModel =
        !controller.operationRunning &&
        !runtimeBusy &&
        snapshot?.serverState == 'stopped';
    return _SectionCard(
      title: 'Models',
      actions: [
        FilledButton.icon(
          onPressed: canChangeModel ? controller.importModel : null,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('导入完整目录'),
        ),
        IconButton(
          onPressed: controller.operationRunning
              ? null
              : controller.refreshModels,
          tooltip: '刷新',
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: controller.models.isEmpty
          ? const Text('尚未导入模型。请选择根部包含 config.json 的目录。')
          : Column(
              children: controller.models
                  .map((model) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        model.isActive ? Icons.memory : Icons.folder_outlined,
                      ),
                      title: Text(model.displayName),
                      subtitle: Text(
                        '${model.modelId}\n${_formatBytes(model.sizeBytes)}'
                        '\nCapabilities: text'
                        '${model.supportsVision ? ' · vision' : ''}'
                        '${model.supportsToolCalling ? ' · tools' : ''}'
                        '${model.loadDurationMs == null ? '' : '\nLoad: ${model.loadDurationMs} ms'}'
                        '${model.validationWarnings.isEmpty ? '' : '\n${model.validationWarnings.join('；')}'}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          if (!model.isActive)
                            IconButton(
                              onPressed: canChangeModel
                                  ? () => controller.loadModel(model.modelId)
                                  : null,
                              tooltip: '加载',
                              icon: const Icon(Icons.play_arrow),
                            )
                          else
                            IconButton(
                              onPressed: canChangeModel
                                  ? controller.unloadModel
                                  : null,
                              tooltip: '卸载',
                              icon: const Icon(Icons.stop),
                            ),
                          IconButton(
                            onPressed: canChangeModel && !model.isActive
                                ? () => controller.deleteModel(model.modelId)
                                : null,
                            tooltip: '删除测试模型',
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.controller,
    required this.portController,
    required this.apiKeyController,
    required this.portValid,
    required this.onCheckPort,
    required this.onStart,
    required this.onGenerateApiKey,
  });

  final MnnTestController controller;
  final TextEditingController portController;
  final TextEditingController apiKeyController;
  final bool portValid;
  final VoidCallback onCheckPort;
  final VoidCallback onStart;
  final VoidCallback onGenerateApiKey;

  @override
  Widget build(BuildContext context) {
    final server = controller.snapshot?.server;
    final running = server?.running == true;
    final serverState = controller.snapshot?.serverState;
    final generating = controller.snapshot?.generationState == 'generating';
    final lanMode = controller.bindMode == MnnServerBindMode.allInterfaces;
    final canStart =
        !controller.operationRunning &&
        serverState == 'stopped' &&
        controller.snapshot?.modelState == 'loaded' &&
        controller.snapshot?.activeModel != null &&
        !generating &&
        portValid;
    return _SectionCard(
      title: 'API Server',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<MnnServerBindMode>(
            segments: const [
              ButtonSegment(
                value: MnnServerBindMode.loopback,
                icon: Icon(Icons.smartphone),
                label: Text('仅本机'),
              ),
              ButtonSegment(
                value: MnnServerBindMode.allInterfaces,
                icon: Icon(Icons.lan_outlined),
                label: Text('所有接口'),
              ),
            ],
            selected: <MnnServerBindMode>{controller.bindMode},
            onSelectionChanged: serverState == 'stopped'
                ? (selection) => controller.setBindMode(selection.first)
                : null,
          ),
          const SizedBox(height: 8),
          SelectableText(
            lanMode ? 'Bind: 0.0.0.0（所有 IPv4 网络接口）' : 'Bind: 127.0.0.1（仅设备本机）',
          ),
          if (lanMode) ...[
            const SizedBox(height: 8),
            Text(
              '警告：所有接口模式会向当前 Wi-Fi、热点、VPN 等 IPv4 网络暴露服务。API Key 留空时，任何能够访问设备端口的客户端都可以直接调用模型，请仅在可信网络中使用。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: portController,
            enabled: serverState == 'stopped',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '8081',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: apiKeyController,
            enabled: serverState == 'stopped',
            obscureText: true,
            decoration: InputDecoration(
              labelText: lanMode ? 'API Key（可选，留空关闭认证）' : 'API Key（留空关闭认证）',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: serverState == 'stopped' ? onGenerateApiKey : null,
            icon: const Icon(Icons.key),
            label: const Text('生成随机 Key'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed:
                    serverState == 'stopped' &&
                        !controller.operationRunning &&
                        portValid
                    ? onCheckPort
                    : null,
                child: const Text('检测端口'),
              ),
              FilledButton(
                onPressed: canStart ? onStart : null,
                child: const Text('启动 Server'),
              ),
              OutlinedButton(
                onPressed:
                    running &&
                        !controller.operationRunning &&
                        !generating &&
                        !controller.streamRunning
                    ? controller.stopServer
                    : null,
                child: const Text('停止 Server'),
              ),
            ],
          ),
          if (controller.portCheck != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.portCheck!.ownedByMnn
                  ? '该端口由当前 MNN Server 使用。'
                  : controller.portCheck!.available
                  ? '端口可用。'
                  : '端口不可用：${controller.portCheck!.message ?? '-'}',
            ),
          ],
          if (server != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: SelectableText('URL: ${server.baseUrl}')),
                IconButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: server.baseUrl)),
                  tooltip: '复制 Server URL',
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            if (server.startDurationMs != null)
              Text('Start duration: ${server.startDurationMs} ms'),
            if (server.advertisedUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...server.advertisedUrls.map(
                (url) => Row(
                  children: [
                    Expanded(child: SelectableText('LAN: $url')),
                    IconButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: url)),
                      tooltip: '复制 LAN URL',
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ApiCard extends StatelessWidget {
  const _ApiCard({
    required this.controller,
    required this.systemPromptController,
    required this.promptController,
    required this.temperatureController,
    required this.topPController,
    required this.maxTokensController,
    required this.apiKey,
    required this.temperature,
    required this.topP,
    required this.maxTokens,
    required this.parametersValid,
  });

  final MnnTestController controller;
  final TextEditingController systemPromptController;
  final TextEditingController promptController;
  final TextEditingController temperatureController;
  final TextEditingController topPController;
  final TextEditingController maxTokensController;
  final String? apiKey;
  final double? temperature;
  final double? topP;
  final int? maxTokens;
  final bool parametersValid;

  @override
  Widget build(BuildContext context) {
    final running = controller.snapshot?.server?.running == true;
    final generating = controller.snapshot?.generationState == 'generating';
    final requestBusy =
        controller.operationRunning ||
        controller.streamRunning ||
        controller.toolFlowRunning ||
        generating;
    final promptReady = promptController.text.trim().isNotEmpty;
    final canSend = running && !requestBusy && promptReady && parametersValid;
    final maxTokensReady =
        maxTokens != null && maxTokens! >= 1 && maxTokens! <= 8192;
    final canCapabilityTest = running && !requestBusy && maxTokensReady;
    final activeModel = controller.snapshot?.activeModel;
    final canQuery = running && !requestBusy;
    final displayedToolSteps = controller.apiResult?.steps.isNotEmpty == true
        ? controller.apiResult!.steps
        : controller.toolFlowSteps;
    return _SectionCard(
      title: 'API Test',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: systemPromptController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'System Prompt（可选）'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: promptController,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Prompt'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: TextField(
                  controller: temperatureController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'temperature'),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: topPController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'top_p'),
                ),
              ),
              SizedBox(
                width: 150,
                child: TextField(
                  controller: maxTokensController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'max_tokens'),
                ),
              ),
            ],
          ),
          if (!parametersValid)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('参数范围：temperature 0-2，top_p 0-1，max_tokens 1-8192。'),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: canQuery
                    ? () => controller.testHealth(apiKey)
                    : null,
                child: const Text('/health'),
              ),
              OutlinedButton(
                onPressed: canQuery
                    ? () => controller.testModels(apiKey)
                    : null,
                child: const Text('/v1/models'),
              ),
              FilledButton(
                onPressed: canSend
                    ? () => controller.testChat(
                        prompt: promptController.text,
                        apiKey: apiKey,
                        systemPrompt: systemPromptController.text,
                        temperature: temperature,
                        topP: topP,
                        maxTokens: maxTokens!,
                      )
                    : null,
                child: const Text('非流式 Chat'),
              ),
              FilledButton.tonal(
                onPressed: canSend
                    ? () => controller.testStream(
                        prompt: promptController.text,
                        apiKey: apiKey,
                        systemPrompt: systemPromptController.text,
                        temperature: temperature,
                        topP: topP,
                        maxTokens: maxTokens!,
                      )
                    : null,
                child: const Text('SSE Chat'),
              ),
              OutlinedButton(
                onPressed: controller.streamRunning || generating
                    ? controller.cancelStream
                    : null,
                child: const Text('取消生成'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    canCapabilityTest &&
                        activeModel?.supportsToolCalling == true
                    ? () => controller.testToolFlow(
                        apiKey: apiKey,
                        maxTokens: maxTokens!,
                      )
                    : null,
                icon: const Icon(Icons.build_outlined),
                label: const Text('工具调用全流程'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    canCapabilityTest && activeModel?.supportsVision == true
                    ? () => controller.testMultimodal(
                        apiKey: apiKey,
                        maxTokens: maxTokens!,
                      )
                    : null,
                icon: const Icon(Icons.image_outlined),
                label: const Text('apple.jpg 图片问答（SSE）'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.streamingOutput.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  controller.streamRunning ? '流式输出（生成中）' : '流式输出',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (controller.streamRunning) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            _OutputBox(text: controller.streamingOutput),
            const SizedBox(height: 12),
          ],
          if (displayedToolSteps.isNotEmpty) ...[
            _ToolFlowPanel(steps: displayedToolSteps),
            const SizedBox(height: 12),
          ],
          if (controller.apiResult != null) ...[
            _ApiResultPanel(result: controller.apiResult!),
          ],
        ],
      ),
    );
  }
}

class _ApiResultPanel extends StatelessWidget {
  const _ApiResultPanel({required this.result});

  final MnnApiTestResult result;

  @override
  Widget build(BuildContext context) {
    final statusColor = result.cancelled
        ? Theme.of(context).colorScheme.outline
        : result.succeeded
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              result.cancelled
                  ? Icons.cancel
                  : result.succeeded
                  ? Icons.check_circle
                  : Icons.error,
              color: statusColor,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${result.label} · ${result.cancelled
                    ? '已取消'
                    : result.succeeded
                    ? '成功'
                    : '失败'}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'HTTP ${result.statusCode?.toString() ?? '-'} · 总耗时 ${result.elapsedMs} ms'
          '${result.firstTokenMs == null ? '' : ' · 首 token ${result.firstTokenMs} ms'}',
        ),
        if (result.totalTokens != null)
          Text(
            'Usage：prompt ${result.promptTokens ?? '-'} · '
            'completion ${result.completionTokens ?? '-'} · '
            'total ${result.totalTokens}',
          ),
        if (result.toolName != null || result.toolCallId != null) ...[
          const SizedBox(height: 4),
          SelectableText(
            '工具：${result.toolName ?? '-'} · call id：${result.toolCallId ?? '-'}\n'
            'arguments：${result.toolArguments ?? '-'}',
          ),
        ],
        if (result.errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            result.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (result.output.isNotEmpty) ...[
          const SizedBox(height: 8),
          _OutputBox(text: result.output),
        ],
        if (result.exchanges.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('API 请求与响应', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          ...result.exchanges.asMap().entries.map(
            (entry) =>
                _ExchangeTile(index: entry.key + 1, exchange: entry.value),
          ),
        ],
      ],
    );
  }
}

class _ToolFlowPanel extends StatelessWidget {
  const _ToolFlowPanel({required this.steps});

  final List<MnnApiTestStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('工具调用全流程（每步状态）', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...steps.asMap().entries.map(
          (entry) => _ToolStepTile(index: entry.key + 1, step: entry.value),
        ),
      ],
    );
  }
}

class _ToolStepTile extends StatelessWidget {
  const _ToolStepTile({required this.index, required this.step});

  final int index;
  final MnnApiTestStep step;

  @override
  Widget build(BuildContext context) {
    final color = _stepStatusColor(context, step.status);
    final hasDetails =
        step.checks.isNotEmpty ||
        step.exchange != null ||
        step.input != null ||
        step.output != null ||
        step.error != null;
    final title = '$index. ${step.title} · ${step.status.label}';
    final header = Row(
      children: [
        Icon(_stepStatusIcon(step.status), color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
        if (step.elapsedMs != null) Text('${step.elapsedMs} ms'),
      ],
    );
    if (!hasDetails) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: header,
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        title: header,
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (step.error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                step.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (step.checks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '格式检查',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            ...step.checks.map((check) => _ValidationRow(check: check)),
          ],
          if (step.input != null) ...[
            const SizedBox(height: 6),
            _LabeledOutput(label: '输入 / 请求入参', text: step.input!),
          ],
          if (step.output != null && step.exchange == null) ...[
            const SizedBox(height: 6),
            _LabeledOutput(label: '输出 / 检查结果', text: step.output!),
          ],
          if (step.exchange != null) ...[
            const SizedBox(height: 6),
            _ExchangeTile(index: null, exchange: step.exchange!),
          ],
        ],
      ),
    );
  }
}

class _ValidationRow extends StatelessWidget {
  const _ValidationRow({required this.check});

  final MnnApiValidationCheck check;

  @override
  Widget build(BuildContext context) {
    final color = check.succeeded
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            check.succeeded ? Icons.check : Icons.close,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '${check.label}${check.detail == null ? '' : '（${check.detail}）'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ExchangeTile extends StatelessWidget {
  const _ExchangeTile({required this.index, required this.exchange});

  final int? index;
  final MnnApiExchange exchange;

  @override
  Widget build(BuildContext context) {
    final title = index == null
        ? '${exchange.method} ${exchange.url}'
        : '请求 $index：${exchange.method} ${exchange.url}';
    final status = exchange.cancelled
        ? '已取消'
        : exchange.succeeded
        ? '成功'
        : '失败';
    return Card(
      margin: const EdgeInsets.only(top: 4),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title),
        subtitle: Text(
          '$status · HTTP ${exchange.statusCode?.toString() ?? '-'} · '
          '${exchange.elapsedMs} ms'
          '${exchange.sseEventCount == 0 ? '' : ' · SSE ${exchange.sseEventCount} events'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          _LabeledOutput(label: '请求入参', text: exchange.requestDisplay),
          const SizedBox(height: 8),
          _LabeledOutput(label: '响应结构', text: exchange.responseDisplay),
          if (exchange.errorMessage != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                exchange.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledOutput extends StatelessWidget {
  const _LabeledOutput({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            IconButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
              tooltip: '复制内容',
              icon: const Icon(Icons.copy, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 3),
        _OutputBox(text: text),
      ],
    );
  }
}

class _OutputBox extends StatelessWidget {
  const _OutputBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      padding: const EdgeInsets.all(10),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SelectionArea(
        child: SingleChildScrollView(
          child: Text(text, style: const TextStyle(fontFamily: 'monospace')),
        ),
      ),
    );
  }
}

Color _stepStatusColor(BuildContext context, MnnApiTestStepStatus status) {
  switch (status) {
    case MnnApiTestStepStatus.succeeded:
      return Colors.green.shade700;
    case MnnApiTestStepStatus.failed:
      return Theme.of(context).colorScheme.error;
    case MnnApiTestStepStatus.running:
      return Theme.of(context).colorScheme.primary;
    case MnnApiTestStepStatus.pending:
    case MnnApiTestStepStatus.skipped:
      return Theme.of(context).colorScheme.outline;
  }
}

IconData _stepStatusIcon(MnnApiTestStepStatus status) {
  switch (status) {
    case MnnApiTestStepStatus.pending:
      return Icons.hourglass_empty;
    case MnnApiTestStepStatus.running:
      return Icons.timelapse;
    case MnnApiTestStepStatus.succeeded:
      return Icons.check_circle;
    case MnnApiTestStepStatus.failed:
      return Icons.error;
    case MnnApiTestStepStatus.skipped:
      return Icons.skip_next;
  }
}

class _LogsCard extends StatefulWidget {
  const _LogsCard({required this.controller});

  final MnnTestController controller;

  @override
  State<_LogsCard> createState() => _LogsCardState();
}

class _LogsCardState extends State<_LogsCard> {
  final _scrollController = ScrollController();
  String _level = 'all';
  bool _autoScroll = true;
  int _lastLogCount = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoScroll || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = widget.controller.logs;
    if (_lastLogCount != logs.length) {
      _lastLogCount = logs.length;
      _scheduleScrollToBottom();
    }
    final filtered = _level == 'all'
        ? logs
        : logs.where((entry) => entry.level == _level).toList(growable: false);
    final visibleLogs = filtered.length > 200
        ? filtered.sublist(filtered.length - 200)
        : filtered;
    final allText = logs.map(_formatLogEntry).join('\n');
    return _SectionCard(
      title: 'Logs (${filtered.length}/${logs.length})',
      actions: [
        PopupMenuButton<String>(
          initialValue: _level,
          tooltip: '筛选日志级别',
          icon: const Icon(Icons.filter_list),
          onSelected: (value) {
            setState(() => _level = value);
            _scheduleScrollToBottom();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'all', child: Text('全部')),
            PopupMenuItem(value: 'debug', child: Text('Debug')),
            PopupMenuItem(value: 'info', child: Text('Info')),
            PopupMenuItem(value: 'warning', child: Text('Warning')),
            PopupMenuItem(value: 'error', child: Text('Error')),
          ],
        ),
        IconButton(
          onPressed: () {
            setState(() => _autoScroll = !_autoScroll);
            if (_autoScroll) _scheduleScrollToBottom();
          },
          tooltip: _autoScroll ? '暂停自动滚动' : '继续自动滚动',
          icon: Icon(_autoScroll ? Icons.pause : Icons.play_arrow),
        ),
        IconButton(
          onPressed: allText.isEmpty
              ? null
              : () => Clipboard.setData(ClipboardData(text: allText)),
          tooltip: '复制日志',
          icon: const Icon(Icons.copy),
        ),
        IconButton(
          onPressed: logs.isEmpty ? null : widget.controller.clearLogs,
          tooltip: '清空日志',
          icon: const Icon(Icons.clear_all),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 120, maxHeight: 320),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: visibleLogs.isEmpty
            ? const SelectableText('暂无日志。')
            : SelectionArea(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: visibleLogs.length,
                  itemBuilder: (context, index) {
                    final entry = visibleLogs[index];
                    return Text(
                      _formatLogEntry(entry),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: entry.level == 'error'
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

String _formatLogEntry(MnnLogEntry entry) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(
    entry.timestamp,
  ).toIso8601String();
  return '$timestamp ${entry.sequence} ${entry.level.toUpperCase()} '
      '${entry.tag}: ${entry.message}';
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GiB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '$bytes B';
}
