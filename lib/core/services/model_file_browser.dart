import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class ModelFileEntry {
  const ModelFileEntry({required this.path, required this.isDirectory});
  final String path;
  final bool isDirectory;
  String get name => p.basename(path);
}

class SelectedModelPath {
  const SelectedModelPath({
    required this.path,
    required this.name,
    this.sizeBytes = 0,
  });
  final String path;
  final String name;
  final int sizeBytes;
}

/// Browses real paths, never SAF documents or file_picker's cached copies.
class ModelFileBrowser {
  static const _channel = MethodChannel(
    'com.arkanefans.servllama/model_storage',
  );

  Future<String?> requestAccess() =>
      _channel.invokeMethod<String>('requestAccess');

  Future<List<ModelFileEntry>> list(
    String directoryPath, {
    required bool directoriesOnly,
  }) async {
    final entries = <ModelFileEntry>[];
    await for (final entity in Directory(
      directoryPath,
    ).list(followLinks: false)) {
      final isDirectory = entity is Directory;
      if (isDirectory ||
          (!directoriesOnly &&
              entity is File &&
              entity.path.toLowerCase().endsWith('.gguf'))) {
        entries.add(
          ModelFileEntry(path: entity.path, isDirectory: isDirectory),
        );
      }
    }
    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return entries;
  }

  Future<SelectedModelPath> select(ModelFileEntry entry) async {
    var size = 0;
    if (!entry.isDirectory) {
      try {
        size = (await File(entry.path).stat()).size;
        if (size < 0) size = 0;
      } on FileSystemException {
        // Size is display metadata, not a gate on registering an external path.
      }
    }
    return SelectedModelPath(
      path: entry.path,
      name: entry.name,
      sizeBytes: size,
    );
  }
}
