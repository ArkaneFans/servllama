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
