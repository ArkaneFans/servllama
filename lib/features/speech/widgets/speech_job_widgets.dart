import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/features/chat/widgets/chat_speech_button.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/numeric_slider.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

String speechJobText(SpeechJob job) => job.kind == AssetKind.asr
    ? job.text
    : job.snapshot['text'] as String? ?? '';
String speechJobDate(SpeechJob job) =>
    DateFormat('yyyy-MM-dd HH:mm').format(job.createdAt.toLocal());
String speechState(BuildContext context, SpeechJobState state) =>
    switch (state) {
      SpeechJobState.queued => context.l10n.v2Queued,
      SpeechJobState.waiting => context.l10n.v2WaitingLocal,
      SpeechJobState.running => context.l10n.v2Executing,
      SpeechJobState.cancelling => context.l10n.v2Cancelling,
      SpeechJobState.completed => context.l10n.v2Succeeded,
      SpeechJobState.cancelled => context.l10n.v2Cancelled,
      SpeechJobState.failed => context.l10n.v2Failed,
      SpeechJobState.interrupted => context.l10n.v2Interrupted,
    };

class SpeechJobTile extends StatelessWidget {
  const SpeechJobTile({super.key, required this.job, required this.onTap});
  final SpeechJob job;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, theme = Theme.of(context);
    final value = speechJobText(job).replaceAll(RegExp(r'\s+'), ' ').trim();
    return Card(
      child: ListTile(
        key: ValueKey('speech_job_${job.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          job.kind == AssetKind.asr ? Icons.transcribe : Icons.graphic_eq,
        ),
        title: Text(job.snapshot['package']['name']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? l.v2TranscriptPending : value,
              key: ValueKey('speech_job_preview_${job.id}'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${speechState(context, job.state)} · ${speechJobDate(job)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: job.state.active
            ? IconButton(
                tooltip: l.v2CancelTask,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: job.state == SpeechJobState.cancelling
                    ? null
                    : () => runUiAction(
                        context,
                        () => context.read<SpeechJobService>().cancel(job.id),
                      ),
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Shared by the forms and task details. The service owns job state.
class SpeechJobResult extends StatefulWidget {
  const SpeechJobResult({
    super.key,
    required this.id,
    required this.onRetry,
    this.onInsert,
  });
  final String id;
  final Future<void> Function(SpeechJob) onRetry;
  final ValueChanged<SpeechJob>? onInsert;
  @override
  State<SpeechJobResult> createState() => _SpeechJobResultState();
}

class _SpeechJobResultState extends State<SpeechJobResult> {
  final text = TextEditingController();
  final segmentTexts = <TextEditingController>[];
  bool editing = false, busy = false;
  @override
  void dispose() {
    text.dispose();
    for (final controller in segmentTexts) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await runUiAction(context, action);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(SpeechJobService service, SpeechJob job) async {
    if (editing) {
      final segments = segmentTexts.isEmpty
          ? null
          : segmentTexts.map((c) => c.text).toList();
      await service.editTranscript(
        job.id,
        segments?.join('\n') ?? text.text,
        segments: segments,
      );
    } else {
      text.text = job.text;
      for (final c in segmentTexts) {
        c.dispose();
      }
      segmentTexts.clear();
      if (job.result['timing'] == 'native') {
        for (final segment
            in (job.result['editedSegments'] ?? job.result['segments'])
                    as List? ??
                []) {
          segmentTexts.add(
            TextEditingController(text: segment['text'] as String),
          );
        }
      }
    }
    if (mounted) setState(() => editing = !editing);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService>(), l = context.l10n;
    final job = s.job(widget.id);
    if (job == null) return Text(l.v2NoSpeechJobs);
    final theme = Theme.of(context), c = theme.colorScheme;
    final asr = job.kind == AssetKind.asr, complete = !job.state.active;
    final output = job.result['outputPath'] as String?,
        content = speechJobText(job);
    return Column(
      key: ValueKey('speech_result_${job.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        SettingsSection.form(
          title: l.v2TaskResult,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: c.secondaryContainer,
                  foregroundColor: c.onSecondaryContainer,
                  child: Icon(asr ? Icons.transcribe : Icons.graphic_eq),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.snapshot['package']['name'],
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${asr ? l.v2Asr : l.v2Tts} · ${speechState(context, job.state)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              '${l.v2SpeechCreatedAt} · ${speechJobDate(job)}',
              style: theme.textTheme.bodySmall,
            ),
            if (job.state.active)
              LinearProgressIndicator(
                value: job.progress == 0 ? null : job.progress,
              ),
            if (job.state == SpeechJobState.cancelling)
              Text(l.v2CancellationHelp, style: theme.textTheme.bodySmall),
            if (job.state == SpeechJobState.waiting) const SpeechWaitCard(),
            if (job.error != null)
              SelectableText(
                job.error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: c.error),
              ),
            if (complete && job.state != SpeechJobState.completed)
              OutlinedButton.icon(
                icon: const Icon(Icons.replay),
                label: Text(l.v2RetrySpeech),
                onPressed: busy ? null : () => act(() => widget.onRetry(job)),
              ),
            if (job.state.active)
              TextButton.icon(
                icon: const Icon(Icons.stop),
                label: Text(l.v2CancelTask),
                onPressed: busy || job.state == SpeechJobState.cancelling
                    ? null
                    : () => act(() => s.cancel(job.id)),
              ),
          ],
        ),
        SettingsSection.form(
          title: asr ? l.v2Transcript : l.v2SynthesisContent,
          children: [
            if (editing && segmentTexts.isNotEmpty)
              ...segmentTexts.asMap().entries.map(
                (entry) => TextField(
                  controller: entry.value,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l.v2TranscriptSegment(entry.key + 1),
                  ),
                ),
              )
            else if (editing)
              TextField(
                key: const Key('speech_transcript_editor'),
                controller: text,
                minLines: 4,
                maxLines: 16,
                decoration: InputDecoration(labelText: l.v2Transcript),
              )
            else
              SelectableText(
                content.isNotEmpty
                    ? content
                    : job.state == SpeechJobState.completed
                    ? l.v2NoSpeechDetected
                    : l.v2TranscriptPending,
                key: const Key('speech_result_text'),
                style: theme.textTheme.bodyLarge,
              ),
            if (asr && job.result['timing'] == 'chunk')
              Text(l.v2ChunkTimingHelp, style: theme.textTheme.bodySmall),
            if (asr && complete || content.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (asr && complete)
                    TextButton.icon(
                      icon: Icon(
                        editing ? Icons.save_outlined : Icons.edit_outlined,
                      ),
                      label: Text(editing ? l.commonSave : l.v2EditTranscript),
                      onPressed: busy ? null : () => act(() => edit(s, job)),
                    ),
                  if (editing)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => editing = false),
                      child: Text(l.commonCancel),
                    ),
                  if (!editing && content.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: Text(l.chatCopyMessage),
                      onPressed: busy
                          ? null
                          : () => act(() async {
                              await Clipboard.setData(
                                ClipboardData(text: content),
                              );
                              if (context.mounted) {
                                AppMessage.show(context, l.v2SpeechTextCopied);
                              }
                            }),
                    ),
                  if (asr && complete && !editing && content.isNotEmpty) ...[
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => act(() => s.exportTranscript(job)),
                      child: Text(l.v2ExportTxt),
                    ),
                    if (job.result['timing'] == 'native' &&
                        (job.result['editedText'] == null ||
                            job.result['editedSegments'] != null))
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => act(
                                () => s.exportTranscript(job, subtitles: true),
                              ),
                        child: Text(l.v2ExportSrt),
                      ),
                  ],
                ],
              ),
            if (asr && complete && content.isNotEmpty && !editing)
              FilledButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(l.v2InsertTranscript),
                onPressed: busy
                    ? null
                    : () => widget.onInsert != null
                          ? widget.onInsert!(job)
                          : act(() => insertTranscript(context, job)),
              ),
          ],
        ),
        if (!asr && complete && output != null)
          SettingsSection.form(
            title: l.v2SpeechAudioResult,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: Icon(
                      s.audio.playingPath == output && s.audio.playing
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(l.v2PlayPause),
                    onPressed:
                        busy || s.audio.recording || s.audio.recordingBusy
                        ? null
                        : () => act(() => s.audio.play(output)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: Text(l.v2ExportWav),
                    onPressed: busy
                        ? null
                        : () => act(
                            () => s.audio.exportAudio(output, '${job.id}.wav'),
                          ),
                  ),
                ],
              ),
              NumericSlider(
                label: l.v2PlaybackSpeed,
                value: s.audio.playbackSpeed.clamp(.5, 2),
                min: .5,
                max: 2,
                divisions: 6,
                onChanged: (v) =>
                    runUiAction(context, () => s.audio.setPlaybackSpeed(v)),
              ),
              Text(
                l.v2SynthesisParameters(
                  (job.snapshot['speaker'] ?? 0).toString(),
                  (job.snapshot['speed'] ?? 1).toString(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (job.snapshot['voice'] != null)
                Text(
                  job.snapshot['voice']['name'],
                  style: theme.textTheme.bodySmall,
                ),
              Text(
                l.v2SampleRate((job.result['sampleRate'] as num? ?? 0).toInt()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}

class SpeechWaitCard extends StatelessWidget {
  const SpeechWaitCard({super.key});
  @override
  Widget build(BuildContext context) {
    final resources = context.watch<SpeechJobService>().resources,
        l = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          resources.requiresRestart(LocalResourceDomain.speech)
              ? l.v2NativeRestart
              : l.v2SpeechWaitingHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
