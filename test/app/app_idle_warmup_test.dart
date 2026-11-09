import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/app_idle_warmup.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';

void main() {
  Widget host({
    required ValueNotifier<bool> ready,
    required List<StartupTask> tasks,
    FutureOr<void> Function()? onReady,
    ValueNotifier<bool>? busy,
  }) => MaterialApp(
    builder: (context, child) => AppIdleWarmup(
      ready: ready,
      createTasks: () async => tasks,
      onReady: onReady,
      activity: busy,
      isBusy: () => busy?.value ?? false,
      child: child!,
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(body: Center(child: Text('route'))),
              ),
            ),
            child: const Text('home ready'),
          ),
        ),
      ),
    ),
  );

  Future<void> frames(WidgetTester tester, [int count = 4]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('waits for readiness and first paint, then runs serially once', (
    tester,
  ) async {
    final ready = ValueNotifier(false);
    final first = Completer<void>();
    final calls = <String>[];
    var backgrounds = 0;
    await tester.pumpWidget(
      host(
        ready: ready,
        onReady: () => backgrounds++,
        tasks: [
          StartupTask('first', () {
            calls.add('first');
            return first.future;
          }),
          StartupTask('second', () async {
            calls.add('second');
          }),
        ],
      ),
    );
    await frames(tester);
    expect(calls, isEmpty);
    ready.value = true;
    await tester.pump();
    expect(find.text('home ready'), findsOneWidget);
    expect(backgrounds, 1);
    expect(calls, isEmpty);
    await frames(tester);
    expect(calls, ['first']);
    first.complete();
    await frames(tester);
    expect(calls, ['first', 'second']);
    await frames(tester);
    expect(backgrounds, 1);
    expect(calls, ['first', 'second']);
    await tester.pumpWidget(const SizedBox());
    ready.dispose();
  });

  testWidgets(
    'busy domains defer warmup but do not abandon background startup',
    (tester) async {
      final ready = ValueNotifier(true), busy = ValueNotifier(true);
      var backgrounds = 0, calls = 0;
      await tester.pumpWidget(
        host(
          ready: ready,
          busy: busy,
          onReady: () => backgrounds++,
          tasks: [
            StartupTask('cache', () async {
              calls++;
            }),
          ],
        ),
      );
      await frames(tester);
      expect(backgrounds, 1);
      expect(calls, 0);
      busy.value = false;
      await frames(tester);
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      ready.dispose();
      busy.dispose();
    },
  );

  testWidgets(
    'pause defers the next task; resume does not repeat successful work',
    (tester) async {
      final ready = ValueNotifier(true);
      final pending = Completer<void>();
      final calls = <int>[];
      await tester.pumpWidget(
        host(
          ready: ready,
          tasks: [
            StartupTask('first', () {
              calls.add(1);
              return pending.future;
            }),
            StartupTask('second', () async {
              calls.add(2);
            }),
          ],
        ),
      );
      await frames(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      pending.complete();
      await frames(tester);
      expect(calls, [1]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await frames(tester);
      expect(calls, [1, 2]);
      await tester.pumpWidget(const SizedBox());
      ready.dispose();
    },
  );

  testWidgets(
    'optional failure does not block later tasks or affect the route',
    (tester) async {
      final ready = ValueNotifier(true);
      var calls = 0;
      await tester.pumpWidget(
        host(
          ready: ready,
          tasks: [
            StartupTask('broken', () async {
              throw StateError('fixture');
            }),
            StartupTask('next', () async {
              calls++;
            }),
          ],
        ),
      );
      await frames(tester, 8);
      expect(find.text('home ready'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      ready.dispose();
    },
  );
}
