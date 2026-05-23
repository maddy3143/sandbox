import 'dart:async';
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
// Route constant
// ---------------------------------------------------------------------------

const _kCallHistoryPath = '/calls';

// ---------------------------------------------------------------------------
// Filter enum
// ---------------------------------------------------------------------------

enum _CallFilter { all, aiAnswered, missed, completed }

extension _CallFilterLabel on _CallFilter {
  String get label {
    switch (this) {
      case _CallFilter.all:
        return 'All';
      case _CallFilter.aiAnswered:
        return 'AI Answered';
      case _CallFilter.missed:
        return 'Missed';
      case _CallFilter.completed:
        return 'Completed';
    }
  }
}

// ---------------------------------------------------------------------------
// CallHistoryScreen
// ---------------------------------------------------------------------------

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _searchExpanded = false;
  String _searchQuery = '';
  _CallFilter _activeFilter = _CallFilter.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(callsProvider.notifier).loadHistory();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(callsProvider.notifier).loadMore();
    }
  }

  List<CallRecord> _applyFiltersAndSearch(List<CallRecord> calls) {
    Iterable<CallRecord> filtered = calls;

    // Apply status filter
    switch (_activeFilter) {
      case _CallFilter.all:
        break;
      case _CallFilter.aiAnswered:
        filtered = filtered.where(
          (c) => c.decision == CallDecision.letAiAnswer,
        );
        break;
      case _CallFilter.missed:
        filtered = filtered.where((c) => c.status == CallStatus.missed);
        break;
      case _CallFilter.completed:
        filtered = filtered.where((c) => c.status == CallStatus.completed);
        break;
    }

    // Apply search
    final q = _searchQuery.toLowerCase().trim();
    if (q.isNotEmpty) {
      filtered = filtered.where((c) {
        return (c.callerName?.toLowerCase().contains(q) ?? false) ||
            c.fromNumber.contains(q) ||
            (c.summary?.toLowerCase().contains(q) ?? false);
      });
    }

    return filtered.toList();
  }

  // -------------------------------------------------------------------------
  // Delete with confirmation
  // -------------------------------------------------------------------------

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
          'Delete Call',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Delete the call record from ${call.callerName ?? call.fromNumber}? This cannot be undone.',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
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
        await ref.read(callsProvider.notifier).deleteCall(call.callId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Call record deleted')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete call record'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    }
  }

  // -------------------------------------------------------------------------
  // Query bottom sheet
  // -------------------------------------------------------------------------

  void _showQueryBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _QueryBottomSheet(
        onQueryResult: (result) {
          Navigator.of(ctx).pop();
          // Navigate or display results — handled inside the sheet
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final callsState = ref.watch(callsProvider);
    final visibleCalls = _applyFiltersAndSearch(callsState.calls);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_searchExpanded) _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildBody(callsState, visibleCalls),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showQueryBottomSheet,
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        tooltip: 'Ask about calls',
        child: const Icon(Icons.mic_rounded),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Call History'),
      backgroundColor: AppTheme.surfaceDark,
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            _searchExpanded ? Icons.search_off_rounded : Icons.search_rounded,
            color: AppTheme.primaryCyan,
          ),
          onPressed: () {
            setState(() {
              _searchExpanded = !_searchExpanded;
              if (!_searchExpanded) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search calls, numbers, summaries…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  color: AppTheme.textSecondary,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    ).animate().slideY(begin: -0.2, duration: 200.ms).fadeIn(duration: 200.ms);
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _CallFilter.values.map((filter) {
          final selected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) => setState(() => _activeFilter = filter),
              selectedColor: AppTheme.primaryCyan.withOpacity(0.2),
              checkmarkColor: AppTheme.primaryCyan,
              side: BorderSide(
                color: selected
                    ? AppTheme.primaryCyan
                    : AppTheme.glassWhiteStrong,
              ),
              labelStyle: TextStyle(
                color: selected ? AppTheme.primaryCyan : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(CallsState state, List<CallRecord> calls) {
    if (state.isLoading && calls.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryCyan),
      );
    }

    if (calls.isEmpty) {
      return _buildEmptyState(state);
    }

    return RefreshIndicator(
      color: AppTheme.primaryCyan,
      backgroundColor: AppTheme.surfaceMid,
      onRefresh: () =>
          ref.read(callsProvider.notifier).loadHistory(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: calls.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == calls.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryCyan,
                  strokeWidth: 2,
                ),
              ),
            );
          }

          final call = calls[index];
          return _CallCard(
            call: call,
            onTap: () => context.push('/calls/${call.callId}'),
            onDelete: () => _confirmDelete(context, call),
          )
              .animate(delay: (index * 40).ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.1, duration: 300.ms);
        },
      ),
    );
  }

  Widget _buildEmptyState(CallsState state) {
    final hasSearch = _searchQuery.isNotEmpty || _activeFilter != _CallFilter.all;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch ? Icons.search_off_rounded : Icons.phone_missed_rounded,
              size: 72,
              color: AppTheme.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 24),
            Text(
              hasSearch ? 'No matching calls' : 'No calls yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasSearch
                  ? 'Try adjusting your search or filters.'
                  : 'Calls handled by your AI assistant will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(callsProvider.notifier).loadHistory(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CallCard
// ---------------------------------------------------------------------------

class _CallCard extends StatelessWidget {
  final CallRecord call;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CallCard({
    required this.call,
    required this.onTap,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (call.status) {
      case CallStatus.completed:
        return AppTheme.accentGreen;
      case CallStatus.missed:
        return AppTheme.errorRed;
      case CallStatus.declined:
        return AppTheme.accentOrange;
      case CallStatus.aiAnswering:
      case CallStatus.inProgress:
        return AppTheme.primaryCyan;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(call.callId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
        ),
        child: const Icon(Icons.delete_rounded, color: AppTheme.errorRed),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Deletion is handled inside onDelete with confirmation
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.callerName ?? call.fromNumber,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (call.callerName != null)
                        Text(
                          call.fromNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatRelativeTime(call.startedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (call.languageDetected != null) ...[
                  Text(
                    call.languageFlag,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    call.languageDisplayName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                if (call.durationSeconds != null && call.durationSeconds! > 0) ...[
                  const Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    call.durationFormatted,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                if (call.hasPendingActions)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.warningAmber.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '${call.pendingActionCount} action${call.pendingActionCount > 1 ? 's' : ''} pending',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (call.summary != null && call.summary!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                call.summary!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    switch (call.status) {
      case CallStatus.missed:
        icon = Icons.phone_missed_rounded;
        break;
      case CallStatus.declined:
        icon = Icons.phone_disabled_rounded;
        break;
      case CallStatus.completed:
        icon = call.decision == CallDecision.letAiAnswer
            ? Icons.smart_toy_rounded
            : Icons.phone_rounded;
        break;
      default:
        icon = Icons.phone_rounded;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: _statusColor.withOpacity(0.35)),
      ),
      child: Icon(icon, color: _statusColor, size: 22),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.4)),
      ),
      child: Text(
        call.statusLabel,
        style: TextStyle(
          fontSize: 11,
          color: _statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ---------------------------------------------------------------------------
// _QueryBottomSheet
// ---------------------------------------------------------------------------

class _QueryBottomSheet extends ConsumerStatefulWidget {
  final void Function(CallQueryResult result) onQueryResult;

  const _QueryBottomSheet({required this.onQueryResult});

  @override
  ConsumerState<_QueryBottomSheet> createState() => _QueryBottomSheetState();
}

class _QueryBottomSheetState extends ConsumerState<_QueryBottomSheet> {
  final TextEditingController _queryController = TextEditingController();
  bool _isSearching = false;
  CallQueryResult? _result;
  String? _error;

  static const List<String> _suggestions = [
    "Summarize today's calls",
    "Any missed meetings?",
    "Did someone call about delivery?",
    "What did the last caller want?",
    "Any follow-up actions pending?",
  ];

  Future<void> _runQuery(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _result = null;
      _error = null;
    });
    try {
      final result =
          await ref.read(callsProvider.notifier).queryCall(query.trim());
      if (mounted) {
        setState(() {
          _result = result;
          _isSearching = false;
        });
        if (result != null) widget.onQueryResult(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.glassWhiteStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Ask about your calls',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Ask anything about your calls…',
                      prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                    ),
                    onSubmitted: _runQuery,
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 12),
                _isSearching
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primaryCyan,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : IconButton.filled(
                        icon: const Icon(Icons.send_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryCyan,
                          foregroundColor: AppTheme.backgroundDark,
                        ),
                        onPressed: () => _runQuery(_queryController.text),
                      ),
              ],
            ),
            const SizedBox(height: 16),
            if (_result == null && !_isSearching) ...[
              const Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions.map((s) {
                  return GestureDetector(
                    onTap: () {
                      _queryController.text = s;
                      _runQuery(s);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.glassWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.glassWhiteStrong),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.primaryCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI Response',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryCyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.answer,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
