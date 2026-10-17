import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/storage/owned_file_cleanup.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/repositories/speech_repository.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'speech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeechHarness h;
  setUp(() async {
    h = SpeechHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test('active queries do not deserialize unrelated historical jobs', () async {
    await h.db.execute(
      "INSERT INTO speech_jobs(id,state,asset_id,created_at,payload) VALUES('old','completed','asset',0,'not read by active queries')",
    );
    final active = SpeechJob(
      id: 'active',
      state: SpeechJobState.waiting,
      snapshot: {
        'assetId': 'asset',
        'kind': 'tts',
        'voice': {'id': 'voice'},
      },
      createdAt: DateTime(2026),
    );
    final repository = SpeechRepository(h.db);
    await repository.saveJob(active);
    expect(await repository.activeCount(), 1);
    expect(await repository.usesAsset('asset'), isTrue);
    expect(await repository.usesVoice('voice'), isTrue);
    await repository.recover();
    expect(await repository.activeCount(), 0);
    expect(await repository.usesAsset('asset'), isFalse);
    expect(await repository.usesVoice('voice'), isFalse);
  });

  test(
    'job deletion commits first, rolls back on SQL failure, and retries cleanup on startup',
    () async {
      final asset = await h.model();
      final job = await h.service.enqueue(asset: asset, text: 'source text');
      await until(() => h.workers.isNotEmpty);
      final output = File(job.snapshot['outputPath'] as String);
      await output.writeAsString('audio fixture');
      h.workers.single.finished.complete({'outputPath': output.path});
      await h.service.settled;
      await h.db.execute(
        "CREATE TRIGGER reject_job BEFORE DELETE ON speech_jobs BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(h.service.deleteJob(job.id), throwsA(anything));
      expect(h.service.job(job.id), isNotNull);
      expect(await output.exists(), isTrue);
      expect(await h.db.query('SELECT * FROM pending_file_deletions'), isEmpty);
      await h.db.execute('DROP TRIGGER reject_job');
      await h.db.execute(
        "CREATE TRIGGER reject_cleanup BEFORE DELETE ON pending_file_deletions BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await h.service.deleteJob(job.id);
      expect(h.service.job(job.id), isNull);
      expect(await h.service.repository.jobs(), isEmpty);
      expect(
        await h.db.query('SELECT * FROM pending_file_deletions'),
        hasLength(1),
      );
      await h.db.execute('DROP TRIGGER reject_cleanup');
      h.service.dispose();
      h.service = SpeechJobService(
        h.resources,
        logger: h.logger,
        workerFactory: () => throw StateError('Recovery must not replay'),
      );
      await h.service.initialize(
        storageRoot: h.directory,
        database: h.db,
        configureAudio: false,
      );
      expect(h.service.ready, isTrue);
      expect(await h.db.query('SELECT * FROM pending_file_deletions'), isEmpty);
      expect(await output.parent.exists(), isFalse);
      expect(h.workers, hasLength(1));
    },
  );

  test(
    'voice deletion is atomic and completed jobs retain their independent copies',
    () async {
      final voiceFile = File(
        '${h.directory.path}/speech/voices/voice/reference.wav',
      );
      await voiceFile.parent.create(recursive: true);
      await voiceFile.writeAsString('voice');
      final copiedFile = File(
        '${h.directory.path}/speech/jobs/saved/reference.wav',
      );
      await copiedFile.parent.create(recursive: true);
      await copiedFile.writeAsString('owned by the job');
      final voice = VoiceProfile(
        id: 'voice',
        name: 'Voice',
        assetId: 'deleted-model',
        revision: 'r',
        path: voiceFile.path,
        hash: 'hash',
        referenceText: 'text',
        durationSeconds: 3,
      );
      await h.service.repository.saveVoice(voice);
      h.service.voices = [voice];
      await h.service.repository.saveJob(
        SpeechJob(
          id: 'saved',
          state: SpeechJobState.completed,
          snapshot: {
            'assetId': 'deleted-model',
            'kind': 'tts',
            'voice': {'id': 'voice', 'path': copiedFile.path},
          },
          createdAt: DateTime(2026),
          result: {'outputPath': copiedFile.path},
        ),
      );
      await h.db.execute(
        "CREATE TRIGGER reject_voice BEFORE DELETE ON voice_profiles BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(h.service.deleteVoice(voice), throwsA(anything));
      expect(await voiceFile.exists(), isTrue);
      expect(h.service.voices, hasLength(1));
      expect(await h.db.query('SELECT * FROM pending_file_deletions'), isEmpty);
      await h.db.execute('DROP TRIGGER reject_voice');
      await h.service.deleteVoice(voice);
      expect(h.service.voices, isEmpty);
      expect(await voiceFile.parent.exists(), isFalse);
      expect(await copiedFile.exists(), isTrue);
      expect(await h.service.repository.jobs(), hasLength(1));
    },
  );

  test(
    'file cleanup refuses external paths even with a persisted invalid intent',
    () async {
      final outside = File('${h.directory.path}/keep.txt');
      await outside.writeAsString('user source');
      await h.db.execute(
        'INSERT INTO pending_file_deletions(path,kind) VALUES(?,?)',
        [outside.path, 'speechJob'],
      );
      await OwnedFileCleanup(h.db, h.directory).retry();
      expect(await outside.readAsString(), 'user source');
      expect(
        await h.db.query('SELECT * FROM pending_file_deletions'),
        hasLength(1),
      );
    },
  );
}
