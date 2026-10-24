import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter that draws a subtle, organic, rounded curved arrow
/// pointing from the "No trips, Import one" text downward to the '+' button.
class RoundedCurvedArrowPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const RoundedCurvedArrowPainter({
    this.color = const Color(0xFF8A99AD),
    this.strokeWidth = 2.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Start slightly right of center under the text
    final startX = size.width * 0.54;
    final startY = 6.0;

    // End point right above the bottom center '+' button
    final endX = size.width * 0.50;
    final endY = size.height - 10.0;

    // Cubic Bezier curve control points creating a graceful, rounded loop/swoop
    final cp1X = size.width * 0.72;
    final cp1Y = size.height * 0.30;

    final cp2X = size.width * 0.62;
    final cp2Y = size.height * 0.78;

    final path = Path();
    path.moveTo(startX, startY);
    path.cubicTo(cp1X, cp1Y, cp2X, cp2Y, endX, endY);
    canvas.drawPath(path, paint);

    // Rounded arrowhead at (endX, endY) pointing toward the button below
    final tangentDx = endX - cp2X;
    final tangentDy = endY - cp2Y;
    final angle = math.atan2(tangentDy, tangentDx);

    const headLength = 13.0;
    const headAngle = 0.52; // ~30 degrees

    final leftX = endX - headLength * math.cos(angle - headAngle);
    final leftY = endY - headLength * math.sin(angle - headAngle);

    final rightX = endX - headLength * math.cos(angle + headAngle);
    final rightY = endY - headLength * math.sin(angle + headAngle);

    final headPath = Path()
      ..moveTo(leftX, leftY)
      ..lineTo(endX, endY)
      ..lineTo(rightX, rightY);

    canvas.drawPath(headPath, paint);
  }

  @override
  bool shouldRepaint(covariant RoundedCurvedArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
