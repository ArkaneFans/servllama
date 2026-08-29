import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servllama/features/about/pages/about_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PackageInfo.setMockInitialValues(
      appName: 'ServLlama',
      packageName: 'com.arkanefans.servllama',
      version: '1.1.0',
      buildNumber: '9',
      buildSignature: '',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.arkanefans.mnn_engine/methods'),
          (call) async {
            if (call.method != 'initialize') {
              return null;
            }
            return <String, Object?>{
              'pluginVersion': '0.0.2',
              'mnnVersion': '3.2.0',
              'mnnCommit': 'abcdef123456',
              'abi': 'arm64-v8a',
              'androidApiLevel': 36,
              'ndkVersion': '27.0',
              'nativeLibraryLoaded': true,
              'testRootPath': '/tmp',
            };
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.arkanefans.mnn_engine/methods'),
          null,
        );
  });

  Future<void> pumpAbout(WidgetTester tester) async {
    await tester.pumpWidget(const _TestHost());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('lays out branding and details from the top', (tester) async {
    await pumpAbout(tester);

    expect(find.text('ServLlama'), findsOneWidget);
    expect(find.text('\u624b\u673a\u4e0a\u7684\u5927\u6a21\u578b\u63a8\u7406\u670d\u52a1\u5668'), findsOneWidget);
    expect(find.text('\u7248\u672c'), findsOneWidget);
    expect(find.text('1.1.0 / 9'), findsOneWidget);
    expect(find.text('\u7cfb\u7edf'), findsOneWidget);
    expect(find.text('Android'), findsOneWidget);
    expect(find.text('llama.cpp'), findsOneWidget);
    expect(find.text('b10441'), findsOneWidget);
    expect(find.text('MNN \u7248\u672c'), findsOneWidget);
    expect(find.text('3.2.0 \u00b7 abcdef1234'), findsOneWidget);
    expect(find.text('\u5728 GitHub \u4e0a\u70b9\u4eae Star'), findsOneWidget);
    expect(find.text('\u5f00\u6e90\u8bb8\u53ef'), findsOneWidget);

    final iconBox = tester.getRect(find.byKey(const Key('about_hero_icon')));
    final nameBox = tester.getRect(find.text('ServLlama'));
    expect(iconBox.top, lessThan(120));
    expect(nameBox.left, greaterThan(iconBox.right));
    expect(nameBox.top, lessThan(160));
  });

  testWidgets('tapping version copies it', (tester) async {
    await pumpAbout(tester);

    expect(find.text('1.1.0 / 9'), findsOneWidget);
    await tester.tap(find.byKey(const Key('about_version_tile')));
    await tester.pump();

    expect(find.text('\u7248\u672c\u53f7\u5df2\u590d\u5236'), findsOneWidget);
  });

  testWidgets('tapping license opens the license page', (tester) async {
    await pumpAbout(tester);

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
