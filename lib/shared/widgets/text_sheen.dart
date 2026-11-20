import 'package:flutter/material.dart';

/// A moving band on text that is still loading. Its ticker stops when disabled,
/// offstage or reduced motion is requested; static text keeps its normal color.
class TextSheen extends StatefulWidget {
  const TextSheen({
    super.key,
    required this.enabled,
    required this.child,
    this.color,
  });

  final bool enabled;
  final Widget child;
  final Color? color;

  @override
  State<TextSheen> createState() => _TextSheenState();
}

class _TextSheenState extends State<TextSheen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant TextSheen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final animate =
        widget.enabled &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.of(context);
    if (animate == _animate) return;
    _animate = animate;
    if (animate) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_animate) return widget.child;
    final theme = Theme.of(context);
    final base = widget.color ?? theme.colorScheme.onSurface;
    final band = Color.lerp(
      base,
      theme.brightness == Brightness.dark ? Colors.black : Colors.white,
      .7,
    )!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final center = bounds.width * (_controller.value * 1.8 - .4);
            final halfWidth = bounds.width * .25;
            return LinearGradient(
              colors: [base, band, base],
              stops: const [0, .5, 1],
            ).createShader(
              Rect.fromLTRB(
                center - halfWidth,
                bounds.top,
                center + halfWidth,
                bounds.bottom,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
