import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class HolographicButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLoading;
  final double? width;
  final double height;
  final bool outlined;

  const HolographicButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.outlined = false,
  });

  @override
  State<HolographicButton> createState() => _HolographicButtonState();
}

class _HolographicButtonState extends State<HolographicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryCyan;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: (_) {
            setState(() => _pressed = true);
            HapticFeedback.lightImpact();
          },
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap?.call();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.outlined
                    ? Colors.transparent
                    : color.withOpacity(0.15),
                border: Border.all(
                  color: color.withOpacity(
                    widget.outlined ? 0.8 : _glowAnimation.value,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(_glowAnimation.value * 0.4),
                    blurRadius: 16,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Scan line effect
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: CustomPaint(
                        painter: _ScanLinePainter(
                          color: color,
                          progress: _controller.value,
                        ),
                      ),
                    ),
                  ),
                  // Content
                  if (widget.isLoading)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: color, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final Color color;
  final double progress;

  _ScanLinePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.06)
      ..strokeWidth = 1;

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => old.progress != progress;
}
