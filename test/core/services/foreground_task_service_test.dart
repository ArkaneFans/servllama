import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/foreground_task_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'overlapping owners serialize transitions and keep a remaining task alive',
    () async {
      final service = ForegroundTaskService()..init();
      var running = false, starts = 0, stops = 0;
      final started = Completer<void>(), continueStart = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('flutter_foreground_task/methods'),
            (call) async {
              switch (call.method) {
                case 'isRunningService':
                  return running;
                case 'startService':
                  starts++;
                  started.complete();
                  await continueStart.future;
                  running = true;
                  return null;
                case 'stopService':
                  stops++;
                  running = false;
                  return null;
                default:
                  return null;
              }
            },
          );
      final chat = service.acquire(
        owner: 'chat',
        notificationTitle: 'Chat',
        notificationText: 'active',
      );
      await started.future;
      final speech = service.acquire(
        owner: 'speech',
        notificationTitle: 'Speech',
        notificationText: 'active',
      );
      final releaseChat = service.release('chat');
      continueStart.complete();
      expect(await chat, isTrue);
      expect(await speech, isTrue);
      await releaseChat;
      expect(starts, 1);
      expect(stops, 0);
      expect(running, isTrue);
      expect(await service.release('speech'), isTrue);
      expect(stops, 1);
    },
  );
}
