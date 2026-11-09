import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'local catalog groups models by engine and search selects their asset ID',
    (tester) async {
      final database = AppDatabase.memory();
      final catalog = UnifiedModelRepository(database: database);
      final assistants = AssistantProvider(
        repository: AssistantRepository(database),
        models: catalog,
      );
      addTearDown(assistants.dispose);
      addTearDown(database.close);
      await tester.runAsync(() async {
        for (final engine in ['llama_cpp', 'mnn']) {
          await catalog.saveAsset(
            ModelAsset(
              id: engine,
              kind: AssetKind.llm,
              engine: engine,
              runtimeId: '$engine-model',
              storageOwner: 'app',
              path: '/models/$engine',
              name: engine == 'mnn' ? 'Qwen MNN' : 'Llama GGUF',
              revision: 'local',
            ),
          );
        }
        await assistants.load();
      });
      ChatTarget? selected;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: assistants,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    selected = await showChatTargetPicker(context);
                  },
                  child: const Text('Choose model'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose model'));
      await tester.pumpAndSettle();
      expect(find.text('Llama GGUF'), findsOneWidget);
      expect(find.text('Qwen MNN'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('chat_target_search')),
        'Qwen',
      );
      await tester.pump();
      expect(find.text('Llama GGUF'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat_target_local_mnn')));
      await tester.pumpAndSettle();
      expect(selected?.assetId, 'mnn');
    },
  );
}
