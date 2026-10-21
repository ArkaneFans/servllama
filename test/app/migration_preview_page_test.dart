import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/bootstrap/migration_preview_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MigrationPreviewPage(),
                ),
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'preview uses the migration chooser, failure recovery and completion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(MigrationPreviewPage)),
      )!;

      expect(find.text(l.migrationSetupTitle), findsOneWidget);
      expect(find.text(l.migrationStartButton), findsOneWidget);
      expect(find.text(l.migrationSkipFreshButton), findsOneWidget);

      await tester.tap(find.byTooltip(l.migrationPreviewFailure));
      await tester.pump();
      expect(find.text(l.v2MigrationTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text(l.migrationFailedTitle), findsOneWidget);
      expect(find.text(l.migrationPreviewError), findsOneWidget);
      expect(find.byKey(const Key('migration_failed_skip')), findsOneWidget);

      await tester.tap(find.text(l.migrationRetryButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text(l.migrationCompleteTitle), findsOneWidget);
      expect(find.text(l.migrationStartUsing), findsOneWidget);

      await tester.tap(find.byKey(const Key('migration_start_using')));
      await tester.pumpAndSettle();
      expect(find.text('Open preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restart returns to the chooser and leaving cancels the timer', (
    tester,
  ) async {
    await open(tester);
    final l = AppLocalizations.of(
      tester.element(find.byType(MigrationPreviewPage)),
    )!;

    await tester.tap(find.byKey(const Key('migration_start')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l.v2MigrationTitle), findsOneWidget);

    await tester.tap(find.byTooltip(l.migrationPreviewRestart));
    await tester.pumpAndSettle();
    expect(find.text(l.migrationSetupTitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('migration_start')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 12));
    expect(find.text('Open preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
