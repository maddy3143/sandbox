import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class MeasurementsScreen extends ConsumerWidget {
  final String objectId;
  const MeasurementsScreen({super.key, required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MeasurementVisualization().animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 20),
                _DimensionsGrid().animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                _AdvancedMeasurements().animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 16),
                _ARMeasurementTools().animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryCyan),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'MEASUREMENTS',
        style: Theme.of(context).textTheme.displaySmall,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.tune, color: AppTheme.primaryCyan),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppTheme.primaryCyan),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _MeasurementVisualization extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Object silhouette
          Container(
            width: 120,
            height: 160,
            decoration: BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.primaryCyan.withOpacity(0.3),
              ),
            ),
          ),

          // Dimension arrows
          CustomPaint(
            size: const Size(300, 220),
            painter: _DimensionArrowPainter(),
          ),

          // Dimension labels
          const Positioned(
            top: 20,
            child: _DimLabel('35.9 cm', AppTheme.accentGreen),
          ),
          const Positioned(
            right: 20,
            child: _DimLabel('2.1 cm', AppTheme.accentOrange),
          ),
          const Positioned(
            bottom: 20,
            child: _DimLabel('23.4 cm', AppTheme.accentPurple),
          ),
        ],
      ),
    );
  }
}

class _DimLabel extends StatelessWidget {
  final String value;
  final Color color;

  const _DimLabel(this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DimensionArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void drawDimLine(Offset start, Offset end, Color color) {
      final paint = Paint()
        ..color = color.withOpacity(0.6)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);

      // Arrowheads
      final dir = (end - start);
      final norm = dir / dir.distance;
      final perp = Offset(-norm.dy, norm.dx);
      const arrowLen = 6.0;
      canvas.drawLine(
        end,
        end - norm * arrowLen + perp * arrowLen * 0.5,
        paint,
      );
      canvas.drawLine(
        end,
        end - norm * arrowLen - perp * arrowLen * 0.5,
        paint,
      );
      canvas.drawLine(
        start,
        start + norm * arrowLen + perp * arrowLen * 0.5,
        paint,
      );
      canvas.drawLine(
        start,
        start + norm * arrowLen - perp * arrowLen * 0.5,
        paint,
      );
    }

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Width line (top)
    drawDimLine(
      Offset(cx - 55, cy - 85),
      Offset(cx + 55, cy - 85),
      AppTheme.accentGreen,
    );

    // Height line (right)
    drawDimLine(
      Offset(cx + 75, cy - 75),
      Offset(cx + 75, cy + 75),
      AppTheme.accentOrange,
    );

    // Depth line (bottom)
    drawDimLine(
      Offset(cx - 55, cy + 85),
      Offset(cx + 55, cy + 85),
      AppTheme.accentPurple,
    );
  }

  @override
  bool shouldRepaint(_DimensionArrowPainter old) => false;
}

class _DimensionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const measurements = [
      ('HEIGHT', '2.1 cm', Icons.height, AppTheme.primaryCyan),
      ('WIDTH', '35.9 cm', Icons.swap_horiz, AppTheme.accentGreen),
      ('DEPTH', '23.4 cm', Icons.open_in_full, AppTheme.accentOrange),
      ('WEIGHT', '1.85 kg', Icons.scale, AppTheme.accentPurple),
      ('VOLUME', '1765 cm³', Icons.view_in_ar, AppTheme.primaryBlue),
      ('SURFACE', '840.6 cm²', Icons.crop_square, Color(0xFF00D4AA)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIMENSIONS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: measurements.map((m) => _MeasureCard(
            label: m.$1,
            value: m.$2,
            icon: m.$3,
            color: m.$4,
          )).toList(),
        ),
      ],
    );
  }
}

class _MeasureCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MeasureCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedMeasurements extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADVANCED METRICS',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          _AdvRow('Screen Diagonal', '15.6 inches / 39.6 cm'),
          _AdvRow('Hinge Angle Range', '0° – 180°'),
          _AdvRow('Port Spacing', 'USB-A: 13mm apart'),
          _AdvRow('Keyboard Travel', '1.5 mm key travel'),
          _AdvRow('Weight Distribution', '52% front / 48% rear'),
          _AdvRow('Center of Mass', 'X: 18.1cm, Y: 1.1cm, Z: 11.2cm'),
          _AdvRow('Measurement Accuracy', '±2% (camera-based)'),
        ],
      ),
    );
  }
}

class _AdvRow extends StatelessWidget {
  final String label;
  final String value;

  const _AdvRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ARMeasurementTools extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.accentGreen.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AR MEASUREMENT TOOLS',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          _ARToolRow(
            icon: Icons.straighten,
            label: 'Custom Ruler',
            description: 'Measure any distance in AR',
            color: AppTheme.primaryCyan,
          ),
          _ARToolRow(
            icon: Icons.square_foot,
            label: 'Area Calculator',
            description: 'Calculate surface areas',
            color: AppTheme.accentGreen,
          ),
          _ARToolRow(
            icon: Icons.architecture,
            label: 'Angle Measure',
            description: 'Measure angles and slopes',
            color: AppTheme.accentOrange,
          ),
          _ARToolRow(
            icon: Icons.compare_arrows,
            label: 'Compare Objects',
            description: 'Size comparison overlay',
            color: AppTheme.accentPurple,
          ),
        ],
      ),
    );
  }
}

class _ARToolRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _ARToolRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 12, color: color.withOpacity(0.5)),
        ],
      ),
    );
  }
}
