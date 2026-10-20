import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/app_tab_bar.dart';

void main() {
  testWidgets(
    'tap and swipe tab changes clear focus; retapping the same tab keeps editing',
    (tester) async {
      final controller = TextEditingController(text: 'Keep this text');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const AppTabBar(
                  tabs: [
                    Tab(text: 'First'),
                    Tab(text: 'Second'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  FocusScope(
                    child: Column(
                      children: [
                        TextField(controller: controller, focusNode: focus),
                        const Expanded(child: SizedBox.expand()),
                      ],
                    ),
                  ),
                  const Center(child: Text('Other page')),
                ],
              ),
            ),
          ),
        ),
      );
      for (final swipe in [false, true]) {
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.text('First'));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        if (swipe) {
          await tester.drag(find.byType(TabBarView), const Offset(-650, 0));
        } else {
          await tester.tap(find.text('Second'));
        }
        await tester.pumpAndSettle();
        expect(
          DefaultTabController.of(tester.element(find.byType(AppTabBar))).index,
          1,
          reason: 'swipe=$swipe',
        );
        expect(focus.hasFocus, isFalse, reason: 'swipe=$swipe');
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.text('First'));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        expect(controller.text, 'Keep this text');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
