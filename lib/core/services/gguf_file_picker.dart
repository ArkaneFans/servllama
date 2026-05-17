import 'package:file_picker/file_picker.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';

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
    return _pickSingleGguf();
  }

  Future<PickedGgufFile?> pickSingleMmproj() async {
    return _pickSingleGguf();
  }

  Future<PickedGgufFile?> _pickSingleGguf() async {
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
      throw const ModelOperationException(
        ModelOperationErrorCode.unsupportedGgufFile,
      );
    }

    final filePath = file.path;
    if (filePath == null || filePath.isEmpty) {
      throw const ModelOperationException(
        ModelOperationErrorCode.selectedFilePathUnavailable,
      );
    }

    return PickedGgufFile(path: filePath, fileName: file.name);
  }

  bool _isGgufFileName(String fileName) =>
      fileName.toLowerCase().endsWith('.gguf');
}
