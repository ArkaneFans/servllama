import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/providers/server_logs_provider.dart';
import 'package:servllama/core/services/downloads_export_service.dart';
import 'package:servllama/l10n/l10n.dart';

class ServerLogsPage extends StatelessWidget {
  const ServerLogsPage({super.key, this.logger, this.exportService});

  final AppLogger? logger;
  final DownloadsExportService? exportService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServerLogsProvider(logger: logger),
      child: _ServerLogsView(
        exportService: exportService ?? DownloadsExportService(),
      ),
    );
  }
}

class _ServerLogsView extends StatefulWidget {
  const _ServerLogsView({required this.exportService});

  final DownloadsExportService exportService;

  @override
  State<_ServerLogsView> createState() => _ServerLogsViewState();
}

class _ServerLogsViewState extends State<_ServerLogsView>
    with WidgetsBindingObserver {
  static const double _bottomStickTolerance = 72;

  final ScrollController _scrollController = ScrollController();
  _LogFilter _filter = _LogFilter.all;
  bool _autoScroll = true;

  // Forward list: stick to the latest logs with jumpTo (no animation).
  // Hide the viewport until the first pin so opening the page does not
  // flash the oldest entries at the top.
  bool _stuckToBottom = true;
  bool _ready = false;
  bool _pinning = false;
  bool _selecting = false;
  bool _pinScheduled = false;
  bool _forcePin = false;

  ServerLogsProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleUserScroll);
    _schedulePinToBottom(force: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<ServerLogsProvider>();
    if (identical(provider, _provider)) {
      return;
    }
    _provider?.removeListener(_handleLogsChanged);
    _provider = provider;
    provider.addListener(_handleLogsChanged);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (_autoScroll && _stuckToBottom && !_selecting && _ready) {
      _schedulePinToBottom();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleUserScroll);
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
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final path = await widget.exportService.saveTextFile(
        fileName: 'servllama-logs-$timestamp.txt',
        content: _filtered(provider.logs).map(provider.formatEntry).join('\n'),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.serverLogsExported(path))));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.serverLogsExportFailed(_exportError(error))),
        ),
      );
    }
  }

  String _exportError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return '$error';
  }

  void _clearLogs() {
    _provider?.clear();
  }

  void _handleLogsChanged() {
    final provider = _provider;
    if (provider == null) {
      return;
    }
    if (provider.count == 0) {
      _stuckToBottom = true;
      _ready = false;
      _selecting = false;
      return;
    }
    if (!_ready || (_autoScroll && _stuckToBottom && !_selecting)) {
      _schedulePinToBottom();
    }
  }

  void _handleUserScroll() {
    if (_pinning || !_scrollController.hasClients) {
      return;
    }
    _stuckToBottom = _isAtBottom();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_pinning || notification.depth != 0) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      _stuckToBottom = _isAtBottom();
    } else if (notification is ScrollEndNotification) {
      _stuckToBottom = _isAtBottom();
    }
    return false;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final selecting = !selection.isCollapsed;
    if (_selecting == selecting) {
      return;
    }
    _selecting = selecting;
    if (!selecting && _autoScroll && _stuckToBottom) {
      _schedulePinToBottom();
    }
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return true;
    }
    return position.pixels >= position.maxScrollExtent - _bottomStickTolerance;
  }

  void _schedulePinToBottom({bool force = false}) {
    _forcePin = _forcePin || force;
    if (_pinScheduled) {
      return;
    }
    _pinScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pinScheduled = false;
      final forcePin = _forcePin;
      _forcePin = false;
      if (!mounted) {
        return;
      }
      if (!_scrollController.hasClients) {
        _ready = false;
        return;
      }
      if (forcePin ||
          !_ready ||
          (_autoScroll && _stuckToBottom && !_selecting)) {
        _pinToBottom();
      }
      if (!_ready) {
        setState(() => _ready = true);
      }
    });
  }

  void _pinToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final target = position.maxScrollExtent;
    _stuckToBottom = true;
    if ((position.pixels - target).abs() < 0.5) {
      return;
    }
    _pinning = true;
    try {
      _scrollController.jumpTo(target);
    } finally {
      _pinning = false;
    }
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
                        onSelected: (_) {
                          setState(() => _filter = filter);
                          if (_autoScroll) {
                            _stuckToBottom = true;
                            _schedulePinToBottom(force: true);
                          } else {
                            _schedulePinToBottom();
                          }
                        },
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
                      onChanged: (value) {
                        setState(() {
                          _autoScroll = value;
                          if (value) {
                            _stuckToBottom = true;
                          }
                        });
                        if (value) {
                          _schedulePinToBottom(force: true);
                        }
                      },
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
                    : NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: IgnorePointer(
                          ignoring: !_ready,
                          child: Opacity(
                            opacity: _ready ? 1 : 0,
                            child: SingleChildScrollView(
                              key: const Key('serverLogsScrollView'),
                              controller: _scrollController,
                              reverse: false,
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
                                          color: _resolveLogColor(
                                            context,
                                            logs[i],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                onSelectionChanged: _handleSelectionChanged,
                              ),
                            ),
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
