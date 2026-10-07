import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/storage/bounded_archive_output.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'speech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeechHarness h;
  const storage = MethodChannel(
    'com.arkanefans.servllama/download_environment',
  );
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => 2 * 1024 * 1024 * 1024);
    h = SpeechHarness();
    await h.initialize();
  });
  tearDown(() async {
    await h.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, null);
  });
  Future<File> zip({
    List<ArchiveFile> extra = const [],
    bool corrupt = false,
    bool missing = false,
  }) async {
    final a = Archive()
      ..add(
        ArchiveFile.string(
          'speech-package.json',
          jsonEncode(SpeechHarness.package().toJson()),
        ),
      );
    for (final e in SpeechHarness.fixtureFiles.entries) {
      if (missing && e.key == 'lexicon.txt') continue;
      a.add(
        ArchiveFile.bytes(
          e.key,
          corrupt ? List.filled(e.value.length, 0) : e.value,
        ),
      );
    }
    for (final e in extra) {
      a.add(e);
    }
    return File(
      '${h.directory.path}/package.zip',
    ).writeAsBytes(ZipEncoder().encode(a));
  }

  test(
    'valid package is committed to the unified index after checksum verification',
    () async {
      final asset = await h.service.models.importArchive((await zip()).path);
      expect(asset.isReady, isTrue);
      expect((await h.service.models.models.asset(asset.id))!.path, asset.path);
      await h.service.models.validate(asset);
      final imported = h.logger
          .entriesFor(LogChannel.speech)
          .singleWhere((e) => e.message.startsWith('speech.import.completed'));
      expect(imported.message, contains('asset="${asset.id}"'));
      expect(imported.message, contains('elapsed_ms='));
      await h.service.models.delete(asset);
      expect(await h.service.models.models.asset(asset.id), isNull);
      expect(
        h.logger.entriesFor(LogChannel.speech).last.message,
        startsWith('speech.model.deleted'),
      );
    },
  );
  test('missing dependency never becomes ready', () async {
    await expectLater(
      h.service.models.importArchive((await zip(missing: true)).path),
      throwsFormatException,
    );
    expect(h.service.models.assets.single.state, 'missing');
    final diagnostic = h.logger
        .entriesFor(LogChannel.speech)
        .map((e) => e.message)
        .join();
    expect(diagnostic, contains('speech.import.failed'));
    expect(diagnostic, isNot(contains(h.directory.path)));
    expect(diagnostic, isNot(contains('lexicon.txt')));
  });
  test('same-size corrupt weights fail checksum validation', () async {
    await expectLater(
      h.service.models.importArchive((await zip(corrupt: true)).path),
      throwsStateError,
    );
    expect(h.service.models.assets.single.state, 'missing');
  });
  test(
    'ZIP traversal is rejected before any write outside owned model storage',
    () async {
      final source = await zip(
        extra: [ArchiveFile.string('../outside.txt', 'bad')],
      );
      await expectLater(
        h.service.models.importArchive(source.path),
        throwsFormatException,
      );
      expect(
        await File('${h.service.root.path}/speech/models/outside.txt').exists(),
        isFalse,
      );
    },
  );
  test('ZIP symlinks and case-ambiguous files are rejected', () async {
    var source = await zip(
      extra: [
        ArchiveFile.string('link', '/external')
          ..symbolicLink = '/external'
          ..mode = 0xA1FF,
      ],
    );
    await expectLater(
      h.service.models.importArchive(source.path),
      throwsFormatException,
    );
    source = await zip(extra: [ArchiveFile.string('TOKENS.TXT', 'duplicate')]);
    await expectLater(
      h.service.models.importArchive(source.path),
      throwsFormatException,
    );
  });
  test('import checks space before creating an indexed model', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storage, (_) async => 1);
    await expectLater(
      h.service.models.importArchive((await zip()).path),
      throwsStateError,
    );
    expect(h.service.models.assets, isEmpty);
  });
  test('explicit import cancellation never publishes a ready asset', () async {
    final source = await zip();
    final pending = h.service.models.importArchive(source.path);
    final rejected = expectLater(pending, throwsStateError);
    await h.service.models.cancelImport();
    await rejected;
    expect(h.service.models.assets.where((a) => a.isReady), isEmpty);
    expect(h.service.models.importing, isFalse);
    final events = h.logger.entriesFor(LogChannel.speech);
    expect(
      events.where(
        (e) => e.message.startsWith('speech.import.cancel_requested'),
      ),
      hasLength(1),
    );
    expect(events.last.message, startsWith('speech.import.cancelled'));
    expect(events.last.level, LogLevel.info);
  });

  test(
    'failed download logs diagnostics and leaves a resumable model',
    () async {
      final asset = await h.service.models.createAsset(SpeechHarness.package());
      await expectLater(h.service.models.resume(asset), throwsFormatException);
      final events = h.logger.entriesFor(LogChannel.speech);
      expect(
        events.where((e) => e.message.startsWith('speech.download.started')),
        hasLength(1),
      );
      final failed = events.singleWhere(
        (e) => e.message.startsWith('speech.download.failed'),
      );
      expect(failed.level, LogLevel.error);
      expect(failed.message, contains('asset="${asset.id}"'));
      expect(failed.message, isNot(contains(asset.path)));
      expect((await h.service.models.models.asset(asset.id))!.state, 'paused');
    },
  );
  test(
    'uncompressed writes are bounded by actual bytes, not archive claims',
    () {
      final output = BoundedArchiveOutput(OutputMemoryStream(), 4);
      output.writeBytes([1, 2, 3, 4]);
      expect(() => output.writeByte(5), throwsFormatException);
      expect(output.length, 4);
    },
  );
  test('manifest rejects traversal and case-mismatched dependencies', () {
    final json = SpeechHarness.package().toJson();
    json['files'] = [
      {'path': '../escape', 'bytes': 1, 'sha256': '0' * 64},
    ];
    expect(() => SpeechPackage.fromJson(json), throwsFormatException);
    final bad = SpeechHarness.package().toJson();
    bad['config'] = {
      'model': 'MODEL.ONNX',
      'tokens': 'tokens.txt',
      'lexicon': 'lexicon.txt',
    };
    expect(() => SpeechPackage.fromJson(bad), throwsFormatException);
  });
}
