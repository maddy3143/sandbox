import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/holographic_button.dart';

class ComponentInspectorPanel extends StatelessWidget {
  final String componentId;
  final String objectId;
  final VoidCallback onClose;

  const ComponentInspectorPanel({
    super.key,
    required this.componentId,
    required this.objectId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        bottomLeft: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withOpacity(0.95),
            border: const Border(
              left: BorderSide(color: AppTheme.primaryCyan, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COMPONENT',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: const Icon(
                        Icons.close,
                        color: AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppTheme.glassWhite),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Component name & icon
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryCyan.withOpacity(0.15),
                              border: Border.all(
                                color: AppTheme.primaryCyan.withOpacity(0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.memory,
                              color: AppTheme.primaryCyan,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Motherboard',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Main logic board',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _InfoRow('Function', 'Central processing hub for all components'),
                      _InfoRow('Material', 'FR4 PCB with copper traces'),
                      _InfoRow('Dimensions', '28.5 × 21.3 cm'),
                      _InfoRow('Connections', '5 components'),
                      _InfoRow('Removable', 'Yes — requires 8 screws'),

                      const SizedBox(height: 16),

                      // Health indicator
                      const Text(
                        'COMPONENT HEALTH',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: const LinearProgressIndicator(
                          value: 0.92,
                          backgroundColor: AppTheme.glassWhite,
                          valueColor: AlwaysStoppedAnimation(AppTheme.accentGreen),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Excellent',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '92%',
                            style: TextStyle(
                              color: AppTheme.accentGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      HolographicButton(
                        label: 'REPAIR GUIDE',
                        icon: Icons.build,
                        color: AppTheme.accentOrange,
                        height: 40,
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                      HolographicButton(
                        label: 'FIND PART',
                        icon: Icons.shopping_bag_outlined,
                        color: AppTheme.primaryCyan,
                        height: 40,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
