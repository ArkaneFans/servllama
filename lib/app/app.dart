import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/app/providers/app_theme_mode_provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/app/main_scaffold.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class ServLlamaApp extends StatelessWidget {
  const ServLlamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppLocaleProvider();
            unawaited(provider.load());
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppThemeModeProvider();
            unawaited(provider.load());
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = ServerProvider()..refresh();
            unawaited(provider.loadSavedEndpoint());
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<ServerProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, serverProvider, chatProvider) {
            final provider = chatProvider ?? ChatProvider();
            provider.updateServerState(
              baseUrl: serverProvider.baseUrl,
              isServerRunning: serverProvider.isRunning,
            );
            return provider;
          },
        ),
      ],
      child: Consumer2<AppThemeModeProvider, AppLocaleProvider>(
        builder: (context, themeModeProvider, localeProvider, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeModeProvider.themeMode,
          locale: localeProvider.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainScaffold(),
        ),
      ),
    );
  }
}
