import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/app/providers/chat_timeout_provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  group('SettingsPage', () {
    setUp(() {
      // The providers persist through KvStorage before calling
      // notifyListeners, so an unmocked write leaves the UI stale. Each test
      // also gets its own KvStorage: the shared singleton caches a
      // SharedPreferences instance that outlives the per-test mock store.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('shows sections and language setting', (tester) async {
      final themeProvider = AppThemeModeProvider(kvStorage: KvStorage());
      final localeProvider = AppLocaleProvider(kvStorage: KvStorage());
      final chatTimeoutProvider = ChatTimeoutProvider(kvStorage: KvStorage());

      _useTallSurface(tester);

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
          chatTimeoutProvider: chatTimeoutProvider,
        ),
      );
      await tester.pump();

      expect(find.text('通用'), findsOneWidget);
      expect(find.text('关于'), findsNWidgets(2));
      expect(find.text('主题模式'), findsOneWidget);
      expect(find.text('跟随系统'), findsNWidgets(2));
      expect(find.text('应用语言'), findsOneWidget);
      expect(find.text('聊天超时时间'), findsOneWidget);
      expect(find.text('180 秒'), findsOneWidget);
      expect(find.text('关于'), findsWidgets);
    });

    testWidgets('updates MaterialApp themeMode from bottom sheet', (tester) async {
      final themeProvider = AppThemeModeProvider(kvStorage: KvStorage());
      final localeProvider = AppLocaleProvider(kvStorage: KvStorage());
      final chatTimeoutProvider = ChatTimeoutProvider(kvStorage: KvStorage());

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
          chatTimeoutProvider: chatTimeoutProvider,
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
      final themeProvider = AppThemeModeProvider(kvStorage: KvStorage());
      final localeProvider = AppLocaleProvider(kvStorage: KvStorage());
      final chatTimeoutProvider = ChatTimeoutProvider(kvStorage: KvStorage());

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
          chatTimeoutProvider: chatTimeoutProvider,
        ),
      );
      await tester.pump();

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).locale,
        const Locale('zh'),
      );

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
      expect(find.text('English (EN)'), findsWidgets);
    });

    testWidgets('updates chat timeout from bottom sheet', (tester) async {
      final themeProvider = AppThemeModeProvider(kvStorage: KvStorage());
      final localeProvider = AppLocaleProvider(kvStorage: KvStorage());
      final chatTimeoutProvider = ChatTimeoutProvider(kvStorage: KvStorage());

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
          chatTimeoutProvider: chatTimeoutProvider,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('settings_chat_timeout_tile')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('settings_chat_timeout_input')),
        '300',
      );
      await tester.tap(find.byKey(const Key('settings_chat_timeout_save_button')));
      await tester.pumpAndSettle();

      expect(chatTimeoutProvider.timeoutSeconds, 300);
      expect(find.text('300 秒'), findsOneWidget);
    });

    testWidgets('opens about page from about menu', (tester) async {
      _useTallSurface(tester);

      final themeProvider = AppThemeModeProvider(kvStorage: KvStorage());
      final localeProvider = AppLocaleProvider(kvStorage: KvStorage());
      final chatTimeoutProvider = ChatTimeoutProvider(kvStorage: KvStorage());

      await tester.pumpWidget(
        _TestHost(
          themeProvider: themeProvider,
          localeProvider: localeProvider,
          chatTimeoutProvider: chatTimeoutProvider,
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

/// The settings list is long enough that a default 800px test surface
/// leaves the About section unbuilt. Give it room instead of scrolling.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 5400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

class _TestHost extends StatelessWidget {
  const _TestHost({
    required this.themeProvider,
    required this.localeProvider,
    required this.chatTimeoutProvider,
  });

  final AppThemeModeProvider themeProvider;
  final AppLocaleProvider localeProvider;
  final ChatTimeoutProvider chatTimeoutProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppThemeModeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AppLocaleProvider>.value(value: localeProvider),
        ChangeNotifierProvider<ChatTimeoutProvider>.value(
          value: chatTimeoutProvider,
        ),
        // The download settings group lives on this page now (FR-X1).
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(),
        ),
      ],
      child: Consumer3<
        AppThemeModeProvider,
        AppLocaleProvider,
        ChatTimeoutProvider
      >(
        builder: (context, themeProvider, localeProvider, _, __) => MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          // Pinned so the Chinese assertions below do not depend on the
          // host OS locale; the language test still overrides it.
          locale: localeProvider.locale ?? const Locale('zh'),
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: themeProvider.themeMode,
          home: const SettingsPage(),
        ),
      ),
    );
  }
}
