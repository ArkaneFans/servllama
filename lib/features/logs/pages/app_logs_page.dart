import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/logs/providers/app_logs_provider.dart';
import 'package:servllama/core/services/downloads_export_service.dart';
import 'package:servllama/l10n/l10n.dart';

class AppLogsPage extends StatelessWidget {
  const AppLogsPage({super.key, this.logger, this.exportService});

  final AppLogger? logger;
  final DownloadsExportService? exportService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppLogsProvider(logger: logger),
      child: _AppLogsView(
        exportService: exportService ?? DownloadsExportService(),
      ),
    );
  }
}

class _AppLogsView extends StatefulWidget {
  const _AppLogsView({required this.exportService});

  final DownloadsExportService exportService;

  @override
  State<_AppLogsView> createState() => _AppLogsViewState();
}

class _AppLogsViewState extends State<_AppLogsView>
    with WidgetsBindingObserver {
  static const double _bottomStickTolerance = 72;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  LogChannel? _channel;
  LogLevel? _minimumLevel;
  String _query = '';
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

  AppLogsProvider? _provider;

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
    final provider = context.read<AppLogsProvider>();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _copyAll(BuildContext context) async {
    final l10n = context.l10n;
    final provider = context.read<AppLogsProvider>();
    final copyText = _filtered(provider).map(provider.formatEntry).join('\n');
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) {
      return;
    }
    AppMessage.show(context, l10n.appLogsCopied);
  }

  Future<void> _export(BuildContext context) async {
    final l10n = context.l10n;
    final provider = context.read<AppLogsProvider>();
    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final path = await widget.exportService.saveTextFile(
        fileName: 'servllama-logs-$timestamp.txt',
        content: _filtered(provider).map(provider.formatEntry).join('\n'),
      );
      if (!context.mounted) {
        return;
      }
      AppMessage.show(context, l10n.appLogsExported(path));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      AppMessage.show(
        context,
        l10n.appLogsExportFailed(_exportError(error)),
        tone: AppMessageTone.error,
      );
    }
  }

  String _exportError(Object error) {
    if (error is PlatformException) {
      return error.message ?? error.code;
    }
    return '$error';
  }

  Future<void> _clearLogs() async {
    try {
      await _provider?.clear();
    } catch (_) {
      if (!mounted) return;
      AppMessage.show(
        context,
        context.l10n.appLogsClearFailed,
        tone: AppMessageTone.error,
      );
    }
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

  List<AppLogEntry> _filtered(AppLogsProvider provider) => provider.query(
    channel: _channel,
    minimumLevel: _minimumLevel,
    text: _query,
  );

  void _changeFilter(VoidCallback update) {
    setState(update);
    if (_autoScroll) {
      _stuckToBottom = true;
      _schedulePinToBottom(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<AppLogsProvider>(
      builder: (context, provider, _) {
        // One snapshot per rebuild — the getter copies the backing list.
        final logs = _filtered(provider);
        return AppScaffold(
          appBar: AppBar(
            title: Text(l10n.appLogsTitle),
            actions: [
              IconButton(
                onPressed: logs.isEmpty ? null : () => _copyAll(context),
                tooltip: l10n.appLogsCopyAll,
                icon: const Icon(Icons.copy_all_outlined),
              ),
              IconButton(
                onPressed: logs.isEmpty ? null : () => _export(context),
                tooltip: l10n.appLogsExport,
                icon: const Icon(Icons.file_download_outlined),
              ),
              IconButton(
                onPressed: provider.isEmpty ? null : _clearLogs,
                tooltip: l10n.appLogsClear,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Keep log results visible when large fonts or the keyboard
                // reduce the viewport. Filters can scroll within their area.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * 0.6,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: TextField(
                            key: const Key('appLogsSearch'),
                            controller: _searchController,
                            onChanged: (value) =>
                                _changeFilter(() => _query = value),
                            decoration: InputDecoration(
                              labelText: l10n.appLogsSearch,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: l10n.appLogsClearSearch,
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        _searchController.clear();
                                        _changeFilter(() => _query = '');
                                      },
                                    ),
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                          child: Row(
                            children: [
                              for (final channel in <LogChannel?>[
                                null,
                                ...LogChannel.values,
                              ]) ...[
                                FilterChip(
                                  selected: _channel == channel,
                                  label: Text(_channelLabel(context, channel)),
                                  onSelected: (_) =>
                                      _changeFilter(() => _channel = channel),
                                ),
                                if (channel != LogChannel.values.last)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 8, 6),
                          child: Wrap(
                            spacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 280,
                                ),
                                child: DropdownButton<LogLevel?>(
                                  key: const Key('appLogsLevel'),
                                  value: _minimumLevel,
                                  isExpanded: true,
                                  items: [
                                    DropdownMenuItem(
                                      value: null,
                                      child: Text(
                                        l10n.appLogsAllLevels,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    for (final level in LogLevel.values)
                                      DropdownMenuItem(
                                        value: level,
                                        child: Text(
                                          _levelLabel(context, level),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (value) => _changeFilter(
                                    () => _minimumLevel = value,
                                  ),
                                ),
                              ),
                              Text(
                                l10n.appLogsVisibleCount(
                                  logs.length,
                                  provider.count,
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(l10n.appLogsAutoScroll),
                                  Switch(
                                    value: _autoScroll,
                                    onChanged: (value) {
                                      setState(() {
                                        _autoScroll = value;
                                        if (value) _stuckToBottom = true;
                                      });
                                      if (value) {
                                        _schedulePinToBottom(force: true);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.appLogsRetention(provider.maxEntries),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
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
                                provider.isEmpty
                                    ? l10n.appLogsEmpty
                                    : l10n.appLogsNoMatches,
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
                                key: const Key('appLogsScrollView'),
                                controller: _scrollController,
                                reverse: false,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  16,
                                ),
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
          ),
        );
      },
    );
  }

  String _channelLabel(BuildContext context, LogChannel? channel) {
    final l10n = context.l10n;
    switch (channel) {
      case null:
        return l10n.appLogsFilterAll;
      case LogChannel.app:
        return l10n.appLogsFilterApp;
      case LogChannel.client:
        return l10n.appLogsFilterClient;
      case LogChannel.agent:
        return l10n.appLogsFilterAgent;
      case LogChannel.speech:
        return l10n.appLogsFilterSpeech;
      case LogChannel.engine:
        return l10n.appLogsFilterEngine;
      case LogChannel.server:
        return l10n.appLogsFilterServer;
      case LogChannel.model:
        return l10n.appLogsFilterModel;
      case LogChannel.download:
        return l10n.appLogsFilterDownload;
    }
  }

  String _levelLabel(BuildContext context, LogLevel level) => switch (level) {
    LogLevel.debug => context.l10n.appLogsLevelDebug,
    LogLevel.info => context.l10n.appLogsLevelInfo,
    LogLevel.warning => context.l10n.appLogsLevelWarning,
    LogLevel.error => context.l10n.appLogsFilterErrors,
  };
}
