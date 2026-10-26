import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/services/app_info_service.dart';
import 'package:servllama/features/about/pages/about_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const info = AppInfo(
    app: '2.0.0 / 15',
    llamaCpp: 'llama-test-build',
    mnn: '3.6.1 \u00b7 abcdef1234',
  );

  Future<void> pumpAbout(WidgetTester tester) async {
    final service = AppInfoService()..cached = info;
    await tester.pumpWidget(
      Provider.value(value: service, child: const _TestHost()),
    );
  }

  testWidgets('lays out branding and details from the top', (tester) async {
    await pumpAbout(tester);

    expect(find.text('ServLlama'), findsOneWidget);
    expect(
      find.text(
        '\u624b\u673a\u4e0a\u7684\u5927\u6a21\u578b\u63a8\u7406\u670d\u52a1\u5668',
      ),
      findsOneWidget,
    );
    expect(find.text('\u7248\u672c'), findsOneWidget);
    expect(find.text(info.app), findsOneWidget);
    expect(find.text('\u7cfb\u7edf'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('llama.cpp'), findsOneWidget);
    expect(find.text(info.llamaCpp), findsOneWidget);
    expect(find.text('MNN \u7248\u672c'), findsOneWidget);
    expect(find.text(info.mnn), findsOneWidget);
    expect(find.text('\u5728 GitHub \u4e0a\u70b9\u4eae Star'), findsOneWidget);
    expect(find.text('\u5f00\u6e90\u8bb8\u53ef'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(AboutPage)))!;
    expect(find.text(l10n.aboutVersionSubtitle), findsOneWidget);
    expect(find.text(l10n.aboutSystemSubtitle), findsOneWidget);
    expect(find.text(l10n.aboutLlamaCppSubtitle), findsOneWidget);
    expect(find.text(l10n.aboutMnnSubtitle), findsOneWidget);
    expect(find.text(l10n.aboutGitHubSubtitle), findsOneWidget);
    expect(find.text(l10n.aboutLicenseSubtitle), findsOneWidget);

    final tiles = tester.widgetList<SettingsMenuTile>(
      find.byType(SettingsMenuTile),
    );
    expect(tiles, isNotEmpty);
    expect(tiles.every((tile) => tile.subtitle?.isNotEmpty ?? false), isTrue);
    final groupedSections = tester
        .widgetList<SettingsSection>(find.byType(SettingsSection))
        .where((section) => section.padding == EdgeInsets.zero);
    expect(groupedSections, hasLength(2));

    final iconBox = tester.getRect(find.byKey(const Key('about_hero_icon')));
    final nameBox = tester.getRect(find.text('ServLlama'));
    expect(iconBox.top, lessThan(120));
    expect(nameBox.left, greaterThan(iconBox.right));
    expect(nameBox.top, lessThan(160));
  });

  testWidgets('tapping version copies it', (tester) async {
    await pumpAbout(tester);

    expect(find.text(info.app), findsOneWidget);
    await tester.tap(find.byKey(const Key('about_version_tile')));
    await tester.pump();

    expect(find.text('\u7248\u672c\u53f7\u5df2\u590d\u5236'), findsOneWidget);
  });

  testWidgets('tapping license opens the license page', (tester) async {
    await pumpAbout(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('about_license_tile')),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about_license_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(LicensePage), findsOneWidget);
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('zh'),
      home: AboutPage(),
    );
  }
}
