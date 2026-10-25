import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/app_empty_state.dart';
import 'package:servllama/shared/widgets/mcp_icon.dart';
import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/models/mcp_connection.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';

class McpServersPage extends StatefulWidget {
  const McpServersPage({super.key});
  @override
  State<McpServersPage> createState() => _McpServersPageState();
}

class _McpServersPageState extends State<McpServersPage> {
  final search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        runUiAction(context, () => reload(refreshAssistants: false));
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> reload({
    bool refreshConnections = false,
    bool refreshAssistants = true,
  }) async {
    if (!mounted) return;
    final service = context.read<AgentToolService>();
    final assistants = context.read<AssistantProvider>();
    if (refreshConnections) {
      await service.mcp.refreshAll();
    } else {
      await service.mcp.ensureLoaded();
    }
    if (refreshAssistants) await assistants.load();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AgentToolService>();
    final servers = s.mcp.servers;
    final loaded = s.mcp.loaded;
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? servers
        : servers
              .where(
                (server) =>
                    server.name.toLowerCase().contains(query) ||
                    server.url.toLowerCase().contains(query),
              )
              .toList();
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2Mcp),
        actions: [
          IconButton(
            tooltip: l.v2Add,
            icon: const Icon(Icons.add),
            onPressed: () => edit(null),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () =>
              runUiAction(context, () => reload(refreshConnections: true)),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!loaded)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (loaded && servers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: McpIcon(
                      size: 40,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    title: l.v2McpEmpty,
                    description: l.v2McpEmptyHint,
                  ),
                ),
              if (loaded && servers.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      key: const Key('mcp_search'),
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l.v2McpSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l.v2McpSearchClear,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(search.clear),
                              ),
                      ),
                    ),
                  ),
                ),
              if (loaded && servers.isNotEmpty && visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
                    child: Text(
                      l.v2McpNoResults,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (visible.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverList.list(
                    children: [
                      ...visible.map(
                        (a) => _McpServerCard(
                          server: a,
                          state: s.mcp.stateFor(a.id),
                          onEdit: () => edit(a),
                          onErrorTap: (error) => _showConnectionError(a, error),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> edit(McpServer? server) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => McpEditor(server: server)),
    );
    if (mounted) await runUiAction(context, reload);
  }

  Future<void> _showConnectionError(McpServer server, String error) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.v2McpConnectionError),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                SelectableText(error),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
  }
}

class _McpServerCard extends StatelessWidget {
  const _McpServerCard({
    required this.server,
    required this.state,
    required this.onEdit,
    required this.onErrorTap,
  });

  final McpServer server;
  final McpConnectionState state;
  final VoidCallback onEdit;
  final ValueChanged<String> onErrorTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const McpIcon(),
        title: Text(server.name),
        subtitle: _McpServerSummary(
          server: server,
          state: state,
          onErrorTap: onErrorTap,
        ),
        onTap: onEdit,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _McpServerSummary extends StatelessWidget {
  const _McpServerSummary({
    required this.server,
    required this.state,
    required this.onErrorTap,
  });

  final McpServer server;
  final McpConnectionState state;
  final ValueChanged<String> onErrorTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final (statusLabel, tone) = server.enabled
        ? switch (state.status) {
            McpConnectionStatus.disconnected => (
              l.v2McpStatusDisconnected,
              StatusTone.idle,
            ),
            McpConnectionStatus.connecting => (
              l.v2McpStatusConnecting,
              StatusTone.warning,
            ),
            McpConnectionStatus.connected => (
              l.v2McpStatusConnected,
              StatusTone.ok,
            ),
            McpConnectionStatus.failed => (
              l.v2McpStatusFailed,
              StatusTone.danger,
            ),
          }
        : (l.v2McpStatusDisabled, StatusTone.idle);
    final error = state.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusPill(label: statusLabel, tone: tone, compact: true),
            _MetaTag(
              label: server.transport == McpTransport.sse ? 'SSE' : 'HTTP',
            ),
            _MetaTag(label: l.v2McpToolCount(state.toolCount)),
          ],
        ),
        if (server.enabled && state.hasError && error != null) ...[
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: l.v2McpConnectionError,
            child: InkWell(
              key: ValueKey('mcp_error_${server.id}'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => onErrorTap(error),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                decoration: BoxDecoration(
                  color: theme.palette.dangerMark.withAlpha(
                    theme.brightness == Brightness.light ? 18 : 30,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.palette.dangerText,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: theme.palette.dangerText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaTag extends StatelessWidget {
  const _MetaTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class McpEditor extends StatefulWidget {
  const McpEditor({super.key, this.server});
  final McpServer? server;
  @override
  State<McpEditor> createState() => _McpEditorState();
}

class _McpEditorState extends State<McpEditor> {
  late final original =
      widget.server ?? McpServer(id: newId(), name: '', url: '');
  late final name = TextEditingController(text: original.name),
      url = TextEditingController(text: original.url);
  final headers = <_McpHeaderDraft>[];
  late bool enabled = original.enabled;
  late McpTransport transport = original.transport;
  late List<Map<String, dynamic>> tools = original.tools;
  bool busy = false, headersLoaded = false, headersLoadFailed = false;
  McpServer get draft => McpServer.fromJson({
    ...original.toJson(),
    'name': name.text.trim(),
    'url': url.text.trim(),
    'enabled': enabled,
    'transport': transport.name,
    'revision': original.revision + 1,
    'tools': tools,
  });

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    for (final header in headers) {
      header.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHeaders() async {
    try {
      final stored = await context.read<AgentToolService>().mcpHeadersFor(
        original,
      );
      if (!mounted) return;
      setState(() {
        headers
          ..clear()
          ..addAll(
            stored.entries.map(
              (entry) => _McpHeaderDraft(entry.key, entry.value),
            ),
          );
        headersLoaded = true;
        headersLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        headersLoaded = true;
        headersLoadFailed = true;
      });
    }
  }

  void _retryHeaders() {
    setState(() {
      headersLoaded = false;
      headersLoadFailed = false;
    });
    _loadHeaders();
  }

  Map<String, String> _headerValues() {
    final result = <String, String>{};
    for (final header in headers) {
      final key = header.keyName.text.trim();
      final value = header.value.text.trim();
      if (key.isEmpty && value.isEmpty) continue;
      if (key.isEmpty) {
        throw const FormatException('HTTP header name cannot be empty');
      }
      if (result.keys.any(
        (existing) => existing.toLowerCase() == key.toLowerCase(),
      )) {
        throw const FormatException('Duplicate HTTP header name');
      }
      result[key] = value;
    }
    return result;
  }

  void _addHeader() {
    setState(() => headers.add(_McpHeaderDraft()));
  }

  void _removeHeader(int index) {
    setState(() => headers.removeAt(index).dispose());
  }

  Future<void> act(Future<void> Function() f) async {
    setState(() => busy = true);
    await runUiAction(context, f);
    if (mounted) setState(() => busy = false);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.v2McpDeleteTitle(original.name)),
        content: Text(l.v2McpDeleteCannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final service = context.read<AgentToolService>();
    await act(() async {
      await service.deleteMcp(original);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AgentToolService>();
    final l = context.l10n;
    final canEditHeaders = headersLoaded && !headersLoadFailed;
    final canSubmit = canEditHeaders && !busy;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2Mcp)),
      body: FormListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SettingsSection(
            title: l.v2McpStatus,
            child: SwitchSettingTile(
              key: const Key('mcp_enabled_switch'),
              title: enabled ? l.v2McpStatusEnabled : l.v2McpStatusDisabled,
              value: enabled,
              onChanged: busy
                  ? null
                  : (value) => setState(() => enabled = value),
            ),
          ),
          SettingsSection.form(
            title: l.v2ProviderConnection,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l.v2Name),
              ),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(labelText: l.v2BaseUrl),
              ),
              DropdownButtonFormField<McpTransport>(
                isExpanded: true,
                initialValue: transport,
                decoration: InputDecoration(labelText: l.v2Protocol),
                items: McpTransport.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(
                          t == McpTransport.sse
                              ? 'Legacy SSE'
                              : 'Streamable HTTP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (t) => setState(() => transport = t!),
              ),
            ],
          ),
          SettingsSection.form(
            title: l.v2McpHeaders,
            children: [
              if (!headersLoaded) const LinearProgressIndicator(),
              if (headersLoadFailed) ...[
                Text(
                  l.v2OperationFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _retryHeaders,
                    child: Text(l.v2ToolRetryLoad),
                  ),
                ),
              ],
              if (canEditHeaders) ...[
                for (var i = 0; i < headers.length; i++)
                  _McpHeaderRow(
                    index: i,
                    header: headers[i],
                    enabled: !busy,
                    onDelete: () => _removeHeader(i),
                  ),
                OutlinedButton.icon(
                  key: const Key('mcp_add_header'),
                  onPressed: busy ? null : _addHeader,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(l.v2AddHeader),
                ),
              ],
            ],
          ),
          SettingsSection.form(
            title: l.v2ModelTools,
            children: [
              OutlinedButton(
                onPressed: canSubmit
                    ? () => act(() async {
                        final discovered = await s.testMcp(
                          draft,
                          headers: _headerValues(),
                        );
                        if (mounted) setState(() => tools = discovered);
                      })
                    : null,
                child: Text(l.v2DiscoverTools),
              ),
              if (busy) const LinearProgressIndicator(),

              ...tools.map(
                (t) => ListTile(
                  title: Text(t['name'].toString()),
                  subtitle: Text((t['description'] ?? '').toString()),
                ),
              ),
            ],
          ),
          FilledButton.icon(
            key: const Key('mcp_save_button'),
            onPressed: canSubmit
                ? () => act(() async {
                    await s.saveMcp(draft, headers: _headerValues());
                    if (context.mounted) Navigator.pop(context);
                  })
                : null,
            icon: const Icon(Icons.save_outlined, size: 20),
            label: Text(l.commonSave),
          ),
          if (widget.server != null)
            OutlinedButton.icon(
              key: const Key('mcp_delete_button'),
              onPressed: busy ? null : _delete,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(l.commonDelete),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}

class _McpHeaderDraft {
  _McpHeaderDraft([String key = '', String value = ''])
    : keyName = TextEditingController(text: key),
      value = TextEditingController(text: value);

  final TextEditingController keyName;
  final TextEditingController value;

  void dispose() {
    keyName.dispose();
    value.dispose();
  }
}

class _McpHeaderRow extends StatelessWidget {
  const _McpHeaderRow({
    required this.index,
    required this.header,
    required this.enabled,
    required this.onDelete,
  });

  final int index;
  final _McpHeaderDraft header;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              TextField(
                key: ValueKey('mcp_header_name_$index'),
                controller: header.keyName,
                enabled: enabled,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.v2McpHeaderName),
              ),
              const SizedBox(height: 12),
              TextField(
                key: ValueKey('mcp_header_value_$index'),
                controller: header.value,
                enabled: enabled,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(labelText: l.v2McpHeaderValue),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l.v2RemoveHeader,
          onPressed: enabled ? onDelete : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
