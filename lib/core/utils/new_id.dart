import 'dart:math';

/// RFC 4122 UUID v4, used only for application identities, never model aliases.
String newId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return [
    h.substring(0, 8),
    h.substring(8, 12),
    h.substring(12, 16),
    h.substring(16, 20),
    h.substring(20),
  ].join('-');
}
