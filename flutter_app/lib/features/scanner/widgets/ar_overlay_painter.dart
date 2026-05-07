import 'package:flutter/material.dart';
import '../providers/scanner_provider.dart';
import '../../../core/theme/app_theme.dart';

class AROverlayPainter extends CustomPainter {
  final List<DetectedObjectPreview> detectedObjects;
  final Size screenSize;

  AROverlayPainter({
    required this.detectedObjects,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final obj in detectedObjects) {
      _drawBoundingBox(canvas, size, obj);
      _drawCornerAccents(canvas, size, obj);
    }
  }

  void _drawBoundingBox(Canvas canvas, Size size, DetectedObjectPreview obj) {
    if (obj.boundingBox.length < 4) return;

    final left = obj.boundingBox[0] * size.width;
    final top = obj.boundingBox[1] * size.height;
    final right = obj.boundingBox[2] * size.width;
    final bottom = obj.boundingBox[3] * size.height;

    final boxPaint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), boxPaint);

    // Fill highlight
    final fillPaint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), fillPaint);
  }

  void _drawCornerAccents(
    Canvas canvas,
    Size size,
    DetectedObjectPreview obj,
  ) {
    if (obj.boundingBox.length < 4) return;

    final left = obj.boundingBox[0] * size.width;
    final top = obj.boundingBox[1] * size.height;
    final right = obj.boundingBox[2] * size.width;
    final bottom = obj.boundingBox[3] * size.height;
    const cornerLen = 16.0;

    final accentPaint = Paint()
      ..color = AppTheme.primaryCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), accentPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), accentPaint);

    // Top-right
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right, top), accentPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), accentPaint);

    // Bottom-left
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom), accentPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), accentPaint);

    // Bottom-right
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right, bottom), accentPaint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), accentPaint);
  }

  @override
  bool shouldRepaint(AROverlayPainter old) =>
      old.detectedObjects != detectedObjects;
}
