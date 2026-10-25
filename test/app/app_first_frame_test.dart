import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/app/bootstrap/app_startup_gate.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';

import '../support/app_startup_fixture.dart';

void main() {
  Widget host({
    required Future<bool> Function() pendingMigration,
    required BootstrapInitializer bootstrap,
    required Future<void> Function(BuildContext) prepare,
  }) => BootstrapGate(
    hasPendingMigration: pendingMigration,
    initialize: bootstrap,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppStartupGate(
        initialize: prepare,
        child: const Text('Business ready'),
      ),
    ),
  );

  testWidgets(
    'prepared app sends its business first frame without a launch hold',
    (tester) async {
      final fixture = AppStartupFixture();
      await fixture.startup.prepare();
      await tester.pumpWidget(ServLlamaApp(startup: fixture.startup));
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.byType(MainScaffold), findsOneWidget);
      expect(
        tester.element(find.byType(MainScaffold)).read<ChatProvider>(),
        same(fixture.chat),
      );
      expect(find.byType(MigrationFlowView), findsNothing);
      expect(find.byType(AppStartupGate), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(fixture.chat.draftLoads, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'app displays a captured snapshot failure without restarting preparation',
    (tester) async {
      final fixture = AppStartupFixture();
      fixture.assistants.fail = true;
      await expectLater(fixture.startup.prepare(), throwsStateError);
      await tester.pumpWidget(ServLlamaApp(startup: fixture.startup));
      await tester.pumpAndSettle();
      expect(fixture.assistants.reconciliationModes, [false]);
      expect(find.byType(MainScaffold), findsNothing);
      expect(find.byType(AppStartupGate), findsOneWidget);
      expect(tester.binding.sendFramesToEngine, isTrue);
      fixture.assistants.fail = false;
      final l = AppLocalizations.of(
        tester.element(find.byType(AppStartupGate)),
      )!;
      await tester.tap(find.text(l.v2RetryStartup));
      await tester.pumpAndSettle();
      expect(fixture.assistants.reconciliationModes, [false, false]);
      expect(find.byType(MainScaffold), findsOneWidget);
      expect(fixture.chat.currentAssistantId, 'a');
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('migration choice is visible before admission', (tester) async {
    var initialized = false;
    await tester.pumpWidget(
      host(
        pendingMigration: () async => true,
        bootstrap: (_, {required skipLegacyImport}) async {
          initialized = true;
        },
        prepare: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byKey(const Key('migration_start')), findsOneWidget);
    expect(find.text('Business ready'), findsNothing);
    expect(initialized, isFalse);
  });

  testWidgets('visible migration keeps progress during business preparation', (
    tester,
  ) async {
    final snapshots = Completer<void>();
    await tester.pumpWidget(
      host(
        pendingMigration: () async => true,
        bootstrap: (_, {required skipLegacyImport}) async {},
        prepare: (_) => snapshots.future,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('migration_start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('migration_start_using')));
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(MigrationFlowView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Business ready'), findsNothing);
    snapshots.complete();
    await tester.pumpAndSettle();
    expect(find.text('Business ready'), findsOneWidget);
  });

  testWidgets('explicit startup retry keeps progress visible', (tester) async {
    final retry = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      host(
        pendingMigration: () async => false,
        bootstrap: (_, {required skipLegacyImport}) {
          if (++attempts == 1) return Future.error(StateError('fixture'));
          return retry.future;
        },
        prepare: (_) async {},
      ),
    );
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(MigrationFlowView)),
    )!;
    await tester.tap(find.text(l.v2RetryStartup));
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(MigrationFlowView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Business ready'), findsOneWidget);
  });

  for (final failure in ['migration_check', 'admission', 'snapshots']) {
    testWidgets(
      '$failure failure remains visible and retryable without a frame hold',
      (tester) async {
        var fail = true;
        await tester.pumpWidget(
          host(
            pendingMigration: () async {
              if (failure == 'migration_check' && fail) {
                throw StateError('fixture');
              }
              return false;
            },
            bootstrap: (_, {required skipLegacyImport}) async {
              if (failure == 'admission' && fail) throw StateError('fixture');
            },
            prepare: (_) async {
              if (failure == 'snapshots' && fail) throw StateError('fixture');
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.binding.sendFramesToEngine, isTrue);
        expect(find.byType(MigrationFlowView), findsOneWidget);
        expect(find.text('Business ready'), findsNothing);
        final l = AppLocalizations.of(
          tester.element(find.byType(MigrationFlowView)),
        )!;
        fail = false;
        await tester.tap(find.text(l.v2RetryStartup));
        await tester.pumpAndSettle();
        expect(find.text('Business ready'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
