import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/models/chat_model_icon_data.dart';
import 'package:servllama/features/chat/widgets/chat_input_bar.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';

void main() {
  Widget harness({
    ChatModelIconData? modelIcon,
    double bottomSafeArea = 0,
    double keyboardInset = 0,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(
            bottom: keyboardInset == 0 ? bottomSafeArea : 0,
          ),
          viewPadding: EdgeInsets.only(bottom: bottomSafeArea),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatInputBar(
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
      ),
    );
  }

  Finder selectorButton() =>
      find.byKey(const Key('chat_model_selector_button'));

  testWidgets('composer keeps 4 dp above the bottom safe area', (tester) async {
    await tester.pumpWidget(harness(bottomSafeArea: 32));
    await tester.pump();
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final bottom = tester
        .getBottomLeft(find.byKey(const Key('chat_composer_surface')))
        .dy;
    expect(bottom, screenHeight - 32 - 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'composer follows the keyboard without retaining system bottom padding',
    (tester) async {
      await tester.pumpWidget(harness(bottomSafeArea: 32, keyboardInset: 280));
      await tester.pump();
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final bottom = tester
          .getBottomLeft(find.byKey(const Key('chat_composer_surface')))
          .dy;
      expect(bottom, screenHeight - 280 - 4);
      expect(tester.takeException(), isNull);
    },
  );

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
