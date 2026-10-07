import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/app_theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'touch feedback clears across navigation and cancellation, dark=$dark',
      (tester) async {
        final boundary = GlobalKey();
        final navigator = GlobalKey<NavigatorState>();
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        expect(theme.splashFactory, NoSplash.splashFactory);
        void open() => navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Destination')),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            navigatorKey: navigator,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: Material(
                    color: theme.colorScheme.surface,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Card(
                          child: ListTile(
                            key: const Key('tile'),
                            title: const Text('Tile'),
                            onTap: open,
                          ),
                        ),
                        InkWell(
                          key: const Key('ink'),
                          onTap: open,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Ink action'),
                          ),
                        ),
                        IconButton(
                          key: const Key('icon'),
                          onPressed: open,
                          icon: const Icon(Icons.settings),
                        ),
                        FilledButton(
                          key: const Key('filled'),
                          onPressed: open,
                          child: const Text('Button'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<Uint8List> pixels() async => (await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData();
          image.dispose();
          return bytes!.buffer.asUint8List();
        }))!;
        final baseline = await pixels();
        for (final key in ['tile', 'ink', 'icon', 'filled']) {
          final finder = find.byKey(Key(key));
          final press = await tester.startGesture(tester.getCenter(finder));
          await tester.pump(const Duration(milliseconds: 160));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            await pixels(),
            isNot(orderedEquals(baseline)),
            reason: '$key still has press feedback',
          );
          await press.up();
          await tester.pumpAndSettle();
          navigator.currentState!.pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            await pixels(),
            orderedEquals(baseline),
            reason: '$key returns without a pressed layer',
          );
          await tester.pumpAndSettle();
          final cancel = await tester.startGesture(tester.getCenter(finder));
          await tester.pump(const Duration(milliseconds: 160));
          await cancel.cancel();
          await tester.pumpAndSettle();
          expect(
            await pixels(),
            orderedEquals(baseline),
            reason: '$key cancels without a pressed layer',
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
