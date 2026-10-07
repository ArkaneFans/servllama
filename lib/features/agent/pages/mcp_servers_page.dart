import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class McpServersPage extends StatefulWidget {
  const McpServersPage({super.key});
  @override
  State<McpServersPage> createState() => _McpServersPageState();
}

class _McpServersPageState extends State<McpServersPage> {
  List<McpServer> servers = [];
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runUiAction(context, reload);
    });
  }

  Future<void> reload() async {
    if (!mounted) return;
    final service = context.read<AgentToolService>();
    final assistants = context.read<AssistantProvider>();
    try {
      final records = await service.repository.servers();
      await assistants.load();
      if (mounted) setState(() => servers = records);
    } finally {
      if (mounted) setState(() => loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AgentToolService>();
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2Mcp)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.v2Add,
        onPressed: () => edit(null),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => runUiAction(context, reload),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!loaded)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (loaded && servers.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 88),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hub_outlined,
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
                          l.v2McpHelp,
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
              if (servers.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                  sliver: SliverList.list(
                    children: [
                      Text(l.v2McpHelp),
                      const SizedBox(height: 12),
                      ...servers.map(
                        (a) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.hub_outlined),
                            title: Text(a.name),
                            subtitle: Text(
                              a.url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => edit(a),
                            trailing: IconButton(
                              tooltip: l.commonDelete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runUiAction(context, () async {
                                try {
                                  await s.deleteMcp(a);
                                } finally {
                                  await reload();
                                }
                              }),
                            ),
                          ),
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
