import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/generation_run_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/tool_invocation_card.dart';
import 'package:servllama/l10n/l10n.dart';

class ToolActivityPage extends StatelessWidget {
  const ToolActivityPage({super.key, required this.conversationId});
  final String conversationId;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AgentToolService>();
    context.watch<ChatProvider?>();
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2ToolActivity)),
      body: Column(
        children: [
          _LatestRunStatus(conversationId: conversationId),
          Expanded(
            child: FutureBuilder<List<ToolInvocation>>(
              future: s.repository.history(conversationId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(l.v2OperationFailed));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data!.isEmpty) {
                  return Center(child: Text(l.v2ToolHistoryEmpty));
                }
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: snap.data!
                      .map(
                        (i) => ToolInvocationCard(
                          key: ValueKey(i.id),
                          invocation: i,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestRunStatus extends StatelessWidget {
  const _LatestRunStatus({required this.conversationId});
  final String conversationId;
  @override
  Widget build(BuildContext context) {
    context.watch<ChatProvider?>();
    final s = context.watch<AgentToolService>();
    final l = context.l10n;
    return FutureBuilder<String?>(
      future: GenerationRunRepository(
        s.repository.db,
      ).latestState(conversationId),
      builder: (context, value) {
        final label = switch (value.data) {
          'tokenBudget' ||
          'toolBudget' ||
          'turnBudget' ||
          'contextBudget' => l.v2BudgetReached,
          'interrupted' => l.v2Interrupted,
          'cancelled' => l.v2Cancelled,
          'failed' => l.v2Failed,
          'completed' => l.v2Succeeded,
          'running' => l.v2Executing,
          _ => null,
        };
        return label == null
            ? const SizedBox.shrink()
            : ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(label),
              );
      },
    );
  }
}

class AgentApprovalBanner extends StatelessWidget {
  const AgentApprovalBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AgentToolService?>();
    if (s == null || s.pendingCount == 0) return const SizedBox.shrink();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.pending_actions),
        title: Text(context.l10n.v2AwaitingApproval),
        trailing: TextButton(
          child: Text(context.l10n.v2Review),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  ToolActivityPage(conversationId: s.activeConversationId!),
            ),
          ),
        ),
      ),
    );
  }
}
