import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/web_search_receipt.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

/// Shared by the chat reply and the conversation's activity page.
class ToolInvocationCard extends StatefulWidget {
  const ToolInvocationCard({super.key, required this.invocation});

  final ToolInvocation invocation;

  @override
  State<ToolInvocationCard> createState() => _ToolInvocationCardState();
}

class _ToolInvocationCardState extends State<ToolInvocationCard> {
  final _answer = TextEditingController();
  bool _expanded = false;
  bool _deciding = false;
  late String _arguments;
  String? _result;

  @override
  void initState() {
    super.initState();
    _cacheText();
  }

  @override
  void didUpdateWidget(covariant ToolInvocationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.invocation.payload, widget.invocation.payload)) {
      _cacheText();
    }
  }

  void _cacheText() {
    _arguments = _format(widget.invocation.payload['arguments'] ?? {});
    final result = widget.invocation.payload['result'];
    _result = result == null ? null : _format(result);
  }

  static String _format(Object? value) {
    if (value is String) {
      final raw = value;
      try {
        value = jsonDecode(raw);
      } on FormatException {
        return raw;
      }
    }
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _decide(bool allowed) async {
    if (_deciding) return;
    final service = context.read<AgentToolService>();
    setState(() => _deciding = true);
    await runUiAction(context, () async {
      try {
        await service.decide(
          widget.invocation.id,
          allowed,
          answer: _answer.text.trim(),
        );
      } finally {
        if (mounted) setState(() => _deciding = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.invocation;
    final service = context.watch<AgentToolService?>();
    final canDecide =
        i.state == 'pendingApproval' && (service?.canDecide(i.id) ?? false);
    final expanded = _expanded || canDecide;
    final l = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final asking = i.name == 'ask_user';
    final busy = const {'prepared', 'approved', 'executing'}.contains(i.state);
    final status = switch (i.state) {
      'prepared' => l.v2ToolPrepared,
      'approved' => l.v2ToolApproved,
      'pendingApproval' =>
        asking ? l.v2ToolAwaitingAnswer : l.v2AwaitingApproval,
      'succeeded' => l.v2Succeeded,
      'unknownOutcome' => l.v2UnknownOutcome,
      'rejected' => l.v2Rejected,
      'cancelled' => l.v2Cancelled,
      'executing' => l.v2Executing,
      'failed' => l.v2Failed,
      _ => i.state,
    };
    final name = switch (i.name) {
      'web_search' => l.v2ToolSearch,
      'clock' => l.v2ToolClock,
      'list_files' => l.v2ToolList,
      'read_file' => l.v2ToolRead,
      'write_file' => l.v2ToolWriteAction,
      'ask_user' => l.v2ToolAsk,
      'read_skill' => l.v2ToolSkill,
      _ => i.payload['displayName'] as String? ?? i.name,
    };
    final color = switch (i.state) {
      'failed' || 'unknownOutcome' => colors.error,
      'pendingApproval' || 'executing' || 'succeeded' => colors.primary,
      _ => colors.onSurfaceVariant,
    };
    final icon = switch (i.state) {
      'succeeded' => Icons.check_circle_outline,
      'failed' => Icons.error_outline,
      'unknownOutcome' => Icons.help_outline,
      'rejected' || 'cancelled' => Icons.block_outlined,
      'pendingApproval' =>
        asking ? Icons.question_answer_outlined : Icons.pending_actions,
      _ => Icons.build_outlined,
    };
    final args = i.payload['arguments'] as Map? ?? {};
    final summary =
        switch (i.name) {
          'web_search' => args['query'],
          'read_file' || 'write_file' => args['path'],
          'ask_user' => args['question'],
          'read_skill' => args['path'] ?? 'SKILL.md',
          _ =>
            args.entries.take(2).map((e) => '${e.key}: ${e.value}').join(', '),
        }?.toString() ??
        '';
    final serverName = i.payload['serverName'] as String?;
    final error = i.payload['error'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: canDecide ? BorderSide(color: colors.primary) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('tool_toggle_${i.id}'),
            onTap: canDecide
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Icon(
                            i.name == 'web_search'
                                ? Icons.travel_explore_rounded
                                : Icons.build_outlined,
                            size: 20,
                            color: colors.primary,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (expanded && summary.isNotEmpty)
                          Text(
                            summary,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (expanded && serverName != null)
                          Text(
                            serverName,
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: status,
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                  if (!canDecide)
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
          if (i.state == 'unknownOutcome')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                l.v2UnknownOutcomeHelp,
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 12),
                  if (asking && args['question'] is String)
                    _ReceiptText(
                      label: l.v2ToolQuestion,
                      text: args['question'] as String,
                    )
                  else
                    _ReceiptText(label: l.v2ToolArguments, text: _arguments),
                  if (i.name == 'web_search')
                    WebSearchReceipt(payload: i.payload),
                  if (error != null)
                    _ReceiptText(label: l.v2Failed, text: error),
                  if (_result != null)
                    _ReceiptText(label: l.v2ToolResult, text: _result!),
                  if (i.payload['resultTruncated'] == true)
                    Text(
                      l.v2ToolResultTruncated,
                      style: theme.textTheme.bodySmall,
                    ),
                  if (canDecide) ...[
                    if (asking) ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: ValueKey('tool_answer_${i.id}'),
                        controller: _answer,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_deciding,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: l.v2YourAnswer),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton(
                          key: ValueKey('tool_reject_${i.id}'),
                          onPressed: _deciding ? null : () => _decide(false),
                          child: Text(l.v2Reject),
                        ),
                        FilledButton(
                          key: ValueKey('tool_approve_${i.id}'),
                          onPressed:
                              _deciding ||
                                  (asking && _answer.text.trim().isEmpty)
                              ? null
                              : () => _decide(true),
                          child: Text(
                            asking ? l.v2ToolSendAnswer : l.v2ApproveOnce,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReceiptText extends StatelessWidget {
  const _ReceiptText({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              primary: false,
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
