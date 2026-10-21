import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/core/database/legacy_migration_progress.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  AppLocalizations localizations(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(MigrationFlowView)))!;

  testWidgets(
    'legacy data waits for a choice and completed migration waits for Start using',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ready = Completer<void>();
      late void Function(LegacyMigrationProgress) report;
      final importChoices = <bool>[];
      await tester.pumpWidget(
        BootstrapGate(
          hasPendingMigration: () async => true,
          initialize: (callback, {required skipLegacyImport}) {
            importChoices.add(skipLegacyImport);
            report = callback;
            return ready.future;
          },
          child: const MaterialApp(home: Text('Business ready')),
        ),
      );
      await tester.pump();

      final l = localizations(tester);
      expect(find.text(l.migrationSetupTitle), findsOneWidget);
      expect(find.text(l.migrationStartButton), findsOneWidget);
      expect(find.text(l.migrationSkipFreshButton), findsOneWidget);
      expect(find.text('Business ready'), findsNothing);
      expect(importChoices, isEmpty);

      await tester.tap(find.byKey(const Key('migration_start')));
      await tester.pump();
      expect(importChoices, [false]);

      report(
        const LegacyMigrationProgress(
          LegacyMigrationStage.writing,
          completed: 3,
          total: 10,
        ),
      );
      await tester.pump();
      expect(find.text(l.v2MigrationTitle), findsOneWidget);
      expect(find.text(l.v2MigrationRecords(3, 10)), findsOneWidget);

      ready.complete();
      await tester.pumpAndSettle();
      expect(find.text(l.migrationCompleteTitle), findsOneWidget);
      expect(find.text(l.migrationStartUsing), findsOneWidget);
      expect(find.text('Business ready'), findsNothing);

      await tester.tap(find.byKey(const Key('migration_start_using')));
      await tester.pumpAndSettle();
      expect(find.text('Business ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('relaunch after completed migration opens the app directly', (
    tester,
  ) async {
    final importChoices = <bool>[];
    await tester.pumpWidget(
      BootstrapGate(
        hasPendingMigration: () async => false,
        initialize: (report, {required skipLegacyImport}) async {
          importChoices.add(skipLegacyImport);
        },
        child: const MaterialApp(home: Text('Business ready')),
      ),
    );
    await tester.pumpAndSettle();

    expect(importChoices, [false]);
    expect(find.byType(MigrationFlowView), findsNothing);
    expect(find.text('Business ready'), findsOneWidget);
  });

  testWidgets('skipping migration confirms and starts without importing', (
    tester,
  ) async {
    final importChoices = <bool>[];
    await tester.pumpWidget(
      BootstrapGate(
        hasPendingMigration: () async => true,
        initialize: (report, {required skipLegacyImport}) async {
          importChoices.add(skipLegacyImport);
        },
        child: const MaterialApp(home: Text('Business ready')),
      ),
    );
    await tester.pump();
    final l = localizations(tester);

    await tester.tap(find.byKey(const Key('migration_skip')));
    await tester.pumpAndSettle();
    expect(find.text(l.migrationSkipFreshTitle), findsOneWidget);
    expect(importChoices, isEmpty);

    await tester.tap(find.text(l.migrationSkipFreshConfirm));
    await tester.pumpAndSettle();
    expect(importChoices, [true]);
    expect(find.text('Business ready'), findsOneWidget);
  });

  testWidgets('a failed migration remains retryable and can be skipped', (
    tester,
  ) async {
    final importChoices = <bool>[];
    await tester.pumpWidget(
      BootstrapGate(
        hasPendingMigration: () async => true,
        initialize: (report, {required skipLegacyImport}) async {
          importChoices.add(skipLegacyImport);
          if (!skipLegacyImport) {
            report(const LegacyMigrationProgress(LegacyMigrationStage.models));
            throw StateError('fixture migration unavailable');
          }
        },
        child: const MaterialApp(home: Text('Business ready')),
      ),
    );
    await tester.pump();
    final l = localizations(tester);

    await tester.tap(find.byKey(const Key('migration_start')));
    await tester.pumpAndSettle();
    expect(find.text(l.migrationFailedTitle), findsOneWidget);
    expect(
      find.textContaining('fixture migration unavailable'),
      findsOneWidget,
    );
    expect(find.text(l.migrationRetryButton), findsOneWidget);
    expect(find.text(l.migrationSkipFreshButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('migration_failed_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.migrationSkipFreshConfirm));
    await tester.pumpAndSettle();

    expect(importChoices, [false, true]);
    expect(find.text('Business ready'), findsOneWidget);
  });

  testWidgets('fresh startup opens directly and a startup failure can retry', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      BootstrapGate(
        hasPendingMigration: () async => false,
        initialize: (report, {required skipLegacyImport}) async {
          attempts++;
          if (attempts == 1) {
            throw StateError('fixture startup unavailable');
          }
        },
        child: const MaterialApp(home: Text('Business ready')),
      ),
    );
    await tester.pumpAndSettle();

    final l = localizations(tester);
    expect(find.text('Business ready'), findsNothing);
    expect(find.text(l.migrationStartupFailedTitle), findsOneWidget);
    expect(find.byKey(const Key('migration_failed_skip')), findsNothing);

    await tester.tap(find.text(l.v2RetryStartup));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Business ready'), findsOneWidget);
  });
}
