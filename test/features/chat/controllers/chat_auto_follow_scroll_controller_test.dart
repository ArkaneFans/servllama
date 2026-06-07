import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/controllers/chat_auto_follow_scroll_controller.dart';

void main() {
  group('ChatAutoFollowScrollController', () {
    testWidgets('pins to bottom during layout when content grows', (
      tester,
    ) async {
      final controller = ChatAutoFollowScrollController();
      addTearDown(controller.dispose);
      controller.shouldAutoFollow = () => true;

      await _pumpList(tester, controller: controller, itemCount: 8);
      controller.jumpTo(controller.position.maxScrollExtent);

      await _pumpList(tester, controller: controller, itemCount: 16);

      expect(controller.offset, controller.position.maxScrollExtent);
    });

    testWidgets('does not pin while a user drag is active', (tester) async {
      final controller = ChatAutoFollowScrollController();
      addTearDown(controller.dispose);
      controller.shouldAutoFollow = () => true;

      await _pumpList(tester, controller: controller, itemCount: 16);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_listKey)),
      );
      await gesture.moveBy(const Offset(0, 120));
      await tester.pump();

      expect(
        controller.position.userScrollDirection,
        isNot(ScrollDirection.idle),
      );

      await _pumpList(tester, controller: controller, itemCount: 24);

      expect(
        controller.position.maxScrollExtent - controller.offset,
        greaterThan(0.5),
      );

      await gesture.up();
    });

    testWidgets('jumps to bottom immediately from far away', (tester) async {
      final controller = ChatAutoFollowScrollController();
      addTearDown(controller.dispose);

      await _pumpList(tester, controller: controller, itemCount: 30);
      controller.jumpTo(0);

      controller.jumpTo(controller.position.maxScrollExtent);

      expect(controller.offset, controller.position.maxScrollExtent);
    });

    testWidgets('corrects overestimated bottom during layout', (tester) async {
      var shouldAutoFollow = false;
      final controller = ChatAutoFollowScrollController();
      addTearDown(controller.dispose);
      controller.shouldAutoFollow = () => shouldAutoFollow;

      await _pumpVariableHeightList(tester, controller: controller);
      controller.jumpTo(0);
      await tester.pump();
      final estimatedMaxFromTop = controller.position.maxScrollExtent;

      shouldAutoFollow = true;
      controller.jumpTo(estimatedMaxFromTop);
      await tester.pump();

      expect(controller.offset, controller.position.maxScrollExtent);
      expect(controller.offset, lessThan(estimatedMaxFromTop));
    });
  });
}

const Key _listKey = Key('auto_follow_test_list');

Future<void> _pumpList(
  WidgetTester tester, {
  required ChatAutoFollowScrollController controller,
  required int itemCount,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 240,
        height: 300,
        child: ListView.builder(
          key: _listKey,
          controller: controller,
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return SizedBox(height: 64, child: Text('Message $index'));
          },
        ),
      ),
    ),
  );
}

Future<void> _pumpVariableHeightList(
  WidgetTester tester, {
  required ChatAutoFollowScrollController controller,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: SizedBox(
        width: 240,
        height: 300,
        child: ListView.builder(
          key: _listKey,
          controller: controller,
          itemCount: 80,
          itemBuilder: (context, index) {
            return SizedBox(
              height: index < 20 ? 260 : 44,
              child: Text('Message $index'),
            );
          },
        ),
      ),
    ),
  );
}
