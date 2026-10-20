import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/add_connection_sheet.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';

class _Recorder extends AssistantProvider {
  AiConnection? saved;
  String? savedKey;
  _Recorder() {
    loaded = true;
  }
  @override
  Future<void> saveConnection(
    AiConnection c, {
    String? key,
    bool clearKey = false,
  }) async {
    saved = c;
    savedKey = key;
  }
}

void main() {
  late _Recorder provider;
  setUp(() => provider = _Recorder());
  tearDown(() => provider.dispose());

  Widget harness() => MultiProvider(
    providers: [
      ChangeNotifierProvider<AssistantProvider>.value(value: provider),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      navigatorObservers: [AppNavigationObserver()],
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                builder: (_) => const AddConnectionSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> selectProtocol(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<AiProtocol>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  test('AiConnection apiPath round-trips through json and changed', () {
    const c = AiConnection(
      id: 'x',
      name: 'X',
      protocol: AiProtocol.openai,
      baseUrl: 'https://a.com/v1',
      apiPath: '/custom',
    );
    expect(c.toJson()['apiPath'], '/custom');
    expect(AiConnection.fromJson(c.toJson()).apiPath, '/custom');
    final kept = c.changed({'name': 'Y'});
    expect(kept.apiPath, '/custom');
    expect(kept.name, 'Y');
    final legacy = AiConnection.fromJson({...c.toJson()}..remove('apiPath'));
    expect(legacy.apiPath, isNull);
  });

  testWidgets('adds an enabled openai provider with the default api path', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.byType(AddConnectionSheet), findsOneWidget);
    expect(find.byKey(const Key('provider_api_path')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('provider_name')),
      'My Provider',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('provider_url')),
      'https://api.example.com/v1',
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('provider_key')), 'secret');
    await tester.pump();

    await tester.tap(find.byKey(const Key('provider_add_button')));
    await tester.pumpAndSettle();

    expect(provider.saved, isNotNull);
    expect(provider.saved!.name, 'My Provider');
    expect(provider.saved!.protocol, AiProtocol.openai);
    expect(provider.saved!.baseUrl, 'https://api.example.com/v1');
    expect(provider.saved!.apiPath, '/chat/completions');
    expect(provider.saved!.enabled, isTrue);
    expect(provider.savedKey, 'secret');
    expect(find.byType(AddConnectionSheet), findsNothing);
  });

  testWidgets(
    'hides the api path field and clears it for non-openai protocols',
    (tester) async {
      await openSheet(tester);

      await tester.tap(find.byType(DropdownButtonFormField<AiProtocol>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anthropic'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('provider_api_path')), findsNothing);

      await tester.enterText(find.byKey(const Key('provider_name')), 'Claude');
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('provider_url')),
        'https://api.anthropic.com',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('provider_add_button')));
      await tester.pumpAndSettle();

      expect(provider.saved, isNotNull);
      expect(provider.saved!.protocol, AiProtocol.anthropic);
      expect(provider.saved!.apiPath, isNull);
      expect(find.byType(AddConnectionSheet), findsNothing);
    },
  );

  testWidgets('blocks add and stays open when fields are invalid', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('provider_add_button')));
    await tester.pumpAndSettle();

    expect(provider.saved, isNull);
    expect(find.byType(AddConnectionSheet), findsOneWidget);
  });

  testWidgets('url field starts with the openai default', (tester) async {
    await openSheet(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://api.openai.com/v1',
    );
  });

  testWidgets('switching to anthropic updates url to its default', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.byType(DropdownButtonFormField<AiProtocol>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://api.anthropic.com/v1',
    );
  });

  testWidgets('switching to gemini updates url to its default', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byType(DropdownButtonFormField<AiProtocol>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://generativelanguage.googleapis.com/v1beta',
    );
  });

  testWidgets('remembers edited base url independently for each protocol', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(
      find.byKey(const Key('provider_url')),
      'https://openai.proxy.example/v1',
    );
    await tester.pump();
    await selectProtocol(tester, 'Anthropic');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://api.anthropic.com/v1',
    );

    await tester.enterText(
      find.byKey(const Key('provider_url')),
      'https://anthropic.proxy.example/v1',
    );
    await tester.pump();
    await selectProtocol(tester, 'Gemini');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://generativelanguage.googleapis.com/v1beta',
    );

    await selectProtocol(tester, 'Anthropic');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://anthropic.proxy.example/v1',
    );

    await selectProtocol(tester, 'OpenAI compatible');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('provider_url')))
          .controller!
          .text,
      'https://openai.proxy.example/v1',
    );
  });
}
