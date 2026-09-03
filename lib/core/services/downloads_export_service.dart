import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Saves a text file into the shared Downloads folder on Android, or the
/// platform downloads/documents directory elsewhere.
class DownloadsExportService {
  DownloadsExportService({
    MethodChannel? channel,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? downloadsDirectory,
    TargetPlatform? platform,
  }) : _channel = channel ?? const MethodChannel(_channelName),
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _downloadsDirectory = downloadsDirectory,
       _platform = platform ?? defaultTargetPlatform;

  static const String _channelName = 'com.arkanefans.servllama/file_export';

  final MethodChannel _channel;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function()? _downloadsDirectory;
  final TargetPlatform _platform;

  Future<String> saveTextFile({
    required String fileName,
    required String content,
  }) async {
    final tempDir = await _temporaryDirectory();
    final tempFile = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await tempFile.writeAsString(content, flush: true);
    try {
      if (_platform == TargetPlatform.android) {
        final path = await _channel.invokeMethod<String>('saveToDownloads', {
          'sourcePath': tempFile.path,
          'fileName': fileName,
          'mimeType': 'text/plain',
        });
        if (path == null || path.isEmpty) {
          throw StateError('Downloads directory is unavailable');
        }
        return path;
      }
      final downloads =
          await (_downloadsDirectory?.call() ?? getDownloadsDirectory());
      final targetDir = downloads ?? await getApplicationDocumentsDirectory();
      final target = File(
        '${targetDir.path}${Platform.pathSeparator}$fileName',
      );
      await tempFile.copy(target.path);
      return target.path;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
