import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/native_library_dir_service.dart';

/// Developer-only page for launching llama-server with custom arguments.
/// Only reachable from the sidebar in debug builds; strings are
/// intentionally not localized.
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  // Survives page re-entry within the same app session.
  static String _lastArgs = '';

  final LlamaServerService _serverService = LlamaServerService();
  final NativeLibraryDirService _nativeLibraryDirService =
      NativeLibraryDirService();
  final ModelStoragePaths _modelStoragePaths = ModelStoragePaths();
  final List<String> _logs = <String>[];
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _argsController;

  bool _isRunning = false;
  bool _isBusy = false;
  String? _nativeLibraryDir;
  String? _modelsDirectoryPath;
  StreamSubscription<String>? _logSubscription;
  StreamSubscription<bool>? _runningSubscription;

  @override
  void initState() {
    super.initState();
    _argsController = TextEditingController(text: _lastArgs);
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
    _runningSubscription = _serverService.runningStateStream.listen((running) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRunning = running;
      });
    });
    _loadPaths();
  }

  @override
  void dispose() {
    _lastArgs = _argsController.text;
    _logSubscription?.cancel();
    _runningSubscription?.cancel();
    _scrollController.dispose();
    _argsController.dispose();
    super.dispose();
  }

  Future<void> _loadPaths() async {
    try {
      final nativeLibraryDir = await _nativeLibraryDirService
          .getNativeLibraryDir();
      final modelsDirectoryPath = await _modelStoragePaths
          .getModelsDirectoryPath();
      if (!mounted) {
        return;
      }
      setState(() {
        _nativeLibraryDir = nativeLibraryDir;
        _modelsDirectoryPath = modelsDirectoryPath;
      });
    } catch (_) {
      // Paths are informational only; leave them blank on failure.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startServer() async {
    if (_isBusy || _isRunning) {
      return;
    }
    setState(() {
      _isBusy = true;
    });

    final customArgs = _argsController.text.trim();
    final args = customArgs.isEmpty
        ? <String>[]
        : customArgs.split(RegExp(r'\s+'));

    _serverService.initForegroundTask();
    await _serverService.startServer(args: args);

    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = _serverService.isRunning;
      _isBusy = false;
    });
  }

  Future<void> _stopServer() async {
    if (_isBusy || !_isRunning) {
      return;
    }
    setState(() {
      _isBusy = true;
    });

    await _serverService.stopServer();

    if (!mounted) {
      return;
    }
    setState(() {
      _isRunning = _serverService.isRunning;
      _isBusy = false;
    });
  }

  void _copyToClipboard(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 已复制'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试'),
        actions: [
          IconButton(
            onPressed: () => setState(_logs.clear),
            icon: const Icon(Icons.clear_all),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PathRow(
                    label: '库目录',
                    value: _nativeLibraryDir,
                    onCopy: _copyToClipboard,
                  ),
                  const SizedBox(height: 4),
                  _PathRow(
                    label: '模型目录',
                    value: _modelsDirectoryPath,
                    onCopy: _copyToClipboard,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _argsController,
                    enabled: !_isRunning,
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: '启动参数',
                      hintText: '例如: -m <模型路径> --device HTP0 -ngl 99',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _isRunning || _isBusy ? null : _startServer,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('启动'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: !_isRunning || _isBusy ? null : _stopServer,
                          icon: const Icon(Icons.stop),
                          label: const Text('停止'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildLogConsole(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogConsole(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _logs.isEmpty
          ? Center(
              child: Text(
                '暂无日志输出',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    _logs[index],
                    style: const TextStyle(
                      color: Colors.lightGreen,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String? value;
  final void Function(String label, String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final path = value;

    return Row(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            path ?? '-',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        if (path != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 16,
            onPressed: () => onCopy(label, path),
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    );
  }
}
