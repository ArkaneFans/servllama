import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servllama/core/services/app_info_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.arkanefans.mnn_engine/methods');
  late List<String> calls;

  setUp(() {
    calls = [];
    PackageInfo.setMockInitialValues(
      appName: 'ServLlama',
      packageName: 'com.arkanefans.servllama',
      version: '2.0.0',
      buildNumber: '15',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return <String, Object?>{
            'pluginVersion': '0.2.0',
            'mnnVersion': '3.6.1',
            'mnnCommit': 'abcdef123456',
            'abi': 'arm64-v8a',
            'androidApiLevel': 35,
            'ndkVersion': '27.3',
            'nativeLibraryLoaded': true,
            'testRootPath': '/tmp',
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<String> bundledVersion() async {
    final manifest =
        jsonDecode(
              await rootBundle.loadString(
                'assets/bin/llama_server_manifest.json',
              ),
            )
            as Map<String, dynamic>;
    return (manifest['version'] as String).trim();
  }

  testWidgets(
    'reads bundled and platform metadata without starting a runtime',
    (tester) async {
      await tester.runAsync(() async {
        final expectedVersion = await bundledVersion();
        expect(expectedVersion, isNotEmpty);
        final service = AppInfoService();
        final info = await service.load();

        expect(info.app, '2.0.0 / 15');
        expect(info.llamaCpp, expectedVersion);
        expect(info.mnn, '3.6.1 \u00b7 abcdef1234');
        expect(service.cached, same(info));
        expect(calls, ['initialize']);
      });
    },
  );

  testWidgets('coalesces concurrent metadata loads and reuses the snapshot', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final service = AppInfoService();
      final first = service.load();
      final second = service.load();
      expect(second, same(first));

      final info = await first;
      expect(await second, same(info));
      expect(await service.load(), same(info));
      expect(calls, ['initialize']);
    });
  });

  testWidgets('a failed engine label does not discard the other metadata', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          throw PlatformException(code: 'unavailable');
        });
    await tester.runAsync(() async {
      final expectedVersion = await bundledVersion();
      final info = await AppInfoService().load();

      expect(info.app, '2.0.0 / 15');
      expect(info.llamaCpp, expectedVersion);
      expect(info.mnn, '\u2014');
      expect(calls, ['initialize']);
    });
  });
}
