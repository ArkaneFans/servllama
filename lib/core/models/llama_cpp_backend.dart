enum LlamaCppBackend { cpu, opencl, hexagon }

class LlamaCppDeviceProbeResult {
  const LlamaCppDeviceProbeResult({
    this.openclDeviceName,
    this.hexagonDeviceName,
    this.rawOutput = '',
    this.error,
  });

  static const LlamaCppDeviceProbeResult cpuOnly = LlamaCppDeviceProbeResult();

  final String? openclDeviceName;
  final String? hexagonDeviceName;
  final String rawOutput;
  final String? error;

  bool get openclAvailable =>
      openclDeviceName != null && openclDeviceName!.isNotEmpty;
  bool get hexagonAvailable =>
      hexagonDeviceName != null && hexagonDeviceName!.isNotEmpty;

  LlamaCppBackend resolve(LlamaCppBackend selected) {
    final available = switch (selected) {
      LlamaCppBackend.cpu => true,
      LlamaCppBackend.opencl => openclAvailable,
      LlamaCppBackend.hexagon => hexagonAvailable,
    };
    return available ? selected : LlamaCppBackend.cpu;
  }

  String? deviceNameFor(LlamaCppBackend resolved) {
    return switch (resolved) {
      LlamaCppBackend.opencl => openclDeviceName,
      LlamaCppBackend.hexagon => hexagonDeviceName,
      _ => null,
    };
  }
}

LlamaCppDeviceProbeResult parseLlamaCppListDevices(String output) {
  final lines = output.split('\n');
  var listing = false;
  String? openclName;
  String? hexagonName;
  for (final raw in lines) {
    final line = raw.trimRight();
    if (!listing) {
      if (line.contains('Available devices:')) {
        listing = true;
      }
      continue;
    }
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      if (openclName != null || hexagonName != null) {
        break;
      }
      continue;
    }
    if (trimmed == '(none)') {
      break;
    }
    final colon = trimmed.indexOf(':');
    if (colon <= 0) {
      break;
    }
    final name = trimmed.substring(0, colon).trim();
    if (name.isEmpty) {
      continue;
    }
    final upper = name.toUpperCase();
    if (hexagonName == null && upper.startsWith('HTP')) {
      hexagonName = name;
    } else if (openclName == null && upper.contains('OPENCL')) {
      openclName = name;
    }
  }
  return LlamaCppDeviceProbeResult(
    openclDeviceName: openclName,
    hexagonDeviceName: hexagonName,
    rawOutput: output,
  );
}
