import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class XRayModeScreen extends ConsumerStatefulWidget {
  final String objectId;
  const XRayModeScreen({super.key, required this.objectId});

  @override
  ConsumerState<XRayModeScreen> createState() => _XRayModeScreenState();
}

class _XRayModeScreenState extends ConsumerState<XRayModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _xrayController;
  XRayStyle _style = XRayStyle.transparent;
  String? _selectedLayer;
  double _cutDepth = 0.5;

  @override
  void initState() {
    super.initState();
    _xrayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _xrayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // X-Ray viewport
          Positioned.fill(
            child: _XRayViewport(
              style: _style,
              controller: _xrayController,
              cutDepth: _cutDepth,
              selectedLayer: _selectedLayer,
            ),
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.glassWhite,
                        border: Border.all(color: AppTheme.glassWhiteStrong),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AppTheme.accentPurple,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'X-RAY VISION',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.accentPurple,
                      ),
                    ),
                  ),
                  // Scan pulse indicator
                  AnimatedBuilder(
                    animation: _xrayController,
                    builder: (context, _) => Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentPurple.withOpacity(
                          0.4 + _xrayController.value * 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentPurple.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Style selector
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: XRayStyle.values.map((s) {
                  final isSelected = s == _style;
                  return GestureDetector(
                    onTap: () => setState(() => _style = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentPurple.withOpacity(0.25)
                            : AppTheme.glassWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentPurple
                              : AppTheme.glassWhiteStrong,
                        ),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? AppTheme.accentPurple
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Internal layers panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _InternalLayersPanel(
              selectedLayer: _selectedLayer,
              onLayerSelected: (layer) => setState(() => _selectedLayer = layer),
            ),
          ),

          // Cut depth slider
          Positioned(
            bottom: 200,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'CROSS-SECTION',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(_cutDepth * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppTheme.accentPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: AppTheme.accentPurple,
                    thumbColor: AppTheme.accentPurple,
                    overlayColor: AppTheme.accentPurple.withOpacity(0.2),
                    inactiveTrackColor: AppTheme.glassWhite,
                  ),
                  child: Slider(
                    value: _cutDepth,
                    onChanged: (v) => setState(() => _cutDepth = v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XRayViewport extends StatelessWidget {
  final XRayStyle style;
  final AnimationController controller;
  final double cutDepth;
  final String? selectedLayer;

  const _XRayViewport({
    required this.style,
    required this.controller,
    required this.cutDepth,
    this.selectedLayer,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                AppTheme.accentPurple.withOpacity(0.08),
                AppTheme.backgroundDark,
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Grid pattern
              CustomPaint(
                painter: _XRayGridPainter(progress: controller.value),
                child: const SizedBox.expand(),
              ),

              // X-ray object visualization
              SizedBox(
                width: 280,
                height: 420,
                child: CustomPaint(
                  painter: _XRayObjectPainter(
                    style: style,
                    cutDepth: cutDepth,
                    progress: controller.value,
                  ),
                ),
              ),

              // Scan line
              Positioned(
                top: MediaQuery.of(context).size.height *
                    ((1 - cutDepth) * 0.4 + 0.1),
                left: 40,
                right: 40,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppTheme.accentPurple.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
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

class _XRayGridPainter extends CustomPainter {
  final double progress;
  _XRayGridPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentPurple.withOpacity(0.04)
      ..strokeWidth = 0.5;

    const step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_XRayGridPainter old) => old.progress != progress;
}

class _XRayObjectPainter extends CustomPainter {
  final XRayStyle style;
  final double cutDepth;
  final double progress;

  _XRayObjectPainter({
    required this.style,
    required this.cutDepth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Outer shell
    final shellPaint = Paint()
      ..color = AppTheme.accentPurple.withOpacity(style == XRayStyle.transparent ? 0.15 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.85,
          height: size.height * 0.65,
        ),
        const Radius.circular(12),
      ),
      shellPaint,
    );

    // Internal components (visible through x-ray)
    final internalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Motherboard
    internalPaint.color = AppTheme.primaryCyan.withOpacity(0.6);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy - 20),
        width: size.width * 0.65,
        height: 30,
      ),
      internalPaint,
    );

    // Battery
    internalPaint.color = AppTheme.accentGreen.withOpacity(0.6);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + 60),
        width: size.width * 0.55,
        height: 20,
      ),
      internalPaint,
    );

    // CPU
    internalPaint.color = AppTheme.warningAmber.withOpacity(0.7);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx - 30, cy - 20),
        width: 28,
        height: 28,
      ),
      internalPaint..style = PaintingStyle.fill,
    );

    // RAM
    internalPaint.color = AppTheme.accentPurple.withOpacity(0.7);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx + 40, cy - 20), width: 40, height: 10),
      internalPaint..style = PaintingStyle.fill,
    );

    // Cross-section cut line
    if (cutDepth < 1.0) {
      final cutY = cy - (size.height * 0.3) + (size.height * 0.6 * (1 - cutDepth));
      final cutPaint = Paint()
        ..color = AppTheme.accentPurple.withOpacity(0.7)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(cx - 120, cutY), Offset(cx + 120, cutY), cutPaint);
    }
  }

  @override
  bool shouldRepaint(_XRayObjectPainter old) =>
      old.cutDepth != cutDepth || old.progress != progress;
}

class _InternalLayersPanel extends StatelessWidget {
  final String? selectedLayer;
  final Function(String?) onLayerSelected;

  const _InternalLayersPanel({
    required this.selectedLayer,
    required this.onLayerSelected,
  });

  @override
  Widget build(BuildContext context) {
    final layers = [
      _Layer('Circuit Board', AppTheme.primaryCyan, Icons.memory),
      _Layer('Power System', AppTheme.accentGreen, Icons.battery_charging_full),
      _Layer('Thermal', AppTheme.accentOrange, Icons.thermostat),
      _Layer('Storage', AppTheme.accentPurple, Icons.storage),
      _Layer('I/O Ports', AppTheme.primaryBlue, Icons.usb),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.glassWhite)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INTERNAL LAYERS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: layers.map((layer) {
                final isSelected = selectedLayer == layer.name;
                return GestureDetector(
                  onTap: () => onLayerSelected(isSelected ? null : layer.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? layer.color.withOpacity(0.2)
                          : AppTheme.glassWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? layer.color : AppTheme.glassWhiteStrong,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: layer.color.withOpacity(0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(layer.icon, size: 16, color: layer.color),
                        const SizedBox(height: 4),
                        Text(
                          layer.name,
                          style: TextStyle(
                            color: layer.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Layer {
  final String name;
  final Color color;
  final IconData icon;

  _Layer(this.name, this.color, this.icon);
}

enum XRayStyle {
  transparent,
  wireframe,
  xray,
  thermal,
  crossSection;

  String get label => switch (this) {
    XRayStyle.transparent => 'GLASS',
    XRayStyle.wireframe => 'WIRE',
    XRayStyle.xray => 'X-RAY',
    XRayStyle.thermal => 'THERMAL',
    XRayStyle.crossSection => 'SECTION',
  };
}
