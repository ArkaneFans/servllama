import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_model_icon_data.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';

void main() {
  Widget harness({ChatModelIconData? modelIcon}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ChatInputBar(
          controller: TextEditingController(),
          hintText: 'Hint',
          isServerRunning: false,
          isServerBusy: false,
          modelLabel: 'Model',
          canOpenModels: true,
          isModelLoading: false,
          hasLoadedModel: false,
          canSend: true,
          isSending: false,
          onServerAction: () {},
          onOpenModels: () {},
          onSend: () {},
          onStop: () {},
          onPickFromGallery: () {},
          pendingImageAttachments: const [],
          onRemoveImageAttachment: (_) {},
          modelIcon: modelIcon,
        ),
      ),
    );
  }

  Finder selectorButton() =>
      find.byKey(const Key('chat_model_selector_button'));

  testWidgets('shows the neutral layers glyph without a selected model', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(
      find.descendant(
        of: selectorButton(),
        matching: find.byIcon(Icons.layers_outlined),
      ),
      findsOneWidget,
    );
    expect(find.byType(AiIdentityIcon), findsNothing);
  });

  testWidgets('replaces the glyph with the selected model brand identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        modelIcon: const ChatModelIconData(
          model: 'deepseek-chat',
          local: false,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.descendant(
        of: selectorButton(),
        matching: find.byType(AiIdentityIcon),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: selectorButton(),
        matching: find.byIcon(Icons.layers_outlined),
      ),
      findsNothing,
    );
  });
}
