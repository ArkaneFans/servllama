import 'package:file_picker/file_picker.dart';

class PickedGgufFile {
  const PickedGgufFile({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

class GgufFilePicker {
  GgufFilePicker({Future<FilePickerResult?> Function()? pickFiles})
    : _pickFiles = pickFiles;

  final Future<FilePickerResult?> Function()? _pickFiles;

  Future<PickedGgufFile?> pickSingle() async {
    final result =
        await (_pickFiles?.call() ??
            FilePicker.platform.pickFiles(
              type: FileType.any,
              allowMultiple: false,
            ));

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    if (!_isGgufFileName(file.name)) {
      throw StateError('仅支持导入 .gguf 模型文件。');
    }

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      throw StateError('无法获取所选模型文件的路径。');
    }

    return PickedGgufFile(path: filePath, fileName: file.name);
  }

  bool _isGgufFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.gguf');
}
