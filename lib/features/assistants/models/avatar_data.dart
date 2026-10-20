import 'dart:convert';
import 'dart:typed_data';

/// A short text avatar or a bounded PNG thumbnail, stored with its owner.
abstract final class AvatarData {
  static const imagePrefix = 'data:image/png;base64,';
  static const imageSize = 128;
  static const maxImageBytes = 72 * 1024;
  static final maxEncodedLength = imagePrefix.length + maxImageBytes * 4 ~/ 3;

  static bool isImage(String value) => value.startsWith(imagePrefix);

  static Uint8List imageBytes(String value) {
    if (!isImage(value) || value.length > maxEncodedLength) {
      throw const FormatException('Invalid avatar image');
    }
    final bytes = base64Decode(value.substring(imagePrefix.length));
    if (bytes.length < 24 ||
        bytes.length > maxImageBytes ||
        bytes[0] != 0x89 ||
        ascii.decode(bytes.sublist(1, 4), allowInvalid: true) != 'PNG' ||
        ByteData.sublistView(bytes).getUint32(16) != imageSize ||
        ByteData.sublistView(bytes).getUint32(20) != imageSize) {
      throw const FormatException('Invalid avatar thumbnail');
    }
    return bytes;
  }

  static void validate(String value) {
    if (isImage(value)) {
      imageBytes(value);
    } else if (value.length > 64 || value.contains(RegExp(r'[\r\n]'))) {
      throw const FormatException('Invalid text avatar');
    }
  }
}
