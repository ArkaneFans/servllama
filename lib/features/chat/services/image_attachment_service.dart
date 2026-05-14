import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:servllama/core/services/model_storage_paths.dart';

class ImageAttachmentException implements Exception {
  const ImageAttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageAttachmentService {
  ImageAttachmentService({
    ModelStoragePaths? storagePaths,
    FilePicker? filePicker,
    ImagePicker? imagePicker,
  }) : _storagePaths = storagePaths ?? ModelStoragePaths(),
       _filePicker = filePicker,
       _imagePicker = imagePicker;

  static const int maxImagesPerMessage = 5;
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10 MB

  final ModelStoragePaths _storagePaths;
  final FilePicker? _filePicker;
  final ImagePicker? _imagePicker;
  final Random _random = Random();

  Future<List<String>> pickFromGallery({int currentCount = 0}) async {
    final remaining = maxImagesPerMessage - currentCount;
    if (remaining <= 0) {
      throw const ImageAttachmentException(
        '每条消息最多添加5张图片',
        // ignore: unnecessary_string_escapes
      );
    }

    final result = await (_filePicker?.pickFiles() ??
        FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        ));

    if (result == null || result.files.isEmpty) {
      return const [];
    }

    final pickedFiles = result.files;
    if (pickedFiles.length > remaining) {
      throw const ImageAttachmentException(
        '每条消息最多添加5张图片',
      );
    }

    return _processAndCopyFiles(pickedFiles);
  }

  Future<String?> pickFromCamera({int currentCount = 0}) async {
    if (currentCount >= maxImagesPerMessage) {
      throw const ImageAttachmentException(
        '每条消息最多添加5张图片',
      );
    }

    final picker = _imagePicker ?? ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.camera);
    if (xFile == null) {
      return null;
    }

    final file = File(xFile.path);
    final fileSize = await file.length();
    if (fileSize > maxImageSizeBytes) {
      throw const ImageAttachmentException(
        '图片大小不能超过10MB',
      );
    }

    return _copyToAttachmentsDirectory(file);
  }

  void validateCount(int currentCount, int additionalCount) {
    if (currentCount + additionalCount > maxImagesPerMessage) {
      throw const ImageAttachmentException(
        '每条消息最多添加5张图片',
      );
    }
  }

  Future<List<String>> _processAndCopyFiles(
    List<PlatformFile> files,
  ) async {
    final copiedPaths = <String>[];
    for (final file in files) {
      final filePath = file.path;
      if (filePath == null || filePath.isEmpty) {
        continue;
      }

      final sourceFile = File(filePath);
      final fileSize = await sourceFile.length();
      if (fileSize > maxImageSizeBytes) {
        throw const ImageAttachmentException(
          '图片大小不能超过10MB',
        );
      }

      final newPath = await _copyToAttachmentsDirectory(sourceFile);
      copiedPaths.add(newPath);
    }
    return copiedPaths;
  }

  Future<String> _copyToAttachmentsDirectory(File sourceFile) async {
    final attachmentsDir = await _storagePaths.getChatAttachmentsDirectory();
    final extension = _fileExtension(sourceFile.path);
    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}$extension';
    final targetPath =
        '${attachmentsDir.path}${Platform.pathSeparator}$fileName';
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex >= path.length - 1) {
      return '.jpg';
    }
    return path.substring(dotIndex).toLowerCase();
  }

  static String mimeTypeForPath(String path) {
    final extension = path.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}
