import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Anel de progresso (0 a 1). Usado nos cards de exercício e no cronômetro de descanso.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 38,
    this.stroke = 4,
    this.color = AppColors.volt,
    this.child,
    this.semanticsLabel,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Widget? child;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(value.clamp(0, 1).toDouble(), stroke, color),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color);

  final double value;
  final double stroke;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.overlay;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    // começa no topo (-90°) e avança no sentido horário
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.stroke != stroke || old.color != color;
}
