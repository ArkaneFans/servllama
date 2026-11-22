import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/widgets/chat_agent_timeline.dart';
import 'package:servllama/l10n/l10n.dart';

enum _Stage {
  reasoning,
  toolInput,
  toolReady,
  executing,
  result,
  summarizing,
  answer,
  completed,
}

/// One successful tool round, using the chat renderer with local sample parts.
class AgentTimelinePreview extends StatefulWidget {
  const AgentTimelinePreview({super.key});

  @override
  State<AgentTimelinePreview> createState() => _AgentTimelinePreviewState();
}

class _AgentTimelinePreviewState extends State<AgentTimelinePreview> {
  _Stage _stage = _Stage.completed;
  Timer? _timer;
  int _replay = 0;
  bool _thinkingEnabled = true;
  DateTime _startedAt = DateTime.now();

  bool get _playing => _timer != null;
  bool get _completed => _stage == _Stage.completed;
  List<_Stage> get _stages => [
    for (final stage in _Stage.values)
      if (_thinkingEnabled ||
          (stage != _Stage.reasoning && stage != _Stage.summarizing))
        stage,
  ];

  void _pause() {
    _timer?.cancel();
    _timer = null;
  }

  void _reset() {
    _pause();
    _replay++;
    _startedAt = DateTime.now();
    _stage = _stages.first;
  }

  void _advance() {
    if (_completed) return;
    final stages = _stages;
    _stage = stages[stages.indexOf(_stage) + 1];
    if (_completed) _pause();
  }

  void _setThinking(bool enabled) {
    setState(() {
      _pause();
      _thinkingEnabled = enabled;
      if (!enabled) {
        if (_stage == _Stage.reasoning) _stage = _Stage.toolInput;
        if (_stage == _Stage.summarizing) _stage = _Stage.answer;
      }
    });
  }

  void _togglePlayback() {
    setState(() {
      if (_playing) {
        _pause();
      } else {
        if (_completed) _reset();
        _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
          setState(_advance);
        });
      }
    });
  }

  @override
  void dispose() {
    _pause();
    super.dispose();
  }

  ChatMessageRecord _message(BuildContext context) {
    final l = context.l10n;
    final input = jsonEncode({'query': l.uiLabAgentQuery});
    final hasResult = _stage.index >= _Stage.result.index;
    return ChatMessageRecord(
      id: 'ui-lab-agent-$_replay',
      role: ChatRole.assistant,
      createdAt: _startedAt,
      parts: [
        TextPart('intro', l.uiLabAgentIntro),
        if (_thinkingEnabled)
          ReasoningPart(
            'plan',
            l.uiLabAgentReasoning,
            startedAt: _startedAt,
            finishedAt: _stage == _Stage.reasoning
                ? null
                : _startedAt.add(const Duration(milliseconds: 1400)),
          ),
        if (_stage.index >= _Stage.toolInput.index)
          ToolPart(
            id: 'search',
            callId: 'ui-lab-search-$_replay',
            name: 'web_search',
            input: _stage == _Stage.toolInput
                ? input.substring(0, input.length ~/ 2)
                : input,
            inputComplete: _stage.index >= _Stage.toolReady.index,
            state: hasResult
                ? ToolState.succeeded
                : switch (_stage) {
                    _Stage.toolReady => ToolState.ready,
                    _Stage.executing => ToolState.executing,
                    _ => ToolState.streaming,
                  },
            result: hasResult ? l.uiLabAgentResult : null,
            startedAt: _stage.index >= _Stage.executing.index
                ? _startedAt.add(const Duration(milliseconds: 4800))
                : null,
            finishedAt: hasResult
                ? _startedAt.add(const Duration(milliseconds: 5620))
                : null,
            durationMs: hasResult ? 820 : null,
          ),
        if (_thinkingEnabled && _stage.index >= _Stage.summarizing.index)
          ReasoningPart(
            'summary',
            l.uiLabAgentSummary,
            startedAt: _startedAt.add(const Duration(seconds: 8)),
            finishedAt: _stage == _Stage.summarizing
                ? null
                : _startedAt.add(const Duration(milliseconds: 9400)),
          ),
        if (_stage.index >= _Stage.answer.index)
          TextPart(
            'answer',
            _completed ? l.uiLabAnswer : l.uiLabAnswer.split('\n\n').first,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final stages = _stages;
    final step = stages.indexOf(_stage) + 1;
    final phase = switch (_stage) {
      _Stage.reasoning => l.chatReasoningProcess,
      _Stage.toolInput => l.uiLabAgentInputStep,
      _Stage.toolReady => l.v2ToolPrepared,
      _Stage.executing => l.v2Executing,
      _Stage.result => l.v2ToolResult,
      _Stage.summarizing => l.uiLabAgentSummaryStep,
      _Stage.answer => l.uiLabAgentAnswerStep,
      _Stage.completed => l.commonDone,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          key: const Key('ui_lab_agent_thinking'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.uiLabAgentThinking),
          subtitle: Text(l.uiLabAgentThinkingHint),
          value: _thinkingEnabled,
          onChanged: _setThinking,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              key: const Key('ui_lab_agent_play'),
              onPressed: _togglePlayback,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(_playing ? l.uiLabAgentPause : l.uiLabAgentPlay),
            ),
            OutlinedButton.icon(
              key: const Key('ui_lab_agent_next'),
              onPressed: _completed
                  ? null
                  : () => setState(() {
                      _pause();
                      _advance();
                    }),
              icon: const Icon(Icons.skip_next_rounded, size: 18),
              label: Text(l.uiLabAgentNext),
            ),
            IconButton(
              key: const Key('ui_lab_agent_reset'),
              tooltip: l.uiLabAgentReset,
              onPressed: () => setState(_reset),
              icon: const Icon(Icons.replay_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '$step / ${stages.length} · $phase',
          key: const Key('ui_lab_agent_stage'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: step / stages.length,
          minHeight: 3,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 20),
        ChatAgentTimeline(
          key: ValueKey(_replay),
          message: _message(context),
          streaming: !_completed,
        ),
      ],
    );
  }
}
