import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/widgets/assistant_selector.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

import '../../../support/chat_fixture.dart';

void main() {
  testWidgets(
    'filters assistants by name, clears search and selects a result',
    (tester) async {
      final fixture = ChatFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        await fixture.assistants.save(
          const Assistant(id: 'reading', name: '阅读 Reading partner'),
        );
        await fixture.assistants.save(
          const Assistant(id: 'coding', name: 'Coding partner'),
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        var closed = false;
        final closing = fixture.close().then((_) => closed = true);
        await settleBusiness(tester, () => closed);
        await closing;
      });
      fixture.chat.updateInputText('Keep input until selecting an assistant');
      await tester.pumpWidget(
        fixture.app(const Scaffold(body: AssistantSelector())),
      );
      await tester.tap(find.byKey(const Key('drawer_assistant_selector')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('assistant_picker_sheet'));
      final search = find.byKey(const Key('assistant_picker_search'));
      final l = AppLocalizations.of(tester.element(sheet))!;
      expect(tester.testTextInput.isVisible, isFalse);

      await tester.enterText(search, '  rEaDiNg  ');
      await tester.pump();
      expect(
        find.byKey(const Key('assistant_picker_item_reading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('assistant_picker_item_assistant')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('assistant_picker_item_coding')),
        findsNothing,
      );
      await tester.enterText(search, '阅读');
      await tester.pump();
      expect(
        find.byKey(const Key('assistant_picker_item_reading')),
        findsOneWidget,
      );
      await tester.enterText(search, 'missing');
      await tester.pump();
      expect(
        find.descendant(of: sheet, matching: find.byType(ListTile)),
        findsNothing,
      );
      expect(find.text(l.v2AssistantNoResults), findsOneWidget);
      expect(fixture.chat.currentAssistantId, 'assistant');
      expect(fixture.chat.inputText, 'Keep input until selecting an assistant');

      await tester.tap(find.byKey(const Key('assistant_picker_search_clear')));
      await tester.pump();
      expect(
        find.descendant(of: sheet, matching: find.byType(ListTile)),
        findsNWidgets(3),
      );
      expect(find.text(l.v2AssistantNoResults), findsNothing);
      await tester.enterText(search, 'reading');
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant_picker_item_reading')));
      await settleBusiness(
        tester,
        () =>
            fixture.chat.currentAssistantId == 'reading' &&
            fixture.chat.canManageSessions,
      );
      expect(sheet, findsNothing);
      expect(fixture.chat.inputText, isEmpty);

      await tester.tap(find.byKey(const Key('drawer_assistant_selector')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      expect(
        find.descendant(of: sheet, matching: find.byType(ListTile)),
        findsNWidgets(3),
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scrolls a long assistant list on a compact screen with large text',
    (tester) async {
      final fixture = ChatFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        for (var index = 0; index < 18; index++) {
          await fixture.assistants.save(
            Assistant(
              id: 'choice-$index',
              name:
                  'Assistant ${index.toString().padLeft(2, '0')} with a long name',
              avatar: 'A',
            ),
          );
        }
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        var closed = false;
        final closing = fixture.close().then((_) => closed = true);
        await settleBusiness(tester, () => closed);
        await closing;
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.7;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      fixture.chat.updateInputText('Discard this when switching assistants');

      await tester.pumpWidget(
        fixture.app(
          const Scaffold(
            body: SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: SizedBox(width: 300, child: AssistantSelector()),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('drawer_assistant_selector')));
      await tester.pumpAndSettle();

      final sheet = find.byKey(const Key('assistant_picker_sheet'));
      final last = find.byKey(const Key('assistant_picker_item_choice-17'));
      expect(sheet, findsOneWidget);
      expect(MediaQuery.textScalerOf(tester.element(sheet)).scale(10), 17);
      expect(last, findsNothing);
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const Key('assistant_picker_item_assistant')),
            )
            .selected,
        isTrue,
      );
      expect(
        find.descendant(of: sheet, matching: find.byIcon(Icons.check_rounded)),
        findsNothing,
      );
      expect(
        find.byKey(const Key('assistant_picker_edit_assistant')).hitTestable(),
        findsOneWidget,
      );
      final search = find.byKey(const Key('assistant_picker_search'));
      await tester.showKeyboard(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(search.hitTestable(), findsOneWidget);
      expect(tester.getBottomRight(search).dy, lessThanOrEqualTo(390));
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.descendant(
          of: find.descendant(of: sheet, matching: find.byType(ListView)),
          matching: find.byType(Scrollable),
        ),
      );
      expect(last.hitTestable(), findsOneWidget);
      expect(
        find.byKey(const Key('assistant_picker_edit_choice-17')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(last);
      await settleBusiness(
        tester,
        () =>
            fixture.chat.currentAssistantId == 'choice-17' &&
            fixture.chat.canManageSessions,
      );
      expect(sheet, findsNothing);
      expect(fixture.chat.inputText, isEmpty);
      await tester.runAsync(() => fixture.chat.selectAssistant('assistant'));
      await tester.pumpAndSettle();
      expect(fixture.chat.inputText, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
