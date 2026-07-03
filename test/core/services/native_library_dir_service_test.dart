import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/native_library_dir_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.arkanefans.servllama/native_libs');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the native library dir and caches it', () async {
    var callCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getNativeLibraryDir');
          callCount++;
          return '/data/app/fake/lib/arm64';
        });

    final service = NativeLibraryDirService(channel: channel);

    expect(await service.getNativeLibraryDir(), '/data/app/fake/lib/arm64');
    expect(await service.getNativeLibraryDir(), '/data/app/fake/lib/arm64');
    expect(callCount, 1);
  });

  test('throws when the platform returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final service = NativeLibraryDirService(channel: channel);

    expect(service.getNativeLibraryDir(), throwsStateError);
  });

  test('throws when the platform returns an empty string', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => '');

    final service = NativeLibraryDirService(channel: channel);

    expect(service.getNativeLibraryDir(), throwsStateError);
  });
}
