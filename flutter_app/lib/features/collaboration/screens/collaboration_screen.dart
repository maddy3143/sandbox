import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/holographic_button.dart';

class CollaborationScreen extends ConsumerStatefulWidget {
  const CollaborationScreen({super.key});

  @override
  ConsumerState<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends ConsumerState<CollaborationScreen> {
  bool _inSession = false;
  int _participantCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(
          'COLLABORATION',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        actions: [
          if (_inSession)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE · $_participantCount',
                    style: const TextStyle(
                      color: AppTheme.accentGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_inSession) ...[
              _SessionBanner().animate().fadeIn(duration: 500.ms),
              const SizedBox(height: 20),
              _CreateSessionCard(
                onCreateSession: () => setState(() {
                  _inSession = true;
                  _participantCount = 1;
                }),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              _JoinSessionCard().animate().fadeIn(delay: 400.ms),
            ] else ...[
              _ActiveSessionPanel(
                participantCount: _participantCount,
                onLeave: () => setState(() {
                  _inSession = false;
                  _participantCount = 0;
                }),
              ).animate().fadeIn(),
            ],
            const SizedBox(height: 20),
            _RecentCollaborations().animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 20),
            _EnterpriseFeatures().animate().fadeIn(delay: 800.ms),
          ],
        ),
      ),
    );
  }
}

class _SessionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryCyan.withOpacity(0.12),
            AppTheme.primaryBlue.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withOpacity(0.15),
              border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.4)),
            ),
            child: const Icon(Icons.people, color: AppTheme.primaryCyan, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-Time AR Collaboration',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Share scanned objects and collaborate in AR with engineers worldwide.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateSessionCard extends StatelessWidget {
  final VoidCallback onCreateSession;

  const _CreateSessionCard({required this.onCreateSession});

  @override
  Widget build(BuildContext context) {
    return GlassCyanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CREATE SESSION',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a live collaboration session and invite engineers to your AR workspace.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: HolographicButton(
                  label: 'CREATE SESSION',
                  icon: Icons.add_circle_outline,
                  color: AppTheme.primaryCyan,
                  height: 44,
                  onTap: onCreateSession,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JoinSessionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOIN SESSION',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Enter session code...',
              prefixIcon: const Icon(Icons.link, size: 18),
              suffixIcon: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                ),
                child: const Text(
                  'JOIN',
                  style: TextStyle(
                    color: AppTheme.accentGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 14, color: AppTheme.primaryCyan),
              SizedBox(width: 6),
              Text(
                'Or scan QR code to join',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveSessionPanel extends StatelessWidget {
  final int participantCount;
  final VoidCallback onLeave;

  const _ActiveSessionPanel({
    required this.participantCount,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCyanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ACTIVE SESSION',
                style: TextStyle(
                  color: AppTheme.accentGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              GestureDetector(
                onTap: onLeave,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
                  ),
                  child: const Text(
                    'LEAVE',
                    style: TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Session Code: AR-7X4K-9M2P',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: 'Orbitron',
              fontSize: 16,
              color: AppTheme.primaryCyan,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SessionTool(icon: Icons.mic, label: 'Voice', isActive: true),
              const SizedBox(width: 10),
              _SessionTool(icon: Icons.videocam, label: 'Video', isActive: false),
              const SizedBox(width: 10),
              _SessionTool(icon: Icons.screen_share, label: 'Share AR', isActive: true),
              const SizedBox(width: 10),
              _SessionTool(icon: Icons.chat, label: 'Chat', isActive: false),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'COLLABORATORS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          _CollaboratorRow(name: 'You (Host)', role: 'Engineer', isYou: true),
        ],
      ),
    );
  }
}

class _SessionTool extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _SessionTool({
    required this.icon,
    required this.label,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppTheme.primaryCyan.withOpacity(0.2)
                  : AppTheme.glassWhite,
              border: Border.all(
                color: isActive
                    ? AppTheme.primaryCyan
                    : AppTheme.glassWhiteStrong,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isActive ? AppTheme.primaryCyan : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollaboratorRow extends StatelessWidget {
  final String name;
  final String role;
  final bool isYou;

  const _CollaboratorRow({
    required this.name,
    required this.role,
    this.isYou = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryCyan.withOpacity(0.15),
              border: Border.all(color: AppTheme.primaryCyan.withOpacity(0.4)),
            ),
            child: const Icon(Icons.person, color: AppTheme.primaryCyan, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isYou)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'HOST',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecentCollaborations extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT SESSIONS',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: const Column(
            children: [
              _RecentRow(
                title: 'Engine Inspection Session',
                participants: 3,
                date: '2 hours ago',
                duration: '45 min',
              ),
              Divider(height: 16, color: AppTheme.glassWhite),
              _RecentRow(
                title: 'Motherboard Repair',
                participants: 2,
                date: 'Yesterday',
                duration: '1h 20min',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String title;
  final int participants;
  final String date;
  final String duration;

  const _RecentRow({
    required this.title,
    required this.participants,
    required this.date,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.history, color: AppTheme.textSecondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$date · $participants participants · $duration',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.replay, size: 16, color: AppTheme.primaryCyan),
      ],
    );
  }
}

class _EnterpriseFeatures extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.factory, 'Industrial Maintenance Teams', 'Coordinate repairs across facilities'),
      (Icons.engineering, 'Remote Engineering Support', 'Expert guidance from anywhere'),
      (Icons.school, 'Training & Certification', 'Live AR training sessions'),
      (Icons.business, 'Enterprise AR Workspace', 'Multi-site collaboration hub'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ENTERPRISE FEATURES',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 12),
        ...features.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.glassWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.glassWhiteStrong),
          ),
          child: Row(
            children: [
              Icon(f.$1, color: AppTheme.primaryCyan, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.$2,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      f.$3,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
