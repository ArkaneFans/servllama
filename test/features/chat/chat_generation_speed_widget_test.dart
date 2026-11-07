import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/providers/chat_display_provider.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capture = bool.fromEnvironment('CAPTURE_SPEED_UI');
const _metrics = GenerationMetrics(
  promptTokens: 100,
  promptMilliseconds: 200,
  predictedTokens: 20,
  predictedMilliseconds: 1000,
  inputTokens: 100,
  outputTokens: 20,
  cachedInputTokens: 64,
);

void main() {
  late ChatDisplayProvider display;
  late ScrollController scroll;
  late StreamingChatMessageNotifier streaming;
  final screenshotKey = GlobalKey();
  final response = ChatMessageRecord(
    id: 'response',
    role: ChatRole.assistant,
    content: '可以。生成完成后，这里会显示本次回复的预填充和解码速度。',
    createdAt: DateTime(2026, 10, 29, 11, 8),
    modelName: 'Qwen3.5-2B · llama.cpp',
    generationMetrics: _metrics,
  );

  setUpAll(() async {
    if (!_capture) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('SpeedUiFont')
      ..addFont(
        File(
          '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    display = ChatDisplayProvider(kvStorage: KvStorage());
    scroll = ScrollController();
    streaming = StreamingChatMessageNotifier();
  });
  tearDown(() {
    display.dispose();
    scroll.dispose();
    streaming.dispose();
  });

  Widget app(
    List<ChatMessageRecord> messages, {
    String? draftId,
    double scale = 1,
    Locale locale = const Locale('zh'),
    bool settings = false,
  }) {
    var theme = AppTheme.light();
    if (_capture) {
      theme = theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          titleTextStyle: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'SpeedUiFont',
          ),
        ),
        textTheme: theme.textTheme.apply(fontFamily: 'SpeedUiFont'),
        primaryTextTheme: theme.primaryTextTheme.apply(
          fontFamily: 'SpeedUiFont',
        ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatDisplayProvider>.value(value: display),
        if (settings) ...[
          ChangeNotifierProvider(create: (_) => AssistantProvider()),
          ChangeNotifierProvider(
            create: (_) => AppThemeModeProvider(kvStorage: KvStorage()),
          ),
          ChangeNotifierProvider(
            create: (_) => AppLocaleProvider(kvStorage: KvStorage()),
          ),
          ChangeNotifierProvider(
            create: (_) => ChatTimeoutProvider(kvStorage: KvStorage()),
          ),
        ],
      ],
      child: RepaintBoundary(
        key: screenshotKey,
        child: MaterialApp(
          theme: theme,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: settings
              ? const SettingsPage()
              : Scaffold(
                  appBar: AppBar(title: const Text('ServLlama')),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ChatMessageList(
                      controller: scroll,
                      streamingMessages: streaming,
                      messages: messages,
                      draftMessageId: draftId,
                      canManageMessages: true,
                      canRegenerateMessage: (_) => true,
                      onCopyMessage: (_) async {},
                      onEditMessage: (_) async {},
                      onDeleteMessage: (_) async {},
                      onRegenerateMessage: (_) async {},
                      onShowMessageActions: (_) async {},
                      onSelectMessageVersion: (_, _) async {},
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!_capture) return;
    await tester.runAsync(() async {
      final boundary =
          screenshotKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('/tmp/servllama-speed-ui');
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'default off; toggling updates old responses but never user messages',
    (tester) async {
      final user = response.copyWith(
        id: 'user',
        role: ChatRole.user,
        content: '你好',
      );
      await tester.pumpWidget(app([user, response]));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('chat_generation_speed_response')),
        findsNothing,
      );
      await display.updateShowGenerationSpeed(true);
      await tester.pumpAndSettle();
      expect(find.text('预填充 500.0 tok/s'), findsOneWidget);
      expect(find.text('解码 20.0 tok/s'), findsOneWidget);
      expect(find.byKey(const Key('chat_generation_speed_user')), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const Key('chat_generation_speed_response')))
            .dy,
        greaterThan(tester.getBottomLeft(find.text(response.content)).dy),
      );
      await display.updateShowGenerationSpeed(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('tok/s'), findsNothing);
    },
  );

  testWidgets('missing phases and historical responses display unavailable', (
    tester,
  ) async {
    await display.updateShowGenerationSpeed(true);
    await tester.pumpWidget(
      app([
        response.copyWith(clearGenerationMetrics: true),
        response.copyWith(
          id: 'partial',
          generationMetrics: const GenerationMetrics(
            predictedTokens: 20,
            predictedMilliseconds: 1000,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('预填充 暂无'), findsNWidgets(2));
    expect(find.text('解码 暂无'), findsOneWidget);
    expect(find.text('解码 20.0 tok/s'), findsOneWidget);
    expect(find.text('输入 未知（缓存 未知）'), findsNWidgets(2));
    expect(find.text('输出 未知'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('estimates are labeled and known zero cache is not unknown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await display.updateShowGenerationSpeed(true);
    await tester.pumpWidget(
      app([
        response.copyWith(
          generationMetrics: const GenerationMetrics(
            promptTokens: 100,
            promptMilliseconds: 200,
            predictedTokens: 20,
            predictedMilliseconds: 1000,
            prefillIsEstimated: true,
            decodeIsEstimated: true,
            inputTokens: 100,
            outputTokens: 20,
            cachedInputTokens: 0,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('预填充 500.0 tok/s (估算)'), findsOneWidget);
    expect(find.text('解码 20.0 tok/s (估算)'), findsOneWidget);
    expect(find.text('输入 100（缓存 0）'), findsOneWidget);
    expect(find.text('输出 20'), findsOneWidget);
    await capture(tester, 'chat-speed-estimated');
  });

  testWidgets(
    'streaming hides metrics until completion and revision changes replace them',
    (tester) async {
      await display.updateShowGenerationSpeed(true);
      streaming.update(response, isStreaming: true);
      await tester.pumpWidget(app([response]));
      await tester.pump();
      expect(
        find.byKey(const Key('chat_generation_speed_response')),
        findsNothing,
      );
      streaming.update(response, isStreaming: false);
      await tester.pumpAndSettle();
      expect(find.text('解码 20.0 tok/s'), findsOneWidget);
      streaming.update(
        response.copyWith(clearGenerationMetrics: true),
        isStreaming: false,
      );
      await tester.pumpAndSettle();
      expect(find.text('解码 20.0 tok/s'), findsNothing);
      expect(find.text('解码 暂无'), findsOneWidget);
    },
  );

  testWidgets(
    'phone layout supports enabled, disabled, missing data and large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final messages = [
        response.copyWith(
          id: 'user',
          role: ChatRole.user,
          content: '请显示每条回复的生成速度。',
        ),
        response,
        response.copyWith(
          id: 'legacy',
          content: '这是一条没有性能数据的历史回复。',
          clearGenerationMetrics: true,
        ),
      ];
      await tester.pumpWidget(app(messages));
      await tester.pumpAndSettle();
      await capture(tester, 'chat-speed-disabled');
      await display.updateShowGenerationSpeed(true);
      await tester.pumpAndSettle();
      await capture(tester, 'chat-speed-enabled');
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(320, 1100);
      await tester.pumpWidget(
        app(
          [
            response.copyWith(
              content: response.content * 3,
              modelName: 'long-model-name-' * 4,
            ),
          ],
          scale: 1.6,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prefill 500.0 tok/s'), findsOneWidget);
      expect(find.text('Decode 20.0 tok/s'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final row = find.byKey(const Key('chat_generation_speed_response'));
      expect(tester.getRect(row).right, lessThanOrEqualTo(300));
      await capture(tester, 'chat-speed-narrow-large-text');
    },
  );

  testWidgets('settings switch and row persist the choice', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app([], settings: true));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const Key('settings_generation_speed_switch'));
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const Key('settings_generation_speed_tile'))),
      alignment: 0.3,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(display.showGenerationSpeed, isTrue);
    expect(tester.widget<Switch>(toggle).value, isTrue);
    final restarted = ChatDisplayProvider(kvStorage: KvStorage());
    await restarted.load();
    expect(restarted.showGenerationSpeed, isTrue);
    restarted.dispose();
    await capture(tester, 'settings-speed-enabled');
    await tester.tap(find.byKey(const Key('settings_generation_speed_tile')));
    await tester.pumpAndSettle();
    expect(display.showGenerationSpeed, isFalse);
    expect(tester.takeException(), isNull);
    await capture(tester, 'settings-speed-disabled');
  });
}
