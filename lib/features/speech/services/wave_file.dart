import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Bounded PCM access. Audio files are never expanded into a full-file buffer.
class WaveFile {
  WaveFile._(
    this.file,
    this.sampleRate,
    this.channels,
    this.bits,
    this.format,
    this.offset,
    this.frames,
  );
  final File file;
  final int sampleRate, channels, bits, format, offset, frames;
  double get seconds => frames / sampleRate;
  static WaveFile inspect(File file) {
    final f = file.openSync();
    try {
      final length = f.lengthSync();
      if (length < 44) throw const FormatException('Truncated WAV');
      final header = f.readSync(12);
      if (String.fromCharCodes(header.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(header.sublist(8, 12)) != 'WAVE') {
        throw const FormatException('Expected PCM WAV');
      }
      final riffEnd =
          ByteData.sublistView(header).getUint32(4, Endian.little) + 8;
      if (riffEnd < 44 || riffEnd > length) {
        throw const FormatException('Invalid RIFF size');
      }
      int? rate,
          channels,
          bits,
          format,
          blockAlign,
          byteRate,
          dataOffset,
          dataLength;
      while (f.positionSync() + 8 <= riffEnd) {
        final h = f.readSync(8);
        final id = String.fromCharCodes(h.sublist(0, 4));
        final size = ByteData.sublistView(h).getUint32(4, Endian.little);
        final position = f.positionSync();
        if (position + size > riffEnd) {
          throw const FormatException('Truncated WAV chunk');
        }
        if (id == 'fmt ') {
          if (format != null) {
            throw const FormatException('Multiple WAV formats');
          }
          if (size < 16) throw const FormatException('Invalid WAV format');
          final b = ByteData.sublistView(f.readSync(16));
          format = b.getUint16(0, Endian.little);
          channels = b.getUint16(2, Endian.little);
          rate = b.getUint32(4, Endian.little);
          byteRate = b.getUint32(8, Endian.little);
          blockAlign = b.getUint16(12, Endian.little);
          bits = b.getUint16(14, Endian.little);
        } else if (id == 'data') {
          if (dataOffset != null) {
            throw const FormatException('Multiple WAV data chunks');
          }
          dataOffset = position;
          dataLength = size;
        }
        f.setPositionSync(position + size + (size.isOdd ? 1 : 0));
      }
      if (rate == null ||
          channels == null ||
          bits == null ||
          dataOffset == null ||
          dataLength == null ||
          rate < 8000 ||
          rate > 192000 ||
          channels < 1 ||
          channels > 8 ||
          !(format == 1 && bits == 16 || format == 3 && bits == 32)) {
        throw const FormatException('Only PCM16 or float32 WAV is supported');
      }
      final stride = channels * (bits ~/ 8);
      if (blockAlign != stride || byteRate != rate * stride) {
        throw const FormatException('Invalid WAV block alignment or byte rate');
      }
      if (dataLength % stride != 0) {
        throw const FormatException('Incomplete WAV frame');
      }
      final result = WaveFile._(
        file,
        rate,
        channels,
        bits,
        format!,
        dataOffset,
        dataLength ~/ stride,
      );
      if (result.seconds <= 0 || result.seconds > 10800) {
        throw const FormatException(
          'Audio duration must be between 0 and 3 hours',
        );
      }
      return result;
    } finally {
      f.closeSync();
    }
  }

  Float32List readMono(int start, int count, {int targetRate = 16000}) {
    if (start < 0 || count < 0 || targetRate < 8000 || targetRate > 192000) {
      throw const FormatException('Invalid audio range or sample rate');
    }
    count = math.min(count, frames - start);
    if (count <= 0) return Float32List(0);
    if (count > sampleRate * 31) {
      throw const FormatException('Audio chunk exceeds memory bound');
    }
    final f = file.openSync();
    try {
      // Windowed-sinc low-pass filtering prevents high frequencies from folding
      // into the speech band when downsampling. Read neighboring frames so
      // independently processed chunks have the same filter boundary.
      final cutoff = math.min(1.0, targetRate / sampleRate) * 0.94;
      final radius = targetRate == sampleRate ? 0 : (16 / cutoff).ceil();
      final readStart = math.max(0, start - radius);
      final readEnd = math.min(
        frames,
        start + count + (radius == 0 ? 0 : radius + 1),
      );
      final readCount = readEnd - readStart;
      final stride = channels * (bits ~/ 8);
      f.setPositionSync(offset + readStart * stride);
      final bytes = f.readSync(readCount * stride);
      if (bytes.length != readCount * stride) {
        throw const FormatException('WAV changed during processing');
      }
      final b = ByteData.sublistView(bytes);
      final mono = Float32List(readCount);
      for (var i = 0; i < readCount; i++) {
        var sum = 0.0;
        for (var c = 0; c < channels; c++) {
          final pos = i * stride + c * (bits ~/ 8);
          final sample = format == 1
              ? b.getInt16(pos, Endian.little) / 32768
              : b.getFloat32(pos, Endian.little);
          if (!sample.isFinite) {
            throw const FormatException('Non-finite audio sample');
          }
          sum += sample;
        }
        mono[i] = (sum / channels).clamp(-1.0, 1.0);
      }
      if (targetRate == sampleRate) return mono;
      final first = (start * targetRate / sampleRate).round();
      final last = ((start + count) * targetRate / sampleRate).round();
      final out = Float32List(last - first);
      // Quantized phase coefficients avoid recomputing trigonometric functions
      // for every sample. The 256 phases bound interpolation error to 1/256 frame.
      final filters = <int, Float64List>{};
      for (var i = 0; i < out.length; i++) {
        final pos = (first + i) * sampleRate / targetRate - readStart;
        final base = pos.floor();
        final phase = ((pos - base) * 256).round();
        final weights = filters.putIfAbsent(phase, () {
          final w = Float64List(radius * 2 + 1);
          var total = 0.0;
          for (var tap = -radius; tap <= radius; tap++) {
            final distance = tap - phase / 256;
            if (distance.abs() > radius) continue;
            final x = math.pi * distance * cutoff;
            final sinc = x.abs() < 1e-10 ? 1.0 : math.sin(x) / x;
            final window = 0.5 + 0.5 * math.cos(math.pi * distance / radius);
            w[tap + radius] = sinc * cutoff * window;
            total += w[tap + radius];
          }
          for (var tap = 0; tap < w.length; tap++) {
            w[tap] /= total;
          }
          return w;
        });
        var value = 0.0;
        for (var tap = -radius; tap <= radius; tap++) {
          value +=
              mono[(base + tap).clamp(0, mono.length - 1)] *
              weights[tap + radius];
        }
        out[i] = value.clamp(-1.0, 1.0);
      }
      return out;
    } finally {
      f.closeSync();
    }
  }

  static void normalize(File source, File destination, {int rate = 16000}) {
    final wave = inspect(source);
    final out = WaveWriter(destination, rate);
    try {
      for (var start = 0; start < wave.frames; start += wave.sampleRate * 20) {
        out.add(wave.readMono(start, wave.sampleRate * 20, targetRate: rate));
      }
    } finally {
      out.close();
    }
  }
}

class WaveWriter {
  WaveWriter(File file, this.rate, {this.maxBytes = 512 * 1024 * 1024})
    : _file = file.openSync(mode: FileMode.write) {
    _file.writeFromSync(Uint8List(44));
  }
  final RandomAccessFile _file;
  final int rate;
  final int maxBytes;
  int _bytes = 0;
  bool _closed = false;
  void add(Float32List pcm) {
    if (_closed) throw StateError('WAV already closed');
    if (_bytes + pcm.length * 2 + 44 > maxBytes) {
      throw const FormatException(
        'Audio output limit reached; use shorter text',
      );
    }
    final b = ByteData(pcm.length * 2);
    for (var i = 0; i < pcm.length; i++) {
      if (!pcm[i].isFinite) {
        throw const FormatException('Invalid synthesized sample');
      }
      b.setInt16(
        i * 2,
        (pcm[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little,
      );
    }
    _file.writeFromSync(b.buffer.asUint8List());
    _bytes += b.lengthInBytes;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      final b = ByteData(44);
      void chars(int offset, String value) {
        for (var i = 0; i < value.length; i++) {
          b.setUint8(offset + i, value.codeUnitAt(i));
        }
      }

      chars(0, 'RIFF');
      b.setUint32(4, _bytes + 36, Endian.little);
      chars(8, 'WAVE');
      chars(12, 'fmt ');
      b.setUint32(16, 16, Endian.little);
      b.setUint16(20, 1, Endian.little);
      b.setUint16(22, 1, Endian.little);
      b.setUint32(24, rate, Endian.little);
      b.setUint32(28, rate * 2, Endian.little);
      b.setUint16(32, 2, Endian.little);
      b.setUint16(34, 16, Endian.little);
      chars(36, 'data');
      b.setUint32(40, _bytes, Endian.little);
      _file.setPositionSync(0);
      _file.writeFromSync(b.buffer.asUint8List());
      _file.flushSync();
    } finally {
      _file.closeSync();
    }
  }
}
