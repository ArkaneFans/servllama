import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/widgets/reasoning_level_picker.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';

import '../../support/chat_fixture.dart';

void main() {
  testWidgets(
    'assistant and chat pickers share a persisted thinking preference',
    (tester) async {
      final fixture = ChatFixture();
      await tester.runAsync(() async {
        await fixture.initialize();
        final connection = fixture.assistants.connections.singleWhere(
          (c) => c.id == 'provider',
        );
        await fixture.assistants.saveConnection(
          connection.changed({
            'modelCapabilities': {
              'model-one': const ModelCapabilities(
                supportsThinking: true,
              ).toJson(),
            },
          }),
        );
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        var closed = false;
        final closing = fixture.close().then((_) => closed = true);
        await settleBusiness(tester, () => closed);
        await closing;
      });
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        fixture.app(
          Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => AssistantEditor(
                          assistant: fixture.assistants.active!,
                        ),
                      ),
                    ),
                    child: const Text('Edit assistant'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const ChatPage()),
                    ),
                    child: const Text('Open chat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      Future<void> choose(ReasoningLevel level) async {
        final rect = tester.getRect(
          find.byKey(const Key('reasoning_level_slider')),
        );
        await tester.tapAt(
          Offset(
            rect.left + 24 + (rect.width - 48) * level.index / 6,
            rect.center.dy,
          ),
        );
        await settleBusiness(
          tester,
          () => fixture.assistants.active!.reasoningLevel == level,
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Edit assistant'));
      await tester.pumpAndSettle();
      final setting = find.byKey(const Key('assistant_reasoning'));
      await tester.ensureVisible(setting);
      await tester.tap(setting);
      await tester.pumpAndSettle();
      await choose(ReasoningLevel.high);
      await tester.pageBack();
      await settleBusiness(
        tester,
        () => find.byType(AssistantEditor).evaluate().isEmpty,
      );

      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
      final button = find.byKey(const Key('chat_reasoning_button'));
      expect(
        (tester.widget<IconButton>(button).icon as Icon).icon,
        ReasoningLevel.high.icon,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      await choose(ReasoningLevel.off);
      await tester.enterText(
        find.descendant(
          of: find.byType(ChatInputBar),
          matching: find.byType(TextField),
        ),
        'Hello',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('chat_send_button')));
      await settleBusiness(
        tester,
        () =>
            fixture.protocol.reasoningLevels.isNotEmpty &&
            !fixture.chat.isSending,
      );
      expect(fixture.protocol.reasoningLevels.single, ReasoningLevel.off);
      await tester.runAsync(() => fixture.assistants.load());
      expect(fixture.assistants.active!.reasoningLevel, ReasoningLevel.off);
      await tester.runAsync(
        () => fixture.chat.selectTarget(
          const ChatTarget.remote('provider', 'model-two'),
        ),
      );
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      expect(fixture.assistants.active!.reasoningLevel, ReasoningLevel.off);
      expect(tester.takeException(), isNull);
    },
  );
}
