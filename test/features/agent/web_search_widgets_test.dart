import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/features/agent/models/web_search.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/web_search_receipt.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class _NoModels extends UnifiedModelRepository {
  @override
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async => [];
}

Widget app(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets(
    'assistant search settings save without losing the tool grant on refresh',
    (tester) async {
      final db = AppDatabase.memory();
      final dir = Directory.systemTemp.createTempSync('web-search-ui');
      final repository = AssistantRepository(db);
      final provider = AssistantProvider(
        repository: repository,
        models: _NoModels(),
      );
      final service = AgentToolService(AgentRepository(db), dir);
      const assistant = Assistant(id: 'a', name: 'Test');
      await repository.saveAssistant(assistant);
      await provider.load();
      addTearDown(() async {
        provider.dispose();
        service.dispose();
        await db.close();
        await dir.delete(recursive: true);
      });
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider.value(value: service),
          ],
          child: app(const AssistantEditor(assistant: assistant)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('webSearchProvider')), findsNothing);
      await tester.scrollUntilVisible(
        find.text('网络搜索'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('网络搜索'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('网络搜索'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('webSearchProvider')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('webSearchProvider')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('webSearchProvider')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DuckDuckGo').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      final saved = (await repository.assistants()).single;
      expect(saved.tools, contains('web_search'));
      expect(saved.webSearch.provider, WebSearchProvider.duckduckgo);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'search receipts expose source links and fit a narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final launches = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        launches.add(call);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        app(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: WebSearchReceipt(
                  payload: {
                    'result': jsonEncode({
                      'provider': 'bing',
                      'items': [
                        const WebSearchItem(
                          title: 'A useful source',
                          url: 'https://docs.example/guide',
                          snippet: 'Source excerpt.',
                        ).toJson(),
                      ],
                    }),
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('搜索来源'), findsOneWidget);
      await tester.tap(find.text('A useful source'));
      await tester.pumpAndSettle();
      expect(launches.single.arguments['url'], 'https://docs.example/guide');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'blocked and empty search results have distinct localized messages',
    (tester) async {
      await tester.pumpWidget(
        app(const WebSearchReceipt(payload: {'searchFailure': 'challenge'})),
      );
      expect(find.textContaining('要求验证'), findsOneWidget);
      await tester.pumpWidget(
        app(
          WebSearchReceipt(
            payload: {
              'result': jsonEncode({'provider': 'bing', 'items': []}),
            },
          ),
        ),
      );
      expect(find.textContaining('没有匹配的网页结果'), findsOneWidget);
      await tester.pumpWidget(
        app(
          const WebSearchReceipt(
            payload: {'result': 'old or incomplete format'},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
