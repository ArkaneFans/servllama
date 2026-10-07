import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/tool_invocation_card.dart';
import 'package:servllama/l10n/l10n.dart';

/// Displays the selected reply's receipts, never executes or replays tools.
class ChatToolActivity extends StatefulWidget {
  const ChatToolActivity({
    super.key,
    required this.conversationId,
    required this.runId,
  });

  final String conversationId;
  final String runId;

  @override
  State<ChatToolActivity> createState() => _ChatToolActivityState();
}

class _ChatToolActivityState extends State<ChatToolActivity> {
  AgentToolService? _service;
  bool _live = false;
  List<ToolInvocation> _lastLive = const [];
  Future<List<ToolInvocation>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.watch<AgentToolService?>();
    if (!identical(service, _service)) {
      _service = service;
      _reset();
    }
    _sync();
  }

  @override
  void didUpdateWidget(covariant ChatToolActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runId != widget.runId ||
        oldWidget.conversationId != widget.conversationId) {
      _reset();
      _sync();
    }
  }

  void _reset() {
    _live = false;
    _lastLive = const [];
    _history = null;
  }

  Future<List<ToolInvocation>> _loadHistory() =>
      _service!.repository.forRun(widget.conversationId, widget.runId);

  void _sync() {
    final service = _service;
    if (service == null) return;
    final live =
        service.activeRunId == widget.runId &&
        service.activeConversationId == widget.conversationId;
    if (live) {
      _lastLive = service.activeInvocations;
    } else if (_live || _history == null) {
      // One read on mount or after the live session closes, never per token.
      _history = _loadHistory();
    }
    _live = live;
  }

  @override
  Widget build(BuildContext context) {
    if (_service == null) return const SizedBox.shrink();
    if (_live) return _receipts(_lastLive);
    return FutureBuilder<List<ToolInvocation>>(
      key: ValueKey((widget.conversationId, widget.runId)),
      future: _history,
      initialData: _lastLive,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(context.l10n.v2ToolHistoryFailed),
                TextButton(
                  onPressed: () => setState(() {
                    _history = _loadHistory();
                  }),
                  child: Text(context.l10n.v2ToolRetryLoad),
                ),
              ],
            ),
          );
        }
        return _receipts(snapshot.data ?? const []);
      },
    );
  }

  Widget _receipts(List<ToolInvocation> records) {
    if (records.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('chat_tools_${widget.runId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.v2ToolCallCount(records.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          for (final record in records)
            ToolInvocationCard(key: ValueKey(record.id), invocation: record),
        ],
      ),
    );
  }
}
