import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';

void main() {
  testWidgets(
    'prepared marks paint on the first frame and survive route disposal',
    (tester) async {
      final cache = BundledSvgCache();
      final theme = AppTheme.light();
      await tester.runAsync(
        () => cache.warmUp(
          identityColors: [theme.colorScheme.onSurface],
          mcpColors: [theme.colorScheme.onSurfaceVariant],
        ),
      );
      addTearDown(cache.dispose);
      for (var visit = 0; visit < 2; visit++) {
        await tester.pumpWidget(
          Provider.value(
            value: cache,
            child: MaterialApp(
              theme: theme,
              home: const Scaffold(
                body: AiIdentityIcon(providerId: 'preset:openai'),
              ),
            ),
          ),
        );
        expect(find.byType(SvgPicture), findsNothing);
        expect(
          find.descendant(
            of: find.byType(BundledSvgAsset),
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
