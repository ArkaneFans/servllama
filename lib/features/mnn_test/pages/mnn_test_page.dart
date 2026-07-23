import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnn_engine/mnn_engine.dart' show MnnLogEntry;
import 'package:provider/provider.dart';
import 'package:servllama/features/mnn_test/controllers/mnn_test_controller.dart';

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
  final _promptController = TextEditingController(
    text: 'Hello! Briefly introduce yourself.',
  );
  final _temperatureController = TextEditingController(text: '0.7');
  final _topPController = TextEditingController(text: '0.9');
  final _maxTokensController = TextEditingController(text: '512');

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MnnTestController();
    _portController.addListener(_handleInputChanged);
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
  });

  final MnnTestController controller;
  final TextEditingController portController;
  final TextEditingController apiKeyController;
  final bool portValid;
  final VoidCallback onCheckPort;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final server = controller.snapshot?.server;
    final running = server?.running == true;
    final serverState = controller.snapshot?.serverState;
    final generating = controller.snapshot?.generationState == 'generating';
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
          const SelectableText('Host: 127.0.0.1（loopback only）'),
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
            decoration: const InputDecoration(labelText: 'API Key（留空关闭认证）'),
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
        controller.operationRunning || controller.streamRunning || generating;
    final promptReady = promptController.text.trim().isNotEmpty;
    final canSend = running && !requestBusy && promptReady && parametersValid;
    final canQuery = running && !controller.operationRunning;
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
            ],
          ),
          const SizedBox(height: 12),
          if (controller.streamingOutput.isNotEmpty)
            SelectableText(controller.streamingOutput),
          if (controller.apiResult != null) ...[
            Text(
              '${controller.apiResult!.label} · '
              '${controller.apiResult!.succeeded ? 'success' : 'failed'}',
            ),
            Text(
              'HTTP ${controller.apiResult!.statusCode?.toString() ?? '-'} · '
              'Total ${controller.apiResult!.elapsedMs} ms'
              '${controller.apiResult!.firstTokenMs == null ? '' : ' · TTFT ${controller.apiResult!.firstTokenMs} ms'}',
            ),
            if (controller.apiResult!.totalTokens != null)
              Text(
                'Usage: prompt ${controller.apiResult!.promptTokens ?? '-'} · '
                'completion ${controller.apiResult!.completionTokens ?? '-'} · '
                'total ${controller.apiResult!.totalTokens}',
              ),
            const SizedBox(height: 4),
            SelectableText(controller.apiResult!.output),
          ],
        ],
      ),
    );
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
