import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/design_preview/ui_primitives_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UiPrimitivesPage(),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'gallery validates inputs and previews dialog and model selection without providers',
    (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('ui_lab_controls')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dialog'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app_top_message')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('app_top_message'))).top,
        tester.getRect(find.byType(AppBar)).bottom + 12,
      );
      await tester.tap(find.byKey(const Key('app_close_message')));
      await tester.pumpAndSettle();
      final validate = find.byKey(const Key('ui_lab_validate'));
      await tester.ensureVisible(validate);
      await tester.pumpAndSettle();
      await tester.tap(validate);
      await tester.pumpAndSettle();
      expect(find.text('Enter an assistant name'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ui_lab_name')), 'Reading');
      await tester.pump();
      expect(find.text('Enter an assistant name'), findsNothing);
      await tester.tap(find.byKey(const Key('ui_lab_scenes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ui_lab_model_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ui_lab_model_1')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Gemini · Flash'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('ui_lab_message')),
        'A preview message',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ui_lab_send')));
      await tester.pumpAndSettle();
      expect(find.text('A preview message'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ui_lab_message')))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.byKey(const Key('ui_lab_tool')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('No network request was made.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'palette switches independently of brightness and preserves the scene draft',
    (tester) async {
      await open(tester, scale: 1.5);
      final paletteButton = find.byKey(const Key('ui_lab_palette'));
      ThemeData theme() => Theme.of(tester.element(paletteButton));
      Future<void> select(String name) async {
        await tester.tap(paletteButton);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('ui_lab_palette_$name')));
        await tester.pumpAndSettle();
      }

      final violetLight = theme().colorScheme.primary;
      await tester.tap(find.byKey(const Key('ui_lab_scenes')));
      await tester.pumpAndSettle();
      final input = find.byKey(const Key('ui_lab_message'));
      await tester.enterText(input, 'Keep this draft');
      await tester.pump();
      await select('tea');
      final teaLight = theme().colorScheme.primary;
      expect(teaLight, isNot(violetLight));
      expect(theme().brightness, Brightness.light);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Keep this draft',
      );
      await tester.tap(paletteButton);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckedPopupMenuItem>(
              find.byKey(const Key('ui_lab_palette_tea')),
            )
            .checked,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('ui_lab_palette_tea')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ui_lab_brightness')));
      await tester.pumpAndSettle();
      final teaDark = theme().colorScheme.primary;
      expect(theme().brightness, Brightness.dark);
      expect(teaDark, isNot(teaLight));
      await tester.tap(find.byKey(const Key('ui_lab_model_picker')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(BottomSheet))).colorScheme.primary,
        teaDark,
      );
      await tester.tap(find.byKey(const Key('ui_lab_model_1')));
      await tester.pumpAndSettle();
      await select('violet');
      expect(theme().brightness, Brightness.dark);
      expect(theme().colorScheme.primary, isNot(teaDark));
      expect(find.text('Gemini · Flash'), findsOneWidget);
      expect(
        tester.widget<TextField>(input).controller!.text,
        'Keep this draft',
      );
      await tester.tap(find.byKey(const Key('ui_lab_brightness')));
      await tester.pumpAndSettle();
      expect(theme().colorScheme.primary, violetLight);
      await select('tea');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Open'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(theme().colorScheme.primary, violetLight);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'gallery supports larger text, keyboard, local dark mode and clean exit during progress',
    (tester) async {
      await open(tester, scale: 1.5);
      await tester.tap(find.byKey(const Key('ui_lab_brightness')));
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const Key('ui_lab_brightness'))),
        ).brightness,
        Brightness.dark,
      );
      await tester.tap(find.byKey(const Key('ui_lab_scenes')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ui_lab_send')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.byKey(const Key('ui_lab_controls')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Simulate progress'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('ui_lab_control_list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate progress'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Open'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.text('Open'))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
