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
              serverStatus: '已停止',
              onServer: action ?? () {},
              onTranscribe: action ?? () {},
              onSynthesize: action ?? () {},
            ),
          ),
        ),
      );

  testWidgets(
    'welcome shows app identity and unpersonalized local-time greeting',
    (tester) async {
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
      expect(find.byKey(const Key('chat_welcome_app_icon')), findsOneWidget);
      expect(find.byKey(const Key('chat_welcome_time_icon')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('large text in a short viewport keeps every shortcut reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var taps = 0;
    await tester.pumpWidget(host(hour: 14, scale: 2, action: () => taps++));
    for (final id in ['server', 'asr', 'tts']) {
      final card = find.byKey(Key('chat_welcome_$id'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      expect(tester.takeException(), isNull);
    }
    expect(taps, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
