import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// Keeps decoded, app-owned marks alive across routes. flutter_svg's byte
/// cache alone does not retain pictures after the last icon leaves a route.
class BundledSvgCache {
  final _pictures = <(String, Color), PictureInfo>{};
  final _pending = <(String, Color), Future<void>>{};
  bool _disposed = false;

  PictureInfo? picture(String asset, Color color) => _pictures[(asset, color)];

  Future<void> warmUp({
    required Iterable<Color> identityColors,
    required Iterable<Color> mcpColors,
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    final manifest = await AssetManifest.loadFromAssetBundle(assets);
    await Future.wait([
      for (final asset in manifest.listAssets())
        if (asset.startsWith('assets/ai-icons/') && asset.endsWith('.svg'))
          for (final color
              in asset.endsWith('/mcp.svg')
                  ? mcpColors.toSet()
                  : identityColors.toSet())
            _load(asset, color, assets),
      _load('assets/app_icon.svg', const Color(0xff000000), assets),
    ]);
  }

  Future<void> _load(String asset, Color color, AssetBundle bundle) {
    final key = (asset, color);
    if (_pictures.containsKey(key)) return Future<void>.value();
    return _pending.putIfAbsent(key, () async {
      try {
        final picture = await vg.loadPicture(
          SvgAssetLoader(
            asset,
            assetBundle: bundle,
            theme: SvgTheme(currentColor: color),
          ),
          null,
        );
        if (_disposed) {
          picture.picture.dispose();
        } else {
          _pictures[key] = picture;
        }
      } finally {
        _pending.remove(key);
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final picture in _pictures.values) {
      picture.picture.dispose();
    }
    _pictures.clear();
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
    final picture = context.read<BundledSvgCache?>()?.picture(
      asset,
      currentColor,
    );
    if (picture == null) {
      return SvgPicture.asset(
        asset,
        width: width,
        height: height,
        theme: SvgTheme(currentColor: currentColor),
      );
    }
    return SizedBox(
      width: width ?? picture.size.width,
      height: height ?? picture.size.height,
      child: CustomPaint(painter: _SvgPainter(picture)),
    );
  }
}

class _SvgPainter extends CustomPainter {
  _SvgPainter(this.info);
  final PictureInfo info;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(BoxFit.contain, info.size, size);
    final destination = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(destination.left, destination.top);
    canvas.scale(
      destination.width / info.size.width,
      destination.height / info.size.height,
    );
    canvas.drawPicture(info.picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgPainter oldDelegate) => oldDelegate.info != info;
}
