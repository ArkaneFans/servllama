import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/app/bootstrap/bootstrap_gate.dart';
import 'package:servllama/app/bootstrap/migration_flow_view.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';

import '../support/app_startup_fixture.dart';

void main() {
  Widget host({
    required Future<bool> Function() pendingMigration,
    required BootstrapInitializer bootstrap,
  }) => BootstrapGate(
    hasPendingMigration: pendingMigration,
    initialize: bootstrap,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Text('Business ready'),
    ),
  );

  testWidgets('homepage paints while assistant restoration is blocked', (
    tester,
  ) async {
    final fixture = AppStartupFixture();
    final pending = Completer<void>();
    fixture.assistants.pending = pending;
    await tester.pumpWidget(ServLlamaApp(scope: fixture.scope));
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(MainScaffold), findsOneWidget);
    expect(
      tester.element(find.byType(MainScaffold)).read<ChatProvider>(),
      same(fixture.chat),
    );
    expect(find.byType(MigrationFlowView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fixture.assistants.loaded, isFalse);
    expect(fixture.assistants.reconciliationModes, [false]);
    await tester.pump();
    expect(fixture.downloads.transferModes, [true]);
    expect(fixture.chat.historyLoads, 1);
    fixture.chat.updateDraft('typed before restoration');
    pending.complete();
    await tester.pumpAndSettle();
    expect(fixture.chat.currentAssistantId, 'a');
    expect(fixture.chat.currentDraft, 'typed before restoration');
    expect(fixture.chat.canManageSessions, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage paints while locale restoration is blocked', (
    tester,
  ) async {
    final fixture = AppStartupFixture();
    final pending = Completer<void>();
    fixture.locale.pending = pending;
    await tester.pumpWidget(ServLlamaApp(scope: fixture.scope));
    await tester.pump();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fixture.assistants.loaded, isTrue);
    pending.complete();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('business load failure never closes the homepage', (
    tester,
  ) async {
    final fixture = AppStartupFixture();
    fixture.assistants.fail = true;
    await tester.pumpWidget(ServLlamaApp(scope: fixture.scope));
    await tester.pumpAndSettle();
    expect(find.byType(MainScaffold), findsOneWidget);
    expect(find.byType(MigrationFlowView), findsNothing);
    expect(fixture.chat.canManageSessions, isFalse);
    expect(tester.binding.sendFramesToEngine, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('idle preparation does not initialize whole feature pages', (
    tester,
  ) async {
    final fixture = AppStartupFixture();
    fixture.library.importing = false;
    await tester.pumpWidget(ServLlamaApp(scope: fixture.scope));
    final context = tester.element(find.byType(MainScaffold));
    final speech = context.read<SpeechJobService>();
    final discovery = context.read<ModelDiscoveryProvider>();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(fixture.library.loads, 0);
    expect(speech.ready, isFalse);
    expect(discovery.catalog, isEmpty);
    expect(discovery.searchResults, isEmpty);
    expect(fixture.chat.historyLoads, 1);
    expect(find.byType(MainScaffold), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('migration choice is visible before admission', (tester) async {
    var initialized = false;
    await tester.pumpWidget(
      host(
        pendingMigration: () async => true,
        bootstrap: (_, {required skipLegacyImport}) async {
          initialized = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.sendFramesToEngine, isTrue);
    expect(find.byKey(const Key('migration_start')), findsOneWidget);
    expect(find.text('Business ready'), findsNothing);
    expect(initialized, isFalse);
  });

  testWidgets(
    'migration opens the business UI without an extra snapshot gate',
    (tester) async {
      final snapshots = Completer<void>();
      await tester.pumpWidget(
        host(
          pendingMigration: () async => true,
          bootstrap: (_, {required skipLegacyImport}) => snapshots.future,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('migration_start')));
      await tester.pump();
      await tester.pump();
      expect(tester.binding.sendFramesToEngine, isTrue);
      expect(find.byType(MigrationFlowView), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Business ready'), findsNothing);
      snapshots.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('migration_start_using')));
      await tester.pumpAndSettle();
      expect(find.text('Business ready'), findsOneWidget);
    },
  );

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

  for (final failure in ['migration_check', 'admission']) {
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
