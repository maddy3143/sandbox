import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/calls_controller.dart';
import '../models/call_model.dart';

// ---------------------------------------------------------------------------
// IncomingCallScreen
// ---------------------------------------------------------------------------

class IncomingCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String fromNumber;
  final String? callerName;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.fromNumber,
    this.callerName,
  });

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _ringController;

  bool _isProcessing = false;
  int _ringingSeconds = 0;
  Timer? _ringingTimer;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ringingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _ringingSeconds++);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _ringingTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String get _displayName =>
      widget.callerName?.isNotEmpty == true ? widget.callerName! : 'Unknown';

  String get _ringingDuration {
    final m = _ringingSeconds ~/ 60;
    final s = _ringingSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  // -------------------------------------------------------------------------
  // Decision actions
  // -------------------------------------------------------------------------

  Future<void> _handleDecision(CallDecision decision) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await ref
          .read(callsProvider.notifier)
          .makeDecision(widget.callId, decision);

      if (!mounted) return;

      if (decision == CallDecision.letAiAnswer) {
        await _showAiHandlingDialog();
      }

      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process decision: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showAiHandlingDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.primaryCyan.withOpacity(0.4),
            width: 1,
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.smart_toy_rounded, color: AppTheme.primaryCyan),
            const SizedBox(width: 12),
            const Text(
              'AI is handling the call',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Your AI assistant is now answering this call. You will receive a summary and transcript once the call ends.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),
                _buildHeader(),
                const SizedBox(height: 48),
                _buildPulseAvatar(),
                const SizedBox(height: 32),
                _buildCallerInfo(),
                const SizedBox(height: 16),
                _buildTimestamp(),
                const Spacer(flex: 2),
                _buildActionButtons(),
                const SizedBox(height: 16),
                _buildDeclineButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isProcessing) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sub-widgets
  // -------------------------------------------------------------------------

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final opacity = 0.03 + (_pulseController.value * 0.05);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                AppTheme.primaryBlue.withOpacity(opacity * 2),
                AppTheme.backgroundDark,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'INCOMING CALL',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryCyan,
            letterSpacing: 3,
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(duration: 800.ms)
            .then()
            .fadeOut(duration: 800.ms, delay: 800.ms),
        const SizedBox(height: 8),
        Text(
          _ringingDuration,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildPulseAvatar() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse rings
          AnimatedBuilder(
            animation: _ringController,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  _buildRingLayer(
                    scale: 1.0 + (_ringController.value * 0.6),
                    opacity: (1.0 - _ringController.value) * 0.25,
                    color: AppTheme.primaryBlue,
                    size: 200,
                  ),
                  _buildRingLayer(
                    scale: 1.0 +
                        ((_ringController.value + 0.33) % 1.0) * 0.6,
                    opacity: (1.0 -
                            ((_ringController.value + 0.33) % 1.0)) *
                        0.2,
                    color: AppTheme.primaryCyan,
                    size: 200,
                  ),
                  _buildRingLayer(
                    scale: 1.0 +
                        ((_ringController.value + 0.66) % 1.0) * 0.6,
                    opacity: (1.0 -
                            ((_ringController.value + 0.66) % 1.0)) *
                        0.15,
                    color: AppTheme.primaryBlue,
                    size: 200,
                  ),
                ],
              );
            },
          ),
          // Avatar circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.8),
                  AppTheme.accentPurple.withOpacity(0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              size: 52,
              color: Colors.white,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.05, 1.05),
                duration: 1000.ms,
                curve: Curves.easeInOut,
              ),
        ],
      ),
    );
  }

  Widget _buildRingLayer({
    required double scale,
    required double opacity,
    required Color color,
    required double size,
  }) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withOpacity(opacity),
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        Text(
          _displayName,
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.fromNumber,
          style: const TextStyle(
            fontSize: 18,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTimestamp() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.glassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassWhiteStrong),
      ),
      child: const Text(
        'Just now',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Answer Myself — Red
          Expanded(
            child: _CallActionButton(
              label: 'Answer Myself',
              icon: Icons.phone_rounded,
              color: AppTheme.errorRed,
              onTap: () => _handleDecision(CallDecision.answerMyself),
            ),
          ),
          const SizedBox(width: 16),
          // Let AI Answer — Blue/Purple gradient
          Expanded(
            child: _GradientCallButton(
              label: 'Let AI Answer',
              icon: Icons.smart_toy_rounded,
              onTap: () => _handleDecision(CallDecision.letAiAnswer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeclineButton() {
    return TextButton.icon(
      onPressed: _isProcessing
          ? null
          : () => _handleDecision(CallDecision.decline),
      icon: const Icon(Icons.call_end_rounded, size: 18),
      label: const Text('Decline'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        textStyle: const TextStyle(fontSize: 15, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryCyan,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CallActionButton — solid colour button used for "Answer Myself"
// ---------------------------------------------------------------------------

class _CallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GradientCallButton — gradient button for "Let AI Answer"
// ---------------------------------------------------------------------------

class _GradientCallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GradientCallButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.7),
              AppTheme.accentPurple.withOpacity(0.7),
            ],
          ),
          border: Border.all(
            color: AppTheme.primaryCyan.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
