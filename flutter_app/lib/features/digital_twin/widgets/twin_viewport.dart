import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../screens/digital_twin_screen.dart';
import '../../../core/theme/app_theme.dart';

class TwinViewport extends StatefulWidget {
  final String objectId;
  final ViewMode viewMode;
  final String? selectedComponentId;
  final Function(String?) onComponentSelected;

  const TwinViewport({
    super.key,
    required this.objectId,
    required this.viewMode,
    this.selectedComponentId,
    required this.onComponentSelected,
  });

  @override
  State<TwinViewport> createState() => _TwinViewportState();
}

class _TwinViewportState extends State<TwinViewport>
    with SingleTickerProviderStateMixin {
  late AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background grid
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF0D2040),
                AppTheme.backgroundDark,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _GridPainter(),
            child: const SizedBox.expand(),
          ),
        ),

        // Model viewer
        Center(
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ModelViewer(
              src: 'assets/models_3d/placeholder.glb',
              alt: 'Digital Twin Model',
              ar: false,
              autoRotate: true,
              autoRotateDelay: 0,
              cameraControls: true,
              shadowIntensity: 0.8,
              backgroundColor: Colors.transparent,
            ),
          ),
        ),

        // View mode shader overlay
        if (widget.viewMode != ViewMode.solid)
          Positioned.fill(
            child: _ViewModeOverlay(mode: widget.viewMode),
          ),

        // Component tap zones (overlaid)
        Positioned.fill(
          child: GestureDetector(
            onTapDown: (details) => _handleTap(details.localPosition),
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Ambient glow effect
        AnimatedBuilder(
          animation: _ambientController,
          builder: (context, child) {
            return Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 200,
                  height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryCyan.withOpacity(
                          0.15 + _ambientController.value * 0.15,
                        ),
                        blurRadius: 40,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Axis labels
        const Positioned(
          right: 16,
          bottom: 140,
          child: _AxisWidget(),
        ),
      ],
    );
  }

  void _handleTap(Offset position) {
    // Simplified hit-testing — in production use 3D ray-casting
    widget.onComponentSelected(
      widget.selectedComponentId == null ? 'comp_001' : null,
    );
  }
}

class _ViewModeOverlay extends StatelessWidget {
  final ViewMode mode;

  const _ViewModeOverlay({required this.mode});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: mode == ViewMode.xray
              ? const LinearGradient(
                  colors: [
                    Color(0x228B00FF),
                    Color(0x220066FF),
                  ],
                )
              : mode == ViewMode.thermal
                  ? const LinearGradient(
                      colors: [
                        Color(0x220066FF),
                        Color(0x2200FF88),
                        Color(0x22FFBE0B),
                        Color(0x22FF4757),
                      ],
                    )
                  : null,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryCyan.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

class _AxisWidget extends StatelessWidget {
  const _AxisWidget();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(painter: _AxisPainter()),
    );
  }
}

class _AxisPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const len = 18.0;

    void drawAxis(Offset end, Color color, String label) {
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + end.dx, cy + end.dy),
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx + end.dx + 2, cy + end.dy - 5));
    }

    drawAxis(const Offset(len, 0), Colors.red, 'X');
    drawAxis(const Offset(0, -len), Colors.green, 'Y');
    drawAxis(const Offset(-len * 0.5, len * 0.5), Colors.blue, 'Z');
  }

  @override
  bool shouldRepaint(_AxisPainter old) => false;
}
