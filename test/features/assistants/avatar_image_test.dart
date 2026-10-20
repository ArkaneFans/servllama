import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';
import 'package:servllama/features/assistants/services/avatar_image_service.dart';
import 'package:servllama/features/assistants/widgets/avatar_editor.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const Color(0xff00ff00), BlendMode.src);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 3, height.toDouble()),
    Paint()..color = const Color(0xffff0000),
  );
  canvas.drawRect(
    Rect.fromLTWH(width * 2 / 3, 0, width / 3, height.toDouble()),
    Paint()..color = const Color(0xff0000ff),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class _Picker extends Fake implements FilePicker {
  _Picker(this.result);
  final FilePickerResult? result;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #pickFiles
      ? Future<FilePickerResult?>.value(result)
      : super.noSuchMethod(invocation);
}

class _PendingImage extends AvatarImageService {
  final completion = Completer<String?>();
  @override
  Future<String?> pick() => completion.future;
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'wide input becomes a bounded square PNG cropped at its center',
    () async {
      final value = await AvatarImageService().normalize(await _png(384, 128));
      final png = AvatarData.imageBytes(value);
      expect(png.length, lessThanOrEqualTo(AvatarData.maxImageBytes));
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width, 128);
        expect(image.height, 128);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        // Both corners are green; the red/blue outer thirds were cropped away.
        expect(rgba.sublist(0, 4), [0, 255, 0, 255]);
        expect(rgba.sublist(rgba.length - 4), [0, 255, 0, 255]);
      } finally {
        image.dispose();
        codec.dispose();
      }
    },
  );

  test('cancelled selection leaves the avatar unchanged', () async {
    expect(await AvatarImageService(picker: _Picker(null)).pick(), isNull);
  });

  test(
    'actual stream size is bounded even when picker metadata is wrong',
    () async {
      final picker = _Picker(
        FilePickerResult([
          PlatformFile(
            name: 'fixture.png',
            size: 1,
            readStream: Stream.fromIterable([
              Uint8List(AvatarImageService.maxInputBytes),
              Uint8List(1),
            ]),
          ),
        ]),
      );
      await expectLater(
        AvatarImageService(picker: picker).pick(),
        throwsA(
          isA<AvatarImageException>().having(
            (e) => e.reason,
            'reason',
            AvatarImageFailure.tooLarge,
          ),
        ),
      );
    },
  );

  test(
    'damaged images and excessive dimensions fail with bounded reasons',
    () async {
      final service = AvatarImageService();
      await expectLater(
        service.normalize(Uint8List.fromList([1, 2, 3])),
        throwsA(
          isA<AvatarImageException>().having(
            (e) => e.reason,
            'reason',
            AvatarImageFailure.invalidImage,
          ),
        ),
      );
      await expectLater(
        service.normalize(await _png(8193, 1)),
        throwsA(
          isA<AvatarImageException>().having(
            (e) => e.reason,
            'reason',
            AvatarImageFailure.tooLarge,
          ),
        ),
      );
      expect(() => AvatarData.validate('🙂'), returnsNormally);
      expect(() => AvatarData.validate('👩🏽‍💻'), returnsNormally);
      expect(
        () => AvatarData.validate(
          '${AvatarData.imagePrefix}${base64Encode([1, 2, 3])}',
        ),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'image selection reports busy and cancellation retains the draft',
    (tester) async {
      final service = _PendingImage();
      var value = '🌿';
      var busy = false;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, update) => AvatarEditor(
              value: value,
              name: 'Fixture',
              service: service,
              onChanged: (v) => update(() => value = v),
              onBusyChanged: (v) => update(() => busy = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('avatar_pick_image')));
      await tester.pump();
      expect(busy, isTrue);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('avatar_pick_image')),
            )
            .onPressed,
        isNull,
      );
      service.completion.complete(null);
      await tester.pumpAndSettle();
      expect(busy, isFalse);
      expect(value, '🌿');
    },
  );

  testWidgets('damaged stored avatar falls back without breaking the page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const IdentityAvatar(
          value: 'data:image/png;base64,broken',
          name: 'ServLlama',
        ),
      ),
    );
    expect(find.text('S'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
