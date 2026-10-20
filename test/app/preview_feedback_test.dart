import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/numeric_slider.dart';
import 'package:servllama/features/design_preview/preview_theme.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: PreviewTheme.build(dark ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      );

  final input = find.byKey(const Key('ui_lab_numeric_input'));
  final slider = find.byKey(const Key('ui_lab_numeric_slider'));
  final message = find.byKey(const Key('app_top_message'));

  Future<void> openSlider(WidgetTester tester, {double scale = 1}) async {
    var value = 0.6;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, update) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                NumericSlider(
                  label: 'Temperature',
                  value: value,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  onChanged: (next) => update(() => value = next),
                ),
                TextButton(
                  onPressed: () => FocusScope.of(context).unfocus(),
                  child: const Text('Unfocus'),
                ),
              ],
            ),
          ),
        ),
        scale: scale,
      ),
    );
  }

  testWidgets(
    'precise entry and coarse drag stay in sync; blur normalizes text',
    (tester) async {
      await openSlider(tester);
      await tester.enterText(input, '0.65');
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, 0.65);
      await tester.enterText(input, '0.');
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, '0.');
      await tester.enterText(input, ',75');
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, 0.75);
      await tester.tap(find.text('Unfocus'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '0.75');
      await tester.drag(slider, const Offset(-180, 0));
      await tester.pumpAndSettle();
      final afterDrag = tester.widget<Slider>(slider).value;
      expect(afterDrag, isNot(0.75));
      expect(
        double.parse(tester.widget<TextField>(input).controller!.text),
        afterDrag,
      );
    },
  );

  testWidgets('invalid and empty input keeps last valid value and recovers', (
    tester,
  ) async {
    await openSlider(tester);
    for (final value in ['2', '-0.1', 'abc', '0.123', 'NaN', '']) {
      await tester.enterText(input, value);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, 0.6);
      expect(find.textContaining('Enter a value from'), findsOneWidget);
    }
    await tester.enterText(input, '1.00');
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, 1);
    expect(find.textContaining('Enter a value from'), findsNothing);
    await tester.tap(find.text('Unfocus'));
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, '1');
    await tester.enterText(input, '0');
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, 0);
  });

  testWidgets(
    'numeric input remains to the right at large text with keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      await openSlider(tester, scale: 1.6);
      await tester.enterText(input, '0.65');
      await tester.pumpAndSettle();
      expect(
        tester.getRect(input).left,
        greaterThan(tester.getRect(slider).right),
      );
      expect(input.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new message replaces old, resets expiry, and supports dismissal',
    (tester) async {
      final host = GlobalKey<AppMessageHostState>();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AppMessageHost(key: host, child: const SizedBox.expand()),
          ),
        ),
      );
      host.currentState!.show('First');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      host.currentState!.show('Second', tone: AppMessageTone.error);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(message, findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Second'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(message, findsNothing);
      host.currentState!.show('Dismiss me', tone: AppMessageTone.warning);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('app_close_message')));
      await tester.pumpAndSettle();
      expect(message, findsNothing);
      host.currentState!.show('Leave before expiry');
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'message stays below a custom AppBar and keeps toolbar and content interactive',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 32);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.reset);
      final host = GlobalKey<AppMessageHostState>();
      var tapped = false;
      var toolbarTapped = false;
      await tester.pumpWidget(
        app(
          Scaffold(
            appBar: AppBar(
              toolbarHeight: 72,
              title: const Text('Toolbar'),
              actions: [
                IconButton(
                  key: const Key('toolbar_action'),
                  onPressed: () => toolbarTapped = true,
                  icon: const Icon(Icons.palette_outlined),
                ),
              ],
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: SizedBox(height: 64),
              ),
            ),
            body: AppMessageHost(
              key: host,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TextButton(
                  onPressed: () => tapped = true,
                  child: const Text('Content'),
                ),
              ),
            ),
          ),
          dark: true,
          scale: 1.6,
        ),
      );
      host.currentState!.show(
        'A longer message wraps on a narrow screen and stays above the keyboard.',
        tone: AppMessageTone.info,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(
        tester.getRect(message).top,
        greaterThanOrEqualTo(appBarBottom + 12),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(message).top, appBarBottom + 12);
      expect(tester.getCenter(message).dx, 180);
      await tester.tap(find.byKey(const Key('toolbar_action')));
      expect(toolbarTapped, isTrue);
      await tester.tap(find.text('Content'));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
      host.currentState!.hide();
      await tester.pumpAndSettle();
    },
  );
}
