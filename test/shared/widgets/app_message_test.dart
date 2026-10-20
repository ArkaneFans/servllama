import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/navigation/app_navigation_observer.dart';

void main() {
  testWidgets(
    'routes messages below tabs, replaces, dismisses and handles popup context',
    (tester) async {
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [AppNavigationObserver()],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              pageContext = context;
              return AppScaffold(
                appBar: AppBar(
                  title: const Text('Page'),
                  bottom: const PreferredSize(
                    preferredSize: Size.fromHeight(64),
                    child: SizedBox(height: 64),
                  ),
                ),
                body: const SizedBox(),
              );
            },
          ),
        ),
      );
      AppMessage.show(pageContext, 'First');
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(const Key('app_top_message'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppBar)).dy + 12),
      );
      AppMessage.show(pageContext, 'Replacement');
      await tester.pumpAndSettle();
      expect(find.text('First'), findsNothing);
      expect(find.text('Replacement'), findsOneWidget);

      showDialog<void>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          content: TextButton(
            onPressed: () => AppMessage.show(
              dialogContext,
              'Popup error',
              tone: AppMessageTone.error,
            ),
            child: const Text('Trigger'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Replacement'), findsNothing);
      await tester.tap(find.text('Trigger'));
      await tester.pumpAndSettle();
      expect(find.text('Popup error'), findsOneWidget);
      await tester.tap(find.byKey(const Key('app_close_message')));
      await tester.pumpAndSettle();
      expect(find.text('Popup error'), findsNothing);
      AppMessage.show(pageContext, 'Expires');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Expires'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
