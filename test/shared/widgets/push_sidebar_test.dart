import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/push_sidebar.dart';

void main() {
  group('PushSidebar', () {
    testWidgets(
      'opens mobile sidebar, pushes content, and closes on scrim tap',
      (tester) async {
        final controller = PushSidebarController();

        await tester.pumpWidget(
          _TestHost(
            width: 700,
            child: PushSidebar(
              controller: controller,
              drawerWidth: 240,
              drawer: const ColoredBox(
                color: Colors.blue,
                child: SizedBox.expand(child: Center(child: Text('drawer'))),
              ),
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(child: Center(child: Text('main'))),
              ),
            ),
          ),
        );

        expect(find.text('drawer'), findsNothing);

        await controller.open();
        await tester.pumpAndSettle();

        expect(find.text('drawer'), findsOneWidget);
        expect(find.byKey(const Key('push_sidebar_scrim')), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('push_sidebar_main_content')))
              .dx,
          240,
        );

        await tester.tap(find.byKey(const Key('push_sidebar_scrim')));
        await tester.pumpAndSettle();

        expect(find.text('drawer'), findsNothing);
        expect(
          tester
              .getTopLeft(find.byKey(const Key('push_sidebar_main_content')))
              .dx,
          0,
        );
      },
    );

    testWidgets('dragging past settle threshold opens mobile sidebar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const _TestHost(width: 700, child: _SidebarHarness()),
      );

      await tester.drag(
        find.byKey(const Key('push_sidebar_main_content')),
        const Offset(140, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('drawer'), findsOneWidget);
    });

    testWidgets('back closes mobile sidebar before leaving route', (
      tester,
    ) async {
      final controller = PushSidebarController();

      await tester.pumpWidget(
        _TestHost(
          width: 700,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => PushSidebar(
                controller: controller,
                drawerWidth: 240,
                drawer: const ColoredBox(
                  color: Colors.blue,
                  child: SizedBox.expand(child: Center(child: Text('drawer'))),
                ),
                child: const Scaffold(body: Center(child: Text('main'))),
              ),
            ),
          ),
        ),
      );

      await controller.open();
      await tester.pumpAndSettle();
      expect(find.text('drawer'), findsOneWidget);

      final didPop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(didPop, isTrue);
      expect(find.text('drawer'), findsNothing);
      expect(find.text('main'), findsOneWidget);
    });

    testWidgets(
      'shows embedded sidebar by default on large screens and resizes within bounds',
      (tester) async {
        double? latestWidth;

        await tester.pumpWidget(
          _TestHost(
            width: 1300,
            child: PushSidebar(
              embeddedSidebarWidth: 300,
              onSidebarWidthChanged: (value) {
                latestWidth = value;
              },
              showResizeHandle: true,
              drawer: const ColoredBox(
                color: Colors.blue,
                child: SizedBox.expand(child: Center(child: Text('drawer'))),
              ),
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(child: Center(child: Text('main'))),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('drawer'), findsOneWidget);
        expect(
          find.byKey(const Key('push_sidebar_resize_handle')),
          findsOneWidget,
        );
        expect(
          tester.getSize(find.byKey(const Key('push_sidebar_panel'))).width,
          300,
        );

        await tester.drag(
          find.byKey(const Key('push_sidebar_resize_handle')),
          const Offset(120, 0),
        );
        await tester.pumpAndSettle();

        expect(latestWidth, 360);
      },
    );
  });
}

class _SidebarHarness extends StatelessWidget {
  const _SidebarHarness();

  @override
  Widget build(BuildContext context) {
    return PushSidebar(
      drawerWidth: 240,
      drawer: const ColoredBox(
        color: Colors.blue,
        child: SizedBox.expand(child: Center(child: Text('drawer'))),
      ),
      child: const ColoredBox(
        color: Colors.white,
        child: SizedBox.expand(child: Center(child: Text('main'))),
      ),
    );
  }
}

class _TestHost extends StatelessWidget {
  const _TestHost({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: SizedBox(width: width, height: 900, child: child),
      ),
    );
  }
}
