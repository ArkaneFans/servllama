import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/utils/gguf_file_name.dart';

void main() {
  group('isGgufFileName', () {
    test('accepts .gguf regardless of path or case', () {
      expect(isGgufFileName('model.gguf'), isTrue);
      expect(isGgufFileName('MODEL.GGUF'), isTrue);
      expect(isGgufFileName(r'C:\models\Qwen.gguf'), isTrue);
    });

    test('rejects non-gguf names', () {
      expect(isGgufFileName('model.bin'), isFalse);
      expect(isGgufFileName('model.gguf.txt'), isFalse);
    });
  });

  group('isMmprojFileName', () {
    test('matches names that contain mmproj and end with .gguf', () {
      expect(isMmprojFileName('mmproj-f16.gguf'), isTrue);
      expect(isMmprojFileName('mmproj.gguf'), isTrue);
      expect(isMmprojFileName('Qwen3.5-0.8B-mmproj-f16.gguf'), isTrue);
      expect(isMmprojFileName('Qwen3.5-0.8B-MMPROJ-F32.GGUF'), isTrue);
      expect(
        isMmprojFileName(r'C:\staging\Qwen3.5-0.8B-mmproj-f16.gguf'),
        isTrue,
      );
    });

    test('rejects gguf files that do not contain mmproj', () {
      expect(isMmprojFileName('projector.gguf'), isFalse);
      expect(isMmprojFileName('Qwen3.5-0.8B-Q4_K_M.gguf'), isFalse);
    });

    test('rejects mmproj names that are not gguf', () {
      expect(isMmprojFileName('Qwen3.5-0.8B-mmproj-f16.bin'), isFalse);
      expect(isMmprojFileName('mmproj-f16.gguf.txt'), isFalse);
    });
  });
}
