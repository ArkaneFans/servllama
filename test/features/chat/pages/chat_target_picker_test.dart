import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'chat picker uses the library query and hides old deleted registrations',
    (tester) async {
      final db = AppDatabase.memory();
      final catalog = UnifiedModelRepository(database: db);
      final assistants = AssistantProvider(
        repository: AssistantRepository(db),
        models: catalog,
      );
      addTearDown(assistants.dispose);
      addTearDown(db.close);
      await tester.runAsync(() async {
        for (final state in ['ready', 'missing']) {
          await catalog.saveAsset(
            ModelAsset(
              id: state,
              kind: AssetKind.llm,
              engine: 'mnn',
              runtimeId: state,
              storageOwner: 'mnn_engine',
              path: '/missing/$state',
              name: state == 'ready' ? 'Available model' : 'Deleted model',
              revision: 'local',
              state: state,
            ),
          );
        }
        await assistants.load();
        expect(
          assistants.assets.map((a) => a.id),
          (await catalog.listModels()).map((m) => m.id),
        );
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: assistants,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ChatTargetPicker()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Available model'), findsOneWidget);
      expect(find.text('Deleted model'), findsNothing);
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('chat_target_local_ready')),
            )
            .enabled,
        isTrue,
      );
    },
  );
}
