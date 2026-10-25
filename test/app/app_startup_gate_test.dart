import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/app_startup_gate.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Widget host(Future<void> Function(BuildContext) initialize) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AppStartupGate(
      initialize: initialize,
      child: const Text('local snapshots ready'),
    ),
  );

  testWidgets('business routes open together, only after local preparation', (
    tester,
  ) async {
    final local = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      host((_) {
        calls++;
        return local.future;
      }),
    );
    await tester.pump();
    expect(find.text('local snapshots ready'), findsNothing);
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('local snapshots ready'), findsNothing);
    local.complete();
    await tester.pumpAndSettle();
    expect(find.text('local snapshots ready'), findsOneWidget);
    expect(calls, 1);
  });

  testWidgets('failed preparation stays closed and is retryable', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host((_) async {
        if (++calls == 1) throw StateError('fixture');
      }),
    );
    await tester.pump();
    expect(find.text('local snapshots ready'), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(AppStartupGate)))!;
    await tester.tap(find.text(l.v2RetryStartup));
    await tester.pump();
    expect(find.text('local snapshots ready'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('captured pre-runApp failure waits for explicit retry', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppStartupGate(
          initialError: StateError('fixture pre-runApp failure'),
          initialize: (_) async {
            calls++;
          },
          child: const Text('ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.text('ready'), findsNothing);
    final l = AppLocalizations.of(tester.element(find.byType(AppStartupGate)))!;
    await tester.tap(find.text(l.v2RetryStartup));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('ready'), findsOneWidget);
  });
}
