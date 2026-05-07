import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/route_names.dart';
import '../../../shared/models/scanned_object.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';
import '../../scanner/providers/scan_result_provider.dart';

class ScanResultScreen extends ConsumerWidget {
  final String objectId;

  const ScanResultScreen({super.key, required this.objectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final objectAsync = ref.watch(scanResultProvider(objectId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: objectAsync.when(
        data: (obj) => obj != null
            ? _ScanResultContent(object: obj)
            : const _NotFoundView(),
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(error: e.toString()),
      ),
    );
  }
}

class _ScanResultContent extends StatelessWidget {
  final ScannedObject object;

  const _ScanResultContent({required this.object});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ObjectIdentityCard(object: object)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2),
              const SizedBox(height: 16),
              _ConfidenceBar(score: object.confidenceScore)
                  .animate()
                  .fadeIn(delay: 200.ms),
              const SizedBox(height: 20),
              _QuickStatsRow(object: object)
                  .animate()
                  .fadeIn(delay: 300.ms),
              const SizedBox(height: 20),
              _ActionGrid(objectId: object.id)
                  .animate()
                  .fadeIn(delay: 400.ms),
              const SizedBox(height: 20),
              _ComponentsPreview(components: object.components)
                  .animate()
                  .fadeIn(delay: 500.ms),
              const SizedBox(height: 20),
              _MaterialCard(analysis: object.materialAnalysis)
                  .animate()
                  .fadeIn(delay: 600.ms),
              if (object.damageReport != null) ...[
                const SizedBox(height: 20),
                _DamageCard(report: object.damageReport!)
                    .animate()
                    .fadeIn(delay: 700.ms),
              ],
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryCyan),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: AppTheme.primaryCyan),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.bookmark_outline, color: AppTheme.primaryCyan),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Object image
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1B2A), Color(0xFF112240)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.view_in_ar,
                  size: 100,
                  color: Color(0x3300F5FF),
                ),
              ),
            ),
            // Gradient overlay
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.backgroundDark],
                ),
              ),
            ),
            // Category badge
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.5)),
                ),
                child: Text(
                  'ELECTRONICS',
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObjectIdentityCard extends StatelessWidget {
  final ScannedObject object;

  const _ObjectIdentityCard({required this.object});

  @override
  Widget build(BuildContext context) {
    return GlassCyanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppTheme.accentGreen, size: 16),
              const SizedBox(width: 6),
              const Text(
                'OBJECT IDENTIFIED',
                style: TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            object.name,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _InfoChip(label: object.brand, icon: Icons.business),
              const SizedBox(width: 8),
              _InfoChip(label: object.model, icon: Icons.tag),
              const SizedBox(width: 8),
              _InfoChip(label: object.estimatedYear, icon: Icons.calendar_today),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            object.description,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.warningAmber, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  object.probableUseCase,
                  style: const TextStyle(
                    color: AppTheme.warningAmber,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.glassWhiteStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double score;

  const _ConfidenceBar({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'AI CONFIDENCE',
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor: AppTheme.glassWhite,
              valueColor: AlwaysStoppedAnimation(
                score > 0.85
                    ? AppTheme.accentGreen
                    : score > 0.6
                        ? AppTheme.warningAmber
                        : AppTheme.errorRed,
              ),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryCyan,
          ),
        ),
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final ScannedObject object;

  const _QuickStatsRow({required this.object});

  @override
  Widget build(BuildContext context) {
    final m = object.measurements;
    return Row(
      children: [
        _StatCard(
          label: 'HEIGHT',
          value: '${m.heightCm.toStringAsFixed(1)}cm',
          icon: Icons.height,
          color: AppTheme.primaryCyan,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'WIDTH',
          value: '${m.widthCm.toStringAsFixed(1)}cm',
          icon: Icons.swap_horiz,
          color: AppTheme.accentGreen,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'WEIGHT',
          value: '${m.weightKg.toStringAsFixed(2)}kg',
          icon: Icons.scale,
          color: AppTheme.accentOrange,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'PARTS',
          value: '${object.components.length}',
          icon: Icons.category,
          color: AppTheme.accentPurple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
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
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  final String objectId;

  const _ActionGrid({required this.objectId});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(
        label: '3D DIGITAL TWIN',
        icon: Icons.view_in_ar,
        color: AppTheme.primaryCyan,
        description: 'Interactive 3D model',
        onTap: () => context.push('/digital-twin/$objectId'),
      ),
      _ActionItem(
        label: 'EXPLODED VIEW',
        icon: Icons.layers,
        color: AppTheme.accentGreen,
        description: 'Disassemble parts',
        onTap: () => context.push('/exploded-view/$objectId'),
      ),
      _ActionItem(
        label: 'MEASUREMENTS',
        icon: Icons.straighten,
        color: AppTheme.accentOrange,
        description: 'Precise dimensions',
        onTap: () => context.push('/measurements/$objectId'),
      ),
      _ActionItem(
        label: 'X-RAY MODE',
        icon: Icons.blur_on,
        color: AppTheme.accentPurple,
        description: 'Internal structure',
        onTap: () => context.push('/xray-mode/$objectId'),
      ),
      _ActionItem(
        label: 'AI ASSISTANT',
        icon: Icons.smart_toy_outlined,
        color: AppTheme.primaryBlue,
        description: 'Ask anything',
        onTap: () => context.push('/ai-assistant/$objectId'),
      ),
      _ActionItem(
        label: 'REPAIR GUIDE',
        icon: Icons.build_outlined,
        color: AppTheme.warningAmber,
        description: 'Step-by-step repair',
        onTap: () => context.push('/repair-guide/$objectId'),
      ),
      _ActionItem(
        label: 'DIAGNOSTICS',
        icon: Icons.health_and_safety_outlined,
        color: AppTheme.errorRed,
        description: 'Damage & health',
        onTap: () => context.push('/diagnostics/$objectId'),
      ),
      _ActionItem(
        label: 'FIND PARTS',
        icon: Icons.shopping_bag_outlined,
        color: const Color(0xFF00D4AA),
        description: 'Compatible parts',
        onTap: () => context.push('/marketplace'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIGITAL INTELLIGENCE',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: actions.map((action) => _ActionTile(item: action)).toList(),
        ),
      ],
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  final VoidCallback onTap;

  _ActionItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.onTap,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;

  const _ActionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.color.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.color.withOpacity(0.15),
                  border: Border.all(color: item.color.withOpacity(0.4)),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color: item.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      item.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: item.color.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComponentsPreview extends StatelessWidget {
  final List<ObjectComponent> components;

  const _ComponentsPreview({required this.components});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COMPONENTS (${components.length})',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Text(
                'SEE ALL',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...components.take(4).map(
            (comp) => _ComponentRow(component: comp),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final ObjectComponent component;

  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  component.description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (component.isRemovable)
            const Icon(
              Icons.build_circle_outlined,
              size: 14,
              color: AppTheme.accentGreen,
            ),
        ],
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final MaterialAnalysis analysis;

  const _MaterialCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MATERIAL ANALYSIS',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          _MatRow('Primary Material', analysis.primaryMaterial, Icons.texture),
          if (analysis.secondaryMaterial != null)
            _MatRow('Secondary Material', analysis.secondaryMaterial!, Icons.layers),
          _MatRow('Surface Finish', analysis.surfaceFinish, Icons.gradient),
          _MatRow('Heat Resistance', analysis.heatResistance, Icons.thermostat),
          _MatRow('Corrosion Resistance', analysis.corrosionResistance, Icons.water_drop),
          if (analysis.manufacturingProcess != null)
            _MatRow('Manufacturing', analysis.manufacturingProcess!, Icons.factory),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'DURABILITY',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Text(
                '${analysis.durabilityScore.toStringAsFixed(1)}/10',
                style: const TextStyle(
                  color: AppTheme.accentGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: analysis.durabilityScore / 10,
              backgroundColor: AppTheme.glassWhite,
              valueColor: const AlwaysStoppedAnimation(AppTheme.accentGreen),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MatRow(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
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

class _DamageCard extends StatelessWidget {
  final DamageReport report;

  const _DamageCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final healthColor = report.healthScore > 80
        ? AppTheme.accentGreen
        : report.healthScore > 60
            ? AppTheme.warningAmber
            : AppTheme.errorRed;

    return GlassCard(
      borderColor: report.damageDetected
          ? AppTheme.errorRed.withOpacity(0.4)
          : AppTheme.accentGreen.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                report.damageDetected
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                color: report.damageDetected
                    ? AppTheme.warningAmber
                    : AppTheme.accentGreen,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'HEALTH DIAGNOSTICS',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Spacer(),
              Text(
                '${report.healthScore}%',
                style: TextStyle(
                  color: healthColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: report.healthScore / 100,
              backgroundColor: AppTheme.glassWhite,
              valueColor: AlwaysStoppedAnimation(healthColor),
              minHeight: 8,
            ),
          ),
          if (report.damageDetected) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.damageTypes.map((t) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
                ),
                child: Text(
                  t,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],
          if (report.recommendations.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...report.recommendations.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: AppTheme.primaryCyan)),
                  Expanded(
                    child: Text(
                      r,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryCyan),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Object not found',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Error: $error',
        style: const TextStyle(color: AppTheme.errorRed),
      ),
    );
  }
}
