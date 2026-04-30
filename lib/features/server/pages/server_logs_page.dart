import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleLogsChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _copyAll(BuildContext context) async {
    final l10n = context.l10n;
    final copyText = context.read<ServerLogsProvider>().copyText;
    await Clipboard.setData(ClipboardData(text: copyText));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.serverLogsCopied)));
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
    if (countIncreased && shouldAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= 72;
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Color _resolveLogColor(BuildContext context, AppLogEntry entry) {
    final colorScheme = Theme.of(context).colorScheme;
    if (entry.level == LogLevel.error) {
      return colorScheme.error;
    }
  
    return colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Consumer<ServerLogsProvider>(
      builder: (context, provider, _) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.serverLogsTitle),
          actions: [
            IconButton(
              onPressed: provider.isEmpty ? null : () => _copyAll(context),
              tooltip: l10n.serverLogsCopyAll,
              icon: const Icon(Icons.copy_all_outlined),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.serverLogsCount(provider.count),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: provider.isEmpty
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
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: provider.logs.length,
                      itemBuilder: (context, index) {
                        final entry = provider.logs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            entry.formattedMessage,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                  color: _resolveLogColor(context, entry),
                                ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
