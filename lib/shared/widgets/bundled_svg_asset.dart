import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// Retains compiled bytes for the fixed app palette, not GPU pictures.
/// flutter_svg owns picture decoding, layout, painting and resource disposal.
class BundledSvgCache {
  final _bytecode = <(String, Color), ByteData>{};
  final _pending = <(String, Color), Future<ByteData>>{};
  bool _disposed = false;
  Set<Color> _identityColors = {}, _mcpColors = {};

  void configureColors({
    required Iterable<Color> identityColors,
    required Iterable<Color> mcpColors,
  }) {
    _identityColors = identityColors.toSet();
    _mcpColors = mcpColors.toSet();
  }

  // Theme transition colors and caller-specific tints use the framework cache,
  // rather than growing the retained-bytecode set on every animation frame.
  bool supports(String asset, Color color) =>
      !_disposed &&
      (asset == 'assets/app_icon.svg'
          ? color == const Color(0xff000000)
          : asset.startsWith('assets/ai-icons/') &&
                asset.endsWith('.svg') &&
                (asset.endsWith('/mcp.svg') ? _mcpColors : _identityColors)
                    .contains(color));

  ByteData? bytecode(String asset, Color color) => _bytecode[(asset, color)];

  Future<void> warmUp({
    required Iterable<Color> identityColors,
    required Iterable<Color> mcpColors,
    AssetBundle? bundle,
  }) async {
    configureColors(identityColors: identityColors, mcpColors: mcpColors);
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith('assets/ai-icons/') || !asset.endsWith('.svg')) {
        continue;
      }
      for (final color
          in asset.endsWith('/mcp.svg') ? _mcpColors : _identityColors) {
        await load(asset, color, bundle: assets);
      }
    }
    await load('assets/app_icon.svg', const Color(0xff000000), bundle: assets);
  }

  Future<ByteData> load(String asset, Color color, {AssetBundle? bundle}) {
    final key = (asset, color);
    final ready = _bytecode[key];
    if (ready != null) return SynchronousFuture(ready);
    final pending = _pending[key];
    if (pending != null) return pending;
    // Release SVG compilation runs in an isolate. Keep AssetBundle (and its
    // unsendable cached Futures) on the UI isolate; send only the SVG bytes.
    final loading = (bundle ?? rootBundle)
        .load(asset)
        .then(
          (data) => SvgBytesLoader(
            Uint8List.sublistView(data),
            theme: SvgTheme(currentColor: color),
          ).loadBytes(null),
        )
        .then((data) {
          if (!_disposed) _bytecode[key] = data;
          return data;
        });
    _pending[key] = loading;
    // Cached loaders can complete synchronously. Register cleanup only after
    // insertion, and handle the cleanup future's error as well as the caller's.
    loading.then<void>(
      (_) {
        _pending.remove(key);
      },
      onError: (Object error, StackTrace stack) {
        _pending.remove(key);
      },
    );
    return loading;
  }

  void dispose() {
    _disposed = true;
    _bytecode.clear();
  }
}

class BundledSvgAsset extends StatelessWidget {
  const BundledSvgAsset(
    this.asset, {
    super.key,
    this.width,
    this.height,
    this.currentColor = const Color(0xff000000),
  });
  final String asset;
  final double? width, height;
  final Color currentColor;

  @override
  Widget build(BuildContext context) {
    final cache = context.read<BundledSvgCache?>();
    if (cache?.supports(asset, currentColor) == true) {
      return SvgPicture(
        _BundledSvgLoader(cache!, asset, currentColor),
        width: width,
        height: height,
      );
    }
    return _fallback();
  }

  Widget _fallback() => SvgPicture.asset(
    asset,
    width: width,
    height: height,
    theme: SvgTheme(currentColor: currentColor),
  );
}

class _BundledSvgLoader extends BytesLoader {
  const _BundledSvgLoader(this.cache, this.asset, this.color);
  final BundledSvgCache cache;
  final String asset;
  final Color color;

  @override
  Future<ByteData> loadBytes(BuildContext? context) => cache.load(asset, color);

  @override
  int get hashCode => Object.hash(cache, asset, color);

  @override
  bool operator ==(Object other) =>
      other is _BundledSvgLoader &&
      other.cache == cache &&
      other.asset == asset &&
      other.color == color;

  @override
  String toString() => 'BundledSvgLoader($asset)';
}
