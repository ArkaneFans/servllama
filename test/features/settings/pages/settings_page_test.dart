import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  group('SettingsPage', () {
    testWidgets('shows sections and language setting', (tester) async {
      final themeProvider = AppThemeModeProvider();
      final localeProvider = AppLocaleProvider();

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
        ),
      );
      await tester.pump();

      expect(find.text('通用'), findsOneWidget);
      expect(find.text('关于'), findsOneWidget);
      expect(find.text('主题模式'), findsOneWidget);
      expect(find.text('跟随系统'), findsNWidgets(2));
      expect(find.text('应用语言'), findsOneWidget);
      expect(find.text('关于'), findsWidgets);
    });

    testWidgets('updates MaterialApp themeMode from bottom sheet', (tester) async {
      final themeProvider = AppThemeModeProvider();
      final localeProvider = AppLocaleProvider();

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
        ),
      );
      await tester.pump();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );

      await tester.tap(find.byKey(const Key('settings_theme_mode_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_theme_mode_option_dark')));
      await tester.pumpAndSettle();

      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(find.text('深色'), findsOneWidget);
    });

    testWidgets('updates MaterialApp locale from bottom sheet', (tester) async {
      final themeProvider = AppThemeModeProvider();
      final localeProvider = AppLocaleProvider();

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
        ),
      );
      await tester.pump();

      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).locale, isNull);

      await tester.tap(find.byKey(const Key('settings_language_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings_language_option_en')));
      await tester.pumpAndSettle();

      expect(localeProvider.localeMode, AppLocaleMode.en);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('en'),
      );
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('English'), findsWidgets);
    });

    testWidgets('opens about page from about menu', (tester) async {
      final themeProvider = AppThemeModeProvider();
      final localeProvider = AppLocaleProvider();

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('关于').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('关于')),
        findsOneWidget,
      );
      expect(find.text('ServLlama'), findsOneWidget);
    });
  });
}

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.themeProvider,
    required this.localeProvider,
  });

  final AppThemeModeProvider themeProvider;
  final AppLocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppThemeModeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AppLocaleProvider>.value(value: localeProvider),
      ],
      child: Consumer2<AppThemeModeProvider, AppLocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) => MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeProvider.locale,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: themeProvider.themeMode,
          home: const SettingsPage(),
        ),
      ),
    );
  }
}
