import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final double blur;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final List<BoxShadow>? shadows;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.blur = 10,
    this.onTap,
    this.width,
    this.height,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: shadows ??
              [
                BoxShadow(
                  color: AppTheme.primaryCyan.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding ?? const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundColor ?? AppTheme.glassWhite,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? AppTheme.glassWhiteStrong,
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassCyanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const GlassCyanCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding,
      margin: margin,
      borderColor: AppTheme.primaryCyan.withOpacity(0.4),
      backgroundColor: AppTheme.primaryCyan.withOpacity(0.08),
      onTap: onTap,
      shadows: [
        BoxShadow(
          color: AppTheme.primaryCyan.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      child: child,
    );
  }
}
