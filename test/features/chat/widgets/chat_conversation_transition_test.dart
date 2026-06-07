import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/widgets/chat_conversation_transition.dart';

void main() {
  group('ChatConversationTransition', () {
    testWidgets('keeps old child mounted until fade out completes', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
        ),
      );

      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B',
          committedKeys: committedKeys,
        ),
      );

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B'), findsNothing);
      expect(committedKeys, isEmpty);

      await tester.pump(const Duration(milliseconds: 90));

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B'), findsNothing);
      expect(committedKeys, isEmpty);

      await _pumpPastTransition(tester);

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation B'), findsOneWidget);
      expect(committedKeys, <String>['b']);
    });

    testWidgets('commits only the latest pending child during rapid switches', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B',
          committedKeys: committedKeys,
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(
        _host(
          conversationKey: 'c',
          text: 'Conversation C',
          committedKeys: committedKeys,
        ),
      );

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B'), findsNothing);
      expect(find.text('Conversation C'), findsNothing);

      await _pumpPastTransition(tester);

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation B'), findsNothing);
      expect(find.text('Conversation C'), findsOneWidget);
      expect(committedKeys, <String>['c']);
    });

    testWidgets('updates same conversation without running switch callback', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A updated',
          committedKeys: committedKeys,
        ),
      );

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation A updated'), findsOneWidget);
      expect(committedKeys, isEmpty);
    });

    testWidgets('delays next child without fade when body animation is off', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 100),
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 100),
        ),
      );

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B'), findsNothing);
      expect(committedKeys, isEmpty);

      await tester.pump(const Duration(milliseconds: 90));

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B'), findsNothing);
      expect(committedKeys, isEmpty);

      await _pumpPastNoFadeDelay(tester);

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation B'), findsOneWidget);
      expect(committedKeys, <String>['b']);
    });

    testWidgets('commits latest pending child after no-fade delay', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 100),
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 100),
        ),
      );
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(
        _host(
          conversationKey: 'c',
          text: 'Conversation C',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 100),
        ),
      );

      await tester.pump(const Duration(milliseconds: 90));

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation C'), findsNothing);

      await _pumpPastNoFadeDelay(tester);

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation C'), findsOneWidget);
      expect(committedKeys, <String>['c']);
    });

    testWidgets('waits for pending child to become ready before committing', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 50),
          maxUnreadyDelay: const Duration(milliseconds: 320),
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B loading',
          committedKeys: committedKeys,
          animateBody: false,
          readyToCommit: false,
          switchDelay: const Duration(milliseconds: 50),
          maxUnreadyDelay: const Duration(milliseconds: 320),
        ),
      );

      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B loading'), findsNothing);
      expect(committedKeys, isEmpty);

      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B ready',
          committedKeys: committedKeys,
          animateBody: false,
          readyToCommit: true,
          switchDelay: const Duration(milliseconds: 50),
          maxUnreadyDelay: const Duration(milliseconds: 320),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation B ready'), findsOneWidget);
      expect(committedKeys, <String>['b']);
    });

    testWidgets('commits unready pending child after max delay', (
      tester,
    ) async {
      final committedKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          text: 'Conversation A',
          committedKeys: committedKeys,
          animateBody: false,
          switchDelay: const Duration(milliseconds: 50),
          maxUnreadyDelay: const Duration(milliseconds: 120),
        ),
      );
      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          text: 'Conversation B loading',
          committedKeys: committedKeys,
          animateBody: false,
          readyToCommit: false,
          switchDelay: const Duration(milliseconds: 50),
          maxUnreadyDelay: const Duration(milliseconds: 120),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Conversation A'), findsOneWidget);
      expect(find.text('Conversation B loading'), findsNothing);
      expect(committedKeys, isEmpty);

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();

      expect(find.text('Conversation A'), findsNothing);
      expect(find.text('Conversation B loading'), findsOneWidget);
      expect(committedKeys, <String>['b']);
    });
  });
}

Widget _host({
  required String conversationKey,
  required String text,
  required List<String> committedKeys,
  bool animateBody = true,
  bool readyToCommit = true,
  Duration switchDelay = Duration.zero,
  Duration maxUnreadyDelay = const Duration(milliseconds: 320),
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ChatConversationTransition(
        conversationKey: conversationKey,
        duration: const Duration(milliseconds: 100),
        animateBody: animateBody,
        readyToCommit: readyToCommit,
        switchDelay: switchDelay,
        maxUnreadyDelay: maxUnreadyDelay,
        onConversationCommitted: committedKeys.add,
        child: Text(text),
      ),
    ),
  );
}

Future<void> _pumpPastTransition(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpPastNoFadeDelay(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
  await tester.pump();
}
