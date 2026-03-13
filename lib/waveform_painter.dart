import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<double> left;
  final List<double> right;
  WaveformPainter({required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    if (left.isEmpty || right.isEmpty) {
      return;
    }
    final double h = size.height / 2;
    final double w = size.width / left.length;

    final paintL = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paintR = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    _drawPath(canvas, left, paintL, w, h);
    _drawPath(canvas, right, paintR, w, h);
  }

  void _drawPath(Canvas canvas, List<double> samples, Paint paint, double w, double h) {
    Path path = Path();
    if (samples.isEmpty) {
      return;
    }

    path.moveTo(0, h - samples[0] * h);
    for (int i = 1; i < samples.length; i++) {
      path.lineTo(i * w, h - samples[i] * h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.left != left || oldDelegate.right != right;
  }

}
