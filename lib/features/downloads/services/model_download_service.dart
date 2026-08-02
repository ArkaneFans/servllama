import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:servllama/features/downloads/models/download_task.dart';

/// Typed download failures. The page layer maps these to localized text.
enum DownloadErrorKind {
  network,
  unauthorized,
  notFound,
  diskFull,
  integrity,
  cancelled,
}

class DownloadException implements Exception {
  const DownloadException(this.kind, {this.detail});

  final DownloadErrorKind kind;
  final String? detail;

  @override
  String toString() => detail ?? kind.name;
}

typedef DownloadProgressCallback =
    void Function(DownloadFileRecord file, int receivedDelta);

/// Streams remote files to disk with HTTP `Range` resume. Both hubs answer
/// `resolve` with a 302 to a CDN that reports `Accept-Ranges: bytes`, so an
/// interrupted transfer restarts from the byte count already on disk rather
/// than from zero.
class ModelDownloadService {
  ModelDownloadService({Dio? dio}) : _dio = dio ?? _defaultDio();

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      // Model files run into gigabytes; a receive timeout would abort long
      // transfers on slow links. The stream's own idle handling covers stalls.
      receiveTimeout: null,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (_) => true,
      responseType: ResponseType.stream,
    ),
  );

  static const String partSuffix = '.part';

  final Dio _dio;

  /// Downloads [file] from [url] into [targetDirectory], resuming from
  /// whatever the matching `.part` file already holds. Returns the committed
  /// file. Cancel by completing [cancelToken].
  Future<File> downloadFile({
    required String url,
    required DownloadFileRecord file,
    required Directory targetDirectory,
    Map<String, String> headers = const <String, String>{},
    CancelToken? cancelToken,
    DownloadProgressCallback? onProgress,
  }) async {
    final relativePath = _safeRelativePath(file.fileName);
    final destination = File(
      '${targetDirectory.path}${Platform.pathSeparator}$relativePath',
    );
    if (await destination.exists() && file.completed) {
      return destination;
    }

    final partFile = File('${destination.path}$partSuffix');
    var alreadyOnDisk = await partFile.exists() ? await partFile.length() : 0;
    if (file.totalBytes > 0 && alreadyOnDisk > file.totalBytes) {
      await partFile.writeAsBytes(const <int>[], flush: true);
      alreadyOnDisk = 0;
    }
    // A stale record (app killed mid-write) must not out-claim the bytes that
    // actually survived on disk, or the Range offset would skip content.
    if (alreadyOnDisk != file.receivedBytes) {
      file.receivedBytes = alreadyOnDisk;
    }

    await destination.parent.create(recursive: true);

    final requestHeaders = <String, String>{
      ...headers,
      if (alreadyOnDisk > 0) 'Range': 'bytes=$alreadyOnDisk-',
    };

    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          headers: requestHeaders,
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (_) => true,
        ),
        cancelToken: cancelToken,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw const DownloadException(DownloadErrorKind.cancelled);
      }
      throw DownloadException(DownloadErrorKind.network, detail: error.message);
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401 || statusCode == 403) {
      throw const DownloadException(DownloadErrorKind.unauthorized);
    }
    if (statusCode == 404) {
      throw const DownloadException(DownloadErrorKind.notFound);
    }
    if (statusCode != 200 && statusCode != 206) {
      throw DownloadException(
        DownloadErrorKind.network,
        detail: 'HTTP $statusCode',
      );
    }

    // The server ignored our Range and is sending the whole file — discard
    // the partial so the appended stream is not corrupt.
    if (alreadyOnDisk > 0 && statusCode == 200) {
      await partFile.writeAsBytes(const <int>[], flush: true);
      alreadyOnDisk = 0;
      file.receivedBytes = 0;
    }

    final declaredLength = _resolveTotalBytes(response.headers, alreadyOnDisk);
    if (declaredLength > 0) {
      file.totalBytes = declaredLength;
    }

    final sink = partFile.openWrite(
      mode: alreadyOnDisk > 0 ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        file.receivedBytes += chunk.length;
        onProgress?.call(file, chunk.length);
      }
      await sink.flush();
    } on FileSystemException catch (error) {
      await sink.close();
      throw DownloadException(
        DownloadErrorKind.diskFull,
        detail: error.message,
      );
    } catch (error) {
      await sink.close();
      if (cancelToken?.isCancelled == true) {
        throw const DownloadException(DownloadErrorKind.cancelled);
      }
      throw DownloadException(
        DownloadErrorKind.network,
        detail: error.toString(),
      );
    }
    await sink.close();

    final actualLength = await partFile.length();
    file.receivedBytes = actualLength;
    if (file.totalBytes > 0 && actualLength != file.totalBytes) {
      throw DownloadException(
        DownloadErrorKind.integrity,
        detail: 'expected ${file.totalBytes} bytes, got $actualLength',
      );
    }
    final expectedSha256 = _normalizeSha256(file.sha256);
    if (expectedSha256 != null) {
      final digest = await sha256.bind(partFile.openRead()).first;
      if (digest.toString().toLowerCase() != expectedSha256) {
        throw const DownloadException(
          DownloadErrorKind.integrity,
          detail: 'sha256 mismatch',
        );
      }
    }

    if (await destination.exists()) {
      await destination.delete();
    }
    await partFile.rename(destination.path);
    file.completed = true;
    return destination;
  }

  /// Total size of the resource, reconstructed from either `Content-Range`
  /// (partial response) or `Content-Length` plus what is already on disk.
  int _resolveTotalBytes(Headers headers, int alreadyOnDisk) {
    final contentRange = headers.value('content-range');
    if (contentRange != null) {
      final total = contentRange.split('/').last.trim();
      final parsed = int.tryParse(total);
      if (parsed != null) {
        return parsed;
      }
    }
    // Hugging Face reports the real blob size here for LFS pointers.
    final linkedSize = int.tryParse(headers.value('x-linked-size') ?? '');
    if (linkedSize != null) {
      return linkedSize;
    }
    final contentLength = int.tryParse(headers.value('content-length') ?? '');
    if (contentLength != null) {
      return contentLength + alreadyOnDisk;
    }
    return 0;
  }

  String? _normalizeSha256(String? value) {
    final normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final withoutPrefix = normalized.startsWith('sha256:')
        ? normalized.substring('sha256:'.length)
        : normalized;
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(withoutPrefix)
        ? withoutPrefix
        : null;
  }

  String _safeRelativePath(String value) {
    final normalized = value.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (normalized.startsWith('/') ||
        segments.isEmpty ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw const DownloadException(
        DownloadErrorKind.integrity,
        detail: 'unsafe file path',
      );
    }
    return segments.join(Platform.pathSeparator);
  }
}
