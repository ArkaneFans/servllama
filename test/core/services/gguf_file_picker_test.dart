import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/errors/model_operation_exception.dart';
import 'package:servllama/core/services/gguf_file_picker.dart';

void main() {
  group('GgufFilePicker', () {
    test('returns null when user cancels picking', () async {
      final picker = GgufFilePicker(pickFiles: () async => null);

      final result = await picker.pickSingle();

      expect(result, isNull);
    });

    test('returns selected file when gguf file is chosen', () async {
      final picker = GgufFilePicker(
        pickFiles: () async => FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'model.gguf',
            path: 'C:\\models\\model.gguf',
            size: 1024,
          ),
        ]),
      );

      final result = await picker.pickSingle();

      expect(result, isNotNull);
      expect(result!.fileName, 'model.gguf');
      expect(result.path, 'C:\\models\\model.gguf');
    });

    test('rejects non-gguf files after picking', () async {
      final picker = GgufFilePicker(
        pickFiles: () async => FilePickerResult(<PlatformFile>[
          PlatformFile(
            name: 'notes.txt',
            path: 'C:\\models\\notes.txt',
            size: 12,
          ),
        ]),
      );

      expect(
        picker.pickSingle,
        throwsA(
          isA<ModelOperationException>().having(
            (error) => error.code,
            'code',
            ModelOperationErrorCode.unsupportedGgufFile,
          ),
        ),
      );
    });
  });
}
