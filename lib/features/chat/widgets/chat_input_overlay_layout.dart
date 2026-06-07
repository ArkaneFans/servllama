import 'package:flutter/material.dart';

class ChatInputOverlayLayout extends StatelessWidget {
  const ChatInputOverlayLayout({
    super.key,
    required this.content,
    required this.bottomOverlay,
  });

  final Widget content;
  final Widget bottomOverlay;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: content),
        Align(
          alignment: Alignment.bottomCenter,
          child: UnconstrainedBox(
            constrainedAxis: Axis.horizontal,
            alignment: Alignment.bottomCenter,
            child: bottomOverlay,
          ),
        ),
      ],
    );
  }
}
