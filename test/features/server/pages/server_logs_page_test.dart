import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/server/pages/server_logs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ServerLogsPage', () {
    testWidgets('shows empty state when there are no logs', (tester) async {
      final logger = AppLogger();

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      expect(find.text('暂无日志输出'), findsOneWidget);
      expect(find.text('共 0 条日志'), findsOneWidget);
    });

    testWidgets('shows log count and entries', (tester) async {
      final logger = AppLogger();
      logger.info('system', channel: LogChannel.server, inMemory: true);
      logger.info('failed', channel: LogChannel.server, inMemory: true);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      expect(find.text('共 2 条日志'), findsOneWidget);
      expect(find.textContaining('[server] system'), findsOneWidget);
      expect(find.textContaining('[server] failed'), findsOneWidget);
    });

    testWidgets('uses a reversed list for bottom-anchored logs', (
      tester,
    ) async {
      final logger = AppLogger();
      logger.info('first', channel: LogChannel.server, inMemory: true);
      logger.info('second', channel: LogChannel.server, inMemory: true);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.reverse, isTrue);
    });

    testWidgets('wraps long log entries instead of scrolling horizontally', (
      tester,
    ) async {
      final logger = AppLogger();
      logger.info(
        'a long log entry ' * 20,
        channel: LogChannel.server,
        inMemory: true,
      );

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final entry = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(entry.maxLines, isNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
        findsOneWidget,
        reason: 'only the filter chips should scroll horizontally',
      );
    });

    testWidgets('opens at the bottom without scrolling to max extent', (
      tester,
    ) async {
      final logger = AppLogger();
      for (var index = 0; index < 60; index++) {
        logger.info(
          'log-$index ' * 6,
          channel: LogChannel.server,
          inMemory: true,
        );
      }

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, 0);
    });

    testWidgets('clear returns page to empty state', (tester) async {
      final logger = AppLogger();
      logger.info('system', channel: LogChannel.server, inMemory: true);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('清空'));
      await tester.pump();

      expect(find.text('暂无日志输出'), findsOneWidget);
      expect(find.text('共 0 条日志'), findsOneWidget);
    });

    testWidgets('copy all copies logs and shows feedback', (tester) async {
      final logger = AppLogger();
      logger.info('system', channel: LogChannel.server, inMemory: true);
      logger.info('out', channel: LogChannel.server, inMemory: true);
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('复制全部'));
      await tester.pump();

      final copiedLines = clipboardText!.split('\n');
      expect(copiedLines, hasLength(2));
      expect(copiedLines[0], endsWith('[INFO] [server] system'));
      expect(copiedLines[1], endsWith('[INFO] [server] out'));
      expect(find.text('日志已复制'), findsOneWidget);
    });
  });
}
