import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/pages/skills_page.dart';
import 'package:servllama/features/agent/pages/mcp_servers_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/models/web_search.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class AssistantToolsEditor extends StatefulWidget {
  const AssistantToolsEditor({super.key, required this.assistant});
  final Assistant assistant;
  @override
  State<AssistantToolsEditor> createState() => AssistantToolsEditorState();
}

class AssistantToolsEditorState extends State<AssistantToolsEditor>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int tab = 0;
  late final grants = widget.assistant.tools.toSet(),
      skills = widget.assistant.skillIds.toSet(),
      servers = widget.assistant.mcpServerIds.toSet();
  List<SkillRecord> availableSkills = [];
  late WebSearchProvider searchProvider = widget.assistant.webSearch.provider;
  late int searchLimit = widget.assistant.webSearch.maxResults;
  List<McpServer> availableServers = [];
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runUiAction(context, _refreshCatalogs);
    });
  }

  Future<void> _refreshCatalogs() async {
    final repository = AgentRepository(
      (await context.read<AssistantProvider>().repository).db,
    );
    final a = await repository.skills();
    final b = await repository.servers();
    if (!mounted) return;
    setState(() {
      availableSkills = a;
      availableServers = b;
      skills.retainWhere(a.map((s) => s.id).toSet().contains);
      final knownTools = {
        'clock',
        'ask_user',
        'read_skill',
        'web_search',
        for (final server in b)
          for (final tool in server.tools)
            AgentToolService.mcpToolName(server.id, tool['name'] as String),
      };
      grants.retainWhere(knownTools.contains);
      servers
        ..clear()
        ..addAll(
          b
              .where(
                (server) => server.tools.any(
                  (tool) => grants.contains(
                    AgentToolService.mcpToolName(
                      server.id,
                      tool['name'] as String,
                    ),
                  ),
                ),
              )
              .map((server) => server.id),
        );
      loaded = true;
    });
  }

  Future<Map<String, dynamic>> changes() async {
    await _refreshCatalogs();
    return {
      'tools': grants.toList(),
      'skillIds': skills.toList(),
      'mcpServerIds': servers.toList(),
      'webSearch': WebSearchOptions(
        provider: searchProvider,
        maxResults: searchLimit,
      ).toJson(),
    };
  }

  Future<void> manage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => page),
    );
    if (mounted) await runUiAction(context, _refreshCatalogs);
  }

  void toggle(Set<String> target, String id, bool enabled) => setState(() {
    if (enabled) {
      target.add(id);
    } else {
      target.remove(id);
    }
  });
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final scrollTabs = MediaQuery.textScalerOf(context).scale(14) > 18;
    final locals = {
      'clock': l.v2ToolClock,
      'ask_user': l.v2ToolAsk,
      'web_search': l.v2ToolSearch,
    };
    return DefaultTabController(
      length: 3,
      initialIndex: tab,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: scrollTabs,
            tabAlignment: scrollTabs ? TabAlignment.start : TabAlignment.fill,
            onTap: (value) {
              if (value == tab) return;
              FocusManager.instance.primaryFocus?.unfocus();
              setState(() => tab = value);
            },
            tabs: [
              Tab(text: l.v2LocalTools),
              Tab(text: l.v2Skills),
              Tab(text: l.v2Mcp),
            ],
          ),
          const SizedBox(height: 16),
          if (!loaded) const LinearProgressIndicator(),
          if (tab == 0) ...[
            Text(
              l.v2PermissionsHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ...locals.entries.map(
              (e) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                value: grants.contains(e.key),
                onChanged: (v) => toggle(grants, e.key, v!),
              ),
            ),
            if (grants.contains('web_search')) ...[
              Text(
                l.v2SearchGrantHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WebSearchProvider>(
                key: const ValueKey('webSearchProvider'),
                initialValue: searchProvider,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.v2SearchProvider),
                items: [
                  DropdownMenuItem(
                    value: WebSearchProvider.bing,
                    child: Text(l.v2SearchBing),
                  ),
                  DropdownMenuItem(
                    value: WebSearchProvider.duckduckgo,
                    child: Text(l.v2SearchDuckDuckGo),
                  ),
                ],
                onChanged: (value) => setState(() => searchProvider = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                key: const ValueKey('webSearchLimit'),
                initialValue: searchLimit,
                decoration: InputDecoration(labelText: l.v2SearchMaxResults),
                items: [
                  for (var i = 1; i <= 10; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (value) => setState(() => searchLimit = value!),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (tab == 1) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => manage(const SkillsPage()),
                icon: const Icon(Icons.add),
                label: Text(l.v2ManageSkills),
              ),
            ),
            Text(
              l.v2SkillsGrantHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (loaded && availableSkills.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.v2SkillsEmpty, textAlign: TextAlign.center),
              ),
            ...availableSkills.map(
              (s) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.name),
                value: skills.contains(s.id),
                onChanged: (v) => toggle(skills, s.id, v!),
              ),
            ),
          ],
          if (tab == 2) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => manage(const McpServersPage()),
                icon: const Icon(Icons.add),
                label: Text(l.v2ManageMcp),
              ),
            ),
            if (loaded && availableServers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l.v2McpEmpty, textAlign: TextAlign.center),
              ),
            ...availableServers.map(
              (s) => ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(s.name),
                children: [
                  ...s.tools.map((t) {
                    final key = AgentToolService.mcpToolName(
                      s.id,
                      t['name'] as String,
                    );
                    return CheckboxListTile(
                      title: Text(t['name'] as String),
                      value: grants.contains(key),
                      onChanged: (v) {
                        toggle(grants, key, v!);
                        if (v) {
                          servers.add(s.id);
                        } else if (!s.tools.any(
                          (t) => grants.contains(
                            AgentToolService.mcpToolName(
                              s.id,
                              t['name'] as String,
                            ),
                          ),
                        )) {
                          servers.remove(s.id);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
