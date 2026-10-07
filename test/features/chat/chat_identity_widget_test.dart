import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/features/chat/controllers/streaming_chat_message_notifier.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/message_author.dart';
import 'package:servllama/features/chat/widgets/chat_message_list.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class _Identities extends AssistantProvider {
  void update({List<Assistant>? values, String? active, UserProfile? user}) {
    if (values != null) assistants = values;
    if (active != null) activeId = active;
    if (user != null) profile = user;
    notifyListeners();
  }
}

void main() {
  late _Identities identities;
  late ScrollController scroll;
  late StreamingChatMessageNotifier streaming;
  const a = Assistant(id: 'a', name: 'Assistant A', avatar: '📚');
  const b = Assistant(id: 'b', name: 'Assistant B', avatar: '🦙');
  final message = ChatMessageRecord(
    id: 'a1',
    role: ChatRole.assistant,
    content: 'Assistant body',
    createdAt: DateTime(2026, 9, 27, 12, 34),
    modelName: 'actual-model',
    author: const MessageAuthor(assistantId: 'a', name: 'Original A'),
  );
  setUp(() {
    identities = _Identities()
      ..update(
        values: [a, b],
        active: 'b',
        user: const UserProfile(name: 'Local user', avatar: '🌿'),
      );
    scroll = ScrollController();
    streaming = StreamingChatMessageNotifier();
  });
  tearDown(() {
    identities.dispose();
    scroll.dispose();
    streaming.dispose();
  });
  Widget app(
    List<ChatMessageRecord> messages, {
    double scale = 1,
    bool withIdentities = true,
  }) {
    final result = MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: ChatMessageList(
          controller: scroll,
          streamingMessages: streaming,
          messages: messages,
          draftMessageId: null,
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
    );
    return withIdentities
        ? ChangeNotifierProvider<AssistantProvider>.value(
            value: identities,
            child: result,
          )
        : result;
  }

  Finder header(String id) => find.byKey(Key('chat_message_identity_$id'));
  Finder footer(String id) => find.byKey(Key('chat_message_footer_$id'));

  testWidgets(
    'headers use profile and message author, with model and time after the body',
    (tester) async {
      final user = message.copyWith(
        id: 'u1',
        role: ChatRole.user,
        content: 'User body',
        clearAuthor: true,
      );
      await tester.pumpWidget(app([user, message]));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: header('a1'), matching: find.text('Assistant A')),
        findsOneWidget,
      );
      expect(find.text('Assistant B'), findsNothing);
      expect(
        find.descendant(of: header('u1'), matching: find.text('Local user')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IdentityAvatar>(
              find.descendant(
                of: header('a1'),
                matching: find.byType(IdentityAvatar),
              ),
            )
            .value,
        '📚',
      );
      expect(
        tester.getTopLeft(footer('a1')).dy,
        greaterThan(tester.getBottomLeft(find.text('Assistant body')).dy),
      );
      expect(
        find.descendant(of: footer('a1'), matching: find.text('actual-model')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer('a1'), matching: find.text('12:34')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(
              find.descendant(
                of: header('u1'),
                matching: find.byType(IdentityAvatar),
              ),
            )
            .dx,
        greaterThan(tester.getTopRight(find.text('Local user')).dx),
      );
      identities.update(active: 'a');
      await tester.pump();
      identities.update(active: 'b');
      await tester.pump();
      expect(find.text('Assistant A'), findsOneWidget);
      identities.update(
        values: [
          a.changed({'name': 'Renamed A', 'avatar': '⚡'}),
          b,
        ],
      );
      await tester.pump();
      expect(find.text('Renamed A'), findsOneWidget);
      expect(
        tester
            .widget<IdentityAvatar>(
              find.descendant(
                of: header('a1'),
                matching: find.byType(IdentityAvatar),
              ),
            )
            .value,
        '⚡',
      );
      identities.update(values: [b]);
      await tester.pump();
      expect(find.text('Original A'), findsOneWidget);
      expect(find.text('Assistant B'), findsNothing);
    },
  );

  testWidgets(
    'unknown legacy authors stay generic and image-only messages keep their timestamp',
    (tester) async {
      await tester.pumpWidget(
        app([
          message.copyWith(clearAuthor: true),
          message.copyWith(
            id: 'image',
            role: ChatRole.user,
            content: '',
            imageFilePaths: ['/missing-fixture.png'],
            clearAuthor: true,
          ),
        ], withIdentities: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: header('a1'), matching: find.text('Assistant')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header('image'), matching: find.text('User')),
        findsOneWidget,
      );
      expect(footer('image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long names and model metadata fit a narrow screen at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      identities.update(
        values: [
          a.changed({'name': 'A long assistant name ' * 6}),
        ],
      );
      await tester.pumpWidget(
        app([
          message.copyWith(modelName: 'provider-model-with-long-name-' * 5),
        ], scale: 1.8),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(header('a1')).right, lessThanOrEqualTo(360));
      expect(tester.getRect(footer('a1')).right, lessThanOrEqualTo(360));
    },
  );
}
