import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/widgets/chat_staged_message_list.dart';

void main() {
  group('ChatStagedMessageList', () {
    testWidgets('shows a bottom suffix first then expands to full window', (
      tester,
    ) async {
      final settledKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 's1',
          messages: _messages(count: 30),
          settledKeys: settledKeys,
        ),
      );

      expect(find.text('s1:m21'), findsNothing);
      expect(find.text('s1:m22'), findsOneWidget);
      expect(find.text('s1:m29'), findsOneWidget);
      expect(settledKeys, isEmpty);

      await tester.pump();

      expect(find.text('s1:m0'), findsOneWidget);
      expect(find.text('s1:m29'), findsOneWidget);
      expect(settledKeys, <String>['s1']);
    });

    testWidgets('does not stage small light windows', (tester) async {
      final settledKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 's1',
          messages: _messages(count: 3),
          settledKeys: settledKeys,
        ),
      );

      expect(find.text('s1:m0'), findsOneWidget);
      expect(find.text('s1:m2'), findsOneWidget);
      await tester.pump();
      expect(settledKeys, isEmpty);
    });

    testWidgets('ignores stale settle callbacks after conversation switch', (
      tester,
    ) async {
      final settledKeys = <String>[];

      await tester.pumpWidget(
        _host(
          conversationKey: 'a',
          messages: _messages(count: 30),
          settledKeys: settledKeys,
        ),
      );
      expect(find.text('a:m22'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          conversationKey: 'b',
          messages: _messages(count: 30),
          settledKeys: settledKeys,
        ),
      );

      expect(find.text('a:m22'), findsNothing);
      expect(find.text('b:m22'), findsOneWidget);

      await tester.pump();

      expect(find.text('b:m0'), findsOneWidget);
      expect(settledKeys, <String>['b']);
    });
  });
}

Widget _host({
  required String conversationKey,
  required List<ChatMessageRecord> messages,
  required List<String> settledKeys,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: ChatStagedMessageList(
      conversationKey: conversationKey,
      messages: messages,
      onSettled: settledKeys.add,
      builder: (context, visibleMessages) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final message in visibleMessages)
              Text('$conversationKey:${message.id}'),
          ],
        );
      },
    ),
  );
}

List<ChatMessageRecord> _messages({required int count}) {
  return List<ChatMessageRecord>.generate(count, (index) {
    return ChatMessageRecord(
      id: 'm$index',
      role: ChatRole.user,
      content: 'message $index',
      createdAt: DateTime(2024),
    );
  });
}
