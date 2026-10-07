import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:path/path.dart' as p;
import 'package:servllama/features/speech/services/audio_io_service.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/services/wave_file.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('audio import, decode and export log safe lifecycle metadata', () async {
    final root = await Directory.systemTemp.createTemp('private-audio-input-');
    final logger = AppLogger();
    final audio = AudioIoService(root, logger: logger);
    const channel = MethodChannel('com.arkanefans.servllama/file_export');
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      audio.dispose();
      logger.dispose();
      await root.delete(recursive: true);
    });
    final source = File(p.join(root.path, 'private-reference.wav'));
    final writer = WaveWriter(source, 16000);
    writer.add(Float32List(160));
    writer.close();
    final copied = await audio.copyInput(source.path, 'audio-job');
    expect(await audio.decode(copied, 'audio-job'), copied);
    var events = logger.entriesFor(LogChannel.speech);
    expect(events.map((e) => e.message.split(' ').first), [
      'speech.audio.copied',
      'speech.decode.started',
      'speech.decode.completed',
    ]);
    expect(events.last.message, contains('converted=false'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => '/private-export-directory/reference.wav',
        );
    await audio.exportAudio(copied, 'private-voice-name.wav');
    expect(
      logger.entriesFor(LogChannel.speech).last.message,
      'speech.audio.exported',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'export_failed',
            message: 'private-platform-message',
          );
        });
    await expectLater(
      audio.exportAudio(copied, 'private-voice-name.wav'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      audio.decode(p.join(root.path, 'private-missing.wav'), 'missing-job'),
      throwsA(isA<FileSystemException>()),
    );
    events = logger.entriesFor(LogChannel.speech);
    expect(events.last.message, startsWith('speech.decode.failed'));
    expect(events.last.level, LogLevel.error);
    final diagnostic = events.map((e) => e.message).join();
    for (final excluded in [
      root.path,
      'private-platform-message',
      'private-voice-name',
      'private-export-directory',
      'private-missing',
      'private-reference',
    ]) {
      expect(diagnostic, isNot(contains(excluded)));
    }
  });

  test(
    'restart retains the latest unsubmitted recording and never deletes a task input',
    () async {
      final root = await Directory.systemTemp.createTemp('recording-recovery');
      final recordings = await Directory(
        p.join(root.path, 'speech', 'recordings'),
      ).create(recursive: true);
      final old = File(p.join(recordings.path, 'old.wav'));
      final latest = File(p.join(recordings.path, 'latest.wav'));
      for (final f in [old, latest]) {
        final writer = WaveWriter(f, 16000);
        writer.add(Float32List(160));
        writer.close();
      }
      await old.setLastModified(DateTime(2020));
      await latest.setLastModified(DateTime(2026));
      final jobDir = await Directory(
        p.join(root.path, 'speech', 'jobs', 'job'),
      ).create(recursive: true);
      final copy = await old.copy(p.join(jobDir.path, 'input.wav'));
      final audio = AudioIoService(root);
      try {
        await audio.initialize();
        expect(audio.recordingPath, latest.path);
        expect(await old.exists(), isFalse);
        await audio.discardRecording();
        expect(audio.recordingPath, isNull);
        expect(await latest.exists(), isFalse);
        expect(await copy.exists(), isTrue);
      } finally {
        audio.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'read-aloud retains visible link labels and removes code and raw URLs',
    () {
      final result = SpeechJobService.spokenText(
        'Read [the guide](https://example.com).\n~~~python\nsecret code\n~~~\nhttps://example.org',
      );
      expect(result, 'Read the guide.');
    },
  );
}
