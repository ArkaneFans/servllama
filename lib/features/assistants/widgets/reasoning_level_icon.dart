import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/assistant.dart';

class ReasoningLevelIcon extends StatelessWidget {
  const ReasoningLevelIcon({
    super.key,
    required this.level,
    this.size,
    this.color,
  });

  final ReasoningLevel level;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    var tint = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    if (theme.opacity != null && theme.opacity != 1) {
      tint = tint.withValues(alpha: tint.a * theme.opacity!);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimension,
        child: CustomPaint(painter: _ReasoningPainter(level, tint)),
      ),
    );
  }
}

class _ReasoningPainter extends CustomPainter {
  const _ReasoningPainter(this.level, this.color);

  final ReasoningLevel level;
  final Color color;

  static final _bulb = Path()
    ..moveTo(6.08938, 14.9992)
    ..cubicTo(5.71097, 14.1486, 5.5, 13.2023, 5.5, 12.2051)
    ..cubicTo(5.5, 8.50154, 8.41015, 5.49921, 12, 5.49921)
    ..cubicTo(15.5899, 5.49921, 18.5, 8.50154, 18.5, 12.2051)
    ..cubicTo(18.5, 13.2023, 18.289, 14.1486, 17.9106, 14.9992)
    ..moveTo(14.517, 19.3056)
    ..cubicTo(15.5274, 18.9788, 15.9326, 18.054, 16.0466, 17.1238)
    ..cubicTo(16.0806, 16.8459, 15.852, 16.6154, 15.572, 16.6154)
    ..lineTo(8.47685, 16.6156)
    ..cubicTo(8.18725, 16.6156, 7.95467, 16.8614, 7.98925, 17.1489)
    ..cubicTo(8.1009, 18.0773, 8.3827, 18.7555, 9.45345, 19.3056)
    ..lineTo(14.517, 19.3056)
    ..cubicTo(14.3955, 21.2506, 13.8338, 22.0209, 12.0068, 21.9993)
    ..cubicTo(10.0526, 22.0354, 9.60303, 21.0833, 9.45345, 19.3056);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(
      (size.width - size.shortestSide) / 2,
      (size.height - size.shortestSide) / 2,
    );
    canvas.scale(size.shortestSide / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_bulb, paint);

    final angles = switch (level) {
      ReasoningLevel.off => const <int>[],
      ReasoningLevel.low => const [45, 90, 135],
      ReasoningLevel.auto ||
      ReasoningLevel.medium => const [0, 45, 90, 135, 180],
      ReasoningLevel.high => const [
        0,
        22.5,
        45,
        67.5,
        90,
        112.5,
        135,
        157.5,
        180,
      ],
      ReasoningLevel.xhigh => const [
        -22.5,
        0,
        22.5,
        45,
        67.5,
        90,
        112.5,
        135,
        157.5,
        180,
        202.5,
      ],
      ReasoningLevel.max => const [
        -45,
        -22.5,
        0,
        22.5,
        45,
        67.5,
        90,
        112.5,
        135,
        157.5,
        180,
        202.5,
        225,
      ],
    };
    for (final angle in angles) {
      final radians = angle * math.pi / 180;
      final direction = Offset(math.cos(radians), -math.sin(radians));
      canvas.drawLine(
        const Offset(12, 12) + direction * 9,
        const Offset(12, 12) + direction * 10,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReasoningPainter oldDelegate) =>
      level != oldDelegate.level || color != oldDelegate.color;
}
