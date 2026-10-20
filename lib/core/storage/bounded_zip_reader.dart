import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Checks headers before decompressing anything. ZipDecoder eagerly expands
/// symlink contents and collapses duplicate names, so package importers use the
/// lower-level directory API and keep file contents lazy until bounded output.
Archive readBoundedZip(
  InputStream input, {
  required int maxEntries,
  required int maxExpandedBytes,
}) {
  final headers = _readHeaders(input, maxEntries);
  final names = <String>{};
  final archive = Archive();
  var expanded = 0;
  for (final header in headers) {
    final file = header.file;
    final type = (header.externalFileAttributes >> 16) & 0xf000;
    if (file == null ||
        file.filename != header.filename ||
        header.diskNumberStart != 0 ||
        (header.generalPurposeBitFlag & 1) != 0 ||
        (file.flags & 1) != 0 ||
        !const [0, 8].contains(header.compressionMethod) ||
        !const [0, 0x4000, 0x8000].contains(type)) {
      throw const FormatException(
        'ZIP links, special files or encryption are not supported',
      );
    }
    final name = header.filename.replaceAll(r'\', '/');
    if (!names.add(name.toLowerCase())) {
      throw const FormatException('Duplicate ZIP path');
    }
    expanded += header.uncompressedSize;
    if (header.uncompressedSize < 0 || expanded > maxExpandedBytes) {
      throw const FormatException('Expanded package exceeds its size limit');
    }
    final entry = name.endsWith('/')
        ? ArchiveFile.directory(name)
        : ArchiveFile.file(name, header.uncompressedSize, file);
    entry.compression = file.compressionMethod;
    archive.add(entry);
  }
  return archive;
}

/// ZipDirectory.read builds every header before returning. Bound both the
/// directory metadata and the actual header count before asking the library
/// to parse local headers or file contents (including ZIP64 model packages).
List<ZipFileHeader> _readHeaders(InputStream input, int maxEntries) {
  final length = input.position + input.length;
  ByteData bytes(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > length) {
      throw const FormatException('Truncated ZIP metadata');
    }
    return ByteData.sublistView(
      input.subset(position: offset, length: count).toUint8List(),
    );
  }

  const le = Endian.little;
  final tailLength = length.clamp(0, 65535 + 22);
  final tail = bytes(length - tailLength, tailLength);
  var end = -1;
  for (var i = tailLength - 22; i >= 0; i--) {
    if (tail.getUint32(i, le) == ZipDirectory.eocdSignature &&
        i + 22 + tail.getUint16(i + 20, le) == tailLength) {
      end = length - tailLength + i;
      break;
    }
  }
  if (end < 0) throw const FormatException('Missing ZIP end record');
  final footer = bytes(end, 22);
  if (footer.getUint16(4, le) != 0 ||
      footer.getUint16(6, le) != 0 ||
      footer.getUint16(8, le) != footer.getUint16(10, le)) {
    throw const FormatException('Multidisk ZIP is not supported');
  }
  var count = footer.getUint16(10, le);
  var size = footer.getUint32(12, le);
  var start = footer.getUint32(16, le);
  var boundary = end;
  if (end >= 20) {
    final locator = bytes(end - 20, 20);
    if (locator.getUint32(0, le) == ZipDirectory.zip64EocdLocatorSignature) {
      if (locator.getUint32(4, le) != 0 || locator.getUint32(16, le) != 1) {
        throw const FormatException('Multidisk ZIP64 is not supported');
      }
      boundary = locator.getUint64(8, le);
      final record = bytes(boundary, 56);
      if (record.getUint32(0, le) != ZipDirectory.zip64EocdSignature ||
          record.getUint64(4, le) < 44 ||
          record.getUint64(4, le) > 1024 ||
          boundary + 12 + record.getUint64(4, le) != end - 20 ||
          record.getUint32(16, le) != 0 ||
          record.getUint32(20, le) != 0 ||
          record.getUint64(24, le) != record.getUint64(32, le)) {
        throw const FormatException('Invalid ZIP64 end record');
      }
      count = record.getUint64(32, le);
      size = record.getUint64(40, le);
      start = record.getUint64(48, le);
    }
  }
  if (count < 1 ||
      count > maxEntries ||
      size < 46 ||
      size > maxEntries * 8192 ||
      start < 0 ||
      start + size != boundary) {
    throw const FormatException('Invalid or oversized ZIP directory');
  }
  final headers = <ZipFileHeader>[];
  var position = start;
  for (var i = 0; i < count; i++) {
    final fixed = bytes(position, 46);
    final nameLength = fixed.getUint16(28, le);
    final extraLength = fixed.getUint16(30, le);
    final commentLength = fixed.getUint16(32, le);
    final recordSize = 46 + nameLength + extraLength + commentLength;
    if (fixed.getUint32(0, le) != ZipFileHeader.signature ||
        nameLength > 1024 ||
        extraLength > 4096 ||
        commentLength > 1024 ||
        position + recordSize > start + size) {
      throw const FormatException('Invalid ZIP file metadata');
    }
    final header = ZipFileHeader()
      ..read(input.subset(position: position + 4, length: recordSize - 4));
    final local = bytes(header.localHeaderOffset, 30);
    final localNameLength = local.getUint16(26, le);
    final localExtraLength = local.getUint16(28, le);
    final localSize =
        30 + localNameLength + localExtraLength + header.compressedSize;
    final type = (header.externalFileAttributes >> 16) & 0xf000;
    if (local.getUint32(0, le) != 0x04034b50 ||
        header.compressedSize < 0 ||
        (local.getUint16(6, le) & 1) != 0 ||
        header.generalPurposeBitFlag != local.getUint16(6, le) ||
        header.compressionMethod != local.getUint16(8, le) ||
        !const [0, 8].contains(header.compressionMethod) ||
        !const [0, 0x4000, 0x8000].contains(type) ||
        localNameLength > 1024 ||
        localExtraLength > 4096 ||
        header.localHeaderOffset + localSize > start) {
      throw const FormatException('Invalid ZIP local header');
    }
    header.file = ZipFile(header)
      ..read(
        input.subset(
          position: header.localHeaderOffset,
          length: start - header.localHeaderOffset,
        ),
      );
    headers.add(header);
    position += recordSize;
  }
  if (position != start + size) {
    throw const FormatException('ZIP entry count does not match its directory');
  }
  return headers;
}
