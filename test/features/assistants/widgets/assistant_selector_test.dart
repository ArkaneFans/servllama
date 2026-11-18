import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/widgets/assistant_selector.dart';

import '../../../support/chat_fixture.dart';

void main() {
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
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.descendant(
          of: sheet,
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
