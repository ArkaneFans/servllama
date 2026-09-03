import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/downloads_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.arkanefans.servllama/file_export');

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('downloads_export');
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('sends the temp file to Android Downloads', () async {
    late String sourcePath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'saveToDownloads');
          final args = Map<String, Object?>.from(call.arguments as Map);
          sourcePath = args['sourcePath']! as String;
          expect(args['fileName'], 'servllama-logs.txt');
          expect(args['mimeType'], 'text/plain');
          expect(File(sourcePath).existsSync(), isTrue);
          expect(File(sourcePath).readAsStringSync(), 'hello logs');
          return '/storage/emulated/0/Download/servllama-logs.txt';
        });

    final service = DownloadsExportService(
      channel: channel,
      temporaryDirectory: () async => tempDir,
      platform: TargetPlatform.android,
    );

    final path = await service.saveTextFile(
      fileName: 'servllama-logs.txt',
      content: 'hello logs',
    );

    expect(path, '/storage/emulated/0/Download/servllama-logs.txt');
    expect(File(sourcePath).existsSync(), isFalse);
  });

  test('throws when Android returns an empty path', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => '');

    final service = DownloadsExportService(
      channel: channel,
      temporaryDirectory: () async => tempDir,
      platform: TargetPlatform.android,
    );

    await expectLater(
      service.saveTextFile(fileName: 'servllama-logs.txt', content: 'x'),
      throwsStateError,
    );
    expect(tempDir.listSync(), isEmpty);
  });

  test('copies to the downloads directory on non-Android platforms', () async {
    final downloadsDir = Directory(
      '${tempDir.path}${Platform.pathSeparator}Download',
    )..createSync();

    final service = DownloadsExportService(
      channel: channel,
      temporaryDirectory: () async => tempDir,
      downloadsDirectory: () async => downloadsDir,
      platform: TargetPlatform.windows,
    );

    final path = await service.saveTextFile(
      fileName: 'servllama-logs.txt',
      content: 'desktop logs',
    );

    expect(
      path,
      '${downloadsDir.path}${Platform.pathSeparator}servllama-logs.txt',
    );
    expect(File(path).readAsStringSync(), 'desktop logs');
    expect(
      File(
        '${tempDir.path}${Platform.pathSeparator}servllama-logs.txt',
      ).existsSync(),
      isFalse,
    );
  });
}
