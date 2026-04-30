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
      logger.pageInfo('system', channel: LogChannel.server);
      logger.serverStderr('failed');

      await tester.pumpWidget(
        MaterialApp(home: ServerLogsPage(logger: logger)),
      );
      await tester.pump();

      expect(find.text('共 2 条日志'), findsOneWidget);
      expect(find.text('system'), findsOneWidget);
      expect(find.text('failed'), findsOneWidget);
    });

    testWidgets('clear returns page to empty state', (tester) async {
      final logger = AppLogger();
      logger.pageInfo('system', channel: LogChannel.server);

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
      logger.pageInfo('system', channel: LogChannel.server);
      logger.serverStdout('out');
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

      expect(clipboardText, 'system\nout');
      expect(find.text('日志已复制'), findsOneWidget);
    });
  });
}
