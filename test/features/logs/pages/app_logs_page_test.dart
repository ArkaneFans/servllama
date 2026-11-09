import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/services/downloads_export_service.dart';
import 'package:servllama/features/logs/pages/app_logs_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ScrollController logsScrollController(WidgetTester tester) {
    return tester
        .widget<SingleChildScrollView>(
          find.byKey(const Key('appLogsScrollView')),
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

  group('AppLogsPage', () {
    testWidgets('combined filters drive visible, copied and exported results', (
      tester,
    ) async {
      final logger = AppLogger();
      addTearDown(logger.dispose);
      logger.event(
        'job ready',
        channel: LogChannel.speech,
        fields: {'job': 'wanted'},
      );
      logger.event(
        'job failed',
        channel: LogChannel.speech,
        level: LogLevel.error,
        fields: {'job': 'wanted'},
      );
      logger.event(
        'request failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: {'job': 'wanted'},
      );
      logger.event(
        'other failed',
        channel: LogChannel.speech,
        level: LogLevel.error,
        fields: {'job': 'other'},
      );
      final exporter = _FakeDownloadsExportService();
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
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
        MaterialApp(
          home: AppLogsPage(logger: logger, exportService: exporter),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('语音'));
      await tester.tap(find.text('语音'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appLogsLevel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('警告及错误').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('appLogsSearch')), 'WANTED');
      await tester.pumpAndSettle();
      expect(find.text('1 / 4 条日志'), findsOneWidget);
      final visible = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .textSpan!
          .toPlainText();
      expect(visible, contains('[ERROR] [speech] job failed'));
      await tester.tap(find.byTooltip('复制筛选结果'));
      await tester.pump();
      await tester.tap(find.byTooltip('导出日志'));
      await tester.pump();
      expect(copied, visible);
      expect(exporter.lastContent, visible);
      await tester.enterText(
        find.byKey(const Key('appLogsSearch')),
        'no-matches',
      );
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的日志'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.copy_all_outlined),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.file_download_outlined),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('清空全部日志'));
      await tester.pump();
      expect(find.text('0 / 0 条日志'), findsOneWidget);
      for (final channel in LogChannel.values) {
        expect(logger.entriesFor(channel), isEmpty);
      }
    });

    testWidgets('shows empty state when there are no logs', (tester) async {
      final logger = AppLogger();

      await tester.pumpWidget(MaterialApp(home: AppLogsPage(logger: logger)));
      await tester.pump();

      expect(find.text('暂无日志输出'), findsOneWidget);
      expect(find.text('0 / 0 条日志'), findsOneWidget);
    });

    testWidgets('follows new logs while stuck to the bottom', (tester) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(MaterialApp(home: AppLogsPage(logger: logger)));
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

      await tester.pumpWidget(MaterialApp(home: AppLogsPage(logger: logger)));
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

    testWidgets('turning auto-scroll back on jumps to the latest logs', (
      tester,
    ) async {
      final logger = AppLogger();
      seedLogs(logger, 60);

      await tester.pumpWidget(MaterialApp(home: AppLogsPage(logger: logger)));
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

      await tester.pumpWidget(MaterialApp(home: AppLogsPage(logger: logger)));
      await tester.pump();

      await tester.tap(find.byTooltip('清空全部日志'));
      await tester.pump();

      expect(find.text('暂无日志输出'), findsOneWidget);
      expect(find.text('0 / 0 条日志'), findsOneWidget);
    });

    testWidgets('export writes logs to Downloads and shows the path', (
      tester,
    ) async {
      final logger = AppLogger();
      logger.info('system', channel: LogChannel.server, inMemory: true);
      logger.info('out', channel: LogChannel.engine, inMemory: true);
      final exporter = _FakeDownloadsExportService();

      await tester.pumpWidget(
        MaterialApp(
          home: AppLogsPage(logger: logger, exportService: exporter),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('导出日志'));
      await tester.pump();

      expect(exporter.lastFileName, startsWith('servllama-logs-'));
      expect(exporter.lastFileName, endsWith('.txt'));
      expect(exporter.lastContent, contains('[server] system'));
      expect(exporter.lastContent, contains('[engine] out'));
      expect(
        find.text(
          '日志已导出到 /storage/emulated/0/Download/${exporter.lastFileName}',
        ),
        findsOneWidget,
      );
    });
  });
}

class _FakeDownloadsExportService extends DownloadsExportService {
  String? lastFileName;
  String? lastContent;

  @override
  Future<String> saveTextFile({
    required String fileName,
    required String content,
  }) async {
    lastFileName = fileName;
    lastContent = content;
    return '/storage/emulated/0/Download/$fileName';
  }
}
