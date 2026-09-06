import 'package:flutter/material.dart';

const Duration kAnimFast = Duration(milliseconds: 180);
const Duration kAnim = Duration(milliseconds: 240);
const Duration kAnimSlow = Duration(milliseconds: 320);

/// A simple text switcher: fade + slide up on change.
class AnimatedTextSwap extends StatelessWidget {
  const AnimatedTextSwap({
    super.key,
    required this.text,
    this.style,
    this.duration = kAnim,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(anim);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Text(
        text,
        key: ValueKey(text),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
