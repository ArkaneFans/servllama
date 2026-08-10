import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';

void main() {
  group('ModelDownloadService', () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'servllama-download-test-',
      );
    });

    tearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('commits a file only after length and sha256 pass', () async {
      final bytes = <int>[1, 2, 3, 4, 5];
      final service = ModelDownloadService(dio: _dioFor(bytes));
      final record = DownloadFileRecord(
        remotePath: 'model.gguf',
        fileName: 'model.gguf',
        totalBytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      );

      final file = await service.downloadFile(
        url: 'https://example.test/model.gguf',
        file: record,
        targetDirectory: tempDirectory,
      );

      expect(await file.readAsBytes(), bytes);
      expect(record.completed, isTrue);
      expect(record.receivedBytes, bytes.length);
    });

    test('keeps the part file when sha256 validation fails', () async {
      final bytes = <int>[1, 2, 3, 4, 5];
      final service = ModelDownloadService(dio: _dioFor(bytes));
      final record = DownloadFileRecord(
        remotePath: 'model.gguf',
        fileName: 'model.gguf',
        totalBytes: bytes.length,
        sha256: List<String>.filled(64, '0').join(),
      );

      await expectLater(
        service.downloadFile(
          url: 'https://example.test/model.gguf',
          file: record,
          targetDirectory: tempDirectory,
        ),
        throwsA(
          isA<DownloadException>().having(
            (error) => error.kind,
            'kind',
            DownloadErrorKind.integrity,
          ),
        ),
      );

      expect(
        File(
          '${tempDirectory.path}${Platform.pathSeparator}'
          'model.gguf${ModelDownloadService.partSuffix}',
        ).existsSync(),
        isTrue,
      );
      expect(File('${tempDirectory.path}/model.gguf').existsSync(), isFalse);
      expect(record.completed, isFalse);
    });

    test(
      'uses the completed byte count when response size is unknown',
      () async {
        final bytes = <int>[1, 2, 3, 4, 5];
        final service = ModelDownloadService(
          dio: _dioFor(bytes, headers: const <String, List<String>>{}),
        );
        final record = DownloadFileRecord(
          remotePath: 'model.mnn.weight',
          fileName: 'model.mnn.weight',
          totalBytes: 0,
        );

        await service.downloadFile(
          url: 'https://example.test/model.mnn.weight',
          file: record,
          targetDirectory: tempDirectory,
        );

        expect(record.receivedBytes, bytes.length);
        expect(record.totalBytes, bytes.length);
        expect(record.completed, isTrue);
      },
    );

    test('resumes from the bytes that actually exist on disk', () async {
      final destination = File(
        '${tempDirectory.path}${Platform.pathSeparator}model.gguf',
      );
      final partFile = File(
        '${destination.path}${ModelDownloadService.partSuffix}',
      );
      await partFile.writeAsBytes(<int>[1, 2]);
      final adapter = _RangeAdapter(<int>[3, 4, 5]);
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ModelDownloadService(dio: dio);
      final record = DownloadFileRecord(
        remotePath: 'model.gguf',
        fileName: 'model.gguf',
        totalBytes: 5,
        // Simulate a stale Hive snapshot from before the last disk flush.
        receivedBytes: 1,
      );

      final file = await service.downloadFile(
        url: 'https://example.test/model.gguf',
        file: record,
        targetDirectory: tempDirectory,
      );

      expect(adapter.rangeHeader, 'bytes=2-');
      expect(await file.readAsBytes(), <int>[1, 2, 3, 4, 5]);
      expect(record.receivedBytes, 5);
      expect(record.completed, isTrue);
    });

    test('recovers a file renamed just before process death', () async {
      final bytes = <int>[1, 2, 3, 4, 5];
      final destination = File(
        '${tempDirectory.path}${Platform.pathSeparator}model.gguf',
      );
      await destination.writeAsBytes(bytes);
      final adapter = _NeverFetchAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final service = ModelDownloadService(dio: dio);
      final record = DownloadFileRecord(
        remotePath: 'model.gguf',
        fileName: 'model.gguf',
        totalBytes: bytes.length,
        sha256: sha256.convert(bytes).toString(),
      );

      final file = await service.downloadFile(
        url: 'https://example.test/model.gguf',
        file: record,
        targetDirectory: tempDirectory,
      );

      expect(adapter.fetchCount, 0);
      expect(file.path, destination.path);
      expect(record.receivedBytes, bytes.length);
      expect(record.completed, isTrue);
    });
  });
}

Dio _dioFor(List<int> bytes, {Map<String, List<String>>? headers}) {
  final dio = Dio();
  dio.httpClientAdapter = _BytesAdapter(bytes, headers: headers);
  return dio;
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes, {Map<String, List<String>>? headers})
    : headers =
          headers ??
          <String, List<String>>{
            'content-length': <String>['${bytes.length}'],
          };

  final List<int> bytes;
  final Map<String, List<String>> headers;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(bytes, 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

class _RangeAdapter implements HttpClientAdapter {
  _RangeAdapter(this.remainingBytes);

  final List<int> remainingBytes;
  String? rangeHeader;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    rangeHeader = options.headers['Range'] as String?;
    return ResponseBody.fromBytes(
      remainingBytes,
      206,
      headers: <String, List<String>>{
        'content-range': <String>['bytes 2-4/5'],
        'content-length': <String>['${remainingBytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NeverFetchAdapter implements HttpClientAdapter {
  int fetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;
    throw StateError('network should not be used');
  }

  @override
  void close({bool force = false}) {}
}
