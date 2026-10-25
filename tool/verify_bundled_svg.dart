// Hardware Release check; flutter_svg's Debug compiler does not use isolates.
// Build with: flutter build apk --release --target-platform android-arm64
//   --target tool/verify_bundled_svg.dart
// Install only on an idle test device with matching signing via adb install -r.
// This entrypoint does not open the database or read application settings.
// Restore the normal Release APK afterwards. Do not uninstall or clear data.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';

void main() {
  if (!kReleaseMode) {
    throw StateError('Run this verifier in Release on an Android device.');
  }
  runApp(const _SvgVerifier());
}

class _SvgVerifier extends StatefulWidget {
  const _SvgVerifier();

  @override
  State<_SvgVerifier> createState() => _SvgVerifierState();
}

class _SvgVerifierState extends State<_SvgVerifier> {
  final _cache = BundledSvgCache();
  final _boundary = GlobalKey();
  final _themes = [AppTheme.light(), AppTheme.dark()];
  ThemeData? _theme;
  Widget _mark = const SizedBox();
  String _status = 'Checking Release SVG loading and painting...';
  int _checks = 0;

  @override
  void initState() {
    super.initState();
    _cache.configureColors(
      identityColors: _themes.map((t) => t.colorScheme.onSurface),
      mcpColors: _themes.map((t) => t.colorScheme.onSurfaceVariant),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    try {
      // Real cached Futures, as created by normal business asset loading.
      // An explicit SvgAssetLoader(rootBundle) would capture these in Release.
      await rootBundle.loadString('assets/licenses/lobe-icons.txt');
      await rootBundle.loadString('assets/bin/llama_server_manifest.json');
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = [
        ...manifest.listAssets().where(
          (a) => a.startsWith('assets/ai-icons/') && a.endsWith('.svg'),
        ),
        'assets/app_icon.svg',
      ];
      if (assets.length < 2) throw StateError('Bundled SVG assets missing.');
      for (final asset in assets) {
        for (final theme in _themes) {
          final color = asset == 'assets/app_icon.svg'
              ? const Color(0xff000000)
              : asset.endsWith('/mcp.svg')
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.onSurface;
          final first = _cache.load(asset, color);
          final second = _cache.load(asset, color);
          if (!identical(await first, await second)) {
            throw StateError('Demand did not join compilation: $asset');
          }
          // Reentry must reuse compiled bytes and still paint a live picture.
          for (var visit = 0; visit < 2; visit++) {
            await _checkPixels(asset, color, theme);
          }
        }
        // Unsupported/animated palette values take the framework asset path.
        await _checkPixels(asset, const Color(0xff12579b), _themes.first);
      }
      final status = 'PASS: $_checks Release SVG pixel checks';
      debugPrintSynchronously('SVG_VERIFY $status');
      if (mounted) setState(() => _status = status);
    } catch (error, stack) {
      debugPrintSynchronously('SVG_VERIFY FAIL: $error\n$stack');
      if (mounted) setState(() => _status = 'FAIL: $error');
    }
  }

  Future<void> _checkPixels(String asset, Color color, ThemeData theme) async {
    setState(() {
      _theme = theme;
      _mark = BundledSvgAsset(
        asset,
        currentColor: color,
        width: 48,
        height: 48,
      );
    });
    // The fallback path is asynchronous; allow decoding but never accept an
    // indefinitely empty widget as a passing test.
    var opaque = 0;
    for (var attempt = 0; attempt < 30 && opaque <= 100; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      final image =
          await (_boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      try {
        final rgba = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        opaque = 0;
        for (var i = 3; i < rgba.length; i += 4) {
          if (rgba[i] != 0) opaque++;
        }
      } finally {
        image.dispose();
      }
    }
    if (opaque <= 100) throw StateError('Empty SVG: $asset $color');
    _checks++;
    // Unmount so the next visit exercises a fresh picture as real routes do.
    setState(() => _mark = const SizedBox());
    await WidgetsBinding.instance.endOfFrame;
  }

  @override
  void dispose() {
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Provider.value(
    value: _cache,
    child: MaterialApp(
      theme: _theme ?? _themes.first,
      home: Scaffold(
        appBar: AppBar(title: const Text('Release SVG verification')),
        body: Column(
          children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(_status)),
            RepaintBoundary(
              key: _boundary,
              child: SizedBox(width: 48, height: 48, child: _mark),
            ),
          ],
        ),
      ),
    ),
  );
}
