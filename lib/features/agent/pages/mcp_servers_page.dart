import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
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
      if (mounted) runUiAction(context, reload);
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> reload({bool refreshConnections = false}) async {
    if (!mounted) return;
    final service = context.read<AgentToolService>();
    final assistants = context.read<AssistantProvider>();
    if (refreshConnections) {
      await service.mcp.refreshAll();
    } else {
      await service.mcp.load();
    }
    await assistants.load();
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        McpIcon(
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.v2McpEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.v2McpEmptyHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
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
                          onDelete: () => runUiAction(context, () async {
                            try {
                              await s.deleteMcp(a);
                            } finally {
                              await reload();
                            }
                          }),
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
    required this.onDelete,
    required this.onErrorTap,
  });

  final McpServer server;
  final McpConnectionState state;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onErrorTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        trailing: IconButton(
          tooltip: l.commonDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
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
    final (statusLabel, tone) = switch (state.status) {
      McpConnectionStatus.disconnected => (
        l.v2McpStatusDisconnected,
        StatusTone.idle,
      ),
      McpConnectionStatus.connecting => (
        l.v2McpStatusConnecting,
        StatusTone.warning,
      ),
      McpConnectionStatus.connected => (l.v2McpStatusConnected, StatusTone.ok),
      McpConnectionStatus.failed => (l.v2McpStatusFailed, StatusTone.danger),
    };
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
        if (state.hasError && error != null) ...[
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
  final keyInput = TextEditingController(),
      headerInput = TextEditingController();
  bool clearKey = false, clearHeaders = false, showHeaders = false;
  Map<String, String>? get draftHeaders => headerInput.text.trim().isEmpty
      ? null
      : McpCredentials.parseHeaders(headerInput.text);
  late McpTransport transport = original.transport;
  late List<Map<String, dynamic>> tools = original.tools;
  bool busy = false;
  McpServer get draft => McpServer.fromJson({
    ...original.toJson(),
    'name': name.text.trim(),
    'url': url.text.trim(),
    'transport': transport.name,
    'revision': original.revision + 1,
    'tools': tools,
  });
  @override
  void dispose() {
    name.dispose();
    url.dispose();
    keyInput.dispose();
    headerInput.dispose();
    super.dispose();
  }

  Future<void> act(Future<void> Function() f) async {
    setState(() => busy = true);
    await runUiAction(context, f);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AgentToolService>();
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2Mcp),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => act(() async {
                    await s.saveMcp(
                      draft,
                      newKey: keyInput.text,
                      headers: draftHeaders,
                      clearKey: clearKey,
                      clearHeaders: clearHeaders,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: FormListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
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
            title: l.v2Credentials,
            children: [
              TextField(
                controller: keyInput,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l.v2McpToken,
                  helperText: l.v2KeyHelp,
                ),
              ),
              if (original.secretRef != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.v2ClearMcpToken),
                  value: clearKey,
                  onChanged: (v) => setState(() {
                    clearKey = v ?? false;
                  }),
                ),
              TextField(
                controller: headerInput,
                obscureText: !showHeaders,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l.v2McpHeaders,
                  helperText: l.v2McpHeadersHelp,
                  helperMaxLines: 4,
                  suffixIcon: IconButton(
                    icon: Icon(
                      showHeaders ? Icons.visibility_off : Icons.visibility,
                    ),
                    tooltip: l.v2ShowHideCredential,
                    onPressed: () => setState(() {
                      showHeaders = !showHeaders;
                    }),
                  ),
                ),
              ),
              if (original.secretRef != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.v2ClearMcpHeaders),
                  value: clearHeaders,
                  onChanged: (v) => setState(() {
                    clearHeaders = v ?? false;
                  }),
                ),
            ],
          ),
          SettingsSection.form(
            title: l.v2ModelTools,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => act(() async {
                        final discovered = await s.testMcp(
                          draft,
                          keyInput.text,
                          headers: draftHeaders,
                          clearKey: clearKey,
                          clearHeaders: clearHeaders,
                        );
                        if (mounted) setState(() => tools = discovered);
                      }),
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
          Text(l.v2DraftHelp, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
