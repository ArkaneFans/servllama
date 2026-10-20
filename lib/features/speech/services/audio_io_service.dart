import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:audio_session/audio_session.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/speech/services/wave_file.dart';

class AudioIoService extends ChangeNotifier with WidgetsBindingObserver {
  AudioIoService(this.root, {AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;
  final AppLogger _logger;
  final Directory root;
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  AudioSession? _session;
  bool _recordingFocus = false,
      _captureStarting = false,
      _captureInterrupted = false;
  bool _disposed = false, _starting = false;
  Future<String?>? _stopping;
  Completer<String?>? _recorded;
  final Set<String> _decodes = {};
  final Set<String> _decodeCancels = {};
  String? _recordingId, _playbackId;
  Stopwatch? _recordingWatch;
  Duration get recordingElapsed => _recordingWatch?.elapsed ?? Duration.zero;
  ProcessingState? _lastPlaybackState;
  bool get playing => _player?.playing ?? false;
  bool get recordingBusy => _starting || _stopping != null;
  double get playbackSpeed => _player?.speed ?? 1;
  Future<String?> get recordingFinished =>
      _recorded?.future ?? Future.value(recordingPath);
  String? error;
  AudioPlayer get _playback {
    if (_player != null) return _player!;
    final value = _player = AudioPlayer();
    _playerState = value.playerStateStream.listen(
      (state) {
        if (state.processingState == ProcessingState.completed &&
            _lastPlaybackState != ProcessingState.completed) {
          _event('speech.playback.completed', fields: {'audio': _playbackId});
        }
        _lastPlaybackState = state.processingState;
        _changed();
      },
      onError: (Object error) {
        _event(
          'speech.playback.failed',
          level: LogLevel.error,
          fields: {'audio': _playbackId, ...AppLogger.errorFields(error)},
        );
      },
    );
    return value;
  }

  void _event(
    String name, {
    LogLevel level = LogLevel.info,
    Map<String, Object?> fields = const {},
  }) => _logger.event(
    name,
    channel: LogChannel.speech,
    level: level,
    fields: fields,
  );

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _background(
    Future<void> action, {
    String operation = 'audio',
    Map<String, Object?> fields = const {},
  }) {
    unawaited(
      action.catchError((Object e) {
        error = LogRedactor.redact(e.toString());
        _event(
          'speech.$operation.failed',
          level: LogLevel.error,
          fields: {...fields, ...AppLogger.errorFields(e)},
        );
        _changed();
      }),
    );
  }

  static const _channel = MethodChannel('com.arkanefans.servllama/audio');
  static const _export = MethodChannel('com.arkanefans.servllama/file_export');
  bool recording = false;
  String? recordingPath, playingPath;
  Timer? _recordingLimit;
  StreamSubscription<AudioInterruptionEvent>? _interruptions;
  StreamSubscription<void>? _noisy;
  StreamSubscription<PlayerState>? _playerState;
  Future<void> initialize() async {
    // Jobs and voice profiles own copies. Only the latest unsubmitted recording
    // is offered after a restart; older temporary recordings can be reclaimed.
    final recordings = Directory(p.join(root.path, 'speech', 'recordings'));
    if (await recordings.exists()) {
      final files = await recordings
          .list(followLinks: false)
          .where((e) => e is File && p.extension(e.path) == '.wav')
          .cast<File>()
          .toList();
      final modified = <String, DateTime>{};
      for (final file in files) {
        modified[file.path] = await file.lastModified();
      }
      files.sort((a, b) => modified[b.path]!.compareTo(modified[a.path]!));
      recordingPath = files.firstOrNull?.path;
      if (recordingPath != null) _event('speech.recording.recovered');
      for (final file in files.skip(1)) {
        await file.delete();
      }
    }
    if (!Platform.isAndroid) return;
    WidgetsBinding.instance.addObserver(this);
    final session = _session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _interruptions = session.interruptionEventStream.listen((e) {
      if (e.begin) {
        _event(
          'speech.audio.interrupted',
          level: LogLevel.warning,
          fields: {
            'recording': recording || _captureStarting,
            'playing': playing,
          },
        );
        if (_captureStarting) _captureInterrupted = true;
        _background(pausePlayback());
        if (recording) _background(stopRecording().then((_) {}));
      }
    });
    _noisy = session.becomingNoisyEventStream.listen((_) {
      _event('speech.audio.route_changed');
      _background(pausePlayback());
    });
  }

  Future<String?> pickAudio() async {
    final chosen = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'opus'],
      allowMultiple: false,
    );
    final path = chosen?.files.single.path;
    if (path != null) _event('speech.audio.selected');
    return path;
  }

  Future<void> startRecording() async {
    if (_disposed) throw StateError('Audio service is closed');
    if (_stopping != null) await _stopping;
    if (recording) return;
    if (_starting) throw StateError('Recording is starting');
    _starting = true;
    final id = newId();
    _event('speech.recording.start_requested', fields: {'audio': id});
    _changed();
    String? pendingPath;
    try {
      await pausePlayback();
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        _event(
          'speech.recording.permission_denied',
          level: LogLevel.warning,
          fields: {'audio': id},
        );
        throw StateError(
          'Microphone permission denied; import an audio file instead',
        );
      }
      final dir = Directory(p.join(root.path, 'speech', 'recordings'));
      await dir.create(recursive: true);
      final path = p.join(dir.path, '$id.wav');
      pendingPath = path;
      _captureInterrupted = false;
      _captureStarting = true;
      if (_session != null) {
        _recordingFocus = await _session!.setActive(
          true,
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientExclusive,
        );
        if (!_recordingFocus) {
          _event(
            'speech.recording.focus_denied',
            level: LogLevel.warning,
            fields: {'audio': id},
          );
          throw StateError('Microphone audio focus is unavailable');
        }
      }
      if (_captureInterrupted || !_canRecordNow) {
        throw StateError('Return to the app to record audio');
      }
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          // AudioSession owns focus and stops on interruption. A second focus
          // request from record would interrupt our own session on Android.
          audioInterruption: AudioInterruptionMode.none,
        ),
        path: path,
      );
      if (_captureInterrupted || !_canRecordNow) {
        await recorder.stop();
        throw StateError('Recording was interrupted');
      }
      recordingPath = path;
      recording = true;
      _recordingId = id;
      _recordingWatch = Stopwatch()..start();
      _event('speech.recording.started', fields: {'audio': id});
      _recorded = Completer<String?>();
      error = null;
      _recordingLimit = Timer(const Duration(minutes: 10), () {
        _event('speech.recording.limit_reached', fields: {'audio': id});
        _background(stopRecording().then((_) {}));
      });
      _changed();
    } catch (error) {
      _event(
        'speech.recording.start_failed',
        level: LogLevel.error,
        fields: {'audio': id, ...AppLogger.errorFields(error)},
      );
      await _releaseRecordingFocus();
      if (pendingPath != null && await File(pendingPath).exists()) {
        await File(pendingPath).delete();
      }
      rethrow;
    } finally {
      _captureStarting = false;
      _starting = false;
      _changed();
    }
  }

  bool get _canRecordNow =>
      !_disposed &&
      (!Platform.isAndroid ||
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  Future<void> _releaseRecordingFocus() async {
    if (!_recordingFocus) return;
    _recordingFocus = false;
    await _session?.setActive(false);
  }

  Future<String?> stopRecording() =>
      _stopping ??= _stopRecording().whenComplete(() {
        _stopping = null;
        _changed();
      });
  Future<String?> _stopRecording() async {
    if (!recording) return recordingPath;
    _recordingLimit?.cancel();
    try {
      recordingPath = await _recorder?.stop() ?? recordingPath;
      _event(
        'speech.recording.stopped',
        fields: {
          'audio': _recordingId,
          'elapsed_ms': _recordingWatch?.elapsedMilliseconds,
        },
      );
      return recordingPath;
    } catch (error) {
      _event(
        'speech.recording.stop_failed',
        level: LogLevel.error,
        fields: {'audio': _recordingId, ...AppLogger.errorFields(error)},
      );
      rethrow;
    } finally {
      _recordingWatch?.stop();
      recording = false;
      if (_recorded?.isCompleted == false) _recorded!.complete(recordingPath);
      await _releaseRecordingFocus();
      _changed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _captureStarting) {
      _captureInterrupted = true;
    }
    if (state != AppLifecycleState.resumed && recording) {
      _event(
        'speech.recording.background_stop',
        fields: {'audio': _recordingId},
      );
      _background(stopRecording().then((_) {}));
    }
  }

  Future<void> play(String path) async {
    if (recording || recordingBusy) {
      throw StateError('Stop recording before playback');
    }
    try {
      final player = _playback;
      if (playingPath == path && player.playing) {
        await pausePlayback();
        return;
      }
      if (playingPath != path ||
          player.processingState == ProcessingState.completed) {
        _playbackId = newId();
        await player.setFilePath(path);
        playingPath = path;
      }
      _event('speech.playback.started', fields: {'audio': _playbackId});
      _background(
        player.play(),
        operation: 'playback',
        fields: {'audio': _playbackId},
      );
    } catch (error) {
      _event(
        'speech.playback.failed',
        level: LogLevel.error,
        fields: {'audio': _playbackId, ...AppLogger.errorFields(error)},
      );
      rethrow;
    }
  }

  Future<void> setPlaybackSpeed(double value) => _playback.setSpeed(value);
  Future<void> pausePlayback() async {
    final wasPlaying = playing;
    await _player?.pause();
    if (wasPlaying) {
      _event('speech.playback.paused', fields: {'audio': _playbackId});
    }
  }

  Future<void> stopPlayback() async {
    await _player?.stop();
    if (playingPath != null) {
      _event('speech.playback.stopped', fields: {'audio': _playbackId});
    }
    playingPath = null;
    _changed();
  }

  Future<void> discardRecording() async {
    if (recording || recordingBusy) {
      throw StateError('Stop recording before deleting it');
    }
    final path = recordingPath;
    if (path == null) return;
    if (playingPath == path) await stopPlayback();
    final recordings = Directory(p.join(root.path, 'speech', 'recordings'));
    // This operation never targets an imported file or a task-owned copy.
    if (!p.isWithin(recordings.path, path)) {
      throw StateError('Invalid recording path');
    }
    final file = File(path);
    if (await file.exists()) await file.delete();
    _event('speech.recording.discarded', fields: {'audio': _recordingId});
    recordingPath = null;
    _recordingWatch = null;
    _changed();
  }

  Future<String> copyInput(String path, String jobId) async {
    final f = File(path);
    final length = await f.length();
    if (length <= 0 || length > 512 * 1024 * 1024) {
      throw const FormatException(
        'Audio file must be between 1 byte and 512 MiB',
      );
    }
    final dir = Directory(p.join(root.path, 'speech', 'jobs', jobId));
    await dir.create(recursive: true);
    final target = p.join(dir.path, 'input${p.extension(path).toLowerCase()}');
    await f.copy(target);
    _event('speech.audio.copied', fields: {'job': jobId, 'bytes': length});
    return target;
  }

  Future<String> decode(String path, String id) async {
    final watch = Stopwatch()..start();
    _event('speech.decode.started', fields: {'job': id});
    try {
      final result = await _decode(path, id);
      _event(
        'speech.decode.completed',
        fields: {
          'job': id,
          'elapsed_ms': watch.elapsedMilliseconds,
          'converted': result != path,
        },
      );
      return result;
    } catch (error) {
      final cancelled = _decodeCancels.contains(id);
      _event(
        cancelled ? 'speech.decode.cancelled' : 'speech.decode.failed',
        level: cancelled ? LogLevel.info : LogLevel.error,
        fields: {
          'job': id,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    } finally {
      _decodeCancels.remove(id);
    }
  }

  Future<String> _decode(String path, String id) async {
    if (p.extension(path).toLowerCase() == '.wav') {
      try {
        await Isolate.run(() => WaveFile.inspect(File(path)));
        return path;
      } on FormatException {
        /* Android can decode additional WAV encodings. */
      }
    }
    if (!Platform.isAndroid) {
      throw const FormatException('Import a PCM WAV on this platform');
    }
    final output = p.join(p.dirname(path), 'decoded.wav');
    _decodes.add(id);
    try {
      await _channel.invokeMethod<void>('decode', {
        'id': id,
        'source': path,
        'destination': output,
      });
      return output;
    } finally {
      _decodes.remove(id);
    }
  }

  Future<void> cancelDecode(String id) async {
    if (Platform.isAndroid && _decodes.contains(id)) {
      _decodeCancels.add(id);
      _event('speech.decode.cancel_requested', fields: {'job': id});
      await _channel.invokeMethod<void>('cancelDecode', {'id': id});
    }
  }

  Future<void> exportAudio(String path, String name) async {
    try {
      final destination = await _export.invokeMethod<String>(
        'saveToDownloads',
        {'sourcePath': path, 'fileName': name, 'mimeType': 'audio/wav'},
      );
      if (destination == null || destination.isEmpty) {
        throw StateError('Downloads directory is unavailable');
      }
      _event('speech.audio.exported');
    } catch (error) {
      _event(
        'speech.audio.export_failed',
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _recordingLimit?.cancel();
    unawaited(_interruptions?.cancel());
    unawaited(_noisy?.cancel());
    unawaited(_playerState?.cancel());
    if (_recorded?.isCompleted == false) _recorded!.complete(recordingPath);
    unawaited(_recorder?.dispose());
    unawaited(_releaseRecordingFocus());
    unawaited(_player?.dispose());
    super.dispose();
  }
}
