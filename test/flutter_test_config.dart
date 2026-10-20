import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    if (BindingBase.debugBindingType() == null) return;
    var foregroundRunning = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_foreground_task/methods'),
          (call) async {
            switch (call.method) {
              case 'isRunningService':
                return foregroundRunning;
              case 'startService':
                foregroundRunning = true;
                return null;
              case 'stopService':
                foregroundRunning = false;
                return null;
              default:
                return null;
            }
          },
        );
  });
  await testMain();
}
