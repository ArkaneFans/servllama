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
  });
}

Dio _dioFor(List<int> bytes) {
  final dio = Dio();
  dio.httpClientAdapter = _BytesAdapter(bytes);
  return dio;
}

class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes);

  final List<int> bytes;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: <String, List<String>>{
        'content-length': <String>['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
