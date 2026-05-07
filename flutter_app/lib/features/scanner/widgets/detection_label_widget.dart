import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/scanner_provider.dart';
import '../../../core/theme/app_theme.dart';

class DetectionLabelWidget extends StatelessWidget {
  final List<DetectedObjectPreview> objects;

  const DetectionLabelWidget({super.key, required this.objects});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: objects.take(3).map((obj) {
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withOpacity(0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryCyan.withOpacity(0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                obj.label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(obj.confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppTheme.primaryCyan.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2);
      }).toList(),
    );
  }
}
