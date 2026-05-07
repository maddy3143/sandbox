import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/route_names.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNavBar(),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.glassWhite)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.camera_alt_outlined,
                activeIcon: Icons.camera_alt,
                label: 'Scan',
                isActive: location.startsWith('/scanner') ||
                    location.startsWith('/scan-result'),
                onTap: () => context.go(RouteNames.scanner),
              ),
              _NavItem(
                icon: Icons.view_in_ar_outlined,
                activeIcon: Icons.view_in_ar,
                label: 'Twins',
                isActive: location.startsWith('/digital-twin'),
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.shopping_bag_outlined,
                activeIcon: Icons.shopping_bag,
                label: 'Parts',
                isActive: location.startsWith('/marketplace'),
                onTap: () => context.go(RouteNames.marketplace),
              ),
              _NavItem(
                icon: Icons.people_outline,
                activeIcon: Icons.people,
                label: 'Collab',
                isActive: location.startsWith('/collaboration'),
                onTap: () => context.go(RouteNames.collaboration),
              ),
              _NavItem(
                icon: Icons.emoji_events_outlined,
                activeIcon: Icons.emoji_events,
                label: 'Achieve',
                isActive: location.startsWith('/gamification'),
                onTap: () => context.go(RouteNames.gamification),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.primaryCyan.withOpacity(0.15),
                border: Border.all(
                  color: AppTheme.primaryCyan.withOpacity(0.3),
                ),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
