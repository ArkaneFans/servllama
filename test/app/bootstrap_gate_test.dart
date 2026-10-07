import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'migration progress gates business startup and fits narrow screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ready = Completer<void>();
      late void Function(LegacyMigrationProgress) report;
      await tester.pumpWidget(
        BootstrapGate(
          initialize: (callback) {
            report = callback;
            return ready.future;
          },
          child: const MaterialApp(home: Text('Business ready')),
        ),
      );
      report(const LegacyMigrationProgress(LegacyMigrationStage.models));
      await tester.pump();
      final l = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
      expect(find.text(l.v2MigrationTitle), findsOneWidget);
      expect(find.text(l.v2MigrationModels), findsOneWidget);
      expect(find.text('Business ready'), findsNothing);
      report(
        const LegacyMigrationProgress(
          LegacyMigrationStage.writing,
          completed: 3,
          total: 10,
        ),
      );
      await tester.pump();
      expect(find.text(l.v2MigrationRecords(3, 10)), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.3,
      );
      report(const LegacyMigrationProgress(LegacyMigrationStage.complete));
      await tester.pump();
      expect(find.text('Business ready'), findsNothing);
      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text('Business ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a failed migration is visible and retry opens one business context',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        BootstrapGate(
          initialize: (report) async {
            report(
              const LegacyMigrationProgress(LegacyMigrationStage.downloads),
            );
            if (++attempts == 1) {
              throw StateError('fixture storage unavailable');
            }
          },
          child: const MaterialApp(home: Text('Business ready')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Business ready'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.textContaining('fixture storage unavailable'),
        findsOneWidget,
      );
      final l = AppLocalizations.of(tester.element(find.byType(FilledButton)))!;
      await tester.tap(find.text(l.v2RetryStartup));
      await tester.pumpAndSettle();
      expect(find.text('Business ready'), findsOneWidget);
      expect(attempts, 2);
    },
  );
}
