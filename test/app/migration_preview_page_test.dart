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
    'preview fails, retries to completion and returns on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.tap(find.byKey(const Key('migration_preview_failure')));
      await tester.pump(const Duration(seconds: 8));
      final l = AppLocalizations.of(
        tester.element(find.byType(MigrationPreviewPage)),
      )!;
      expect(find.text(l.migrationPreviewError), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.ensureVisible(find.text(l.v2RetryStartup));
      await tester.tap(find.text(l.v2RetryStartup));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 13));
      expect(find.text(l.migrationPreviewComplete), findsOneWidget);
      await tester.tap(find.text(l.migrationPreviewReturn));
      await tester.pumpAndSettle();
      expect(find.text('Open preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restart replaces a pending simulation and leaving cancels its timer',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('migration_preview_failure')));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.byKey(const Key('migration_preview_restart')));
      await tester.pump(const Duration(seconds: 8));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Open preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
