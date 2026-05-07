import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class DiagnosticsScreen extends ConsumerWidget {
  final String objectId;
  const DiagnosticsScreen({super.key, required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.backgroundDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.errorRed),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'DIAGNOSTICS',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.errorRed,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryCyan),
                onPressed: () {},
                tooltip: 'Scan for damage',
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HealthDashboard().animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 20),
                _ComponentHealthGrid().animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),
                _DamageAnalysis().animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 20),
                _FailurePrediction().animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 20),
                _MaintenanceAlerts().animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.accentGreen.withOpacity(0.4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OVERALL HEALTH',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const Text(
                    'Last scanned: just now',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              // Health score circle
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: 0.95,
                      strokeWidth: 6,
                      backgroundColor: AppTheme.glassWhite,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.accentGreen),
                    ),
                  ),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '95',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _StatusChip('NO DAMAGE', AppTheme.accentGreen, Icons.check_circle),
              _StatusChip('EXCELLENT', AppTheme.primaryCyan, Icons.star),
              _StatusChip('LOW RISK', AppTheme.accentGreen, Icons.shield),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip(this.label, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentHealthGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const components = [
      _ComponentHealth('Motherboard', 98, AppTheme.primaryCyan),
      _ComponentHealth('Battery', 82, AppTheme.accentGreen),
      _ComponentHealth('Display', 97, AppTheme.primaryCyan),
      _ComponentHealth('Storage', 94, AppTheme.accentGreen),
      _ComponentHealth('RAM', 99, AppTheme.primaryCyan),
      _ComponentHealth('Fan/Cooling', 88, AppTheme.accentGreen),
      _ComponentHealth('Keyboard', 100, AppTheme.primaryCyan),
      _ComponentHealth('Ports', 95, AppTheme.accentGreen),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMPONENT HEALTH',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        ...components.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _HealthBar(component: c),
        )),
      ],
    );
  }
}

class _ComponentHealth {
  final String name;
  final int health;
  final Color color;

  const _ComponentHealth(this.name, this.health, this.color);
}

class _HealthBar extends StatelessWidget {
  final _ComponentHealth component;

  const _HealthBar({required this.component});

  Color get _color {
    if (component.health > 85) return AppTheme.accentGreen;
    if (component.health > 60) return AppTheme.warningAmber;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            component.name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: component.health / 100,
              backgroundColor: AppTheme.glassWhite,
              valueColor: AlwaysStoppedAnimation(_color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${component.health}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DamageAnalysis extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAMAGE ANALYSIS', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          const _DamageRow(
            type: 'Physical Damage',
            status: 'None Detected',
            icon: Icons.broken_image_outlined,
            isGood: true,
          ),
          const _DamageRow(
            type: 'Corrosion / Rust',
            status: 'None Detected',
            icon: Icons.water_damage_outlined,
            isGood: true,
          ),
          const _DamageRow(
            type: 'Burn Marks',
            status: 'None Detected',
            icon: Icons.local_fire_department_outlined,
            isGood: true,
          ),
          const _DamageRow(
            type: 'Missing Components',
            status: 'None Detected',
            icon: Icons.inventory_2_outlined,
            isGood: true,
          ),
          const _DamageRow(
            type: 'Dust Accumulation',
            status: 'Minor — Clean Soon',
            icon: Icons.cloud_outlined,
            isGood: false,
          ),
        ],
      ),
    );
  }
}

class _DamageRow extends StatelessWidget {
  final String type;
  final String status;
  final IconData icon;
  final bool isGood;

  const _DamageRow({
    required this.type,
    required this.status,
    required this.icon,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGood ? AppTheme.accentGreen : AppTheme.warningAmber;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              type,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FailurePrediction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.warningAmber.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.warningAmber, size: 16),
              const SizedBox(width: 8),
              Text('AI FAILURE PREDICTION', style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          _PredictionRow(
            component: 'Battery',
            prediction: 'Capacity degradation expected in ~18 months',
            confidence: 0.76,
            urgency: 'Low',
          ),
          _PredictionRow(
            component: 'Fan',
            prediction: 'Bearing wear — clean in 3-6 months',
            confidence: 0.62,
            urgency: 'Medium',
          ),
          _PredictionRow(
            component: 'SSD',
            prediction: 'Estimated 4.2 years remaining lifespan',
            confidence: 0.84,
            urgency: 'Low',
          ),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final String component;
  final String prediction;
  final double confidence;
  final String urgency;

  const _PredictionRow({
    required this.component,
    required this.prediction,
    required this.confidence,
    required this.urgency,
  });

  Color get _urgencyColor => urgency == 'Low'
      ? AppTheme.accentGreen
      : urgency == 'Medium'
          ? AppTheme.warningAmber
          : AppTheme.errorRed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                component,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _urgencyColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  urgency,
                  style: TextStyle(
                    color: _urgencyColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            prediction,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Confidence: ',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              ),
              Text(
                '${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MaintenanceAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const alerts = [
      ('Clean cooling vents with compressed air', AppTheme.warningAmber, 'RECOMMENDED'),
      ('Update firmware to latest version', AppTheme.primaryCyan, 'OPTIONAL'),
      ('Back up data before next repair attempt', AppTheme.errorRed, 'IMPORTANT'),
      ('Calibrate battery (full charge cycle)', AppTheme.accentGreen, 'OPTIONAL'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MAINTENANCE ALERTS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        ...alerts.map((alert) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alert.$2.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: alert.$2.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_outlined, color: alert.$2, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.$1,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.$2.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.$3,
                  style: TextStyle(
                    color: alert.$2,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
