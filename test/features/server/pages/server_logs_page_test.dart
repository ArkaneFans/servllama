import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/server/pages/server_logs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ScrollController logsScrollController(WidgetTester tester) {
    return tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('serverLogsScrollView')),
        )
        .controller!;
  }

  void seedLogs(AppLogger logger, int count) {
    for (var index = 0; index < count; index++) {
      logger.info(
        'log-$index ' * 6,
        channel: LogChannel.server,
        inMemory: true,
      );
    }
  }

  Future<void> pumpThrottledLogs(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
  }

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

    testWidgets('lays out a few logs from the top in a forward list', (
      tester,
    ) async {
      final logger = AppLogger();
      logger.info('first', channel: LogChannel.server, inMemory: true);
      logger.info('second', channel: LogChannel.server, inMemory: true);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final logView = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('serverLogsScrollView')),
      );
      expect(logView.reverse, isFalse);

      final scrollTop = tester
          .getTopLeft(find.byKey(const Key('serverLogsScrollView')))
          .dy;
      final textTop = tester.getTopLeft(find.byType(SelectableText)).dy;
      expect(textTop, closeTo(scrollTop + 8, 0.5));
      expect(logView.controller!.offset, 0);
      expect(logView.controller!.position.maxScrollExtent, 0);
    });

    testWidgets('keeps log entries in one selectable block', (tester) async {
      final logger = AppLogger();
      logger.info('first', channel: LogChannel.server, inMemory: true);
      logger.info('second', channel: LogChannel.server, inMemory: true);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      expect(find.byType(SelectableText), findsOneWidget);
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      final plain = selectable.textSpan!.toPlainText();
      expect(plain.split('\n'), hasLength(2));
      expect(plain, contains('[server] first'));
      expect(plain, contains('[server] second'));
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

    testWidgets('opens at the latest logs without a reverse list', (
      tester,
    ) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final controller = logsScrollController(tester);
      expect(controller.offset, greaterThan(0));
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    });

    testWidgets('follows new logs while stuck to the bottom', (tester) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final controller = logsScrollController(tester);
      final previousMax = controller.position.maxScrollExtent;
      expect(controller.offset, closeTo(previousMax, 1));

      logger.info('fresh-bottom', channel: LogChannel.server, inMemory: true);
      await pumpThrottledLogs(tester);

      expect(find.textContaining('fresh-bottom'), findsOneWidget);
      expect(controller.position.maxScrollExtent, greaterThan(previousMax));
      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1),
      );
    });

    testWidgets('does not follow new logs after scrolling away from bottom', (
      tester,
    ) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      final controller = logsScrollController(tester);
      controller.jumpTo(0);
      await tester.pump();
      expect(controller.offset, 0);

      logger.info('history-view', channel: LogChannel.server, inMemory: true);
      await pumpThrottledLogs(tester);

      expect(find.textContaining('history-view'), findsOneWidget);
      expect(controller.offset, closeTo(0, 1));
      expect(
        controller.offset,
        lessThan(controller.position.maxScrollExtent - 72),
      );
    });

    testWidgets('does not follow new logs when auto-scroll is off', (
      tester,
    ) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final controller = logsScrollController(tester);
      final offsetBefore = controller.offset;
      expect(offsetBefore, closeTo(controller.position.maxScrollExtent, 1));

      logger.info('no-follow', channel: LogChannel.server, inMemory: true);
      await pumpThrottledLogs(tester);

      expect(find.textContaining('no-follow'), findsOneWidget);
      expect(controller.offset, closeTo(offsetBefore, 1));
      expect(controller.position.maxScrollExtent, greaterThan(offsetBefore));
    });

    testWidgets('turning auto-scroll back on jumps to the latest logs', (
      tester,
    ) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final controller = logsScrollController(tester);
      controller.jumpTo(0);
      await tester.pump();
      expect(controller.offset, 0);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(
        controller.offset,
        closeTo(controller.position.maxScrollExtent, 1),
      );
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
