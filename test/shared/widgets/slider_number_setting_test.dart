import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/slider_number_setting.dart';

void main() {
  group('SliderNumberSetting', () {
    Widget wrap(Widget child) {
      return MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );
    }

    testWidgets('commits once on drag end, not per drag tick', (tester) async {
      final committed = <int>[];
      await tester.pumpWidget(
        wrap(
          SliderNumberSetting(
            label: 'Context',
            value: 0,
            min: 0,
            max: 100,
            onChanged: committed.add,
          ),
        ),
      );

      final sliderCenter = tester.getCenter(find.byType(Slider));
      final gesture = await tester.startGesture(sliderCenter);
      await tester.pump();
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      // Mid-drag: nothing is committed yet.
      expect(committed, isEmpty);

      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(committed, isEmpty);

      await gesture.up();
      await tester.pump();

      expect(committed, hasLength(1));
    });

    testWidgets('text field submit still commits directly', (tester) async {
      final committed = <int>[];
      await tester.pumpWidget(
        wrap(
          SliderNumberSetting(
            label: 'Threads',
            value: 2,
            min: 1,
            max: 8,
            onChanged: committed.add,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '6');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(committed, contains(6));
    });
  });
}
