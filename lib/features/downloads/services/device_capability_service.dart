import 'dart:io';

import 'package:servllama/features/downloads/models/model_hub.dart';

/// Whether a given model file is expected to run on this device.
enum ModelFeasibility { comfortable, tight, notEnoughMemory, unknown }

class DeviceMemoryInfo {
  const DeviceMemoryInfo({required this.totalBytes, required this.availableBytes});

  static const DeviceMemoryInfo unknown = DeviceMemoryInfo(
    totalBytes: 0,
    availableBytes: 0,
  );

  final int totalBytes;
  final int availableBytes;

  bool get isKnown => totalBytes > 0;
}

/// Answers "can this phone actually run that model" *before* the download
/// starts, instead of letting the user find out when loading fails.
class DeviceCapabilityService {
  DeviceCapabilityService({File? meminfoFile})
    : _meminfoFile = meminfoFile ?? File('/proc/meminfo');

  /// Weights are memory-mapped, but the KV cache, activations and the
  /// runtime's own allocations sit on top of the file size. Measured on the
  /// bundled builds this lands around a fifth of the weights for the context
  /// sizes this app defaults to.
  static const double runtimeOverheadRatio = 0.20;

  /// Android will start killing background apps well before free memory hits
  /// zero, so a model is only "comfortable" with room to spare.
  static const double comfortableHeadroomRatio = 1.35;

  final File _meminfoFile;
  DeviceMemoryInfo? _cached;

  Future<DeviceMemoryInfo> readMemory() async {
    final cached = _cached;
    if (cached != null) {
      return cached;
    }
    if (!Platform.isAndroid && !Platform.isLinux) {
      return DeviceMemoryInfo.unknown;
    }
    try {
      final lines = await _meminfoFile.readAsLines();
      var total = 0;
      var available = 0;
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          total = _parseKilobytes(line);
        } else if (line.startsWith('MemAvailable:')) {
          available = _parseKilobytes(line);
        }
        if (total > 0 && available > 0) {
          break;
        }
      }
      final info = DeviceMemoryInfo(
        totalBytes: total * 1024,
        availableBytes: available * 1024,
      );
      _cached = info;
      return info;
    } catch (_) {
      return DeviceMemoryInfo.unknown;
    }
  }

  /// Peak resident memory a model of [fileSizeBytes] is expected to need.
  int estimatedPeakBytes(int fileSizeBytes) =>
      (fileSizeBytes * (1 + runtimeOverheadRatio)).round();

  Future<ModelFeasibility> assess(int fileSizeBytes) async {
    if (fileSizeBytes <= 0) {
      return ModelFeasibility.unknown;
    }
    final memory = await readMemory();
    if (!memory.isKnown) {
      return ModelFeasibility.unknown;
    }
    final needed = estimatedPeakBytes(fileSizeBytes);
    if (needed > memory.availableBytes) {
      return ModelFeasibility.notEnoughMemory;
    }
    if (needed * comfortableHeadroomRatio > memory.availableBytes) {
      return ModelFeasibility.tight;
    }
    return ModelFeasibility.comfortable;
  }

  Future<Map<String, ModelFeasibility>> assessAll(
    Iterable<HubRepoFile> files,
  ) async {
    final result = <String, ModelFeasibility>{};
    for (final file in files) {
      result[file.path] = await assess(file.sizeBytes);
    }
    return result;
  }

  /// `MemTotal:       11534336 kB` → 11534336
  int _parseKilobytes(String line) {
    final match = RegExp(r'(\d+)').firstMatch(line);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
