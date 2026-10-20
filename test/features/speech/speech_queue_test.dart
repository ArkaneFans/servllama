import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/repositories/speech_repository.dart';
import 'package:servllama/features/speech/services/speech_worker.dart';
import 'speech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeechHarness h;
  setUp(() async {
    h = SpeechHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test(
    'a durable partial transcript survives failure and restart without replay',
    () async {
      final asset = await h.model();
      final job = await h.service.enqueue(asset: asset, text: 'fixture');
      await until(() => h.workers.isNotEmpty);
      h.workers.single.checkpoint!({
        'text': 'completed chunk',
        'segments': [
          {'start': 0, 'end': 2, 'text': 'completed chunk'},
        ],
        'timing': 'native',
      });
      h.workers.single.finished.completeError(StateError('worker stopped'));
      await h.service.settled;
      final saved = (await h.service.repository.jobs()).single;
      expect(saved.text, 'completed chunk');
      await h.service.repository.saveJob(
        saved.copyWith(state: SpeechJobState.running),
      );
      await h.service.repository.recover();
      final recovered = (await h.service.repository.jobs()).single;
      expect(recovered.state, SpeechJobState.interrupted);
      expect(recovered.text, 'completed chunk');
      expect(h.service.job(job.id)!.state, SpeechJobState.failed);
      expect(h.workers.length, 1);
      final diagnostic = h.logger
          .entriesFor(LogChannel.speech)
          .map((e) => e.message)
          .join();
      for (final private in [
        'completed chunk',
        'worker stopped',
        h.directory.path,
      ]) {
        expect(diagnostic, isNot(contains(private)));
      }
      final finished = h
          .serviceLog(job.id)
          .singleWhere((e) => e.startsWith('speech.job.finished'));
      expect(finished, contains('outcome="failed"'));
      expect(finished, contains('resources_released=true'));
    },
  );

  test(
    'LLM residency permits speech; cancelling speech preserves the LLM',
    () async {
      final asset = await h.model();
      final llm = h.resources.tryAcquire(
        kind: LocalResourceKind.llm,
        assetId: 'llm',
        owner: 'server',
      );
      final first = await h.service.enqueue(asset: asset, text: 'first');
      final removed = await h.service.enqueue(asset: asset, text: 'never run');
      final service = h.service;
      await until(() => h.workers.length == 1);
      await service.cancel(removed.id);
      expect(h.workers.single.received!['text'], 'first');
      expect(service.hasWaitingJobs, isFalse);
      expect(h.resources.leaseFor(LocalResourceDomain.llm), same(llm));
      await service.cancel(first.id);
      expect(h.workers.single.cancellationRequested, isTrue);
      expect(h.resources.leaseFor(LocalResourceDomain.llm), same(llm));
      h.workers.single.finished.complete({});
      await until(
        () => service.job(first.id)?.state == SpeechJobState.cancelled,
      );
      expect(service.job(removed.id)!.state, SpeechJobState.cancelled);
      expect(h.resources.leaseFor(LocalResourceDomain.llm), same(llm));
      expect(h.workers.length, 1);
    },
  );

  test(
    'FIFO holds native lease after cancel until worker cleanup completes',
    () async {
      final asset = await h.model();
      final first = await h.service.enqueue(asset: asset, text: 'first');
      final next = await h.service.enqueue(asset: asset, text: 'next');
      await until(() => h.workers.length == 1);
      final lease = h.resources.leaseFor(LocalResourceDomain.speech);
      await h.service.cancel(first.id);
      await h.service.cancel(first.id);
      expect(h.workers.first.cancellationRequested, isTrue);
      expect(h.service.job(first.id)!.state, SpeechJobState.cancelling);
      expect(h.resources.leaseFor(LocalResourceDomain.speech), same(lease));
      expect(h.workers.length, 1);
      var events = h.serviceLog(first.id);
      expect(
        events.where((e) => e.startsWith('speech.job.cancel_requested')),
        hasLength(1),
      );
      expect(
        events.any((e) => e.startsWith('speech.worker.released')),
        isFalse,
      );
      expect(events.any((e) => e.startsWith('speech.job.finished')), isFalse);
      h.workers.first.finished.complete({});
      await until(() => h.workers.length == 2);
      expect(h.service.job(first.id)!.state, SpeechJobState.cancelled);
      expect(h.resources.leaseFor(LocalResourceDomain.speech)!.owner, next.id);
      events = h.serviceLog(first.id);
      expect(events.any((e) => e.startsWith('speech.worker.released')), isTrue);
      final finished = events.singleWhere(
        (e) => e.startsWith('speech.job.finished'),
      );
      expect(finished, contains('outcome="cancelled"'));
      expect(finished, contains('resources_released=true'));
      h.workers.last.finished.complete({});
      await until(
        () => h.service.job(next.id)!.state == SpeechJobState.completed,
      );
    },
  );

  test(
    'model deletion rejects queued work and parameters stay frozen',
    () async {
      final asset = await h.model();
      final reservation = h.resources.tryAcquire(
        kind: LocalResourceKind.tts,
        assetId: 'other-speech',
        owner: 'fixture',
      )!;
      final first = await h.service.enqueue(
        asset: asset,
        text: 'snapshot',
        speed: 1.5,
        speaker: 3,
      );
      await h.service.select(asset.kind, 'later-selection');
      expect(first.snapshot['speed'], 1.5);
      expect(
        () => (first.snapshot['package'] as Map)['name'] = 'changed',
        throwsUnsupportedError,
      );
      await expectLater(h.service.models.delete(asset), throwsStateError);
      await h.service.cancel(first.id);
      h.resources.release(reservation);
      await h.service.models.delete(asset);
      expect(await Directory(asset.path).exists(), isFalse);
    },
  );

  test(
    'failed speech cleanup blocks speech and permits LLM residency',
    () async {
      final asset = await h.model();
      final first = await h.service.enqueue(asset: asset, text: 'first');
      final next = await h.service.enqueue(asset: asset, text: 'next');
      await until(() => h.workers.length == 1);
      h.workers.first.finished.completeError(
        SpeechCleanupException('fixture failure'),
      );
      await until(
        () => h.service.job(first.id)!.state == SpeechJobState.failed,
      );
      expect(h.resources.requiresRestart(LocalResourceDomain.speech), isTrue);
      expect(h.resources.leaseFor(LocalResourceDomain.speech)!.owner, first.id);
      expect(h.resources.requiresRestart(LocalResourceDomain.llm), isFalse);
      final events = h.serviceLog(first.id);
      expect(
        events.any((e) => e.startsWith('speech.resources.quarantined')),
        isTrue,
      );
      expect(
        events.any((e) => e.startsWith('speech.worker.released')),
        isFalse,
      );
      expect(
        events.singleWhere((e) => e.startsWith('speech.job.finished')),
        contains('resources_released=false'),
      );
      expect(
        h.resources.tryAcquire(
          kind: LocalResourceKind.llm,
          assetId: 'llm',
          owner: 'server',
        ),
        isNotNull,
      );
      await expectLater(h.service.deleteJob(first.id), throwsStateError);
      await expectLater(h.service.models.delete(asset), throwsStateError);
      expect(h.workers.length, 1);
      await h.service.cancel(next.id);
    },
  );

  test(
    'starting and stopping LLM residency does not interrupt speech',
    () async {
      final asset = await h.model();
      final job = await h.service.enqueue(asset: asset, text: 'keep speaking');
      await until(() => h.workers.length == 1);
      final speech = h.resources.leaseFor(LocalResourceDomain.speech);
      final llm = h.resources.tryAcquire(
        kind: LocalResourceKind.llm,
        assetId: 'llm',
        owner: 'server',
      )!;
      expect(h.resources.leaseFor(LocalResourceDomain.speech), same(speech));
      expect(h.resources.release(llm), isTrue);
      expect(h.resources.leaseFor(LocalResourceDomain.speech), same(speech));
      expect(h.workers.single.cancellationRequested, isFalse);
      expect(h.service.job(job.id)!.state, SpeechJobState.running);
      h.workers.single.finished.complete({});
      await until(
        () => h.service.job(job.id)!.state == SpeechJobState.completed,
      );
    },
  );

  test('speech residency waits and resumes the same snapshot', () async {
    final asset = await h.model();
    final reservation = h.resources.tryAcquire(
      kind: LocalResourceKind.tts,
      assetId: 'other-speech',
      owner: 'fixture',
    )!;
    final job = await h.service.enqueue(asset: asset, text: 'after release');
    await until(() => h.service.job(job.id)!.state == SpeechJobState.waiting);
    await h.service.settled;
    expect(h.serviceLog(job.id).last, contains('reason="speech_busy"'));
    expect(h.workers, isEmpty);
    h.resources.release(reservation);
    await until(() => h.workers.length == 1);
    expect(h.workers.single.received!['text'], 'after release');
    h.workers.single.finished.complete({});
    await until(() => h.service.job(job.id)!.state == SpeechJobState.completed);
  });

  test('restart interrupts all pending states without re-executing', () async {
    final asset = await h.model();
    for (final state in [
      SpeechJobState.queued,
      SpeechJobState.waiting,
      SpeechJobState.running,
      SpeechJobState.cancelling,
    ]) {
      await h.service.repository.saveJob(
        SpeechJob(
          id: state.name,
          state: state,
          createdAt: DateTime.now(),
          snapshot: {'assetId': asset.id, 'kind': 'tts'},
        ),
      );
    }
    await SpeechRepository(h.db).recover();
    final jobs = await h.service.repository.jobs();
    expect(jobs.length, 4);
    expect(jobs.every((j) => j.state == SpeechJobState.interrupted), isTrue);
    expect(h.workers, isEmpty);
  });

  test(
    'explicit retry creates another job with the original parameters',
    () async {
      final asset = await h.model();
      final job = await h.service.enqueue(
        asset: asset,
        text: 'retry me',
        speed: 1.2,
      );
      await until(() => h.workers.length == 1);
      h.workers.single.finished.completeError(StateError('model error'));
      await until(() => h.service.job(job.id)!.state == SpeechJobState.failed);
      final retried = await h.service.retry(h.service.job(job.id)!);
      expect(retried.id, isNot(job.id));
      expect(retried.snapshot['speed'], 1.2);
      expect(retried.snapshot['text'], 'retry me');
      await until(() => h.workers.length == 2);
      h.workers.last.finished.complete({});
      await until(
        () => h.service.job(retried.id)!.state == SpeechJobState.completed,
      );
    },
  );
}
