import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/text_sheen.dart';

void main() {
  testWidgets('loading title changes visually and settles when loading ends', (
    tester,
  ) async {
    final capture = GlobalKey();
    Widget app(bool enabled) => MaterialApp(
      home: Scaffold(
        body: RepaintBoundary(
          key: capture,
          child: TextSheen(enabled: enabled, child: const Text('Tool title')),
        ),
      ),
    );
    Future<List<int>> pixels() async => (await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData();
        return bytes!.buffer.asUint8List().toList();
      } finally {
        image.dispose();
      }
    }))!;

    await tester.pumpWidget(app(true));
    await tester.pump(const Duration(milliseconds: 600));
    final before = await pixels();
    await tester.pump(const Duration(milliseconds: 450));
    expect(await pixels(), isNot(equals(before)));
    expect(find.text('Tool title'), findsOneWidget);
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Tool title'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion and disabled tickers keep the title static', (
    tester,
  ) async {
    Widget app({bool reduced = false, bool tickers = true}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: TickerMode(
          enabled: tickers,
          child: const TextSheen(enabled: true, child: Text('Tool title')),
        ),
      ),
    );
    await tester.pumpWidget(app());
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pumpWidget(app(reduced: true));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('Tool title'), findsOneWidget);
    await tester.pumpWidget(app(tickers: false));
    await tester.pumpAndSettle();
    expect(find.byType(ShaderMask), findsNothing);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
