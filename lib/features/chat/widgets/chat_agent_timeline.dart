import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/widgets/tool_invocation_card.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_timeline.dart';
import 'package:servllama/features/chat/presentation/chat_timeline_projection.dart';
import 'package:servllama/features/chat/widgets/chat_tool_activity.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/text_sheen.dart';

/// Message-owned view of existing Run receipts and revision-owned ranges.
class ChatAgentTimeline extends StatelessWidget {
  const ChatAgentTimeline({
    super.key,
    required this.message,
    required this.streaming,
  });
  final ChatMessageRecord message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    Widget body(BuildContext context, List<ToolInvocation> receipts) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in projectChatTimeline(
          message,
          receipts,
          streaming: streaming,
        ))
          Padding(
            key: ValueKey('timeline_block_${block.key}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: block.text != null
                ? RepaintBoundary(
                    child: GptMarkdown(
                      block.text!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  )
                : _ActivityBlock(
                    key: PageStorageKey((
                      message.id,
                      message.runId,
                      message.currentVersionIndex,
                      block.key,
                    )),
                    block: block,
                    streaming: streaming,
                  ),
          ),
      ],
    );
    if (message.sessionId == null || message.runId == null) {
      return body(context, const []);
    }
    return ChatToolActivity(
      key: ValueKey((message.sessionId, message.runId)),
      conversationId: message.sessionId!,
      runId: message.runId!,
      builder: body,
    );
  }
}

class _ActivityBlock extends StatefulWidget {
  const _ActivityBlock({
    super.key,
    required this.block,
    required this.streaming,
  });
  final ChatTimelineBlock block;
  final bool streaming;
  @override
  State<_ActivityBlock> createState() => _ActivityBlockState();
}

class _ActivityBlockState extends State<_ActivityBlock> {
  bool _expanded = false;
  PageStorageBucket? _storage;
  bool _restored = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (!_restored) {
      _restored = true;
      _expanded =
          _storage?.readState(context, identifier: widget.key) as bool? ??
          false;
    }
  }

  @override
  void deactivate() {
    _storage?.writeState(context, _expanded, identifier: widget.key);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final steps = widget.block.steps;
    final start = chatTimelineVisibleStart(steps, expanded: _expanded);
    return Container(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withAlpha(110),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (steps.length > 2)
            InkWell(
              key: ValueKey('timeline_expand_${widget.block.key}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _expanded
                            ? context.l10n.chatTimelineCollapse
                            : start > 0
                            ? context.l10n.chatTimelineExpand(start)
                            : context.l10n.chatTimelineTitle,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: colors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (var index = start; index < steps.length; index++)
            _TimelineStep(
              key: ValueKey(steps[index].key),
              step: steps[index],
              first: index == start,
              last: index == steps.length - 1,
              streaming: widget.streaming,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    super.key,
    required this.step,
    required this.first,
    required this.last,
    required this.streaming,
  });
  final ChatTimelineStep step;
  final bool first, last, streaming;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reasoning = step.part.kind == ChatTimelineKind.reasoning;
    final record = step.invocation;
    final stoppedInput = !reasoning && !step.part.inputComplete && !streaming;
    final icon = stoppedInput
        ? Icons.block_outlined
        : reasoning
        ? Icons.psychology_alt_outlined
        : switch (record?.state) {
            'failed' || 'unknownOutcome' => Icons.error_outline,
            'pendingApproval' => Icons.pending_actions_outlined,
            'cancelled' || 'rejected' => Icons.block_outlined,
            _ => switch (record?.name ?? step.part.toolName) {
              'web_search' => Icons.travel_explore_rounded,
              'clock' => Icons.schedule_outlined,
              'read_file' || 'read_skill' => Icons.description_outlined,
              'write_file' => Icons.edit_note_outlined,
              'list_files' => Icons.folder_outlined,
              'ask_user' => Icons.question_answer_outlined,
              _ => Icons.build_outlined,
            },
          };
    final busy =
        streaming &&
        (const {'prepared', 'approved', 'executing'}.contains(record?.state) ||
            (!reasoning && record == null));
    return CustomPaint(
      painter: _StepLine(
        first: first,
        last: last,
        color: colors.outlineVariant,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 40,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color:
                          record?.state == 'unknownOutcome' ||
                              record?.state == 'failed'
                          ? colors.error
                          : colors.primary,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: reasoning
                ? _ReasoningStep(
                    key: PageStorageKey(step.key),
                    step: step,
                    streaming: streaming,
                  )
                : record != null
                ? ToolInvocationCard(
                    key: ValueKey(record.id),
                    invocation: record,
                    inTimeline: true,
                  )
                : _ToolPreviewStep(step: step, streaming: streaming),
          ),
        ],
      ),
    );
  }
}

class _ToolPreviewStep extends StatefulWidget {
  const _ToolPreviewStep({required this.step, required this.streaming});
  final ChatTimelineStep step;
  final bool streaming;
  @override
  State<_ToolPreviewStep> createState() => _ToolPreviewStepState();
}

class _ToolPreviewStepState extends State<_ToolPreviewStep> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final input = step.preview?.input ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: ValueKey('timeline_tool_preview_${step.part.streamId}'),
            onTap: input.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Expanded(
                  child: TextSheen(
                    key: ValueKey('timeline_tool_sheen_${step.part.streamId}'),
                    enabled: widget.streaming,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    child: Text(
                      (step.part.toolName?.isNotEmpty ?? false)
                          ? step.part.toolName!
                          : context.l10n.v2ToolActivity,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                if (input.isNotEmpty)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                  ),
              ],
            ),
          ),
          if (!widget.streaming && step.part.inputComplete)
            Text(
              context.l10n.chatTimelineToolNotExecuted,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_expanded && input.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: SelectableText(
                  input.length > 8192 ? '${input.substring(0, 8192)}…' : input,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepLine extends CustomPainter {
  const _StepLine({
    required this.first,
    required this.last,
    required this.color,
  });
  final bool first, last;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    if (!first) {
      canvas.drawLine(const Offset(12, 0), const Offset(12, 8), paint);
    }
    if (!last) {
      canvas.drawLine(const Offset(12, 32), Offset(12, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_StepLine old) =>
      old.first != first || old.last != last || old.color != color;
}

class _ReasoningStep extends StatefulWidget {
  const _ReasoningStep({
    super.key,
    required this.step,
    required this.streaming,
  });
  final ChatTimelineStep step;
  final bool streaming;
  @override
  State<_ReasoningStep> createState() => _ReasoningStepState();
}

class _ReasoningStepState extends State<_ReasoningStep> {
  bool _expanded = false;
  PageStorageBucket? _storage;
  bool _restored = false;
  Timer? _timer;
  final _scroll = ScrollController();
  final _tick = ValueNotifier<int>(0);
  bool get _running => widget.streaming && widget.step.part.finishedAt == null;
  void _syncTimer() {
    if (_running) {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _tick.value++,
      );
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (!_restored) {
      _restored = true;
      _expanded =
          _storage?.readState(context, identifier: widget.key) as bool? ??
          false;
    }
  }

  @override
  void deactivate() {
    _storage?.writeState(context, _expanded, identifier: widget.key);
    super.deactivate();
  }

  @override
  void didUpdateWidget(_ReasoningStep old) {
    super.didUpdateWidget(old);
    _syncTimer();
    if (_running && old.step.text != widget.step.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.extentAfter < 100) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tick.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = widget.step.part;
    final visible = _expanded || _running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('timeline_reasoning_${widget.step.key}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.chatReasoningProcess,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                if (part.startedAt != null)
                  ValueListenableBuilder<int>(
                    valueListenable: _tick,
                    builder: (context, _, child) {
                      final end =
                          part.finishedAt ??
                          (_running ? DateTime.now() : part.startedAt!);
                      final seconds =
                          (end
                                      .difference(part.startedAt!)
                                      .inMilliseconds
                                      .clamp(0, 1 << 52) /
                                  1000)
                              .toStringAsFixed(1);
                      return Text(
                        context.l10n.chatTimelineDuration(seconds),
                        style: theme.textTheme.labelSmall,
                      );
                    },
                  ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        if (visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _expanded
                ? GptMarkdown(
                    widget.step.text,
                    style: theme.textTheme.bodySmall,
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: SingleChildScrollView(
                      primary: false,
                      controller: _scroll,
                      child: Text(
                        widget.step.text,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
