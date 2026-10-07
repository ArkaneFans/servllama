import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key});
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  List<SkillRecord> skills = [];
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
      final records = await service.repository.skills();
      await assistants.load();
      if (mounted) setState(() => skills = records);
    } finally {
      if (mounted) setState(() => loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AgentToolService>();
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2Skills)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.v2ImportSkill,
        onPressed: () => runUiAction(context, () async {
          await s.importSkill();
          await reload();
        }),
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
              if (loaded && skills.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 88),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.v2SkillsEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.v2SkillsHelp,
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
              if (skills.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                  sliver: SliverList.list(
                    children: [
                      Text(l.v2SkillsHelp),
                      const SizedBox(height: 12),
                      ...skills.map(
                        (a) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(a.name),
                            subtitle: Text(
                              a.description +
                                  (a.hasScripts
                                      ? '\n${l.v2ScriptsUnsupported}'
                                      : ''),
                            ),
                            trailing: IconButton(
                              tooltip: l.commonDelete,
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => runUiAction(context, () async {
                                try {
                                  await s.deleteSkill(a);
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
}
