import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';
import '../widgets/twin_viewport.dart';
import '../widgets/component_inspector_panel.dart';
import '../providers/digital_twin_provider.dart';

class DigitalTwinScreen extends ConsumerStatefulWidget {
  final String objectId;

  const DigitalTwinScreen({super.key, required this.objectId});

  @override
  ConsumerState<DigitalTwinScreen> createState() => _DigitalTwinScreenState();
}

class _DigitalTwinScreenState extends ConsumerState<DigitalTwinScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ViewMode _viewMode = ViewMode.solid;
  bool _showComponentPanel = false;
  String? _selectedComponentId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(digitalTwinProvider(widget.objectId).notifier).initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final twinState = ref.watch(digitalTwinProvider(widget.objectId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // 3D viewport — takes full screen
          Positioned.fill(
            child: TwinViewport(
              objectId: widget.objectId,
              viewMode: _viewMode,
              selectedComponentId: _selectedComponentId,
              onComponentSelected: (id) {
                setState(() {
                  _selectedComponentId = id;
                  _showComponentPanel = id != null;
                });
              },
            ),
          ),

          // Top controls overlay
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context),
                const SizedBox(height: 8),
                _buildViewModeBar(),
              ],
            ),
          ),

          // Right side tools
          Positioned(
            right: 12,
            top: 130,
            child: _buildRightTools(),
          ),

          // Bottom HUD
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomHUD(twinState),
          ),

          // Component inspector panel (slides in from right)
          if (_showComponentPanel && _selectedComponentId != null)
            Positioned(
              right: 0,
              top: 100,
              bottom: 120,
              width: 260,
              child: ComponentInspectorPanel(
                componentId: _selectedComponentId!,
                objectId: widget.objectId,
                onClose: () => setState(() {
                  _showComponentPanel = false;
                  _selectedComponentId = null;
                }),
              ).animate().slideX(begin: 1.0),
            ),

          // Loading overlay
          if (twinState.isLoading)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
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
                  'DIGITAL TWIN',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontSize: 16,
                    letterSpacing: 3,
                  ),
                ),
                const Text(
                  'Interactive 3D Model',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _TwinActionButton(icon: Icons.screenshot, onTap: () {}),
          const SizedBox(width: 8),
          _TwinActionButton(icon: Icons.share_outlined, onTap: () {}),
          const SizedBox(width: 8),
          _TwinActionButton(icon: Icons.fullscreen, onTap: () {}),
        ],
      ),
    );
  }

  Widget _buildViewModeBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ViewMode.values.map((mode) {
          final isSelected = mode == _viewMode;
          return GestureDetector(
            onTap: () => setState(() => _viewMode = mode),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? mode.color.withOpacity(0.2)
                    : AppTheme.glassWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? mode.color : AppTheme.glassWhiteStrong,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mode.icon, size: 12, color: isSelected ? mode.color : AppTheme.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? mode.color : AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRightTools() {
    return Column(
      children: [
        _ToolButton(
          icon: Icons.add,
          onTap: () => ref.read(digitalTwinProvider(widget.objectId).notifier).zoom(1.2),
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.remove,
          onTap: () => ref.read(digitalTwinProvider(widget.objectId).notifier).zoom(0.8),
        ),
        const SizedBox(height: 16),
        _ToolButton(
          icon: Icons.rotate_right,
          onTap: () => ref.read(digitalTwinProvider(widget.objectId).notifier).autoRotate(),
        ),
        const SizedBox(height: 8),
        _ToolButton(
          icon: Icons.center_focus_strong,
          onTap: () => ref.read(digitalTwinProvider(widget.objectId).notifier).resetCamera(),
        ),
        const SizedBox(height: 16),
        _ToolButton(
          icon: Icons.layers_outlined,
          onTap: () {},
          color: AppTheme.accentGreen,
        ),
      ],
    );
  }

  Widget _buildBottomHUD(DigitalTwinState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppTheme.backgroundDark, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Component count & info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HUDChip(
                label: '${state.componentCount} PARTS',
                icon: Icons.category,
                color: AppTheme.primaryCyan,
              ),
              const SizedBox(width: 10),
              _HUDChip(
                label: 'POLY ${state.polyCount}K',
                icon: Icons.grid_3x3,
                color: AppTheme.accentGreen,
              ),
              const SizedBox(width: 10),
              _HUDChip(
                label: state.renderQuality,
                icon: Icons.high_quality,
                color: AppTheme.accentPurple,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              HolographicButton(
                label: 'EXPLODE',
                icon: Icons.layers,
                color: AppTheme.accentGreen,
                onTap: () => context.push('/exploded-view/${widget.objectId}'),
                width: 120,
                height: 42,
              ),
              HolographicButton(
                label: 'X-RAY',
                icon: Icons.blur_on,
                color: AppTheme.accentPurple,
                onTap: () => context.push('/xray-mode/${widget.objectId}'),
                width: 120,
                height: 42,
              ),
              HolographicButton(
                label: 'SIMULATE',
                icon: Icons.play_circle_outline,
                color: AppTheme.warningAmber,
                onTap: () => ref.read(digitalTwinProvider(widget.objectId).notifier).startSimulation(),
                width: 120,
                height: 42,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: AppTheme.backgroundDark.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryCyan),
            const SizedBox(height: 16),
            Text(
              'GENERATING 3D TWIN',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 14,
                letterSpacing: 3,
              ),
            ).animate().shimmer(duration: 1500.ms, color: AppTheme.primaryCyan),
          ],
        ),
      ),
    );
  }
}

class _TwinActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TwinActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.glassWhite,
          border: Border.all(color: AppTheme.glassWhiteStrong),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 18),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ToolButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.glassWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color != null ? color!.withOpacity(0.4) : AppTheme.glassWhiteStrong,
          ),
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

class _HUDChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _HUDChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum ViewMode {
  solid,
  wireframe,
  transparent,
  xray,
  thermal;

  String get label => switch (this) {
    ViewMode.solid => 'SOLID',
    ViewMode.wireframe => 'WIRE',
    ViewMode.transparent => 'GLASS',
    ViewMode.xray => 'X-RAY',
    ViewMode.thermal => 'THERMAL',
  };

  IconData get icon => switch (this) {
    ViewMode.solid => Icons.crop_square,
    ViewMode.wireframe => Icons.grid_3x3,
    ViewMode.transparent => Icons.blur_circular,
    ViewMode.xray => Icons.blur_on,
    ViewMode.thermal => Icons.thermostat,
  };

  Color get color => switch (this) {
    ViewMode.solid => AppTheme.primaryCyan,
    ViewMode.wireframe => AppTheme.accentGreen,
    ViewMode.transparent => AppTheme.primaryBlue,
    ViewMode.xray => AppTheme.accentPurple,
    ViewMode.thermal => AppTheme.accentOrange,
  };
}
