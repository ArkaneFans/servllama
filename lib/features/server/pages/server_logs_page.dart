import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/providers/server_logs_provider.dart';
import 'package:servllama/l10n/l10n.dart';

class ServerLogsPage extends StatelessWidget {
  const ServerLogsPage({super.key, this.logger});

  final AppLogger? logger;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServerLogsProvider(logger: logger),
      child: const _ServerLogsView(),
    );
  }
}

class _ServerLogsView extends StatefulWidget {
  const _ServerLogsView();

  @override
  State<_ServerLogsView> createState() => _ServerLogsViewState();
}

class _ServerLogsViewState extends State<_ServerLogsView> {
  final ScrollController _scrollController = ScrollController();
  _LogFilter _filter = _LogFilter.all;
  bool _autoScroll = true;

  ServerLogsProvider? _provider;
  int _lastCount = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ServerLogsProvider>();
    if (identical(provider, _provider)) {
      return;
    }
    _provider?.removeListener(_handleLogsChanged);
    _provider = provider;
    _lastCount = provider.count;
    provider.addListener(_handleLogsChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyAll(BuildContext context) async {
    final l10n = context.l10n;
    final provider = context.read<ServerLogsProvider>();
    final copyText = _filtered(
      provider.logs,
    ).map(provider.formatEntry).join('\n');
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.serverLogsCopied)));
  }

  Future<void> _export(BuildContext context) async {
    final l10n = context.l10n;
    final provider = context.read<ServerLogsProvider>();
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'servllama-logs-$timestamp.txt',
      );
      await file.writeAsString(
        _filtered(provider.logs).map(provider.formatEntry).join('\n'),
        flush: true,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serverLogsExported(file.path))),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.serverLogsExportFailed('$error'))),
      );
    }
  }

  void _clearLogs() {
    _provider?.clear();
  }

  void _handleLogsChanged() {
    final provider = _provider;
    if (provider == null) {
      return;
    }
    final shouldAutoScroll = _isNearBottom();
    final countIncreased = provider.count > _lastCount;
    _lastCount = provider.count;
    if (countIncreased && _autoScroll && shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.pixels <= 72;
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(0);
  }

  Color _resolveLogColor(BuildContext context, AppLogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    if (entry.level == LogLevel.error) {
      return colorScheme.error;
    }

    return colorScheme.onSurfaceVariant;
  }

  List<AppLogEntry> _filtered(List<AppLogEntry> logs) {
    return logs
        .where((entry) {
          switch (_filter) {
            case _LogFilter.all:
              return true;
            case _LogFilter.engine:
              return entry.channel == LogChannel.engine;
            case _LogFilter.server:
              return entry.channel == LogChannel.server;
            case _LogFilter.model:
              return entry.channel == LogChannel.model;
            case _LogFilter.download:
              return entry.channel == LogChannel.download;
            case _LogFilter.errors:
              return entry.isError;
          }
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<ServerLogsProvider>(
      builder: (context, provider, _) {
        // One snapshot per rebuild — the getter copies the backing list.
        final logs = _filtered(provider.logs);
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.serverLogsTitle),
            actions: [
              IconButton(
                onPressed: provider.isEmpty ? null : () => _copyAll(context),
                tooltip: l10n.serverLogsCopyAll,
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                onPressed: logs.isEmpty ? null : () => _export(context),
                tooltip: l10n.serverLogsExport,
                icon: const Icon(Icons.file_download_outlined),
              ),
              IconButton(
                onPressed: provider.isEmpty ? null : _clearLogs,
                tooltip: l10n.serverLogsClear,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    for (final filter in _LogFilter.values) ...[
                      FilterChip(
                        selected: _filter == filter,
                        label: Text(_filterLabel(context, filter)),
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                      if (filter != _LogFilter.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.serverLogsCount(logs.length),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(l10n.serverLogsAutoScroll),
                    Switch(
                      value: _autoScroll,
                      onChanged: (value) => setState(() => _autoScroll = value),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.terminal_outlined,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.serverLogsEmpty,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        key: const Key('serverLogsScrollView'),
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: SelectableText.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                            children: [
                              for (var i = 0; i < logs.length; i++)
                                TextSpan(
                                  text: i == logs.length - 1
                                      ? provider.formatEntry(logs[i])
                                      : '${provider.formatEntry(logs[i])}\n',
                                  style: TextStyle(
                                    color: _resolveLogColor(context, logs[i]),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _filterLabel(BuildContext context, _LogFilter filter) {
    final l10n = context.l10n;
    switch (filter) {
      case _LogFilter.all:
        return l10n.serverLogsFilterAll;
      case _LogFilter.engine:
        return l10n.serverLogsFilterEngine;
      case _LogFilter.server:
        return l10n.serverLogsFilterServer;
      case _LogFilter.model:
        return l10n.serverLogsFilterModel;
      case _LogFilter.download:
        return l10n.serverLogsFilterDownload;
      case _LogFilter.errors:
        return l10n.serverLogsFilterErrors;
    }
  }
}

enum _LogFilter { all, engine, server, model, download, errors }
