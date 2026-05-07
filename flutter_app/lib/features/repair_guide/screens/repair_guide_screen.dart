import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';

class RepairGuideScreen extends ConsumerStatefulWidget {
  final String objectId;
  const RepairGuideScreen({super.key, required this.objectId});

  @override
  ConsumerState<RepairGuideScreen> createState() => _RepairGuideScreenState();
}

class _RepairGuideScreenState extends ConsumerState<RepairGuideScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _highlightController;
  RepairCategory _selectedCategory = RepairCategory.battery;
  bool _isARMode = false;

  final Map<RepairCategory, List<_RepairStep>> _repairGuides = {
    RepairCategory.battery: [
      _RepairStep(
        title: 'Power Off & Discharge',
        instruction: 'Shut down the laptop completely. Discharge battery below 30% if possible to minimize risk.',
        tools: ['Nothing required'],
        warning: 'Never attempt repair while device is powered on.',
        highlightComponent: 'Power Button',
        duration: '1 min',
      ),
      _RepairStep(
        title: 'Remove Bottom Cover',
        instruction: 'Remove all 8 Torx T5 screws from the bottom panel. Place them in a magnetic tray to avoid loss.',
        tools: ['Torx T5 screwdriver', 'Magnetic tray'],
        warning: 'Note screw positions — some have different lengths.',
        highlightComponent: 'Bottom Cover',
        duration: '3 min',
      ),
      _RepairStep(
        title: 'Pry Open Cover',
        instruction: 'Insert plastic pry tool into the seam near the air vents. Work around the perimeter gently.',
        tools: ['Plastic pry tool', 'Spudger'],
        warning: 'Do not use metal tools — will scratch and damage clips.',
        highlightComponent: 'Bottom Cover',
        duration: '2 min',
      ),
      _RepairStep(
        title: 'Disconnect Battery',
        instruction: 'Locate the white ZIF connector near the center-right of the board. Gently pull the pull-tab to disconnect.',
        tools: ['Spudger or fingernail'],
        warning: '⚡ Critical: Disconnect this before touching any other component.',
        highlightComponent: 'Battery Connector',
        duration: '1 min',
      ),
      _RepairStep(
        title: 'Remove Battery Screws',
        instruction: 'Remove the 2 Phillips #1 screws holding the battery bracket.',
        tools: ['Phillips #1 screwdriver'],
        warning: null,
        highlightComponent: 'Battery',
        duration: '1 min',
      ),
      _RepairStep(
        title: 'Lift Out Battery',
        instruction: 'Lift the battery straight up. If adhesive-held, apply iOpener or heat gun at 60°C along edges.',
        tools: ['iOpener or heat gun (60°C)', 'Plastic card'],
        warning: 'Never puncture the battery — fire hazard.',
        highlightComponent: 'Battery',
        duration: '3 min',
      ),
      _RepairStep(
        title: 'Install New Battery',
        instruction: 'Place new battery in position. Reconnect ZIF connector firmly until it clicks.',
        tools: ['New battery (compatible: Dell WDX0R)'],
        warning: 'Verify battery part number compatibility before purchase.',
        highlightComponent: 'Battery',
        duration: '2 min',
      ),
      _RepairStep(
        title: 'Reassemble & Test',
        instruction: 'Snap bottom cover back, replace all 8 screws. Power on and verify battery detected in BIOS.',
        tools: ['Torx T5 screwdriver'],
        warning: null,
        highlightComponent: 'Bottom Cover',
        duration: '4 min',
      ),
    ],
    RepairCategory.ram: [
      _RepairStep(
        title: 'Remove Bottom Cover',
        instruction: 'Follow steps 1-3 from battery replacement guide.',
        tools: ['Torx T5 screwdriver', 'Plastic pry tool'],
        warning: 'Disconnect battery first.',
        highlightComponent: 'Bottom Cover',
        duration: '5 min',
      ),
      _RepairStep(
        title: 'Locate RAM Slot',
        instruction: 'The RAM slot is located near the center of the motherboard. One slot is occupied.',
        tools: ['None'],
        warning: null,
        highlightComponent: 'RAM Module',
        duration: '30 sec',
      ),
      _RepairStep(
        title: 'Remove Existing RAM',
        instruction: 'Press outward on the two retention clips simultaneously. The RAM stick will pop up at 45°. Slide it out.',
        tools: ['Fingers only'],
        warning: '⚡ Ground yourself first! Static electricity kills RAM.',
        highlightComponent: 'RAM Module',
        duration: '1 min',
      ),
      _RepairStep(
        title: 'Insert New RAM',
        instruction: 'Insert at 45° angle. Push down firmly until both clips engage with an audible click.',
        tools: ['Compatible DDR4 SODIMM module'],
        warning: 'Handle only by edges — never touch gold contacts.',
        highlightComponent: 'RAM Module',
        duration: '1 min',
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  List<_RepairStep> get _currentGuide =>
      _repairGuides[_selectedCategory] ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          // App bar
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
                        color: AppTheme.accentOrange,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'REPAIR GUIDE',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.accentOrange,
                      ),
                    ),
                  ),
                  _ARModeToggle(
                    isActive: _isARMode,
                    onToggle: () => setState(() => _isARMode = !_isARMode),
                  ),
                ],
              ),
            ),
          ),

          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: RepairCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedCategory = cat;
                    _currentStep = 0;
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentOrange.withOpacity(0.2)
                          : AppTheme.glassWhite,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentOrange
                            : AppTheme.glassWhiteStrong,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.icon, size: 12, color: isSelected ? AppTheme.accentOrange : AppTheme.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? AppTheme.accentOrange : AppTheme.textSecondary,
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
          const SizedBox(height: 12),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'STEP ${_currentStep + 1} OF ${_currentGuide.length}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      _currentGuide[_currentStep].duration,
                      style: const TextStyle(
                        color: AppTheme.accentOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / _currentGuide.length,
                    backgroundColor: AppTheme.glassWhite,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accentOrange),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Current step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _StepCard(
                step: _currentGuide[_currentStep],
                stepIndex: _currentStep,
                highlightController: _highlightController,
              ).animate().fadeIn().slideY(begin: 0.1),
            ),
          ),

          // Navigation
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: HolographicButton(
                      label: 'PREVIOUS',
                      icon: Icons.chevron_left,
                      color: AppTheme.textSecondary,
                      height: 48,
                      onTap: () => setState(() => _currentStep--),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _currentStep < _currentGuide.length - 1
                      ? HolographicButton(
                          label: 'NEXT STEP',
                          icon: Icons.chevron_right,
                          color: AppTheme.accentOrange,
                          height: 48,
                          onTap: () => setState(() => _currentStep++),
                        )
                      : HolographicButton(
                          label: 'COMPLETE ✓',
                          icon: Icons.check_circle,
                          color: AppTheme.accentGreen,
                          height: 48,
                          onTap: () => _showCompletionDialog(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'REPAIR COMPLETE!',
          style: TextStyle(color: AppTheme.accentGreen, fontFamily: 'Orbitron'),
        ),
        content: const Text(
          'Congratulations! You\'ve completed the repair guide.\n\nDon\'t forget to test functionality before fully closing the device.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('DONE', style: TextStyle(color: AppTheme.primaryCyan)),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final _RepairStep step;
  final int stepIndex;
  final AnimationController highlightController;

  const _StepCard({
    required this.step,
    required this.stepIndex,
    required this.highlightController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Visual guide area
        Container(
          height: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppTheme.surfaceMid,
            border: Border.all(color: AppTheme.accentOrange.withOpacity(0.3)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Simplified object visualization
              Icon(
                Icons.laptop,
                size: 80,
                color: AppTheme.textSecondary.withOpacity(0.2),
              ),
              // Animated highlight
              AnimatedBuilder(
                animation: highlightController,
                builder: (context, _) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(
                      0.1 + highlightController.value * 0.15,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.accentOrange.withOpacity(
                        0.4 + highlightController.value * 0.4,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentOrange.withOpacity(
                          highlightController.value * 0.3,
                        ),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: AppTheme.accentOrange,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        step.highlightComponent,
                        style: const TextStyle(
                          color: AppTheme.accentOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // AR overlay badge
              const Positioned(
                top: 12,
                right: 12,
                child: _ARBadge(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Step details
        GlassCard(
          borderColor: AppTheme.accentOrange.withOpacity(0.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.instruction,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),

              if (step.warning != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningAmber, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.warning!,
                          style: const TextStyle(
                            color: AppTheme.warningAmber,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Text(
                'TOOLS NEEDED',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: step.tools.map((tool) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryCyan.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hardware, size: 11, color: AppTheme.primaryCyan),
                      const SizedBox(width: 5),
                      Text(
                        tool,
                        style: const TextStyle(
                          color: AppTheme.primaryCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ARBadge extends StatelessWidget {
  const _ARBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.view_in_ar, size: 10, color: AppTheme.primaryCyan),
          SizedBox(width: 4),
          Text(
            'AR OVERLAY',
            style: TextStyle(
              color: AppTheme.primaryCyan,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ARModeToggle extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const _ARModeToggle({required this.isActive, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryCyan.withOpacity(0.2)
              : AppTheme.glassWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryCyan : AppTheme.glassWhiteStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_in_ar,
              size: 14,
              color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'AR MODE',
              style: TextStyle(
                fontSize: 11,
                color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepairStep {
  final String title;
  final String instruction;
  final List<String> tools;
  final String? warning;
  final String highlightComponent;
  final String duration;

  _RepairStep({
    required this.title,
    required this.instruction,
    required this.tools,
    this.warning,
    required this.highlightComponent,
    required this.duration,
  });
}

enum RepairCategory {
  battery,
  ram,
  storage,
  display,
  keyboard,
  fan;

  String get label => switch (this) {
    RepairCategory.battery => 'Battery',
    RepairCategory.ram => 'RAM',
    RepairCategory.storage => 'Storage',
    RepairCategory.display => 'Display',
    RepairCategory.keyboard => 'Keyboard',
    RepairCategory.fan => 'Cooling',
  };

  IconData get icon => switch (this) {
    RepairCategory.battery => Icons.battery_charging_full,
    RepairCategory.ram => Icons.memory,
    RepairCategory.storage => Icons.storage,
    RepairCategory.display => Icons.monitor,
    RepairCategory.keyboard => Icons.keyboard,
    RepairCategory.fan => Icons.air,
  };
}
