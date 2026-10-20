import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Official Model Context Protocol mark.
///
/// The mark is bundled with the other provider/model logos. Its source and
/// license are recorded in `assets/ai-icons/sources.json`.
class McpIcon extends StatelessWidget {
  const McpIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return SvgPicture.asset(
      'assets/ai-icons/mcp.svg',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: resolvedColor),
    );
  }
}
