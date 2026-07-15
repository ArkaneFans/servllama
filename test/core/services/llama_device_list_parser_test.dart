import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/llama_device_list_parser.dart';

void main() {
  group('LlamaDeviceListParser', () {
    test('parses devices and ignores surrounding shell noise', () {
      const output = '''
PS D:\\LLM\\llama-b9999-bin-win-vulkan-x64> ./llama-server.exe --list-devices
Available devices:
  Vulkan0: NVIDIA GeForce RTX 4070 Laptop GPU (7948 MiB, 7180 MiB free)
  Vulkan1: AMD Radeon 780M Graphics (8086 MiB, 7681 MiB free)
PS D:\\LLM\\llama-b9999-bin-win-vulkan-x64>''';

      expect(
        LlamaDeviceListParser.parse(output),
        <String>['Vulkan0', 'Vulkan1'],
      );
    });

    test('tolerates parentheses inside device descriptions', () {
      const output = '''
Available devices:
  GPUOpenCL: Adreno (TM) 750 (2048 MiB, 1536 MiB free)
  HTP0: Hexagon NPU (v75) (8192 MiB, 8192 MiB free)
''';

      expect(
        LlamaDeviceListParser.parse(output),
        <String>['GPUOpenCL', 'HTP0'],
      );
    });

    test('handles CRLF line endings', () {
      const output =
          'Available devices:\r\n'
          '  Vulkan0: NVIDIA GeForce RTX 4070 Laptop GPU (7948 MiB, 7180 MiB free)\r\n';

      expect(LlamaDeviceListParser.parse(output), <String>['Vulkan0']);
    });

    test('returns empty when the header is missing', () {
      const output = '''
some backend log line
  Vulkan0: NVIDIA GeForce RTX 4070 Laptop GPU (7948 MiB, 7180 MiB free)
''';

      expect(LlamaDeviceListParser.parse(output), isEmpty);
    });

    test('returns empty for a header with no device lines', () {
      expect(LlamaDeviceListParser.parse('Available devices:\n'), isEmpty);
      expect(LlamaDeviceListParser.parse(''), isEmpty);
    });

    test('ignores lines that do not match the device format', () {
      const output = '''
Available devices:
  load_backend: loaded OpenCL backend
  GPUOpenCL: Adreno (TM) 750 (2048 MiB, 1536 MiB free)
  warning: something unrelated
''';

      expect(LlamaDeviceListParser.parse(output), <String>['GPUOpenCL']);
    });
  });
}
