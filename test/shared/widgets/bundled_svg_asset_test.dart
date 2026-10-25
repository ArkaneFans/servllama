import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';

void main() {
  testWidgets('all warmed marks paint nonempty framework-equivalent pixels', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    final themes = [AppTheme.light(), AppTheme.dark()];
    await tester.runAsync(
      () => cache.warmUp(
        identityColors: themes.map((t) => t.colorScheme.onSurface),
        mcpColors: themes.map((t) => t.colorScheme.onSurfaceVariant),
      ),
    );
    addTearDown(cache.dispose);
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = [
      ...manifest.listAssets().where(
        (a) => a.startsWith('assets/ai-icons/') && a.endsWith('.svg'),
      ),
      'assets/app_icon.svg',
    ];
    for (final asset in assets) {
      for (final theme in themes) {
        final color = asset == 'assets/app_icon.svg'
            ? const Color(0xff000000)
            : asset.endsWith('/mcp.svg')
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onSurface;
        expect(cache.supports(asset, color), isTrue);
        final actual = await _pixels(
          tester,
          Provider.value(
            value: cache,
            child: BundledSvgAsset(asset, currentColor: color),
          ),
        );
        expect(
          _opaquePixels(actual),
          greaterThan(100),
          reason: '$asset $color',
        );
        final expected = await _pixels(
          tester,
          SvgPicture.asset(asset, theme: SvgTheme(currentColor: color)),
        );
        expect(actual, expected, reason: '$asset $color');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an early route joins the same compilation as warmup', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    final theme = AppTheme.light();
    final color = theme.colorScheme.onSurface;
    cache.configureColors(identityColors: [color], mcpColors: []);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      Provider.value(
        value: cache,
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: boundary,
                child: const AiIdentityIcon(
                  providerId: 'preset:anthropic',
                  framed: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
    await tester.runAsync(
      () => cache.load('assets/ai-icons/anthropic.svg', color),
    );
    await tester.pump();
    expect(_opaquePixels(await _capture(tester, boundary)), greaterThan(100));
    await tester.pumpWidget(const SizedBox());
    cache.dispose();
  });

  testWidgets('warmup and demand share one bounded-theme compilation', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    final color = AppTheme.light().colorScheme.onSurface;
    cache.configureColors(identityColors: [color], mcpColors: []);
    const asset = 'assets/ai-icons/openai.svg';
    final bundle = _CountingBundle();
    await tester.runAsync(() async {
      final first = cache.load(asset, color, bundle: bundle);
      final second = cache.load(asset, color, bundle: bundle);
      expect(identical(await first, await second), isTrue);
    });
    expect(bundle.loads[asset], 1);
    expect(cache.bytecode(asset, color), isNotNull);
    expect(cache.supports(asset, const Color(0xff12ab34)), isFalse);
    await cache.load(asset, color, bundle: bundle);
    expect(bundle.loads[asset], 1);
    cache.dispose();
    expect(cache.bytecode(asset, color), isNull);
    expect(cache.supports(asset, color), isFalse);
  });

  testWidgets('dispose during compilation does not retain late results', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    final bundle = _DelayedBundle();
    const asset = 'assets/ai-icons/anthropic.svg';
    const color = Color(0xffabcdef);
    final load = cache.load(asset, color, bundle: bundle);
    expect(identical(load, cache.load(asset, color, bundle: bundle)), isTrue);
    cache.dispose();
    await tester.runAsync(() async {
      bundle.ready.complete(await rootBundle.load(asset));
      await load;
    });
    expect(cache.bytecode(asset, color), isNull);
  });

  testWidgets('source read failures can retry without poisoning compilation', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    addTearDown(cache.dispose);
    final bundle = _RetryBundle();
    const asset = 'assets/ai-icons/anthropic.svg';
    const color = Color(0xff123456);
    await tester.runAsync(() async {
      await expectLater(
        cache.load(asset, color, bundle: bundle),
        throwsStateError,
      );
      expect(cache.bytecode(asset, color), isNull);
      final bytes = await cache.load(asset, color, bundle: bundle);
      expect(bytes.lengthInBytes, greaterThan(0));
      expect(cache.bytecode(asset, color), same(bytes));
    });
    expect(bundle.loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('source ByteData views preserve their offset and length', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    addTearDown(cache.dispose);
    const asset = 'assets/ai-icons/openai.svg';
    const color = Color(0xff234567);
    final bundle = _OffsetBundle();
    await tester.runAsync(() async {
      // The bundle deliberately retains an unsendable Future. The Release
      // verifier exercises the real isolate boundary with the same condition.
      await bundle.loadString(asset);
      final actual = await cache.load(asset, color, bundle: bundle);
      final expected = await const SvgAssetLoader(
        asset,
        theme: SvgTheme(currentColor: color),
      ).loadBytes(null);
      expect(actual.buffer.asUint8List(), expected.buffer.asUint8List());
    });
  });

  testWidgets('prepared marks paint on first frame after route reentry', (
    tester,
  ) async {
    final cache = BundledSvgCache();
    final color = AppTheme.light().colorScheme.onSurface;
    cache.configureColors(identityColors: [color], mcpColors: []);
    const asset = 'assets/ai-icons/openai.svg';
    await tester.runAsync(() => cache.load(asset, color));
    for (var visit = 0; visit < 2; visit++) {
      final bytes = await _pixels(
        tester,
        Provider.value(
          value: cache,
          child: BundledSvgAsset(asset, width: 48, currentColor: color),
        ),
        size: const Size(72, 48),
      );
      expect(_opaquePixels(bytes), greaterThan(100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    cache.dispose();
  });
}

// Capture the first pump, not just widget presence: a blank icon also builds.
Future<List<int>> _pixels(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(48, 48),
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  );
  return _capture(tester, key);
}

Future<List<int>> _capture(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!.buffer.asUint8List().toList();
    }))!;

int _opaquePixels(List<int> bytes) {
  var count = 0;
  for (var i = 3; i < bytes.length; i += 4) {
    if (bytes[i] != 0) count++;
  }
  return count;
}

class _CountingBundle extends CachingAssetBundle {
  final loads = <String, int>{};
  @override
  Future<ByteData> load(String key) {
    loads.update(key, (value) => value + 1, ifAbsent: () => 1);
    return rootBundle.load(key);
  }
}

class _DelayedBundle extends CachingAssetBundle {
  final ready = Completer<ByteData>();
  @override
  Future<ByteData> load(String key) => ready.future;
}

class _RetryBundle extends CachingAssetBundle {
  var loads = 0;
  @override
  Future<ByteData> load(String key) {
    if (++loads == 1) return Future.error(StateError('temporary read failure'));
    return rootBundle.load(key);
  }
}

class _OffsetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final source = Uint8List.sublistView(await rootBundle.load(key));
    final padded = Uint8List(source.length + 8)
      ..fillRange(0, source.length + 8, 255);
    padded.setRange(4, 4 + source.length, source);
    return ByteData.sublistView(padded, 4, 4 + source.length);
  }
}
