import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';
import 'package:servllama/features/assistants/services/avatar_image_service.dart';
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
