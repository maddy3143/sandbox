import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';

class ExplodedViewScreen extends ConsumerStatefulWidget {
  final String objectId;
  const ExplodedViewScreen({super.key, required this.objectId});

  @override
  ConsumerState<ExplodedViewScreen> createState() => _ExplodedViewScreenState();
}

class _ExplodedViewScreenState extends ConsumerState<ExplodedViewScreen>
    with TickerProviderStateMixin {
  late AnimationController _explodeController;
  double _explodeAmount = 0.0;
  int _currentAssemblyStep = 0;
  bool _isAnimating = false;
  bool _showAssemblyGuide = false;

  final List<_ExplodedPart> _parts = [
    _ExplodedPart('Display Panel', Icons.monitor, AppTheme.primaryCyan, Offset(0, -160)),
    _ExplodedPart('Keyboard Deck', Icons.keyboard, AppTheme.accentGreen, Offset(0, -80)),
    _ExplodedPart('Motherboard', Icons.memory, AppTheme.accentPurple, Offset(0, 0)),
    _ExplodedPart('Battery', Icons.battery_charging_full, AppTheme.warningAmber, Offset(0, 80)),
    _ExplodedPart('Bottom Cover', Icons.crop_square, AppTheme.textSecondary, Offset(0, 160)),
  ];

  @override
  void initState() {
    super.initState();
    _explodeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    _explodeController.dispose();
    super.dispose();
  }

  void _explodeAll() {
    setState(() => _isAnimating = true);
    _explodeController.forward().then((_) {
      setState(() {
        _explodeAmount = 1.0;
        _isAnimating = false;
      });
    });
  }

  void _assembleAll() {
    setState(() => _isAnimating = true);
    _explodeController.reverse().then((_) {
      setState(() {
        _explodeAmount = 0.0;
        _isAnimating = false;
        _currentAssemblyStep = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                colors: [Color(0xFF0D1B2A), AppTheme.backgroundDark],
              ),
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
                        color: AppTheme.primaryCyan,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'EXPLODED VIEW',
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                        const Text(
                          'Interactive Disassembly',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_play, color: AppTheme.accentGreen),
                    onPressed: () => setState(() => _showAssemblyGuide = !_showAssemblyGuide),
                    tooltip: 'Assembly Guide',
                  ),
                ],
              ),
            ),
          ),

          // Exploded view canvas
          Positioned(
            top: 110,
            bottom: 220,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _explodeController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: _parts.asMap().entries.map((entry) {
                    final i = entry.key;
                    final part = entry.value;
                    final explodeOffset = Offset(
                      part.offset.dx * _explodeController.value,
                      part.offset.dy * _explodeController.value,
                    );
                    return Transform.translate(
                      offset: explodeOffset,
                      child: _ExplodedPartWidget(
                        part: part,
                        index: i,
                        isSelected: _currentAssemblyStep == i && _showAssemblyGuide,
                        explodeAmount: _explodeController.value,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),

          // Explode slider
          Positioned(
            bottom: 200,
            left: 24,
            right: 24,
            child: Row(
              children: [
                const Text(
                  'EXPLODE',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _explodeController.value,
                    onChanged: (v) {
                      _explodeController.value = v;
                      setState(() => _explodeAmount = v);
                    },
                  ),
                ),
                Text(
                  '${(_explodeController.value * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppTheme.primaryCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Parts list
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PartsList(parts: _parts, selectedIndex: _currentAssemblyStep),
          ),

          // Bottom action buttons
          Positioned(
            bottom: 95,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                HolographicButton(
                  label: 'EXPLODE ALL',
                  icon: Icons.open_with,
                  color: AppTheme.primaryCyan,
                  width: 140,
                  height: 42,
                  onTap: _explodeAll,
                  isLoading: _isAnimating,
                ),
                HolographicButton(
                  label: 'ASSEMBLE',
                  icon: Icons.compress,
                  color: AppTheme.accentGreen,
                  width: 140,
                  height: 42,
                  onTap: _assembleAll,
                  isLoading: _isAnimating,
                ),
              ],
            ),
          ),

          // Assembly guide panel
          if (_showAssemblyGuide)
            Positioned(
              top: 90,
              right: 16,
              child: _AssemblyStepPanel(
                step: _currentAssemblyStep,
                total: _parts.length,
                partName: _parts[_currentAssemblyStep].name,
                onNext: () {
                  if (_currentAssemblyStep < _parts.length - 1) {
                    setState(() => _currentAssemblyStep++);
                  }
                },
                onPrev: () {
                  if (_currentAssemblyStep > 0) {
                    setState(() => _currentAssemblyStep--);
                  }
                },
              ).animate().fadeIn().slideX(begin: 0.5),
            ),
        ],
      ),
    );
  }
}

class _ExplodedPart {
  final String name;
  final IconData icon;
  final Color color;
  final Offset offset;

  _ExplodedPart(this.name, this.icon, this.color, this.offset);
}

class _ExplodedPartWidget extends StatelessWidget {
  final _ExplodedPart part;
  final int index;
  final bool isSelected;
  final double explodeAmount;

  const _ExplodedPartWidget({
    required this.part,
    required this.index,
    required this.isSelected,
    required this.explodeAmount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? part.color : part.color.withOpacity(0.3 + explodeAmount * 0.4),
          width: isSelected ? 2 : 1,
        ),
        color: isSelected
            ? part.color.withOpacity(0.2)
            : part.color.withOpacity(0.05 + explodeAmount * 0.08),
        boxShadow: isSelected
            ? [BoxShadow(color: part.color.withOpacity(0.4), blurRadius: 16)]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(part.icon, color: part.color, size: 22),
          if (explodeAmount > 0.3) ...[
            const SizedBox(width: 10),
            Opacity(
              opacity: (explodeAmount - 0.3) / 0.7,
              child: Text(
                part.name,
                style: TextStyle(
                  color: part.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PartsList extends StatelessWidget {
  final List<_ExplodedPart> parts;
  final int selectedIndex;

  const _PartsList({required this.parts, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.glassWhite)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: parts.length,
        itemBuilder: (context, i) {
          final part = parts[i];
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: part.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: part.color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(part.icon, size: 14, color: part.color),
                const SizedBox(width: 6),
                Text(
                  part.name,
                  style: TextStyle(
                    color: part.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssemblyStepPanel extends StatelessWidget {
  final int step;
  final int total;
  final String partName;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _AssemblyStepPanel({
    required this.step,
    required this.total,
    required this.partName,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: 200,
      borderColor: AppTheme.accentGreen.withOpacity(0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STEP ${step + 1} of $total',
            style: const TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            partName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Remove 4 screws (Torx T8) and carefully lift component upward.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onPrev,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.glassWhite,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.chevron_left, size: 16, color: AppTheme.textPrimary),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onNext,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.chevron_right, size: 16, color: AppTheme.accentGreen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
