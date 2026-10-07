import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';

enum AvatarImageFailure { tooLarge, invalidImage }

class AvatarImageException implements Exception {
  const AvatarImageException(this.reason);
  final AvatarImageFailure reason;
}

class AvatarImageService {
  AvatarImageService({FilePicker? picker}) : _picker = picker;
  final FilePicker? _picker;
  static const maxInputBytes = 10 * 1024 * 1024;
  static const maxPixels = 32 * 1000 * 1000;

  Future<String?> pick() async {
    final result = await (_picker ?? FilePicker.platform).pickFiles(
      type: FileType.image,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > maxInputBytes) {
      throw const AvatarImageException(AvatarImageFailure.tooLarge);
    }
    final stream =
        file.readStream ??
        (file.path == null ? null : File(file.path!).openRead());
    if (stream == null) {
      if (file.bytes != null) return normalize(file.bytes!);
      throw const AvatarImageException(AvatarImageFailure.invalidImage);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > maxInputBytes) {
        throw const AvatarImageException(AvatarImageFailure.tooLarge);
      }
      bytes.add(chunk);
    }
    return normalize(bytes.takeBytes());
  }

  Future<String> normalize(Uint8List bytes) async {
    if (bytes.length > maxInputBytes) {
      throw const AvatarImageException(AvatarImageFailure.tooLarge);
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? source, thumbnail;
    ui.Picture? picture;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width, height = descriptor.height;
      if (width > 8192 || height > 8192 || width * height > maxPixels) {
        throw const AvatarImageException(AvatarImageFailure.tooLarge);
      }
      // Decode close to display size, even for unusually wide/tall images.
      final scale = math.min(
        AvatarData.imageSize / math.min(width, height),
        1024 / math.max(width, height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (width * scale).round()),
        targetHeight: math.max(1, (height * scale).round()),
      );
      source = (await codec.getNextFrame()).image;
      final edge = math.min(source.width, source.height).toDouble();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        source,
        ui.Rect.fromLTWH(
          (source.width - edge) / 2,
          (source.height - edge) / 2,
          edge,
          edge,
        ),
        const ui.Rect.fromLTWH(0, 0, 128, 128),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      picture = recorder.endRecording();
      thumbnail = await picture.toImage(
        AvatarData.imageSize,
        AvatarData.imageSize,
      );
      final png = (await thumbnail.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      final value = '${AvatarData.imagePrefix}${base64Encode(png)}';
      AvatarData.validate(value);
      return value;
    } on AvatarImageException {
      rethrow;
    } catch (_) {
      throw const AvatarImageException(AvatarImageFailure.invalidImage);
    } finally {
      thumbnail?.dispose();
      picture?.dispose();
      source?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
