import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../screens/scanner_screen.dart';

class ScanFrameWidget extends StatelessWidget {
  final AnimationController scanLineController;
  final AnimationController pulseController;
  final bool isScanning;
  final ScanMode scanMode;

  const ScanFrameWidget({
    super.key,
    required this.scanLineController,
    required this.pulseController,
    required this.isScanning,
    required this.scanMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([scanLineController, pulseController]),
      builder: (context, child) {
        return SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            children: [
              // Outer frame
              CustomPaint(
                size: const Size(260, 260),
                painter: _ScanFramePainter(
                  progress: scanLineController.value,
                  pulse: pulseController.value,
                  isScanning: isScanning,
                  color: isScanning ? AppTheme.accentGreen : AppTheme.primaryCyan,
                ),
              ),
              // Scan line
              Positioned(
                top: 30 + (scanLineController.value * 200),
                left: 30,
                right: 30,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.primaryCyan.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  final double progress;
  final double pulse;
  final bool isScanning;
  final Color color;

  _ScanFramePainter({
    required this.progress,
    required this.pulse,
    required this.isScanning,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLen = 30.0;
    const inset = 8.0;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    final paint = Paint()
      ..color = color.withOpacity(0.6 + pulse * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLen), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLen, top), paint);

    // Top-right corner
    canvas.drawLine(Offset(right - cornerLen, top), Offset(right, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLen), paint);

    // Bottom-left corner
    canvas.drawLine(Offset(left, bottom - cornerLen), Offset(left, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLen, bottom), paint);

    // Bottom-right corner
    canvas.drawLine(Offset(right - cornerLen, bottom), Offset(right, bottom), paint);
    canvas.drawLine(Offset(right, bottom), Offset(right, bottom - cornerLen), paint);

    // Center crosshair (small)
    final cx = size.width / 2;
    final cy = size.height / 2;
    final crossPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(cx - 8, cy), Offset(cx + 8, cy), crossPaint);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), crossPaint);
    canvas.drawCircle(Offset(cx, cy), 3, crossPaint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) =>
      old.progress != progress || old.pulse != pulse;
}
