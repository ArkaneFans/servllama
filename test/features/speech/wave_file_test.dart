import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/speech/services/wave_file.dart';
import 'package:servllama/features/speech/services/speech_worker.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wave-test-');
  });
  tearDown(() => directory.delete(recursive: true));
  File wave(String name, Float32List pcm, int rate) {
    final file = File('${directory.path}/$name.wav');
    final writer = WaveWriter(file, rate);
    writer.add(pcm);
    writer.close();
    return file;
  }

  test('PCM roundtrip preserves duration without an extra frame', () {
    final f = wave('roundtrip', Float32List.fromList([-.5, 0, .5, 1]), 16000);
    final inspected = WaveFile.inspect(f);
    expect(inspected.frames, 4);
    expect(inspected.seconds, 4 / 16000);
    final pcm = inspected.readMono(0, 4);
    expect(pcm.length, 4);
    expect(pcm[0], closeTo(-.5, .0001));
    expect(pcm[3], closeTo(1, .0001));
  });
  test(
    'band-limited downsampling rejects frequencies above the new Nyquist',
    () {
      Float32List tone(int frequency) => Float32List.fromList(
        List.generate(
          48000,
          (i) => .5 * math.sin(2 * math.pi * frequency * i / 48000),
        ),
      );
      final pass = WaveFile.inspect(
        wave('pass', tone(1000), 48000),
      ).readMono(0, 48000);
      final stop = WaveFile.inspect(
        wave('stop', tone(12000), 48000),
      ).readMono(0, 48000);
      double rms(Float32List x) => math.sqrt(
        x
                .skip(100)
                .take(x.length - 200)
                .map((v) => v * v)
                .reduce((a, b) => a + b) /
            (x.length - 200),
      );
      expect(pass.length, 16000);
      expect(rms(pass), closeTo(.3535, .02));
      expect(rms(stop), lessThan(.01));
    },
  );
  test(
    'chunk boundaries match continuous resampling without duration drift',
    () {
      final signal = Float32List.fromList(
        List.generate(44100, (i) => .4 * math.sin(i / 7)),
      );
      final source = WaveFile.inspect(wave('chunk', signal, 44100));
      final full = source.readMono(0, 44100);
      final chunks = <double>[];
      for (var offset = 0; offset < 44100; offset += 1000) {
        chunks.addAll(source.readMono(offset, math.min(1000, 44100 - offset)));
      }
      expect(chunks.length, full.length);
      for (var i = 0; i < full.length; i++) {
        expect(chunks[i], closeTo(full[i], .00001));
      }
    },
  );
  test('truncated chunks and oversized output fail without a valid result', () {
    final file = wave('broken', Float32List(160), 16000);
    final handle = file.openSync(mode: FileMode.append);
    handle.truncateSync(50);
    handle.closeSync();
    expect(() => WaveFile.inspect(file), throwsFormatException);
    final writer = WaveWriter(
      File('${directory.path}/limit.wav'),
      16000,
      maxBytes: 50,
    );
    expect(() => writer.add(Float32List(10)), throwsFormatException);
    writer.close();
    expect(File('${directory.path}/limit.wav').lengthSync(), 44);
  });
  test('TTS chunking never splits a surrogate pair', () {
    final text = '字' * 239 + '🙂继续。hello!';
    final chunks = SpeechWorker.splitText(text);
    expect(chunks.join(), text);
    expect(chunks.every((p) => !p.runes.contains(0xfffd)), isTrue);
    expect(chunks.every((p) => p.length <= 240), isTrue);
  });
  test('inconsistent RIFF and PCM frame headers are rejected', () {
    for (final offset in [4, 28, 32]) {
      final file = wave('header-$offset', Float32List(160), 16000);
      final bytes = file.readAsBytesSync();
      ByteData.sublistView(bytes).setUint32(offset, 1, Endian.little);
      file.writeAsBytesSync(bytes);
      expect(() => WaveFile.inspect(file), throwsFormatException);
    }
  });
}
