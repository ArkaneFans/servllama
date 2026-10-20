import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';

Widget editor(String name, {bool autofocus = false}) => Scaffold(
  appBar: AppBar(title: Text(name)),
  body: FocusScope(
    child: TextField(key: Key(name), autofocus: autofocus),
  ),
);

EditableText input(WidgetTester tester, String name) =>
    tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(name), skipOffstage: false),
        matching: find.byType(EditableText, skipOffstage: false),
      ),
    );

void main() {
  late GlobalKey<NavigatorState> navigator;
  setUp(() => navigator = GlobalKey<NavigatorState>());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [AppNavigationObserver()],
        home: editor('source'),
      ),
    );
    await tester.enterText(find.byKey(const Key('source')), 'Draft to keep');
    await tester.pump();
    expect(input(tester, 'source').focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }

  void sourceBlurred(WidgetTester tester) {
    expect(input(tester, 'source').focusNode.hasFocus, isFalse);
    expect(input(tester, 'source').controller.text, 'Draft to keep');
  }

  testWidgets(
    'page round trip clears source history, preserves destination autofocus',
    (tester) async {
      await mount(tester);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => editor('destination', autofocus: true),
        ),
      );
      await tester.pumpAndSettle();
      sourceBlurred(tester);
      expect(input(tester, 'destination').focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byKey(const Key('destination')), 'Edit here');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      sourceBlurred(tester);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const Key('source')));
      await tester.pumpAndSettle();
      expect(input(tester, 'source').focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );

  for (final popup in ['dialog', 'sheet', 'menu']) {
    testWidgets('$popup dismiss does not restore source keyboard', (
      tester,
    ) async {
      await mount(tester);
      final context = tester.element(find.byKey(const Key('source')));
      switch (popup) {
        case 'dialog':
          showDialog<void>(
            context: context,
            builder: (_) => const AlertDialog(
              content: TextField(key: Key('popup'), autofocus: true),
            ),
          );
        case 'sheet':
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const Padding(
              padding: EdgeInsets.all(24),
              child: TextField(key: Key('popup'), autofocus: true),
            ),
          );
        case 'menu':
          showMenu<void>(
            context: context,
            requestFocus: false,
            position: const RelativeRect.fromLTRB(20, 20, 0, 0),
            items: const [PopupMenuItem(child: Text('Action'))],
          );
      }
      await tester.pumpAndSettle();
      sourceBlurred(tester);
      if (popup != 'menu') {
        expect(input(tester, 'popup').focusNode.hasFocus, isTrue);
      } else {
        expect(tester.testTextInput.isVisible, isFalse);
      }
      // Barrier dismissal, swipe dismissal and back ultimately pop the route.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      sourceBlurred(tester);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  }

  testWidgets('replace and remove top keep the returning source unfocused', (
    tester,
  ) async {
    await mount(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => editor('first', autofocus: true)),
    );
    await tester.pumpAndSettle();
    final replacement = MaterialPageRoute<void>(
      builder: (_) => editor('replacement', autofocus: true),
    );
    navigator.currentState!.pushReplacement(replacement);
    await tester.pumpAndSettle();
    expect(input(tester, 'replacement').focusNode.hasFocus, isTrue);
    navigator.currentState!.removeRoute(replacement);
    await tester.pumpAndSettle();
    sourceBlurred(tester);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'background removal, rebuild and rejected back do not interrupt editing',
    (tester) async {
      await mount(tester);
      final background = ModalRoute.of(
        tester.element(find.byKey(const Key('source'))),
      )!;
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => PopScope(
            canPop: false,
            child: editor('current', autofocus: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.removeRoute(background);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [AppNavigationObserver()],
          theme: ThemeData.dark(),
          home: editor('source'),
        ),
      );
      await tester.pumpAndSettle();
      expect(input(tester, 'current').focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    },
  );
}
