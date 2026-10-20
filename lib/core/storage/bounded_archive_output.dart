import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Enforces the actual decompressed size, independent of ZIP metadata.
class BoundedArchiveOutput extends OutputStream {
  BoundedArchiveOutput(this.output, this.limit, {this.checkCancelled})
    : super(byteOrder: output.byteOrder);
  final OutputStream output;
  final int limit;
  final void Function()? checkCancelled;
  int _checkedAt = -65536;
  @override
  int get length => output.length;
  @override
  bool get isOpen => output.isOpen;
  void _admit(int count) {
    if (count < 0 || length + count > limit) {
      throw const FormatException('Decompressed file exceeds its size limit');
    }
    if (length + count - _checkedAt >= 65536) {
      checkCancelled?.call();
      _checkedAt = length + count;
    }
  }

  @override
  void writeByte(int value) {
    _admit(1);
    output.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _admit(length ?? bytes.length);
    output.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _admit(stream.length);
    while (!stream.isEOS) {
      final count = stream.length < 65536 ? stream.length : 65536;
      writeBytes(stream.readBytes(count).toUint8List());
    }
  }

  @override
  void flush() => output.flush();
  @override
  Future<void> close() => output.close();
  @override
  void closeSync() => output.closeSync();
  @override
  void clear() => output.clear();
  @override
  Uint8List subset(int start, [int? end]) => output.subset(start, end);
}
