import 'package:servllama/core/runtime/resource_coordinator.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/services/audio_io_service.dart';
import 'package:servllama/features/speech/services/wave_file.dart';
import 'package:servllama/features/speech/widgets/audio_input_panel.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_speech_button.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/pages/speech_job_page.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/speech/pages/voice_profiles_page.dart';
import 'package:servllama/features/speech/widgets/speech_job_widgets.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'speech_test_support.dart';

class _ClockAudio extends AudioIoService {
  _ClockAudio(super.root);
  Duration elapsed = Duration.zero;
  @override
  Duration get recordingElapsed => elapsed;
}

class _DraftChat extends ChatProvider {
  final a = ChatSessionRecord(
    id: 'a',
    title: 'Destination A',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final b = ChatSessionRecord(
    id: 'b',
    title: 'Active B',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  int sends = 0, cancellations = 0;
  @override
  List<ChatSessionRecord> get sessions => [a, b];
  @override
  ChatSessionRecord? get selectedSession => b;
  @override
  bool get isSending => true;
  @override
  Future<void> sendMessage(
    String text, {
    List<String>? imageAttachments,
  }) async {
    sends++;
  }

  @override
  void cancelStreaming() {
    cancellations++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SpeechHarness h;
  setUp(() async {
    h = SpeechHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  Widget app(Widget child, {ChatProvider? chat, double scale = 1}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SpeechJobService>.value(value: h.service),
          ChangeNotifierProvider<ChatProvider>.value(value: chat ?? h.chat),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      );

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'TTS stays inline, prevents duplicates and preserves frozen text across tabs',
    (tester) async {
      await tester.runAsync(() async {
        final asset = await h.model();
        await h.service.select(AssetKind.tts, asset.id);
      });
      tallScreen(tester);
      await tester.pumpWidget(
        app(const SpeechPage(initialText: 'Read this exact text')),
      );
      await tester.pumpAndSettle();
      final start = find.byKey(const Key('speech_start_tts'));
      await tester.runAsync(() async {
        await tester.tap(start);
        await until(() => h.workers.isNotEmpty);
        await h.workers.single.started.future;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SpeechJobPage), findsNothing);
      expect(tester.widget<FilledButton>(start).onPressed, isNull);
      expect(h.service.jobs, hasLength(1));
      final id = h.service.jobs.single.id;
      final l = AppLocalizations.of(tester.element(find.byType(SpeechPage)))!;
      await tester.tap(find.text(l.v2Tasks));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Read this exact text'), findsOneWidget);
      await tester.runAsync(() async {
        h.workers.single.finished.complete({
          'outputPath': '${h.directory.path}/output.wav',
          'sampleRate': 22050,
        });
        await until(() => h.service.job(id)!.state == SpeechJobState.completed);
      });
      await tester.tap(find.text(l.v2Tts));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('speech_result_$id')), findsOneWidget);
      expect(find.text(l.v2SpeechAudioResult), findsOneWidget);
      expect(find.text(l.v2ExportWav), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('speech_synthesis_input')),
        'Next task text',
      );
      expect(
        tester
            .widget<SelectableText>(find.byKey(const Key('speech_result_text')))
            .data,
        'Read this exact text',
      );
      expect(find.text(l.v2InputSnapshot), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(const SpeechPage(initialKind: AssetKind.tts)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SpeechJobResult), findsNothing);
      expect(h.service.jobs.single.id, id);
      await tester.tap(find.text(l.v2Tasks));
      await tester.pumpAndSettle();
      expect(find.text('Read this exact text'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'ASR completes inline and edited text reaches task preview and details',
    (tester) async {
      late String input;
      await tester.runAsync(() async {
        final bytes = 'lmgg'.codeUnits;
        final package = SpeechPackage(
          recipe: SpeechRecipe.crispWhisper,
          name: 'Test transcription model',
          revision: 'fixture',
          files: [
            SpeechFile(
              path: 'model.bin',
              bytes: bytes.length,
              sha256: sha256.convert(bytes).toString(),
            ),
          ],
          config: {'model': 'model.bin'},
        );
        final asset = await h.service.models.createAsset(
          package,
          state: 'ready',
        );
        await File('${asset.path}/model.bin').writeAsBytes(bytes);
        await h.service.select(AssetKind.asr, asset.id);
        input = '${h.directory.path}/input.wav';
        final writer = WaveWriter(File(input), 16000);
        writer.add(Float32List(16000));
        writer.close();
      });
      tallScreen(tester);
      await tester.pumpWidget(app(const SpeechPage()));
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(SpeechModelPicker)).dy,
        lessThan(tester.getTopLeft(find.byType(AudioInputPanel)).dy),
      );
      // Supply the result of the native picker; copy/decode/queue remain real.
      tester
          .widget<AudioInputPanel>(find.byType(AudioInputPanel))
          .onChanged(input);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('speech_start_asr')));
        await until(() => h.workers.isNotEmpty);
        await h.workers.single.started.future;
        h.workers.single.finished.complete({'text': 'Original transcript'});
        await until(
          () => h.service.jobs.single.state == SpeechJobState.completed,
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(SpeechJobPage), findsNothing);
      expect(h.service.jobs.single.state, SpeechJobState.completed);
      final l = AppLocalizations.of(tester.element(find.byType(SpeechPage)))!;
      await tester.ensureVisible(find.text(l.v2EditTranscript));
      await tester.tap(find.text(l.v2EditTranscript));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('speech_transcript_editor')),
        'Reviewed transcript',
      );
      await tester.runAsync(() async {
        await tester.tap(find.text(l.commonSave));
        await until(() => h.service.jobs.single.text == 'Reviewed transcript');
      });
      await tester.pumpAndSettle();
      expect(find.text(l.v2InsertTranscript), findsOneWidget);
      await tester.tap(find.text(l.v2Tasks));
      await tester.pumpAndSettle();
      final job = h.service.jobs.single;
      expect(find.text('Reviewed transcript'), findsOneWidget);
      expect(find.textContaining(speechJobDate(job)), findsOneWidget);
      await tester.tap(find.text('Reviewed transcript'));
      await tester.pumpAndSettle();
      expect(find.byType(SpeechJobPage), findsOneWidget);
      expect(find.text('Reviewed transcript'), findsOneWidget);
      expect(find.textContaining(l.v2SpeechCreatedAt), findsOneWidget);
      expect(find.text(l.v2InputSnapshot), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(const SpeechPage()));
      await tester.pumpAndSettle();
      expect(find.byType(SpeechJobResult), findsNothing);
      expect(h.service.jobs.single.text, 'Reviewed transcript');
      await tester.tap(find.text(l.v2Tasks));
      await tester.pumpAndSettle();
      expect(find.text('Reviewed transcript'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('voice preview synthesizes inline without closing the editor', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = 'GGUF'.codeUnits;
      final asset = await h.service.models.createAsset(
        SpeechPackage(
          recipe: SpeechRecipe.crispQwenTts,
          name: 'Clone fixture',
          revision: 'fixture',
          files: [
            SpeechFile(
              path: 'model.gguf',
              bytes: bytes.length,
              sha256: sha256.convert(bytes).toString(),
            ),
          ],
          config: {
            'model': 'model.gguf',
            'codec': 'model.gguf',
            'voice': 'model.gguf',
          },
        ),
        state: 'ready',
      );
      await File('${asset.path}/model.gguf').writeAsBytes(bytes);
      final input = File('${h.directory.path}/voice.wav');
      final writer = WaveWriter(input, 16000);
      writer.add(Float32List(16000 * 3));
      writer.close();
      await h.service.createVoice(
        asset: asset,
        name: 'My voice',
        input: input.path,
        referenceText: 'Reference transcript',
        rightsConfirmed: true,
      );
    });
    tallScreen(tester);
    await tester.pumpWidget(app(const VoiceProfilesPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My voice'));
    await tester.pumpAndSettle();
    final input = find.byKey(const Key('voice_preview_input'));
    await tester.enterText(input, 'Voice audition text');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('voice_save_preview')));
      await until(() => h.workers.isNotEmpty);
      await h.workers.single.started.future;
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('voice_save_preview')))
          .onPressed,
      isNull,
    );
    expect(find.byType(SpeechJobPage), findsNothing);
    await tester.runAsync(() async {
      h.workers.single.finished.complete({
        'outputPath': '${h.directory.path}/preview.wav',
        'sampleRate': 24000,
      });
      await until(
        () => h.service.jobs.single.state == SpeechJobState.completed,
      );
    });
    await tester.pumpAndSettle();
    expect(input, findsOneWidget);
    expect(find.byKey(const Key('speech_result_text')), findsOneWidget);
    expect(
      tester
          .widget<SelectableText>(find.byKey(const Key('speech_result_text')))
          .data,
      'Voice audition text',
    );
    expect(find.byType(SpeechJobPage), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failure retries inline with new ID and cancellation keeps the form',
    (tester) async {
      await tester.runAsync(() async {
        final asset = await h.model();
        await h.service.select(AssetKind.tts, asset.id);
      });
      tallScreen(tester);
      await tester.pumpWidget(
        app(const SpeechPage(initialText: 'Retry original text')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('speech_start_tts')));
        await until(() => h.workers.isNotEmpty);
        await h.workers.single.started.future;
        h.workers.single.finished.completeError(StateError('Fixture failure'));
        await until(() => h.service.jobs.single.state == SpeechJobState.failed);
      });
      await tester.pumpAndSettle();
      final oldId = h.service.jobs.single.id;
      final l = AppLocalizations.of(tester.element(find.byType(SpeechPage)))!;
      await tester.ensureVisible(find.text(l.v2RetrySpeech));
      await tester.runAsync(() async {
        await tester.tap(find.text(l.v2RetrySpeech));
        await until(() => h.workers.length == 2);
        await h.workers.last.started.future;
      });
      await tester.pump();
      final nextId = h.service.jobs.first.id;
      expect(nextId, isNot(oldId));
      expect(h.service.jobs.first.snapshot['text'], 'Retry original text');
      expect(find.byType(SpeechJobPage), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('speech_start_tts')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text(l.v2CancelTask));
      await tester.runAsync(() async {
        await tester.tap(find.text(l.v2CancelTask));
        await until(() => h.workers.last.cancellationRequested);
        h.workers.last.finished.complete({'cancelled': true});
        await until(
          () => h.service.job(nextId)!.state == SpeechJobState.cancelled,
        );
      });
      await tester.pumpAndSettle();
      expect(find.byType(SpeechPage), findsOneWidget);
      expect(find.byKey(ValueKey('speech_result_$nextId')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'recording clock reads elapsed time and stops ticking after stop',
    (tester) async {
      final audio = _ClockAudio(h.directory)..recording = true;
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        app(Scaffold(body: RecordingClock(audio: audio))),
      );
      expect(find.text('00:00'), findsOneWidget);
      audio.elapsed = const Duration(seconds: 65);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:05'), findsOneWidget);
      audio.recording = false;
      await tester.pumpWidget(
        app(Scaffold(body: RecordingClock(audio: audio))),
      );
      audio.elapsed = const Duration(seconds: 90);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('01:05'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('speech empty states fit 360 dp, dark mode and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const SpeechPage(), scale: 1.6));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(SpeechPage)))!;
    expect(find.text(l.v2Speech), findsOneWidget);
    expect(find.text(l.v2ImportAudio), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.v2Tts));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(l.v2Tasks));
    await tester.pumpAndSettle();
    expect(find.text(l.v2NoSpeechJobs), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('speech residency explains waiting without an LLM stop action', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final asset = await h.model();
      h.resources.tryAcquire(
        kind: LocalResourceKind.tts,
        assetId: 'other-speech',
        owner: 'fixture',
      );
      final job = await h.service.enqueue(asset: asset, text: 'after release');
      await until(() => h.service.job(job.id)!.state == SpeechJobState.waiting);
    });
    expect(h.service.hasWaitingJobs, isTrue);
    await tester.pumpWidget(app(const Scaffold(body: SpeechWaitCard())));
    final l = AppLocalizations.of(tester.element(find.byType(SpeechWaitCard)))!;
    expect(find.text(l.v2SpeechWaitingHelp), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SpeechWaitCard),
        matching: find.byType(TextButton),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'approximate ASR chunk timing offers TXT without misleading SRT',
    (tester) async {
      final job = SpeechJob(
        id: 'result',
        state: SpeechJobState.completed,
        createdAt: DateTime(2026),
        snapshot: {
          'assetId': 'a',
          'kind': 'asr',
          'package': {'name': 'Whisper'},
          'revision': 'test',
        },
        result: {
          'text': 'Recognized text',
          'timing': 'chunk',
          'segments': [
            {'start': 0, 'end': 25, 'text': 'Recognized text'},
          ],
        },
      );
      h.service.jobs = [job];
      await tester.pumpWidget(app(SpeechJobPage(id: job.id)));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(SpeechJobPage)),
      )!;
      expect(find.text(l.v2ExportTxt), findsOneWidget);
      expect(find.text(l.v2ExportSrt), findsNothing);
      expect(find.text(l.v2ChunkTimingHelp), findsOneWidget);
    },
  );

  for (final replace in [false, true]) {
    testWidgets(
      replace
          ? 'stale transcript replacement keeps both drafts'
          : 'transcript append uses the chosen latest draft without stopping a Run',
      (tester) async {
        final chat = _DraftChat();
        addTearDown(chat.dispose);
        chat.updateDraft('reviewed draft', key: 'a');
        chat.updateDraft('keep active B', key: 'b');
        final job = SpeechJob(
          id: 'asr',
          state: SpeechJobState.completed,
          createdAt: DateTime(2026),
          snapshot: {'assetId': 'model', 'kind': 'asr', 'conversationId': 'a'},
          result: {'text': 'transcript'},
        );
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => AppScaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => runUiAction(
                      context,
                      () => insertTranscript(context, job),
                    ),
                    child: const Text('Insert'),
                  ),
                ),
              ),
            ),
            chat: chat,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Insert'));
        await tester.pumpAndSettle();
        expect(find.text('Destination A'), findsOneWidget);
        chat.updateDraft('new latest draft', key: 'a');
        final l = AppLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        )!;
        await tester.tap(
          find.text(replace ? l.v2ReplaceDraft : l.v2AppendDraft),
        );
        await tester.pumpAndSettle();
        expect(
          chat.draftFor('a'),
          replace ? 'new latest draft' : 'new latest draft\ntranscript',
        );
        expect(chat.currentDraft, 'keep active B');
        expect(chat.selectedSession!.id, 'b');
        expect(chat.sends, 0);
        expect(chat.cancellations, 0);
        if (replace) {
          expect(find.textContaining(l.v2DraftChanged), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
