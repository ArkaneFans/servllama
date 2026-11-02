import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/features/chat/models/chat_context_usage.dart';
import 'package:servllama/features/chat/widgets/chat_context_usage_ring.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

const capture = bool.fromEnvironment('CAPTURE_CONTEXT_UI');
void main() {
  final boundaryKey = GlobalKey();
  late TextEditingController controller;
  int sends = 0;
  setUpAll(() async {
    if (!capture) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('ContextUiFont')..addFont(
          File(
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    controller = TextEditingController(text: 'Hello');
    sends = 0;
  });
  tearDown(() => controller.dispose());
  Widget app(
    ChatContextUsage usage, {
    double scale = 1,
    bool sending = false,
    Locale locale = const Locale('en'),
  }) {
    var theme = AppTheme.light();
    if (capture) {
      theme = theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'ContextUiFont'),
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'ContextUiFont',
          ),
        ),
      );
    }
    return MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: boundaryKey,
        child: Scaffold(
          appBar: AppBar(title: const Text('ServLlama')),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              hintText: 'Message',
              isServerRunning: true,
              isServerBusy: false,
              modelLabel: 'Qwen',
              canOpenModels: true,
              isModelLoading: false,
              hasLoadedModel: true,
              canSend: true,
              isSending: sending,
              onServerAction: () {},
              onOpenModels: () {},
              onSend: () {
                sends++;
              },
              onStop: () {
                sends++;
              },
              onPickFromGallery: () {},
              pendingImageAttachments: const [],
              onRemoveImageAttachment: (_) {},
              contextIndicator: ChatContextUsageRing(usage: usage),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!capture) return;
    // Layout tests exercise Send with a draft. The visual snapshot represents
    // the post-send composer, because real usage is unknown while editing.
    controller.clear();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/context-ui/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets('far-right ring preserves send touch target at 320 and 360 dp', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 640);
      controller.text = 'Hello';
      await tester.pumpWidget(
        app(
          const ChatContextUsage(usedTokens: 3000, capacityTokens: 4000),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      final ring = find.byKey(const Key('chat_context_usage_button'));
      final send = find.byKey(const Key('chat_send_button'));
      expect(tester.getSize(ring), const Size(48, 48));
      expect(
        tester.getRect(ring).left,
        greaterThanOrEqualTo(tester.getRect(send).right),
      );
      expect(tester.getRect(ring).right, lessThanOrEqualTo(width));
      expect(tester.getSize(send).width, greaterThanOrEqualTo(48));
      await tester.tap(send);
      expect(tester.takeException(), isNull);
      await screenshot(tester, 'composer-${width.toInt()}');
    }
    expect(sends, 2);
  });
  testWidgets(
    'tap shows actual tokens and snapshot caveat, then closes cleanly',
    (tester) async {
      await tester.pumpWidget(
        app(const ChatContextUsage(usedTokens: 3900, capacityTokens: 4000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('98%'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat_context_usage_button')));
      await tester.pumpAndSettle();
      expect(find.text('3900 / 4000 tokens'), findsOneWidget);
      expect(find.text('Backend token count'), findsOneWidget);
      expect(find.textContaining('snapshot'), findsOneWidget);
      Navigator.of(tester.element(find.text('3900 / 4000 tokens'))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat_context_usage_details')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown is literal dash, never zero, and stop remains tappable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        app(
          const ChatContextUsage(),
          sending: true,
          locale: const Locale('zh'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('-'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      await tester.tap(find.byKey(const Key('chat_send_button')));
      expect(sends, 1);
      await screenshot(tester, 'composer-unknown-zh');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('warning colors and determinate arcs follow actual capacity', (
    tester,
  ) async {
    for (final used in [2000, 3400, 3900]) {
      await tester.pumpWidget(
        app(ChatContextUsage(usedTokens: used, capacityTokens: 4000)),
      );
      await tester.pumpAndSettle();
      final progress = tester.widget<CircularProgressIndicator>(
        find.byKey(const Key('chat_context_usage_progress')),
      );
      final colors = Theme.of(
        tester.element(find.byType(ChatContextUsageRing)),
      ).colorScheme;
      expect(progress.value, used / 4000);
      expect(
        progress.color,
        used >= 3800
            ? colors.error
            : used >= 3200
            ? colors.tertiary
            : colors.primary,
      );
    }
  });
}
