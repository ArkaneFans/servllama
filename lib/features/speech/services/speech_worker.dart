import 'dart:async';
import 'dart:io';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:path/path.dart' as p;
import 'package:crispasr/crispasr.dart' as crisp;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/wave_file.dart';

enum SpeechWorkerStage { loading, ready, releasing, released }

/// A worker that cannot confirm native cleanup must keep its residency lease.
class SpeechCleanupException implements Exception {
  SpeechCleanupException(this.detail);
  final String detail;
  @override
  String toString() =>
      'Native cleanup was not confirmed; restart the app. $detail';
}

/// Owns every native handle within one worker. Cancellation acknowledges only
/// after synchronous FFI returns and all native handles have been released.
class SpeechWorker {
  SendPort? _commands;
  bool _cancelled = false;
  void cancel() {
    _cancelled = true;
    _commands?.send('cancel');
  }

  Future<Map<String, dynamic>> run(
    Map<String, dynamic> snapshot,
    void Function(double) progress, {
    void Function(Map<String, dynamic>)? onCheckpoint,
    void Function(SpeechWorkerStage)? onStage,
  }) async {
    final events = ReceivePort();
    final done = Completer<Map<String, dynamic>>();
    void reportStage(SpeechWorkerStage stage) {
      try {
        onStage?.call(stage);
      } catch (_) {
        // Diagnostic callbacks must not prevent the cleanup acknowledgement.
      }
    }

    Map<String, dynamic>? result;
    String? failure;
    var released = false;
    final sub = events.listen((dynamic event) {
      if (event is SendPort) {
        _commands = event;
        if (_cancelled) _commands!.send('cancel');
      } else if (event is Map && event['stage'] is int) {
        reportStage(SpeechWorkerStage.values[event['stage'] as int]);
      } else if (event is Map && event['progress'] is num) {
        progress((event['progress'] as num).toDouble());
      } else if (event is Map && event['checkpoint'] is Map) {
        onCheckpoint?.call(Map<String, dynamic>.from(event['checkpoint']));
      } else if (event is Map && event['result'] is Map) {
        result = Map<String, dynamic>.from(event['result']);
        released = event['released'] == true;
      } else if (event is Map && event['error'] != null) {
        failure = event['error'].toString();
        released = event['released'] == true;
      } else if (event is List) {
        failure = event.firstOrNull?.toString() ?? 'Speech worker failed';
      } else if (event == null && !done.isCompleted) {
        if (released) reportStage(SpeechWorkerStage.released);
        if (!released) {
          done.completeError(
            SpeechCleanupException(
              failure ?? 'Worker exited without acknowledgement',
            ),
          );
        } else if (failure != null) {
          done.completeError(StateError(failure!));
        } else {
          done.complete(result ?? {'cancelled': true});
        }
      }
    });
    try {
      await Isolate.spawn(
        _entry,
        [events.sendPort, snapshot],
        onExit: events.sendPort,
        onError: events.sendPort,
        errorsAreFatal: true,
      );
      return await done.future;
    } finally {
      _commands = null;
      await sub.cancel();
      events.close();
    }
  }

  static Future<void> _entry(List<Object> args) async {
    final send = args[0] as SendPort,
        j = Map<String, dynamic>.from(args[1] as Map);
    final commands = ReceivePort();
    var cancelled = false;
    commands.listen((m) {
      if (m == 'cancel') cancelled = true;
    });
    send.send(commands.sendPort);
    sherpa.OfflineRecognizer? recognizer;
    sherpa.OfflineTts? tts;
    crisp.CrispasrSession? session;
    WaveWriter? writer;
    Map<String, dynamic>? result;
    String? failure;
    try {
      final manifest = SpeechPackage.fromJson(
        Map<String, dynamic>.from(j['package']),
      );
      final root = j['modelPath'] as String;
      String file(String role) => p.join(root, manifest.config[role] as String);
      await Future<void>.delayed(Duration.zero);
      if (cancelled) {
        result = {'cancelled': true};
        return;
      }
      send.send({'stage': SpeechWorkerStage.loading.index});
      if (manifest.recipe.engine == 'sherpa_onnx') {
        sherpa.initBindings();
        if (manifest.recipe == SpeechRecipe.sherpaWhisper) {
          recognizer = sherpa.OfflineRecognizer(
            sherpa.OfflineRecognizerConfig(
              model: sherpa.OfflineModelConfig(
                whisper: sherpa.OfflineWhisperModelConfig(
                  encoder: file('encoder'),
                  decoder: file('decoder'),
                  language: j['language'] ?? '',
                  task: 'transcribe',
                ),
                tokens: file('tokens'),
                numThreads: 2,
                modelType: 'whisper',
                provider: 'cpu',
              ),
            ),
          );
        } else {
          tts = sherpa.OfflineTts(
            sherpa.OfflineTtsConfig(
              model: sherpa.OfflineTtsModelConfig(
                vits: sherpa.OfflineTtsVitsModelConfig(
                  model: file('model'),
                  tokens: file('tokens'),
                  lexicon: file('lexicon'),
                ),
                numThreads: 2,
                provider: 'cpu',
              ),
              ruleFsts: (manifest.config['rules'] as List? ?? [])
                  .map((v) => p.join(root, v))
                  .join(','),
            ),
          );
          final speaker = j['speaker'] as int? ?? 0;
          if (speaker < 0 || speaker >= tts.numSpeakers) {
            throw FormatException(
              'Speaker must be between 0 and ${tts.numSpeakers - 1} for this model',
            );
          }
        }
      } else {
        session = crisp.CrispasrSession.openWithParams(
          file('model'),
          nThreads: 2,
          useGpu: false,
          backend: manifest.recipe == SpeechRecipe.crispWhisper
              ? 'whisper'
              : 'qwen3-tts',
          libPath: 'libservllama_crispasr.so',
        );
        if (manifest.recipe.canClone) {
          session.setCodecPath(file('codec'));
          final voice = j['voice'] as Map?;
          session.setVoice(
            voice?['path'] as String? ?? file('voice'),
            refText: voice?['referenceText'] as String?,
          );
        }
      }
      send.send({'stage': SpeechWorkerStage.ready.index});
      if (manifest.recipe.kind.name == 'asr') {
        final wave = WaveFile.inspect(File(j['inputPath']));
        final segments = <Map<String, dynamic>>[];
        for (
          var start = 0;
          start < wave.frames;
          start += wave.sampleRate * 25
        ) {
          await Future<void>.delayed(Duration.zero);
          if (cancelled) break;
          final n = math.min(wave.sampleRate * 25, wave.frames - start);
          final pcm = wave.readMono(start, n);
          final offset = start / wave.sampleRate;
          if (recognizer != null) {
            final stream = recognizer.createStream();
            try {
              stream.acceptWaveform(samples: pcm, sampleRate: 16000);
              recognizer.decode(stream);
              final text = recognizer.getResult(stream).text.trim();
              if (text.isNotEmpty) {
                segments.add({
                  'start': offset,
                  'end': offset + n / wave.sampleRate,
                  'text': text,
                });
              }
            } finally {
              stream.free();
            }
          } else {
            final native = session!.transcribe(
              pcm,
              language: (j['language'] as String? ?? '').isEmpty
                  ? null
                  : j['language'] as String,
            );
            for (final s in native) {
              if (s.text.trim().isEmpty) continue;
              segments.add({
                'start': offset + s.start.clamp(0, n / wave.sampleRate),
                'end': offset + s.end.clamp(0, n / wave.sampleRate),
                'text': s.text.trim(),
              });
            }
          }
          send.send({'progress': (start + n) / wave.frames});
          send.send({
            'checkpoint': {
              'text': segments.map((s) => s['text']).join('\n'),
              'segments': segments,
              'duration': wave.seconds,
              'timing': recognizer != null ? 'chunk' : 'native',
            },
          });
        }
        result = {
          'text': segments.map((s) => s['text']).join('\n'),
          'segments': segments,
          'duration': wave.seconds,
          'timing': recognizer != null ? 'chunk' : 'native',
          'cancelled': cancelled,
        };
      } else {
        final text = j['text'] as String;
        final parts = splitText(text);
        var rate = 0;
        for (var i = 0; i < parts.length; i++) {
          await Future<void>.delayed(Duration.zero);
          if (cancelled) break;
          if (tts != null) {
            final audio = tts.generate(
              text: parts[i],
              sid: j['speaker'] as int? ?? 0,
              speed: (j['speed'] as num? ?? 1).toDouble(),
            );
            rate = audio.sampleRate;
            writer ??= WaveWriter(
              File(j['outputPath']),
              rate,
              maxBytes: 64 * 1024 * 1024,
            );
            if (writer.rate != rate) {
              throw StateError('Synthesis sample rate changed');
            }
            writer.add(audio.samples);
          } else {
            final pcm = session!.synthesize(parts[i]);
            rate = session.outputSampleRate;
            if (rate <= 0) {
              throw StateError('Engine did not report its output sample rate');
            }
            writer ??= WaveWriter(
              File(j['outputPath']),
              rate,
              maxBytes: 64 * 1024 * 1024,
            );
            if (writer.rate != rate) {
              throw StateError('Synthesis sample rate changed');
            }
            writer.add(pcm);
          }
          send.send({'progress': (i + 1) / parts.length});
        }
        final produced = writer != null;
        writer?.close();
        writer = null;
        if (produced && session != null) {
          final file = File(j['outputPath']);
          if (file.lengthSync() > 64 * 1024 * 1024) {
            throw StateError(
              'Synthesis output exceeds 64 MiB; split the input text',
            );
          }
          final marked = crisp.CrispasrC2pa.sign(
            file.readAsBytesSync(),
            format: 'audio/wav',
            lib: DynamicLibrary.open('libservllama_crispasr.so'),
          );
          if (marked == null) {
            throw StateError('CrispASR audio provenance signing failed');
          }
          file.writeAsBytesSync(marked, flush: true);
        }
        result = {
          if (produced) 'outputPath': j['outputPath'],
          'sampleRate': rate,
          'cancelled': cancelled,
        };
      }
    } catch (e) {
      failure = e.toString();
    } finally {
      var released = true;
      send.send({'stage': SpeechWorkerStage.releasing.index});
      try {
        writer?.close();
      } catch (e) {
        failure ??= e.toString();
      }
      // One failed cleanup must not skip the other independent handles.
      for (final cleanup in <void Function()>[
        if (recognizer != null) recognizer.free,
        if (tts != null) tts.free,
        if (session != null) session.close,
      ]) {
        try {
          cleanup();
        } catch (e) {
          failure ??= e.toString();
          released = false;
        }
      }
      commands.close();
      // The receiver releases its resource lease only after this acknowledgement.
      send.send(
        failure == null
            ? {
                'result': result ?? {'cancelled': true},
                'released': released,
              }
            : {'error': failure, 'released': released},
      );
    }
  }

  static List<String> splitText(String text) {
    final sentences = text.split(RegExp(r'(?<=[。！？.!?\n])'));
    final out = <String>[];
    for (final sentence in sentences) {
      for (var start = 0; start < sentence.length;) {
        var end = math.min(start + 240, sentence.length);
        if (end < sentence.length &&
            sentence.codeUnitAt(end - 1) >= 0xD800 &&
            sentence.codeUnitAt(end - 1) <= 0xDBFF) {
          end--;
        }
        final s = sentence.substring(start, end).trim();
        if (s.isNotEmpty) out.add(s);
        start = end;
      }
    }
    return out;
  }
}
