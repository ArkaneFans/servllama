import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/core/services/downloads_export_service.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/repositories/speech_repository.dart';
import 'package:servllama/features/speech/services/audio_io_service.dart';
import 'package:servllama/features/speech/services/speech_model_service.dart';
import 'package:servllama/features/speech/services/speech_worker.dart';
import 'package:servllama/features/speech/services/wave_file.dart';

/// The only speech FIFO. ResourceCoordinator has no competing task queue.
class SpeechJobService extends ChangeNotifier {
  SpeechJobService(
    this.resources, {
    this.workerFactory = SpeechWorker.new,
    AppLogger? logger,
  }) : _logger = logger ?? AppLogger.instance;
  final AppLogger _logger;
  final SpeechWorker Function() workerFactory;
  final ResourceCoordinator resources;
  late Directory root;
  late SpeechRepository repository;
  late SpeechModelService models;
  late AudioIoService audio;
  bool ready = false, _draining = false, _disposed = false, _needsWake = false;
  String? loadError, asrId, ttsId;
  List<SpeechJob> jobs = [];
  List<VoiceProfile> voices = [];
  SpeechWorker? _worker;
  String? _activeId;
  final Set<String> _cancelled = {};
  final Set<String> _deleting = {};
  Future<void> _writes = Future.value();
  Future<void>? _drainOperation;

  /// Waits for current native cleanup and queued persistence, without starting
  /// blocked jobs. Useful when tearing down the process-owned services.
  Future<void> get settled async {
    await _drainOperation;
    await _writes;
  }

  bool get hasWaitingJobs => jobs.any((j) => j.state == SpeechJobState.waiting);
  Future<void> initialize({
    Directory? storageRoot,
    AppDatabase? database,
    bool configureAudio = true,
  }) async {
    try {
      final storage = storageRoot ?? await getApplicationSupportDirectory();
      await storage.create(recursive: true);
      root = Directory(await storage.resolveSymbolicLinks());
      repository = SpeechRepository(database ?? await AppDatabase.shared());
      await repository.recover();
      models = SpeechModelService(
        UnifiedModelRepository(database: repository.db),
        repository,
        root,
        resources: resources,
        logger: _logger,
      );
      audio = AudioIoService(root, logger: _logger);
      await models.load();
      if (configureAudio) await audio.initialize();
      final prefs = await SharedPreferences.getInstance();
      asrId = prefs.getString('v2/speech/asr');
      ttsId = prefs.getString('v2/speech/tts');
      jobs = await repository.jobs();
      voices = await repository.voices();
      resources.addListener(_wake);
      models.addListener(_changed);
      audio.addListener(_changed);
      ready = true;
      _logger.event(
        'speech.initialized',
        channel: LogChannel.speech,
        fields: {'jobs': jobs.length, 'models': models.assets.length},
      );
    } catch (e) {
      loadError = LogRedactor.redact(e.toString());
      _logger.event(
        'speech.initialize_failed',
        channel: LogChannel.speech,
        level: LogLevel.error,
        fields: AppLogger.errorFields(e),
      );
    }
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  ModelAsset? selected(AssetKind kind) {
    if (!ready) return null;
    final id = kind == AssetKind.asr ? asrId : ttsId;
    return id == null
        ? models.assets.where((a) => a.kind == kind && a.isReady).firstOrNull
        : models.assets.where((a) => a.id == id && a.isReady).firstOrNull;
  }

  Future<void> select(AssetKind kind, String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (kind == AssetKind.asr) {
      asrId = id;
      await prefs.setString('v2/speech/asr', id);
    } else {
      ttsId = id;
      await prefs.setString('v2/speech/tts', id);
    }
    _logger.event(
      'speech.model.selected',
      channel: LogChannel.speech,
      fields: {'asset': id, 'kind': kind.name},
    );
    _changed();
  }

  SpeechJob? job(String id) => jobs.where((j) => j.id == id).firstOrNull;
  void _event(
    String name,
    SpeechJob job, {
    LogLevel level = LogLevel.info,
    Map<String, Object?> fields = const {},
  }) => _logger.event(
    name,
    channel: LogChannel.speech,
    level: level,
    fields: {
      'job': job.id,
      'asset': job.assetId,
      'kind': job.kind.name,
      'recipe': (job.snapshot['package'] as Map?)?['recipe'],
      'conversation': job.snapshot['conversationId'],
      ...fields,
    },
  );

  Future<void> _save(SpeechJob job) async {
    if (_deleting.contains(job.id)) throw StateError('Task is being deleted');
    final previous = this.job(job.id)?.state;
    jobs = jobs.where((j) => j.id != job.id).toList()..add(job);
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final write = _writes.then((_) => repository.saveJob(job));
    _writes = write.catchError((Object _) {});
    await write;
    if (previous != job.state) {
      _event(
        'speech.job.state',
        job,
        level: job.state == SpeechJobState.failed
            ? LogLevel.error
            : LogLevel.info,
        fields: {
          'state': job.state.name,
          if (job.state == SpeechJobState.waiting)
            'reason': resources.requiresRestart(LocalResourceDomain.speech)
                ? 'cleanup_unconfirmed'
                : 'speech_busy',
        },
      );
    }
    _changed();
  }

  Future<SpeechJob> enqueue({
    required ModelAsset asset,
    String? inputPath,
    String text = '',
    String language = '',
    int speaker = 0,
    double speed = 1,
    VoiceProfile? voice,
    String? conversationId,
    String? draftAtEnqueue,
  }) async {
    if (!ready) throw StateError('Speech is not ready');
    if (jobs.where((j) => j.state.active).length >= 8) {
      throw StateError('Speech queue is full');
    }
    final package = SpeechPackage.fromJson(asset.manifest);
    if (asset.kind == AssetKind.tts &&
        (text.trim().isEmpty || text.length > 4000)) {
      throw const FormatException(
        'Synthesis text must contain 1–4000 characters',
      );
    }
    if (speaker < 0 || speaker > 217 || speed < 0.5 || speed > 2) {
      throw const FormatException('Invalid synthesis parameters');
    }
    if (!package.recipe.synthesisSpeed && speed != 1) {
      throw const FormatException('This model does not expose synthesis speed');
    }
    if (voice != null &&
        (!package.recipe.canClone ||
            voice.assetId != asset.id ||
            voice.revision != asset.revision)) {
      throw const FormatException(
        'Reference voice belongs to another model revision',
      );
    }
    final id = newId();
    final dir = Directory(p.join(root.path, 'speech', 'jobs', id));
    await dir.create(recursive: true);
    try {
      final copied = inputPath == null
          ? null
          : await audio.copyInput(inputPath, id);
      if (asset.kind == AssetKind.asr && copied == null) {
        throw const FormatException('Select an audio input');
      }
      Map<String, dynamic>? voiceSnapshot;
      if (voice != null) {
        final original = File(voice.path);
        if ((await sha256.bind(original.openRead()).first).toString() !=
            voice.hash) {
          throw StateError('Reference voice changed');
        }
        final destination = p.join(dir.path, 'reference.wav');
        await original.copy(destination);
        voiceSnapshot = {...voice.toJson(), 'path': destination};
      }
      final snapshot = SpeechJob.freeze({
        'assetId': asset.id,
        'revision': asset.revision,
        'kind': asset.kind.name,
        'modelPath': asset.path,
        'package': package.toJson(),
        'inputPath': copied,
        'inputHash': copied == null
            ? null
            : (await sha256.bind(File(copied).openRead()).first).toString(),
        'outputPath': p.join(dir.path, 'output.wav'),
        'text': text.trim(),
        'language': language.trim(),
        'speaker': speaker,
        'speed': speed,
        'voice': voiceSnapshot,
        'conversationId': conversationId,
        'draftAtEnqueue': draftAtEnqueue,
      });
      final job = SpeechJob(
        id: id,
        state: SpeechJobState.queued,
        snapshot: snapshot,
        createdAt: DateTime.now(),
      );
      await repository.db.transaction(() async {
        if (await repository.db
                .query(
                  "SELECT id FROM speech_jobs WHERE state IN ('queued','waiting','running','cancelling')",
                )
                .then((rows) => rows.length) >=
            8) {
          throw StateError('Speech queue is full');
        }
        final current = await models.models.asset(asset.id);
        if (current == null ||
            !current.isReady ||
            current.revision != asset.revision) {
          throw StateError('Model is not ready');
        }
        await repository.saveJob(job);
      });
      jobs = [job, ...jobs];
      _event('speech.job.queued', job);
      _changed();
      _wake();
      return job;
    } catch (error) {
      _logger.event(
        'speech.enqueue_failed',
        channel: LogChannel.speech,
        level: LogLevel.error,
        fields: {
          'job': id,
          'asset': asset.id,
          'kind': asset.kind.name,
          ...AppLogger.errorFields(error),
        },
      );
      await dir.delete(recursive: true);
      rethrow;
    }
  }

  void _wake() {
    if (!ready || _disposed) return;
    if (_draining) {
      _needsWake = true;
      return;
    }
    _draining = true;
    unawaited(
      _drainOperation = _drain()
          .catchError((Object e) {
            loadError = LogRedactor.redact(e.toString());
            _logger.event(
              'speech.queue.failed',
              channel: LogChannel.speech,
              level: LogLevel.error,
              fields: AppLogger.errorFields(e),
            );
            _changed();
          })
          .whenComplete(() {
            _draining = false;
            if (_needsWake) {
              _needsWake = false;
              scheduleMicrotask(_wake);
            }
          }),
    );
  }

  Future<void> _drain() async {
    while (!_disposed) {
      final current = jobs.reversed
          .where(
            (j) =>
                j.state == SpeechJobState.queued ||
                j.state == SpeechJobState.waiting,
          )
          .firstOrNull;
      if (current == null) return;
      final lease = resources.tryAcquire(
        kind: current.kind == AssetKind.asr
            ? LocalResourceKind.asr
            : LocalResourceKind.tts,
        assetId: current.assetId,
        owner: current.id,
      );
      if (lease == null) {
        if (current.state != SpeechJobState.waiting) {
          await _save(current.copyWith(state: SpeechJobState.waiting));
        }
        return;
      }
      _activeId = current.id;
      final watch = Stopwatch()..start();
      var safeToRelease = true;
      final foreground = ForegroundTaskService()..init();
      try {
        await _save(current.copyWith(state: SpeechJobState.running));
        await foreground.acquire(
          owner: 'speech',
          notificationTitle: current.snapshot['package']['name'],
          notificationText: 'ServLlama',
        );
        final asset = await models.models.asset(current.assetId);
        if (asset == null ||
            !asset.isReady ||
            asset.revision != current.snapshot['revision']) {
          throw StateError('Model is unavailable');
        }
        await models.validate(asset);
        final snapshot = Map<String, dynamic>.from(current.snapshot);
        final inputPath = snapshot['inputPath'] as String?;
        if (inputPath != null &&
            (await sha256.bind(File(inputPath).openRead()).first).toString() !=
                snapshot['inputHash']) {
          throw StateError('Task input has changed; import it as a new task');
        }
        if (current.kind == AssetKind.asr && !_cancelled.contains(current.id)) {
          snapshot['inputPath'] = await audio.decode(
            snapshot['inputPath'],
            current.id,
          );
        }
        Map<String, dynamic> result = {'cancelled': true};
        if (!_cancelled.contains(current.id)) {
          final worker = workerFactory();
          _worker = worker;
          result = await worker.run(
            snapshot,
            (progress) {
              final active = job(current.id);
              if (active == null) return;
              jobs = jobs
                  .map(
                    (j) =>
                        j.id == active.id ? j.copyWith(progress: progress) : j,
                  )
                  .toList();
              _changed();
            },
            onCheckpoint: (partial) {
              final active = job(current.id);
              if (active == null || !active.state.active) return;
              unawaited(
                _save(active.copyWith(result: partial)).catchError((Object e) {
                  loadError = LogRedactor.redact(e.toString());
                  _event(
                    'speech.checkpoint.failed',
                    active,
                    level: LogLevel.error,
                    fields: AppLogger.errorFields(e),
                  );
                  if (_activeId == current.id) _worker?.cancel();
                  _changed();
                }),
              );
            },
            onStage: (stage) => _event(
              'speech.worker.${stage.name}',
              current,
              fields: {'elapsed_ms': watch.elapsedMilliseconds},
            ),
          );
        }
        final cancelled =
            _cancelled.contains(current.id) || result['cancelled'] == true;
        await _save(
          (job(current.id) ?? current).copyWith(
            state: cancelled
                ? SpeechJobState.cancelled
                : SpeechJobState.completed,
            result: result,
            progress: cancelled ? (job(current.id)?.progress ?? 0) : 1,
          ),
        );
      } catch (e) {
        _event(
          'speech.job.error',
          current,
          level: LogLevel.error,
          fields: AppLogger.errorFields(e),
        );
        if (e is SpeechCleanupException) {
          safeToRelease = false;
          resources.quarantine(lease);
          _event(
            'speech.resources.quarantined',
            current,
            level: LogLevel.error,
          );
        }
        await _save(
          (job(current.id) ?? current).copyWith(
            state: _cancelled.contains(current.id)
                ? SpeechJobState.cancelled
                : SpeechJobState.failed,
            error: LogRedactor.redact(e.toString()),
          ),
        );
      } finally {
        _worker = null;
        _activeId = null;
        _cancelled.remove(current.id);
        final released = safeToRelease && resources.release(lease);
        _event(
          'speech.job.finished',
          job(current.id) ?? current,
          level: released ? LogLevel.info : LogLevel.error,
          fields: {
            'elapsed_ms': watch.elapsedMilliseconds,
            'outcome': job(current.id)?.state.name,
            'resources_released': released,
          },
        );
        await foreground.release('speech');
      }
    }
  }

  Future<void> cancel(String id) async {
    final j = job(id);
    if (j == null || !j.state.active) return;
    if (_cancelled.add(id)) _event('speech.job.cancel_requested', j);
    if (_activeId == id) {
      final saved = _save(j.copyWith(state: SpeechJobState.cancelling));
      // Capture and signal this worker before awaiting persistence. A completion
      // must never allow a delayed cancel to reach the next FIFO item.
      _worker?.cancel();
      await audio.cancelDecode(id);
      await saved;
    } else {
      await _save(j.copyWith(state: SpeechJobState.cancelled));
      _cancelled.remove(id);
    }
    _wake();
  }

  Future<void> deleteJob(String id) async {
    if (job(id)?.state.active == true) {
      throw StateError('Cancel the task before deleting it');
    }
    if (resources.leaseFor(LocalResourceDomain.speech)?.owner == id) {
      throw StateError(
        'Native cleanup is pending; restart before deleting this task',
      );
    }
    if (!_deleting.add(id)) return;
    try {
      await _writes;
      final j = job(id);
      if (j == null) return;
      if (j.state.active) {
        throw StateError('Cancel the task before deleting it');
      }
      if (resources.leaseFor(LocalResourceDomain.speech)?.owner == id) {
        throw StateError(
          'Native cleanup is pending; restart before deleting this task',
        );
      }
      final output = j.result['outputPath'] as String?;
      if (output != null && audio.playingPath == output) {
        await audio.stopPlayback();
      }
      final dir = Directory(p.join(root.path, 'speech', 'jobs', id));
      if (await dir.exists()) {
        if (p.normalize(await dir.resolveSymbolicLinks()) !=
            p.normalize(dir.absolute.path)) {
          throw StateError('Unexpected job storage link');
        }
        await dir.delete(recursive: true);
      }
      jobs.removeWhere((j) => j.id == id);
      await repository.deleteJob(id);
      _event('speech.job.deleted', j);
      _changed();
    } finally {
      _deleting.remove(id);
    }
  }

  Future<void> editTranscript(
    String id,
    String text, {
    List<String>? segments,
  }) async {
    final j = job(id);
    if (j == null || j.kind != AssetKind.asr || j.state.active) {
      throw StateError('Transcript is not final');
    }
    final original = j.result['segments'] as List? ?? [];
    if (segments != null && segments.length != original.length) {
      throw const FormatException('Transcript segment count changed');
    }
    await _save(
      j.copyWith(
        result: {
          ...j.result,
          'editedText': text,
          if (segments != null)
            'editedSegments': [
              for (var i = 0; i < original.length; i++)
                {
                  ...Map<String, dynamic>.from(original[i]),
                  'text': segments[i],
                },
            ],
          'edits': [
            ...?j.result['edits'] as List?,
            {'text': text, 'at': DateTime.now().toIso8601String()},
          ],
        },
      ),
    );
    _event(
      'speech.transcript.edited',
      j,
      fields: {'characters': text.length, 'segments': segments?.length},
    );
  }

  Future<void> exportTranscript(SpeechJob j, {bool subtitles = false}) async {
    if (subtitles &&
        (j.result['timing'] != 'native' ||
            (j.result['editedText'] != null &&
                j.result['editedSegments'] == null))) {
      throw StateError('This model does not provide reliable subtitle timings');
    }
    await DownloadsExportService().saveTextFile(
      fileName: j.id + (subtitles ? '.srt' : '.txt'),
      content: subtitles ? toSrt(j) : j.text,
    );
    _event(
      'speech.transcript.exported',
      j,
      fields: {'format': subtitles ? 'srt' : 'txt'},
    );
  }

  static String toSrt(SpeechJob j) {
    final segments = List<Map<String, dynamic>>.from(
      ((j.result['editedSegments'] ?? j.result['segments']) as List? ?? []).map(
        (s) => Map<String, dynamic>.from(s),
      ),
    );
    String time(num value) {
      final ms = (value * 1000).round();
      String pad(int v, int n) => v.toString().padLeft(n, '0');
      return '${pad(ms ~/ 3600000, 2)}:${pad(ms ~/ 60000 % 60, 2)}:${pad(ms ~/ 1000 % 60, 2)},${pad(ms % 1000, 3)}';
    }

    return segments
        .asMap()
        .entries
        .map(
          (e) =>
              '${e.key + 1}\n${time(e.value['start'] as num)} --> ${time(e.value['end'] as num)}\n${e.value['text']}\n',
        )
        .join('\n');
  }

  /// Retrying is always an explicit new job with the previous immutable inputs.
  /// It never revives the old job or silently substitutes a different model.
  Future<SpeechJob> retry(SpeechJob previous) async {
    if (previous.state.active) throw StateError('Task is still active');
    final asset = await models.models.asset(previous.assetId);
    if (asset == null ||
        !asset.isReady ||
        asset.revision != previous.snapshot['revision']) {
      throw StateError(
        'Reinstall the original model revision or create a new task',
      );
    }
    final source = previous.snapshot;
    final voice = source['voice'] as Map?;
    final next = await enqueue(
      asset: asset,
      inputPath: source['inputPath'] as String?,
      text: source['text'] as String? ?? '',
      language: source['language'] as String? ?? '',
      speaker: source['speaker'] as int? ?? 0,
      speed: (source['speed'] as num? ?? 1).toDouble(),
      voice: voice == null
          ? null
          : VoiceProfile.fromJson(Map<String, dynamic>.from(voice)),
      conversationId: source['conversationId'] as String?,
      draftAtEnqueue: source['draftAtEnqueue'] as String?,
    );
    _event('speech.job.retried', next, fields: {'previous_job': previous.id});
    return next;
  }

  Future<VoiceProfile> renameVoice(
    VoiceProfile voice,
    String name,
    String referenceText,
  ) async {
    if (name.trim().isEmpty ||
        name.length > 120 ||
        referenceText.trim().isEmpty ||
        referenceText.length > 4000) {
      throw const FormatException(
        'A voice needs a name and reference transcript',
      );
    }
    final updated = VoiceProfile.fromJson({
      ...voice.toJson(),
      'name': name.trim(),
      'referenceText': referenceText.trim(),
    });
    await repository.saveVoice(updated);
    voices = await repository.voices();
    _logger.event(
      'speech.voice.updated',
      channel: LogChannel.speech,
      fields: {'voice': voice.id, 'asset': voice.assetId},
    );
    _changed();
    return updated;
  }

  Future<VoiceProfile> createVoice({
    required ModelAsset asset,
    required String name,
    required String input,
    required String referenceText,
    required bool rightsConfirmed,
  }) async {
    if (!SpeechPackage.fromJson(asset.manifest).recipe.canClone) {
      throw StateError('This model cannot clone voices');
    }
    if (!rightsConfirmed ||
        name.trim().isEmpty ||
        name.length > 120 ||
        referenceText.trim().isEmpty ||
        referenceText.length > 4000) {
      throw const FormatException(
        'Name, reference transcript and rights confirmation are required',
      );
    }
    final id = newId(), tempId = newId();
    final copied = await audio.copyInput(input, tempId);
    final dir = Directory(p.join(root.path, 'speech', 'voices', id));
    await dir.create(recursive: true);
    final target = p.join(dir.path, 'reference.wav');
    try {
      final decoded = await audio.decode(copied, tempId);
      final duration = await Isolate.run(() {
        final wave = WaveFile.inspect(File(decoded));
        if (wave.seconds < 3 || wave.seconds > 30) {
          throw const FormatException('Reference audio must be 3–30 seconds');
        }
        WaveFile.normalize(File(decoded), File(target), rate: 24000);
        return wave.seconds;
      });
      final hash = (await sha256.bind(File(target).openRead()).first)
          .toString();
      final voice = VoiceProfile(
        id: id,
        name: name.trim(),
        assetId: asset.id,
        revision: asset.revision,
        path: target,
        hash: hash,
        referenceText: referenceText.trim(),
        durationSeconds: duration,
      );
      await repository.saveVoice(voice);
      voices = await repository.voices();
      _logger.event(
        'speech.voice.created',
        channel: LogChannel.speech,
        fields: {'voice': id, 'asset': asset.id, 'duration_seconds': duration},
      );
      _changed();
      return voice;
    } catch (error) {
      _logger.event(
        'speech.voice.create_failed',
        channel: LogChannel.speech,
        level: LogLevel.error,
        fields: {
          'voice': id,
          'asset': asset.id,
          ...AppLogger.errorFields(error),
        },
      );
      await dir.delete(recursive: true);
      rethrow;
    } finally {
      await Directory(p.dirname(copied)).delete(recursive: true);
    }
  }

  Future<void> deleteVoice(VoiceProfile v) async {
    if (resources.requiresRestart(LocalResourceDomain.speech)) {
      throw StateError(
        'Native cleanup is pending; restart before deleting voices',
      );
    }
    if (await repository.usesVoice(v.id)) {
      throw StateError('A queued or running job uses this voice');
    }
    if (audio.playingPath == v.path) await audio.stopPlayback();
    await repository.deleteVoice(v.id);
    final dir = Directory(p.join(root.path, 'speech', 'voices', v.id));
    if (await dir.exists()) await dir.delete(recursive: true);
    voices = await repository.voices();
    _logger.event(
      'speech.voice.deleted',
      channel: LogChannel.speech,
      fields: {'voice': v.id, 'asset': v.assetId},
    );
    _changed();
  }

  static String spokenText(String text) => text
      .replaceAll(RegExp(r'\x60{3}[\s\S]*?\x60{3}'), '')
      .replaceAll(RegExp(r'~{3}[\s\S]*?~{3}'), '')
      .replaceAll(RegExp(r'\x60[^\x60]+\x60'), '')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]+\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'https?://\S+'), '')
      .replaceAll(RegExp(r'(^|\s)(/|[A-Za-z]:\\)\S+'), ' ')
      .replaceAll(RegExp(r'[#*_>]'), '')
      .trim();
  @override
  void dispose() {
    _disposed = true;
    if (ready) {
      resources.removeListener(_wake);
      models.removeListener(_changed);
      audio.removeListener(_changed);
      audio.dispose();
      models.dispose();
    }
    _worker?.cancel();
    super.dispose();
  }
}
