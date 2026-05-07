import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 180,
            backgroundColor: AppTheme.backgroundDark,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(),
            ),
            title: Text(
              'ACHIEVEMENTS',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _LevelProgress().animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 20),
                _ActiveChallenges().animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 20),
                _AchievementGrid().animate().fadeIn(delay: 400.ms),
                const SizedBox(height: 20),
                _LeaderBoard().animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF112240)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryCyan, AppTheme.primaryBlue],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryCyan.withOpacity(0.4),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.warningAmber,
                      ),
                      child: const Text(
                        '⚡',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'AR Engineer',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                    const Text(
                      'Level 12 · Master Mechanic',
                      style: TextStyle(
                        color: AppTheme.primaryCyan,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const _StatBadge('47', 'Scans'),
                        const SizedBox(width: 12),
                        const _StatBadge('23', 'Repairs'),
                        const SizedBox(width: 12),
                        const _StatBadge('8', 'Badges'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String value;
  final String label;

  const _StatBadge(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LevelProgress extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppTheme.warningAmber.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'LV 12',
                      style: TextStyle(
                        color: AppTheme.warningAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Orbitron',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MASTER MECHANIC',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const Text(
                '2,840 XP',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '2,840 / 4,000 XP to LV 13',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              const Text(
                '71%',
                style: TextStyle(color: AppTheme.warningAmber, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(
              value: 0.71,
              backgroundColor: AppTheme.glassWhite,
              valueColor: AlwaysStoppedAnimation(AppTheme.warningAmber),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Next rank: Elite Engineer at LV 15',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ActiveChallenges extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const challenges = [
      _Challenge(
        title: 'Scan 5 Electronics',
        progress: 3,
        total: 5,
        xp: 200,
        color: AppTheme.primaryCyan,
        icon: Icons.devices,
      ),
      _Challenge(
        title: 'Complete 3 Repairs',
        progress: 1,
        total: 3,
        xp: 350,
        color: AppTheme.accentOrange,
        icon: Icons.build,
      ),
      _Challenge(
        title: 'Use X-Ray Mode × 10',
        progress: 7,
        total: 10,
        xp: 150,
        color: AppTheme.accentPurple,
        icon: Icons.blur_on,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE CHALLENGES',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
            ),
            const Text(
              'SEE ALL',
              style: TextStyle(
                color: AppTheme.primaryCyan,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...challenges.asMap().entries.map(
          (e) => _ChallengeCard(challenge: e.value)
              .animate()
              .fadeIn(delay: Duration(milliseconds: e.key * 100))
              .slideX(begin: 0.1),
        ),
      ],
    );
  }
}

class _Challenge {
  final String title;
  final int progress;
  final int total;
  final int xp;
  final Color color;
  final IconData icon;

  const _Challenge({
    required this.title,
    required this.progress,
    required this.total,
    required this.xp,
    required this.color,
    required this.icon,
  });
}

class _ChallengeCard extends StatelessWidget {
  final _Challenge challenge;

  const _ChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: challenge.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: challenge.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: challenge.color.withOpacity(0.15),
              border: Border.all(color: challenge.color.withOpacity(0.4)),
            ),
            child: Icon(challenge.icon, color: challenge.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: challenge.progress / challenge.total,
                          backgroundColor: AppTheme.glassWhite,
                          valueColor: AlwaysStoppedAnimation(challenge.color),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${challenge.progress}/${challenge.total}',
                      style: TextStyle(
                        color: challenge.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text(
                '+${challenge.xp}',
                style: const TextStyle(
                  color: AppTheme.warningAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'XP',
                style: TextStyle(
                  color: AppTheme.warningAmber,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const achievements = [
      _Achievement('First Scan', Icons.camera_alt, AppTheme.accentGreen, true),
      _Achievement('Master Mechanic', Icons.build, AppTheme.accentOrange, true),
      _Achievement('Electronics Surgeon', Icons.memory, AppTheme.primaryCyan, true),
      _Achievement('Engine Expert', Icons.settings, AppTheme.warningAmber, true),
      _Achievement('X-Ray Vision', Icons.blur_on, AppTheme.accentPurple, true),
      _Achievement('Collaborator', Icons.people, AppTheme.primaryBlue, false),
      _Achievement('Speed Demon', Icons.flash_on, AppTheme.warningAmber, false),
      _Achievement('Perfectionist', Icons.star, AppTheme.accentGreen, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACHIEVEMENTS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: achievements.asMap().entries.map(
            (e) => _AchievementBadge(achievement: e.value)
                .animate()
                .scale(delay: Duration(milliseconds: e.key * 50)),
          ).toList(),
        ),
      ],
    );
  }
}

class _Achievement {
  final String name;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _Achievement(this.name, this.icon, this.color, this.unlocked);
}

class _AchievementBadge extends StatelessWidget {
  final _Achievement achievement;

  const _AchievementBadge({required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: achievement.name,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: achievement.unlocked
              ? achievement.color.withOpacity(0.15)
              : AppTheme.glassWhite,
          border: Border.all(
            color: achievement.unlocked
                ? achievement.color.withOpacity(0.5)
                : AppTheme.glassWhiteStrong,
          ),
          boxShadow: achievement.unlocked
              ? [
                  BoxShadow(
                    color: achievement.color.withOpacity(0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Icon(
          achievement.icon,
          color: achievement.unlocked
              ? achievement.color
              : AppTheme.textSecondary.withOpacity(0.3),
          size: 28,
        ),
      ),
    );
  }
}

class _LeaderBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LEADERBOARD',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            children: [
              _LeaderRow(rank: 1, name: 'TechMaster_Pro', xp: 18420, isMe: false),
              const Divider(height: 12, color: AppTheme.glassWhite),
              _LeaderRow(rank: 2, name: 'EngineerX9', xp: 15230, isMe: false),
              const Divider(height: 12, color: AppTheme.glassWhite),
              _LeaderRow(rank: 3, name: 'ARMechanic', xp: 12890, isMe: false),
              const Divider(height: 12, color: AppTheme.glassWhite),
              _LeaderRow(rank: 12, name: 'You', xp: 2840, isMe: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final int rank;
  final String name;
  final int xp;
  final bool isMe;

  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.xp,
    required this.isMe,
  });

  Color get _rankColor => rank == 1
      ? const Color(0xFFFFD700)
      : rank == 2
          ? const Color(0xFFC0C0C0)
          : rank == 3
              ? const Color(0xFFCD7F32)
              : AppTheme.textSecondary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: isMe
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : EdgeInsets.zero,
      decoration: isMe
          ? BoxDecoration(
              color: AppTheme.primaryCyan.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: _rankColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: isMe ? AppTheme.primaryCyan : AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${xp.toString()} XP',
            style: TextStyle(
              color: isMe ? AppTheme.primaryCyan : AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
