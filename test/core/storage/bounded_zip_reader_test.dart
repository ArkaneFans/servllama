import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/storage/bounded_zip_reader.dart';

void main() {
  Uint8List fixture() => Uint8List.fromList(
    ZipEncoder().encode(
      Archive()..add(ArchiveFile.string('file.txt', 'package contents')),
    ),
  );
  Archive read(Uint8List bytes) => readBoundedZip(
    InputMemoryStream(bytes),
    maxEntries: 2,
    maxExpandedBytes: 1024,
  );
  test('ZIP64 directory metadata preserves lazy file contents', () {
    final original = fixture();
    final end = original.length - 22;
    final previous = ByteData.sublistView(original, end);
    final tail = Uint8List(56 + 20 + 22);
    final data = ByteData.sublistView(tail);
    const le = Endian.little;
    data.setUint32(0, ZipDirectory.zip64EocdSignature, le);
    data.setUint64(4, 44, le);
    data.setUint16(12, 45, le);
    data.setUint16(14, 45, le);
    data.setUint64(24, 1, le);
    data.setUint64(32, 1, le);
    data.setUint64(40, previous.getUint32(12, le), le);
    data.setUint64(48, previous.getUint32(16, le), le);
    data.setUint32(56, ZipDirectory.zip64EocdLocatorSignature, le);
    data.setUint64(64, end, le);
    data.setUint32(72, 1, le);
    tail.setRange(76, tail.length, original.sublist(end));
    data.setUint16(84, 0xffff, le);
    data.setUint16(86, 0xffff, le);
    data.setUint32(88, 0xffffffff, le);
    data.setUint32(92, 0xffffffff, le);
    final archive = read(Uint8List.fromList([...original.take(end), ...tail]));
    final output = OutputMemoryStream();
    archive.single.writeContent(output);
    expect(utf8.decode(output.getBytes()), 'package contents');
  });
  test(
    'declared directory counts and byte sizes are bounded before file parsing',
    () {
      for (final offset in [10, 12]) {
        final bytes = fixture();
        final footer = ByteData.sublistView(bytes, bytes.length - 22);
        if (offset == 10) {
          footer.setUint16(8, 1000, Endian.little);
          footer.setUint16(10, 1000, Endian.little);
        } else {
          footer.setUint32(12, 0x7fffffff, Endian.little);
        }
        expect(() => read(bytes), throwsFormatException);
      }
    },
  );
  test('extra central headers cannot hide behind a smaller declared count', () {
    final bytes = Uint8List.fromList(
      ZipEncoder().encode(
        Archive()
          ..add(ArchiveFile.string('one', '1'))
          ..add(ArchiveFile.string('two', '2')),
      ),
    );
    final footer = ByteData.sublistView(bytes, bytes.length - 22);
    footer.setUint16(8, 1, Endian.little);
    footer.setUint16(10, 1, Endian.little);
    expect(() => read(bytes), throwsFormatException);
  });
}
