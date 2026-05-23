import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../controllers/calls_controller.dart';
import '../models/call_model.dart';

// ---------------------------------------------------------------------------
// CallDetailScreen
// ---------------------------------------------------------------------------

class CallDetailScreen extends ConsumerStatefulWidget {
  final String callId;

  const CallDetailScreen({super.key, required this.callId});

  @override
  ConsumerState<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends ConsumerState<CallDetailScreen> {
  bool _transcriptExpanded = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(callDetailProvider(widget.callId));

    return detailAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('Call Detail'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppTheme.backgroundDark,
        appBar: AppBar(
          title: const Text('Call Detail'),
          backgroundColor: AppTheme.surfaceDark,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppTheme.errorRed,
                  size: 56,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load call details',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.refresh(callDetailProvider(widget.callId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (call) {
        if (call == null) {
          return Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            appBar: AppBar(
              title: const Text('Call Detail'),
              backgroundColor: AppTheme.surfaceDark,
            ),
            body: const Center(
              child: Text(
                'Call not found',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          );
        }
        return _buildDetail(context, call);
      },
    );
  }

  // -------------------------------------------------------------------------
  // Main detail scaffold
  // -------------------------------------------------------------------------

  Widget _buildDetail(BuildContext context, CallRecord call) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, call),
          SliverToBoxAdapter(child: _buildHeaderCard(call)),
          if (call.summary != null && call.summary!.isNotEmpty)
            SliverToBoxAdapter(child: _buildSummaryCard(call)),
          if (call.extractedActions.isNotEmpty)
            SliverToBoxAdapter(child: _buildActionsSection(context, call)),
          SliverToBoxAdapter(child: _buildTranscriptSection(call)),
          SliverToBoxAdapter(child: _buildDeleteButton(context, call)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SliverAppBar
  // -------------------------------------------------------------------------

  SliverAppBar _buildSliverAppBar(BuildContext context, CallRecord call) {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.surfaceDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryBlue.withOpacity(0.3),
                AppTheme.accentPurple.withOpacity(0.2),
                AppTheme.surfaceDark,
              ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryBlue.withOpacity(0.8),
                          AppTheme.accentPurple.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.phone_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    call.callerName ?? call.fromNumber,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Header card — meta info
  // -------------------------------------------------------------------------

  Widget _buildHeaderCard(CallRecord call) {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _metaRow(Icons.phone_rounded, 'Number', call.fromNumber),
          const SizedBox(height: 12),
          _metaRow(
            Icons.calendar_today_rounded,
            'Date',
            DateFormat('MMM d, yyyy · h:mm a').format(call.startedAt),
          ),
          if (call.durationSeconds != null && call.durationSeconds! > 0) ...[
            const SizedBox(height: 12),
            _metaRow(
              Icons.timer_rounded,
              'Duration',
              call.durationFormatted,
            ),
          ],
          if (call.languageDetected != null) ...[
            const SizedBox(height: 12),
            _metaRow(
              Icons.language_rounded,
              'Language',
              '${call.languageFlag}  ${call.languageDisplayName}',
            ),
          ],
          const SizedBox(height: 12),
          _metaRow(
            Icons.info_outline_rounded,
            'Status',
            call.statusLabel,
            valueColor: _statusColor(call.status),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _metaRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryCyan),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _statusColor(CallStatus status) {
    switch (status) {
      case CallStatus.completed:
        return AppTheme.accentGreen;
      case CallStatus.missed:
        return AppTheme.errorRed;
      case CallStatus.declined:
        return AppTheme.accentOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  // -------------------------------------------------------------------------
  // Summary card
  // -------------------------------------------------------------------------

  Widget _buildSummaryCard(CallRecord call) {
    return GlassCyanCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primaryCyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Summary',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryCyan,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            call.summary!,
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  // -------------------------------------------------------------------------
  // Action items
  // -------------------------------------------------------------------------

  Widget _buildActionsSection(BuildContext context, CallRecord call) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: AppTheme.warningAmber,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Action Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.warningAmber.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  '${call.extractedActions.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...call.extractedActions.asMap().entries.map(
            (entry) => _ActionCard(
              action: entry.value,
              index: entry.key,
              callId: call.callId,
            ).animate(delay: (entry.key * 80).ms).fadeIn(duration: 300.ms),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Transcript
  // -------------------------------------------------------------------------

  Widget _buildTranscriptSection(CallRecord call) {
    final hasTurns = call.transcriptTurns.isNotEmpty;
    final hasRaw = call.transcript != null && call.transcript!.isNotEmpty;

    if (!hasTurns && !hasRaw) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                setState(() => _transcriptExpanded = !_transcriptExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.glassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.glassWhiteStrong),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppTheme.primaryCyan,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Full Transcript',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _transcriptExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_transcriptExpanded) ...[
            const SizedBox(height: 12),
            if (hasTurns)
              ...call.transcriptTurns.map((turn) => _TranscriptBubble(turn: turn))
            else if (hasRaw)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.glassWhiteStrong),
                ),
                child: Text(
                  call.transcript!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Delete button
  // -------------------------------------------------------------------------

  Widget _buildDeleteButton(BuildContext context, CallRecord call) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: OutlinedButton.icon(
        onPressed: () => _confirmDelete(context, call),
        icon: const Icon(Icons.delete_rounded),
        label: const Text('Delete Call Record'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorRed,
          side: const BorderSide(color: AppTheme.errorRed, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CallRecord call) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.errorRed.withOpacity(0.4)),
        ),
        title: const Text(
          'Delete Call Record',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'This call record and its transcript will be permanently deleted.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(callsProvider.notifier)
            .deleteCall(call.callId);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// _ActionCard
// ---------------------------------------------------------------------------

class _ActionCard extends ConsumerStatefulWidget {
  final ExtractedAction action;
  final int index;
  final String callId;

  const _ActionCard({
    required this.action,
    required this.index,
    required this.callId,
  });

  @override
  ConsumerState<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<_ActionCard> {
  bool _isLoading = false;

  IconData get _actionIcon {
    switch (widget.action.actionType) {
      case ActionType.meeting:
        return Icons.groups_rounded;
      case ActionType.appointment:
        return Icons.event_rounded;
      case ActionType.reminder:
        return Icons.notifications_rounded;
      case ActionType.travel:
        return Icons.flight_rounded;
      case ActionType.followUp:
        return Icons.reply_rounded;
      case ActionType.delivery:
        return Icons.local_shipping_rounded;
      case ActionType.invitation:
        return Icons.mail_rounded;
      case ActionType.work:
        return Icons.work_rounded;
      case ActionType.personal:
        return Icons.person_rounded;
    }
  }

  Color get _actionColor {
    switch (widget.action.actionType) {
      case ActionType.meeting:
      case ActionType.appointment:
        return AppTheme.primaryCyan;
      case ActionType.reminder:
        return AppTheme.warningAmber;
      case ActionType.travel:
        return AppTheme.accentPurple;
      case ActionType.delivery:
        return AppTheme.accentGreen;
      default:
        return AppTheme.primaryBlue;
    }
  }

  void _showCalendarPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CalendarProviderSheet(
        onProviderSelected: (provider) {
          Navigator.of(ctx).pop();
          _addToCalendar(context, provider);
        },
      ),
    );
  }

  Future<void> _addToCalendar(
    BuildContext context,
    String calendarType,
  ) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(callsProvider.notifier).confirmCalendarAction(
            widget.callId,
            widget.index,
            true,
            calendarType,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Added to ${_calendarDisplayName(calendarType)}'),
            backgroundColor: AppTheme.accentGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to calendar: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismiss(BuildContext context) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(callsProvider.notifier).confirmCalendarAction(
            widget.callId,
            widget.index,
            false,
            'none',
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dismiss: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _calendarDisplayName(String type) {
    switch (type) {
      case 'google':
        return 'Google Calendar';
      case 'outlook':
        return 'Outlook';
      default:
        return 'Device Calendar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: action.confirmed
              ? AppTheme.accentGreen.withOpacity(0.5)
              : _actionColor.withOpacity(0.3),
        ),
        color: action.confirmed
            ? AppTheme.accentGreen.withOpacity(0.07)
            : _actionColor.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _actionColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_actionIcon, color: _actionColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (action.confirmed)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  size: 22,
                ),
            ],
          ),
          if (action.datetimeStr != null || action.location != null) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.glassWhite, height: 1),
            const SizedBox(height: 10),
            if (action.datetimeStr != null)
              _actionMeta(
                Icons.schedule_rounded,
                action.datetimeStr!,
              ),
            if (action.location != null)
              _actionMeta(Icons.location_on_rounded, action.location!),
            if (action.attendees != null && action.attendees!.isNotEmpty)
              _actionMeta(
                Icons.people_rounded,
                action.attendees!.join(', '),
              ),
          ],
          if (!action.confirmed && !_isLoading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCalendarPicker(context),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Add to Calendar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _actionColor,
                      side: BorderSide(color: _actionColor.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => _dismiss(context),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryCyan,
                  strokeWidth: 2,
                ),
              ),
            ),
          if (action.confirmed && action.calendarEventId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentGreen,
                  size: 14,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Added to Calendar',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionMeta(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CalendarProviderSheet
// ---------------------------------------------------------------------------

class _CalendarProviderSheet extends StatelessWidget {
  final void Function(String provider) onProviderSelected;

  const _CalendarProviderSheet({required this.onProviderSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppTheme.glassWhiteStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add to Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose your calendar provider',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _providerTile(
            context,
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF4285F4),
            label: 'Google Calendar',
            provider: 'google',
          ),
          const SizedBox(height: 12),
          _providerTile(
            context,
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFF0078D4),
            label: 'Outlook',
            provider: 'outlook',
          ),
          const SizedBox(height: 12),
          _providerTile(
            context,
            icon: Icons.phone_android_rounded,
            iconColor: AppTheme.accentGreen,
            label: 'Device Calendar',
            provider: 'device',
          ),
        ],
      ),
    );
  }

  Widget _providerTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String provider,
  }) {
    return GestureDetector(
      onTap: () => onProviderSelected(provider),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: AppTheme.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassWhiteStrong),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TranscriptBubble
// ---------------------------------------------------------------------------

class _TranscriptBubble extends StatelessWidget {
  final ConversationTurn turn;

  const _TranscriptBubble({required this.turn});

  bool get _isCaller => turn.role == 'caller';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            _isCaller ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (_isCaller) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.glassWhite,
                border: Border.all(color: AppTheme.glassWhiteStrong),
              ),
              child: const Icon(
                Icons.person_rounded,
                size: 18,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: _isCaller
                    ? AppTheme.surfaceMid
                    : AppTheme.primaryBlue.withOpacity(0.3),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(_isCaller ? 4 : 16),
                  bottomRight: Radius.circular(_isCaller ? 16 : 4),
                ),
                border: Border.all(
                  color: _isCaller
                      ? AppTheme.glassWhiteStrong
                      : AppTheme.primaryBlue.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    turn.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _languageFlag(turn.language),
                        style: const TextStyle(fontSize: 11),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(turn.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!_isCaller) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.8),
                    AppTheme.accentPurple.withOpacity(0.8),
                  ],
                ),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _languageFlag(String lang) {
    switch (lang.toLowerCase()) {
      case 'te':
      case 'tel':
      case 'telugu':
      case 'hi':
      case 'hin':
      case 'hindi':
      case 'kn':
      case 'kan':
      case 'kannada':
      case 'ta':
      case 'tamil':
      case 'ml':
      case 'malayalam':
        return '\u{1F1EE}\u{1F1F3}';
      case 'ar':
      case 'arabic':
        return '\u{1F1F8}\u{1F1E6}';
      case 'es':
      case 'spanish':
        return '\u{1F1EA}\u{1F1F8}';
      case 'fr':
      case 'french':
        return '\u{1F1EB}\u{1F1F7}';
      default:
        return '\u{1F1FA}\u{1F1F8}';
    }
  }
}
