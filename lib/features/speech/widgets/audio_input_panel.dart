import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/speech/services/audio_io_service.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

class AudioInputPanel extends StatefulWidget {
  const AudioInputPanel({
    super.key,
    required this.path,
    required this.onChanged,
    this.enabled = true,
  });
  final String? path;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  @override
  State<AudioInputPanel> createState() => _AudioInputPanelState();
}

class _AudioInputPanelState extends State<AudioInputPanel> {
  AudioIoService? _audio;
  String? _ownedRecording;
  bool importing = false;
  @override
  void dispose() {
    if (_ownedRecording != null &&
        _audio?.recordingPath == _ownedRecording &&
        _audio!.recording) {
      unawaited(_audio!.stopRecording().catchError((Object _) => null));
    }
    super.dispose();
  }

  Future<void> record(AudioIoService audio) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (audio.recording) {
      final path = await audio.stopRecording();
      if (mounted) widget.onChanged(path);
    } else {
      await audio.startRecording();
      _ownedRecording = audio.recordingPath;
      if (!mounted) {
        // The permission dialog can finish after this route has closed.
        if (audio.recordingPath == _ownedRecording && audio.recording) {
          await audio.stopRecording();
        }
        return;
      }
      final path = await audio.recordingFinished;
      if (mounted) widget.onChanged(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<SpeechJobService>().audio, l = context.l10n;
    final theme = Theme.of(context), c = theme.colorScheme;
    _audio = audio;
    final locked = !widget.enabled || importing || audio.recordingBusy;
    return SettingsSection.form(
      title: l.v2SpeechAudioInput,
      children: [
        Row(
          children: [
            IconButton.filled(
              key: const Key('speech_record_button'),
              tooltip: audio.recording ? l.v2StopRecording : l.v2Record,
              onPressed: locked
                  ? null
                  : () => runUiAction(context, () => record(audio)),
              style: IconButton.styleFrom(
                fixedSize: const Size(80, 80),
                shape: const CircleBorder(),
                backgroundColor: audio.recording
                    ? c.errorContainer
                    : c.primaryContainer,
                foregroundColor: audio.recording
                    ? c.onErrorContainer
                    : c.onPrimaryContainer,
              ),
              icon: audio.recordingBusy
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      audio.recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 36,
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RecordingClock(audio: audio),
                  const SizedBox(height: 4),
                  Text(
                    audio.recording ? l.v2RecordingNow : l.v2RecordingReady,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        Text(
          widget.path?.split(RegExp(r'[/\\]')).last ?? l.v2NoAudioSelected,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
        if (audio.error != null)
          Text(
            audio.error!,
            style: theme.textTheme.bodySmall?.copyWith(color: c.error),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('speech_import_audio'),
              icon: const Icon(Icons.audio_file_outlined),
              label: Text(l.v2ImportAudio),
              onPressed: locked || audio.recording
                  ? null
                  : () => runUiAction(context, () async {
                      setState(() => importing = true);
                      FocusManager.instance.primaryFocus?.unfocus();
                      try {
                        final path = await audio.pickAudio();
                        if (mounted && path != null) widget.onChanged(path);
                      } finally {
                        if (mounted) setState(() => importing = false);
                      }
                    }),
            ),
            if (!audio.recording &&
                audio.recordingPath != null &&
                widget.path != audio.recordingPath)
              TextButton(
                onPressed: locked
                    ? null
                    : () => widget.onChanged(audio.recordingPath),
                child: Text(l.v2UseRecording),
              ),
            if (!audio.recording && widget.path != null)
              IconButton(
                tooltip: l.v2PlayPause,
                icon: Icon(
                  audio.playing && audio.playingPath == widget.path
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
                onPressed: locked
                    ? null
                    : () =>
                          runUiAction(context, () => audio.play(widget.path!)),
              ),
            if (!audio.recording && audio.recordingPath != null)
              IconButton(
                tooltip: l.v2DiscardRecording,
                icon: const Icon(Icons.delete_outline),
                onPressed: locked
                    ? null
                    : () => runUiAction(context, () async {
                        final previous = audio.recordingPath;
                        await audio.discardRecording();
                        if (mounted && widget.path == previous) {
                          widget.onChanged(null);
                        }
                      }),
              ),
          ],
        ),
        Text(l.v2RecordingHelp, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Reads the audio service's monotonic watch; only this label ticks each second.
class RecordingClock extends StatefulWidget {
  const RecordingClock({super.key, required this.audio});
  final AudioIoService audio;
  @override
  State<RecordingClock> createState() => _RecordingClockState();
}

class _RecordingClockState extends State<RecordingClock> {
  Timer? timer;
  void sync() {
    if (widget.audio.recording) {
      timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      timer?.cancel();
      timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    sync();
  }

  @override
  void didUpdateWidget(covariant RecordingClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    sync();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.audio.recordingElapsed.inSeconds;
    final value =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Text(
      value,
      key: const Key('speech_recording_clock'),
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
