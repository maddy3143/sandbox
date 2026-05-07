import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';
import '../providers/scanner_provider.dart';
import '../widgets/ar_overlay_painter.dart';
import '../widgets/scan_frame_widget.dart';
import '../widgets/detection_label_widget.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _radarController;
  bool _cameraInitialized = false;
  bool _isScanning = false;
  bool _flashOn = false;
  ScanMode _scanMode = ScanMode.auto;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    if (mounted) {
      setState(() => _cameraInitialized = true);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scanLineController.dispose();
    _pulseController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (_isScanning || _cameraController == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _isScanning = true);

    try {
      final image = await _cameraController!.takePicture();
      final file = File(image.path);

      await ref.read(scannerProvider.notifier).analyzeObject(file);

      if (mounted) {
        final objectId = ref.read(scannerProvider).scannedObjectId;
        if (objectId != null) {
          context.push('/scan-result/$objectId');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _toggleFlash() async {
    if (_cameraController == null) return;
    setState(() => _flashOn = !_flashOn);
    await _cameraController!.setFlashMode(
      _flashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(scannerProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Camera preview
          if (_cameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryCyan),
                ),
              ),
            ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC050A14),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xEE050A14),
                  ],
                  stops: [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // AR Detection overlays
          if (scannerState.detectedObjects.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: AROverlayPainter(
                  detectedObjects: scannerState.detectedObjects,
                  screenSize: size,
                ),
              ),
            ),

          // Scan frame with animation
          Center(
            child: ScanFrameWidget(
              scanLineController: _scanLineController,
              pulseController: _pulseController,
              isScanning: _isScanning,
              scanMode: _scanMode,
            ),
          ),

          // Top HUD
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLogo(),
                  _buildScanModeSelector(),
                  _buildTopActions(),
                ],
              ),
            ),
          ),

          // Real-time detection labels
          if (scannerState.detectedObjects.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: DetectionLabelWidget(
                objects: scannerState.detectedObjects,
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(scannerState),
          ),

          // Scanning overlay
          if (_isScanning)
            Positioned.fill(child: _buildScanningOverlay()),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'AR SCAN',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize: 20,
            letterSpacing: 3,
          ),
        ).animate().fadeIn(duration: 600.ms),
        Text(
          'POINT & DISCOVER',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.primaryCyan.withOpacity(0.7),
            letterSpacing: 2,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildScanModeSelector() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ScanMode.values.map((mode) {
          final isSelected = mode == _scanMode;
          return GestureDetector(
            onTap: () => setState(() => _scanMode = mode),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isSelected
                    ? AppTheme.primaryCyan.withOpacity(0.2)
                    : Colors.transparent,
              ),
              child: Text(
                mode.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryCyan
                      : AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopActions() {
    return Row(
      children: [
        _ActionButton(
          icon: _flashOn ? Icons.flash_on : Icons.flash_off,
          color: _flashOn ? AppTheme.warningAmber : AppTheme.textSecondary,
          onTap: _toggleFlash,
        ),
        const SizedBox(width: 8),
        _ActionButton(
          icon: Icons.history,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildBottomControls(ScannerState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppTheme.backgroundDark, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Instructions
          if (!_isScanning)
            Text(
              state.detectedObjects.isEmpty
                  ? 'AIM CAMERA AT ANY OBJECT'
                  : '${state.detectedObjects.length} OBJECT${state.detectedObjects.length > 1 ? "S" : ""} DETECTED',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 2,
                color: state.detectedObjects.isEmpty
                    ? AppTheme.textSecondary
                    : AppTheme.accentGreen,
                fontWeight: FontWeight.w600,
              ),
            ).animate().fadeIn(),
          const SizedBox(height: 24),

          // Main scan button + side controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SideControlButton(
                icon: Icons.grid_on,
                label: 'Grid',
                onTap: () {},
              ),
              const SizedBox(width: 32),
              _MainScanButton(
                isScanning: _isScanning,
                pulseController: _pulseController,
                onTap: _captureAndScan,
              ),
              const SizedBox(width: 32),
              _SideControlButton(
                icon: Icons.tune,
                label: 'Mode',
                onTap: () => _showModeSheet(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick feature pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FeaturePill(
                  label: '3D TWIN',
                  icon: Icons.view_in_ar,
                  color: AppTheme.primaryCyan,
                ),
                _FeaturePill(
                  label: 'MEASURE',
                  icon: Icons.straighten,
                  color: AppTheme.accentGreen,
                ),
                _FeaturePill(
                  label: 'X-RAY',
                  icon: Icons.blur_on,
                  color: AppTheme.accentPurple,
                ),
                _FeaturePill(
                  label: 'REPAIR',
                  icon: Icons.build,
                  color: AppTheme.accentOrange,
                ),
                _FeaturePill(
                  label: 'AI CHAT',
                  icon: Icons.smart_toy,
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(80, 80),
                    painter: _RadarPainter(progress: _radarController.value),
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'ANALYZING OBJECT',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 16,
                  letterSpacing: 3,
                ),
              ).animate().shimmer(
                duration: 1500.ms,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(height: 8),
              const Text(
                'Building digital twin...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              _AnalysisSteps(),
            ],
          ),
        ),
      ),
    );
  }

  void _showModeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ScanModeSheet(),
    );
  }
}

class _MainScanButton extends StatelessWidget {
  final bool isScanning;
  final AnimationController pulseController;
  final VoidCallback onTap;

  const _MainScanButton({
    required this.isScanning,
    required this.pulseController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: 88 + (pulseController.value * 12),
                height: 88 + (pulseController.value * 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryCyan.withOpacity(
                      0.3 - (pulseController.value * 0.3),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // Inner button
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryCyan.withOpacity(0.3),
                      AppTheme.primaryCyan.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(
                    color: AppTheme.primaryCyan,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryCyan.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: isScanning
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.primaryCyan,
                        ),
                      )
                    : const Icon(
                        Icons.document_scanner,
                        color: AppTheme.primaryCyan,
                        size: 32,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.glassWhite,
          border: Border.all(color: AppTheme.glassWhiteStrong),
        ),
        child: Icon(
          icon,
          color: color ?? AppTheme.textPrimary,
          size: 20,
        ),
      ),
    );
  }
}

class _SideControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SideControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.glassWhite,
              border: Border.all(color: AppTheme.glassWhiteStrong),
            ),
            child: Icon(icon, color: AppTheme.textPrimary, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _FeaturePill({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalysisSteps extends StatefulWidget {
  @override
  State<_AnalysisSteps> createState() => _AnalysisStepsState();
}

class _AnalysisStepsState extends State<_AnalysisSteps> {
  int _currentStep = 0;
  late Timer _timer;

  final _steps = [
    'Object recognition...',
    'Material analysis...',
    'Dimension estimation...',
    'Component mapping...',
    'Building 3D model...',
    'Generating intelligence...',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (mounted && _currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _steps.asMap().entries.map((entry) {
        final isDone = entry.key < _currentStep;
        final isCurrent = entry.key == _currentStep;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 12,
                color: isDone
                    ? AppTheme.accentGreen
                    : isCurrent
                        ? AppTheme.primaryCyan
                        : AppTheme.textSecondary.withOpacity(0.3),
              ),
              const SizedBox(width: 6),
              Text(
                entry.value,
                style: TextStyle(
                  fontSize: 11,
                  color: isDone
                      ? AppTheme.accentGreen
                      : isCurrent
                          ? AppTheme.primaryCyan
                          : AppTheme.textSecondary.withOpacity(0.3),
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ScanModeSheet extends StatelessWidget {
  const _ScanModeSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SCAN MODE',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          ...ScanMode.values.map(
            (mode) => ListTile(
              leading: Icon(mode.icon, color: AppTheme.primaryCyan),
              title: Text(mode.label),
              subtitle: Text(
                mode.description,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              onTap: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double progress;
  _RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.primaryCyan.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Draw inner circles
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        radius * (i / 3),
        Paint()
          ..color = AppTheme.primaryCyan.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Draw sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 3.14,
        colors: [
          AppTheme.primaryCyan.withOpacity(0.0),
          AppTheme.primaryCyan.withOpacity(0.6),
        ],
        transform: GradientRotation(progress * 6.28),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 6.28,
      3.14,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.progress != progress;
}

enum ScanMode {
  auto,
  precision,
  quick,
  scene;

  String get label => switch (this) {
    ScanMode.auto => 'AUTO',
    ScanMode.precision => 'PRECISE',
    ScanMode.quick => 'QUICK',
    ScanMode.scene => 'SCENE',
  };

  String get description => switch (this) {
    ScanMode.auto => 'Automatically detects best settings for any object',
    ScanMode.precision => 'High-accuracy scan for engineering-grade measurements',
    ScanMode.quick => 'Fast identification and basic analysis',
    ScanMode.scene => 'Multi-object environment scanning',
  };

  IconData get icon => switch (this) {
    ScanMode.auto => Icons.auto_mode,
    ScanMode.precision => Icons.precision_manufacturing,
    ScanMode.quick => Icons.flash_on,
    ScanMode.scene => Icons.landscape,
  };
}
