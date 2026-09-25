import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';

void main() {
  group('parseLlamaCppListDevices', () {
    test('parses OpenCL and Hexagon device names', () {
      const output = '''
ggml_cuda_init: failed
Available devices:
  GPUOpenCL: Adreno (TM) 740 (8192 MiB, 7000 MiB free)
  HTP0: Hexagon (0 MiB, 0 MiB free)
''';
      final result = parseLlamaCppListDevices(output);
      expect(result.openclDeviceName, 'GPUOpenCL');
      expect(result.hexagonDeviceName, 'HTP0');
    });

    test('treats an empty device list as CPU only', () {
      const output = '''
Available devices:
  (none)
''';
      final result = parseLlamaCppListDevices(output);
      expect(result.openclAvailable, isFalse);
      expect(result.hexagonAvailable, isFalse);
    });

    test('ignores unknown GPUs', () {
      const output = '''
Available devices:
  Vulkan0: Some GPU (1024 MiB, 512 MiB free)
''';
      final result = parseLlamaCppListDevices(output);
      expect(result.resolve(LlamaCppBackend.opencl), LlamaCppBackend.cpu);
    });
  });

  group('LlamaCppDeviceProbeResult.resolve', () {
    const both = LlamaCppDeviceProbeResult(
      openclDeviceName: 'GPUOpenCL',
      hexagonDeviceName: 'HTP0',
    );
    const openclOnly = LlamaCppDeviceProbeResult(openclDeviceName: 'GPUOpenCL');

    test('keeps CPU when the selected accelerator is missing', () {
      expect(openclOnly.resolve(LlamaCppBackend.hexagon), LlamaCppBackend.cpu);
      expect(
        LlamaCppDeviceProbeResult.cpuOnly.resolve(LlamaCppBackend.opencl),
        LlamaCppBackend.cpu,
      );
    });

    test('keeps an available explicit choice', () {
      expect(both.resolve(LlamaCppBackend.opencl), LlamaCppBackend.opencl);
      expect(both.resolve(LlamaCppBackend.cpu), LlamaCppBackend.cpu);
    });


  });
}
