import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/chat_input_overlay_layout.dart';

void main() {
  group('ChatInputOverlayLayout', () {
    testWidgets('fills content and pins bottom overlay', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              height: 500,
              child: ChatInputOverlayLayout(
                content: ColoredBox(
                  key: Key('content'),
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
                bottomOverlay: SizedBox(
                  key: Key('bottom_overlay'),
                  width: 200,
                  height: 80,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('content'))),
        const Size(300, 500),
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('bottom_overlay'))),
        const Offset(50, 420),
      );
    });
  });
}
