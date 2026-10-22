import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/features/chat/widgets/chat_conversation_hero.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Widget host({required int hour, double scale = 1, VoidCallback? action}) =>
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: ChatConversationHero(
              now: DateTime(2026, 10, 5, hour),
              onServer: action ?? () {},
              onSpeech: action ?? () {},
            ),
          ),
        ),
      );

  testWidgets('welcome uses a light greeting without the app icon', (
    tester,
  ) async {
    for (final entry in [
      (5, '早上好'),
      (11, '中午好'),
      (14, '下午好'),
      (18, '晚上好'),
      (0, '晚上好'),
    ]) {
      await tester.pumpWidget(host(hour: entry.$1));
      expect(find.text(entry.$2), findsOneWidget);
    }
    expect(find.byKey(const Key('chat_welcome_app_icon')), findsNothing);
    expect(find.byKey(const Key('chat_welcome_time_icon')), findsOneWidget);
    final greeting = tester.widget<Text>(
      find.byKey(const Key('chat_welcome_greeting')),
    );
    expect(greeting.style?.fontSize, 22);
    expect(greeting.style?.fontWeight, FontWeight.w400);
    final description = tester.widget<Text>(find.text('今天想聊些什么？'));
    expect(description.style?.fontSize, 18);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('large text in a short viewport keeps every shortcut reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(host(hour: 14, scale: 2, action: () => taps++));
    for (final id in ['server', 'speech']) {
      final card = find.byKey(Key('chat_welcome_$id'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      expect(tester.takeException(), isNull);
    }
    expect(taps, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('welcome shows two equal-height side-by-side cards', (
    tester,
  ) async {
    await tester.pumpWidget(host(hour: 14));

    final server = tester.getRect(find.byKey(const Key('chat_welcome_server')));
    final speech = tester.getRect(find.byKey(const Key('chat_welcome_speech')));
    expect(speech.left, greaterThan(server.right));
    expect(speech.top, server.top);
    expect(speech.height, server.height);
    expect(find.text('服务器'), findsOneWidget);
    expect(find.text('语音工坊'), findsOneWidget);
    expect(find.text('已停止'), findsNothing);
    expect(find.text('转录与合成'), findsNothing);
    expect(find.byKey(const Key('chat_welcome_asr')), findsNothing);
    expect(find.byKey(const Key('chat_welcome_tts')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
