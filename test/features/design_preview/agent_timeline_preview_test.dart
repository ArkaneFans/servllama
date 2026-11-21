import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/agent/widgets/tool_part_card.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/widgets/chat_agent_timeline.dart';
import 'package:servllama/features/design_preview/agent_timeline_preview.dart';
import 'package:servllama/features/design_preview/ui_primitives_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/text_sheen.dart';

const _play = Key('ui_lab_agent_play');
const _next = Key('ui_lab_agent_next');
const _reset = Key('ui_lab_agent_reset');
const _stage = Key('ui_lab_agent_stage');

Widget _host(Widget child, {Locale locale = const Locale('zh')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

ChatAgentTimeline _timeline(WidgetTester tester) =>
    tester.widget<ChatAgentTimeline>(find.byType(ChatAgentTimeline));

void main() {
  testWidgets('steps through live input and results in the same tool card', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AgentTimelinePreview()));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byKey(_play)))!;
    expect(_timeline(tester).streaming, isFalse);

    await _tap(tester, _reset);
    expect(find.byType(ToolPartCard), findsNothing);
    expect(find.textContaining(l.uiLabAnswer), findsNothing);

    await _tap(tester, _next);
    final card = find.byType(ToolPartCard);
    final originalState = tester.state(card);
    var part = tester.widget<ToolPartCard>(card).invocation.part;
    expect(part.inputComplete, isFalse);
    expect(part.result, isNull);
    expect(tester.widget<TextSheen>(find.byType(TextSheen)).enabled, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _tap(
      tester,
      ValueKey('tool_toggle_${tester.widget<ToolPartCard>(card).invocation.id}'),
    );
    expect(find.text(part.input), findsOneWidget);

    await _tap(tester, _next);
    part = tester.widget<ToolPartCard>(card).invocation.part;
    expect(part.arguments, {'query': l.uiLabAgentQuery});
    expect(tester.state(card), same(originalState));
    expect(find.text(l.v2ToolArguments), findsOneWidget);

    await _tap(tester, _next);
    expect(
      tester.widget<ToolPartCard>(card).invocation.part.state,
      ToolState.executing,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _tap(tester, _next);
    expect(tester.state(card), same(originalState));
    expect(find.text(l.uiLabAgentResult), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextSheen>(find.byType(TextSheen)).enabled, isFalse);

    // The final reasoning joins the activity block; earlier steps can fold.
    await _tap(tester, _next);
    expect(find.text(l.chatTimelineExpand(1)), findsOneWidget);
    final messageId = _timeline(tester).message.id;
    await _tap(tester, ValueKey('timeline_expand_$messageId:plan'));
    expect(find.text(l.chatTimelineCollapse), findsOneWidget);

    await _tap(tester, _next);
    expect(
      _timeline(tester).message.content,
      contains(l.uiLabAnswer.split('\n\n').first),
    );
    await _tap(tester, _next);
    expect(_timeline(tester).streaming, isFalse);
    expect(_timeline(tester).message.content, contains(l.uiLabAnswer));
    expect(_timeline(tester).message.parts.map((p) => p.kind), [
      MessagePartKind.text,
      MessagePartKind.reasoning,
      MessagePartKind.tool,
      MessagePartKind.reasoning,
      MessagePartKind.text,
    ]);
    expect(tester.widget<OutlinedButton>(find.byKey(_next)).onPressed, isNull);

    await _tap(tester, _reset);
    expect(find.byType(ToolPartCard), findsNothing);
    expect(_timeline(tester).message.content, l.uiLabAgentIntro);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('plays, pauses, resumes, and disposes playback locally', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AgentTimelinePreview()));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byKey(_play)))!;

    await _tap(tester, _play);
    expect(find.text(l.uiLabAgentPause), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byType(ToolPartCard), findsOneWidget);
    await _tap(tester, _play);
    final pausedStage = tester.widget<Text>(find.byKey(_stage)).data;
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<Text>(find.byKey(_stage)).data, pausedStage);

    await _tap(tester, _play);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1600));
    }
    expect(_timeline(tester).streaming, isFalse);
    expect(find.text(l.uiLabAgentPlay), findsOneWidget);
    await _tap(tester, _play);
    expect(find.byType(ToolPartCard), findsNothing);
    await _tap(tester, _next);
    expect(find.text(l.uiLabAgentPlay), findsOneWidget);
    await _tap(tester, _play);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    testWidgets(
      'gallery exposes the demo at 320 px in ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const UiPrimitivesPage(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ui_lab_scenes')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('ui_lab_agent_preview')),
          250,
          scrollable: find.descendant(
            of: find.byKey(const PageStorageKey('ui_lab_scene_list')),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.byType(ChatAgentTimeline), findsOneWidget);
        await _tap(tester, _play);
        await tester.pump(const Duration(milliseconds: 1600));
        await _tap(tester, _play);
        await tester.tap(find.byKey(const Key('ui_lab_brightness')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
