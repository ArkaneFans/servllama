/// Parses the stdout of `llama-server --list-devices`:
///
/// ```
/// Available devices:
///   Vulkan0: NVIDIA GeForce RTX 4070 Laptop GPU (7948 MiB, 7180 MiB free)
/// ```
class LlamaDeviceListParser {
  const LlamaDeviceListParser._();

  static const String _sectionHeader = 'Available devices:';

  // Device descriptions may themselves contain parentheses ("Adreno (TM)
  // 750"), so the memory suffix is anchored to the end of the line.
  static final RegExp _deviceLine = RegExp(
    r'^\s+(\S+): .+ \(\d+ MiB, \d+ MiB free\)\s*$',
  );

  /// Returns the device ids usable as `--device` values, in listed order.
  /// Lines outside the header section or not matching the known format are
  /// ignored, so interleaved log output cannot produce phantom devices.
  static List<String> parse(String output) {
    final devices = <String>[];
    var inSection = false;
    for (final rawLine in output.split('\n')) {
      final line = rawLine.endsWith('\r')
          ? rawLine.substring(0, rawLine.length - 1)
          : rawLine;
      if (!inSection) {
        inSection = line.trim() == _sectionHeader;
        continue;
      }
      final match = _deviceLine.firstMatch(line);
      if (match != null) {
        devices.add(match.group(1)!);
      }
    }
    return devices;
  }
}
