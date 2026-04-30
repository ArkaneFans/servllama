import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/services/llama_server_service.dart';

class PrototypePage extends StatefulWidget {
  const PrototypePage({super.key});

  @override
  State<PrototypePage> createState() => _PrototypePageState();
}

class _PrototypePageState extends State<PrototypePage> {
  final LlamaServerService _serverService = LlamaServerService();
  final List<String> _logs = <String>[];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _argsController = TextEditingController();

  bool _isRunning = false;
  bool _isLoading = false;
  bool _showAdvancedOptions = false;
  StreamSubscription<String>? _logSubscription;

  @override
  void initState() {
    super.initState();
    _isRunning = _serverService.isRunning;
    _logSubscription = _serverService.logStream.listen((log) {
      if (!mounted) {
        return;
      }
      setState(() {
        _logs.add(log);
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startServer() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final customArgs = _argsController.text.trim();
    final args = customArgs.isEmpty
        ? <String>[]
        : customArgs.split(RegExp(r'\s+'));

    final success = await _serverService.startServer(args: args);

    if (!mounted) {
      return;
    }

    setState(() {
      _isRunning = success;
      _isLoading = false;
    });
  }

  Future<void> _stopServer() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _serverService.stopServer();

    if (!mounted) {
      return;
    }

    setState(() {
      _isRunning = !success;
      _isLoading = false;
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  Future<void> _importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final filePath = file.path;

      if (filePath == null) {
        _addLog('[错误] 无法获取文件路径');
        return;
      }

      _addLog('正在导入模型: ${file.name}');

      final appDir = await getApplicationSupportDirectory();
      final modelsDir = Directory('${appDir.path}/models');

      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      final destPath = '${modelsDir.path}/${file.name}';
      final sourceFile = File(filePath);
      await sourceFile.copy(destPath);

      _addLog('模型导入成功: $destPath');
    } catch (error) {
      _addLog('导入模型失败: $error');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
    _scrollToBottom();
  }

  Color _resolveLogColor(String log) {
    if (log.contains('[错误]') || log.contains('[STDERR]')) {
      return Colors.redAccent;
    }
    if (log.contains('[警告]')) {
      return Colors.orangeAccent;
    }
    if (log.contains('成功')) {
      return Colors.greenAccent;
    }
    return Colors.lightGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          title: const Row(
            children: [
              Icon(Icons.science_outlined),
              SizedBox(width: 8),
              Text('服务原型'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _clearLogs,
              icon: const Icon(Icons.clear_all),
              tooltip: '清空日志',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildControlPanel(context),
            _buildStatusIndicator(context),
            Expanded(child: _buildLogConsole(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '服务控制',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _importModel,
            icon: const Icon(Icons.file_upload),
            label: const Text('导入 GGUF 模型'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showAdvancedOptions = !_showAdvancedOptions;
              });
            },
            icon: Icon(
              _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
            ),
            label: Text(
              _showAdvancedOptions ? '收起高级选项' : '展开高级选项',
            ),
          ),
          if (_showAdvancedOptions) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _argsController,
              decoration: InputDecoration(
                labelText: '额外启动参数',
                hintText: '例如: --port 8080 --ctx-size 4096',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.terminal),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _argsController.clear(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRunning || _isLoading ? null : _startServer,
                  icon: _isLoading && !_isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('启动服务'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !_isRunning || _isLoading ? null : _stopServer,
                  icon: _isLoading && _isRunning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.stop),
                  label: const Text('停止服务'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRunning ? Colors.green : Colors.grey,
              boxShadow: _isRunning
                  ? [
                      BoxShadow(
                        color: Colors.green.withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isRunning ? '服务运行中' : '服务已停止',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (_isRunning) ...[
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(100)),
              ),
              child: const Text(
                'API 可用',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogConsole(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '服务日志',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_logs.length} 条',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.terminal_outlined,
                          size: 48,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '暂无日志输出',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: SelectableText(
                          log,
                          style: TextStyle(
                            color: _resolveLogColor(log),
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
