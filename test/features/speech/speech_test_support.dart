import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/services/speech_worker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SpeechTestWorker extends SpeechWorker {
  final finished = Completer<Map<String, dynamic>>();
  final started = Completer<void>();
  bool cancellationRequested = false;
  Map<String, dynamic>? received;
  void Function(Map<String, dynamic>)? checkpoint;
  @override
  Future<Map<String, dynamic>> run(
    Map<String, dynamic> snapshot,
    void Function(double) progress, {
    void Function(Map<String, dynamic>)? onCheckpoint,
    void Function(SpeechWorkerStage)? onStage,
  }) async {
    received = snapshot;
    checkpoint = onCheckpoint;
    onStage?.call(SpeechWorkerStage.loading);
    onStage?.call(SpeechWorkerStage.ready);
    started.complete();
    var cleanupConfirmed = true;
    try {
      return await finished.future;
    } catch (error) {
      cleanupConfirmed = error is! SpeechCleanupException;
      rethrow;
    } finally {
      onStage?.call(SpeechWorkerStage.releasing);
      if (cleanupConfirmed) onStage?.call(SpeechWorkerStage.released);
    }
  }

  @override
  void cancel() {
    cancellationRequested = true;
  }
}

class SpeechHarness {
  final logger = AppLogger();
  final db = AppDatabase.memory();
  final resources = ResourceCoordinator();
  final chat = ChatProvider();
  final workers = <SpeechTestWorker>[];
  late Directory directory;
  late SpeechJobService service;
  List<String> serviceLog(String id) => logger
      .entriesFor(LogChannel.speech)
      .where((e) => e.message.contains('job="$id"'))
      .map((e) => e.message)
      .toList();
  Future<void> initialize() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('servllama-speech-');
    service = SpeechJobService(
      resources,
      logger: logger,
      workerFactory: () {
        final worker = SpeechTestWorker();
        workers.add(worker);
        return worker;
      },
    );
    await service.initialize(
      storageRoot: directory,
      database: db,
      configureAudio: false,
    );
    expect(service.ready, isTrue, reason: service.loadError);
  }

  static final fixtureFiles = {
    'model.onnx': [1, 2, 3, 4],
    'tokens.txt': [5, 3, 7],
    'lexicon.txt': [8, 9],
  };
  static SpeechPackage package({String revision = 'fixture'}) => SpeechPackage(
    recipe: SpeechRecipe.sherpaVits,
    name: 'Test voice model',
    revision: revision,
    files: fixtureFiles.entries
        .map(
          (e) => SpeechFile(
            path: e.key,
            bytes: e.value.length,
            sha256: sha256.convert(e.value).toString(),
          ),
        )
        .toList(),
    config: {
      'model': 'model.onnx',
      'tokens': 'tokens.txt',
      'lexicon': 'lexicon.txt',
    },
  );
  Future<ModelAsset> model() async {
    final asset = await service.models.createAsset(package(), state: 'ready');
    for (final e in fixtureFiles.entries) {
      await File(p.join(asset.path, e.key)).writeAsBytes(e.value);
    }
    return asset;
  }

  Future<void> close() async {
    for (final job in service.jobs.where((j) => j.state.active).toList()) {
      await service.cancel(job.id);
    }
    for (final w in workers) {
      if (!w.finished.isCompleted) w.finished.complete({'cancelled': true});
    }
    await until(() => service.jobs.every((j) => !j.state.active));
    await service.settled;
    service.dispose();
    chat.dispose();
    resources.dispose();
    logger.dispose();
    await db.close();
    await directory.delete(recursive: true);
  }
}

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition did not become true');
}
