import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/controllers/chat_checkpoint_writer.dart';

void main() {
  test(
    'fast deltas coalesce and terminal flush persists the latest snapshot',
    () async {
      final writer = ChatCheckpointWriter(interval: const Duration(seconds: 1));
      final saved = <int>[];
      for (var i = 0; i < 100; i++) {
        final value = i;
        writer.add(() async {
          saved.add(value);
        });
      }
      expect(saved, isEmpty);
      await writer.flush();
      expect(saved, [99]);
    },
  );

  test(
    'flush waits for the in-flight write then saves only the latest pending one',
    () async {
      final writer = ChatCheckpointWriter(interval: Duration.zero);
      final started = Completer<void>(), release = Completer<void>();
      final saved = <int>[];
      writer.add(() async {
        started.complete();
        await release.future;
        saved.add(0);
      });
      await started.future;
      for (var i = 1; i <= 10; i++) {
        final value = i;
        writer.add(() async {
          saved.add(value);
        });
      }
      final flush = writer.flush();
      expect(saved, isEmpty);
      release.complete();
      await flush;
      expect(saved, [0, 10]);
    },
  );

  test('background persistence failures reach the terminal flush', () async {
    final writer = ChatCheckpointWriter(interval: Duration.zero);
    final attempted = Completer<void>();
    writer.add(() async {
      attempted.complete();
      throw StateError('fixture disk failure');
    });
    await attempted.future;
    await expectLater(writer.flush(), throwsStateError);
  });
}
