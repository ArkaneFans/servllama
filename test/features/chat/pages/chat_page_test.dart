import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';

import '../../../support/chat_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatFixture fixture;
  setUp(() async {
    fixture = ChatFixture();
    await fixture.initialize();
  });
  Future<void> withPage(
    WidgetTester tester,
    Future<void> Function() body,
  ) async {
    try {
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      var closed = false;
      final closing = fixture.close().then((_) => closed = true);
      await settleBusiness(tester, () => closed);
      await closing;
    }
  }

  testWidgets(
    'composer sends a message and new chat returns to the assistant draft',
    (tester) => withPage(tester, () async {
      await tester.pumpWidget(fixture.app(const ChatPage()));
      await tester.runAsync(() => fixture.chat.load(preloadMessages: false));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat_input_field')),
        'Hello',
      );
      await tester.pump();
      expect(fixture.chat.canSubmitInput, isTrue);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('chat_send_button')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await settleBusiness(
        tester,
        () => fixture.chat.selectedSession != null && !fixture.chat.isSending,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_message_list')),
          matching: find.text('Hello'),
        ),
        findsOneWidget,
      );
      expect(find.text('Reply'), findsOneWidget);
      expect(fixture.chat.currentDraft, isEmpty);
      await tester.tap(find.byTooltip('New conversation'));
      await settleBusiness(tester, () => fixture.chat.selectedSession == null);
      expect(find.byKey(const Key('chat_welcome_greeting')), findsOneWidget);
      expect(fixture.chat.currentAssistantId, 'assistant');
      await tester.runAsync(() async {
        expect(await fixture.repository.loadSessions(), hasLength(1));
      });
    }),
  );

  testWidgets(
    'reasoning expands and copy uses the visible reply',
    (tester) => withPage(tester, () async {
      fixture.protocol.events = const [
        AiEvent(reasoning: 'Reasoning text'),
        AiEvent(text: 'Answer text'),
        AiEvent(stopReason: 'stop'),
      ];
      await tester.runAsync(() => fixture.chat.sendMessage('Question'));
      final reply = fixture.chat.visibleMessages.last;
      await tester.pumpWidget(fixture.app(const ChatPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('chat_message_reasoning_${reply.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Reasoning text'), findsOneWidget);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
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
      await tester.tap(find.byKey(Key('chat_message_copy_button_${reply.id}')));
      await tester.pumpAndSettle();
      expect(copied, 'Answer text');
    }),
  );

  testWidgets(
    'editing creates a selectable version while keeping the reply',
    (tester) => withPage(tester, () async {
      await tester.runAsync(
        () => fixture.chat.sendMessage('Original question'),
      );
      final user = fixture.chat.visibleMessages.first;
      await tester.pumpWidget(fixture.app(const ChatPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('chat_message_edit_button_${user.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('chat_message_edit_field')),
        'Edited question',
      );
      await tester.tap(find.byKey(const Key('chat_message_edit_save_button')));
      await settleBusiness(
        tester,
        () => fixture.chat.visibleMessages.first.content == 'Edited question',
      );
      expect(find.text('Reply'), findsOneWidget);
      await tester.tap(
        find.byKey(Key('chat_message_version_previous_button_${user.id}')),
      );
      await settleBusiness(
        tester,
        () => fixture.chat.visibleMessages.first.content == 'Original question',
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('chat_message_list')),
          matching: find.text('Original question'),
        ),
        findsOneWidget,
      );
    }),
  );

  testWidgets(
    'regeneration keeps both replies available in the version selector',
    (tester) => withPage(tester, () async {
      await tester.runAsync(() => fixture.chat.sendMessage('Question'));
      final id = fixture.chat.visibleMessages.last.id;
      fixture.protocol.events = const [
        AiEvent(text: 'Another reply'),
        AiEvent(stopReason: 'stop'),
      ];
      await tester.pumpWidget(fixture.app(const ChatPage()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('chat_message_regenerate_button_$id')));
      await settleBusiness(
        tester,
        () =>
            !fixture.chat.isSending &&
            fixture.chat.visibleMessages.last.content == 'Another reply',
      );
      expect(find.text('Another reply'), findsOneWidget);
      await tester.tap(
        find.byKey(Key('chat_message_version_previous_button_$id')),
      );
      await settleBusiness(
        tester,
        () => fixture.chat.visibleMessages.last.content == 'Reply',
      );
      expect(find.text('Reply'), findsOneWidget);
    }),
  );
}
