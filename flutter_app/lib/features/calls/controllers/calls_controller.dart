import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_model.dart';

// ---------------------------------------------------------------------------
// Dio provider — uses the same base URL pattern as the rest of the app.
// A thin wrapper so tests can override the Dio instance easily.
// ---------------------------------------------------------------------------

final _kBaseUrl = 'https://api.arobjectscanner.com/v1';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: _kBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      LogInterceptor(requestBody: false, responseBody: false, error: true),
    );
});

final apiBaseUrlProvider = Provider<String>((_) => _kBaseUrl);

// ---------------------------------------------------------------------------
// CallsState
// ---------------------------------------------------------------------------

class CallsState {
  final bool isLoading;
  final List<CallRecord> calls;
  final CallRecord? activeCall;
  final String? error;
  final bool hasMore;
  final int total;

  const CallsState({
    this.isLoading = false,
    this.calls = const [],
    this.activeCall,
    this.error,
    this.hasMore = true,
    this.total = 0,
  });

  CallsState copyWith({
    bool? isLoading,
    List<CallRecord>? calls,
    CallRecord? activeCall,
    bool clearActiveCall = false,
    String? error,
    bool clearError = false,
    bool? hasMore,
    int? total,
  }) {
    return CallsState(
      isLoading: isLoading ?? this.isLoading,
      calls: calls ?? this.calls,
      activeCall: clearActiveCall ? null : (activeCall ?? this.activeCall),
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
    );
  }
}

// ---------------------------------------------------------------------------
// CallsNotifier
// ---------------------------------------------------------------------------

class CallsNotifier extends StateNotifier<CallsState> {
  final Dio _dio;

  CallsNotifier(this._dio) : super(const CallsState());

  // -------------------------------------------------------------------------
  // Load call history (first page)
  // -------------------------------------------------------------------------

  Future<void> loadHistory({int limit = 20, int offset = 0}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/calls/history',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      final data = response.data!;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final records = rawItems
          .map((e) => CallRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = (data['total'] as int?) ?? records.length;
      state = state.copyWith(
        isLoading: false,
        calls: records,
        total: total,
        hasMore: records.length < total,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Pagination — append next page
  // -------------------------------------------------------------------------

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/calls/history',
        queryParameters: {
          'limit': 20,
          'offset': state.calls.length,
        },
      );
      final data = response.data!;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final newRecords = rawItems
          .map((e) => CallRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = (data['total'] as int?) ?? state.total;
      final allCalls = [...state.calls, ...newRecords];
      state = state.copyWith(
        isLoading: false,
        calls: allCalls,
        total: total,
        hasMore: allCalls.length < total,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _formatError(e));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // Get a single call's full detail
  // -------------------------------------------------------------------------

  Future<CallRecord?> getCallDetail(String callId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/calls/$callId');
      final record = CallRecord.fromJson(response.data!);
      // Update the record in the local list if it's already there
      final updatedCalls = state.calls.map((c) {
        return c.callId == callId ? record : c;
      }).toList();
      state = state.copyWith(calls: updatedCalls);
      return record;
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Make a decision for an incoming call
  // -------------------------------------------------------------------------

  Future<void> makeDecision(String callId, CallDecision decision) async {
    try {
      await _dio.post<void>(
        '/calls/$callId/decision',
        data: {'decision': decision.name},
      );
      // Update local state optimistically
      final updatedCalls = state.calls.map((c) {
        if (c.callId == callId) return c.copyWith(decision: decision);
        return c;
      }).toList();
      state = state.copyWith(calls: updatedCalls, clearActiveCall: true);
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Fetch AI-generated summary for a call
  // -------------------------------------------------------------------------

  Future<String?> getCallSummary(String callId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/calls/$callId/summary');
      final summary = response.data?['summary'] as String?;
      if (summary != null) {
        final updatedCalls = state.calls.map((c) {
          return c.callId == callId ? c.copyWith(summary: summary) : c;
        }).toList();
        state = state.copyWith(calls: updatedCalls);
      }
      return summary;
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Natural-language query over call history
  // -------------------------------------------------------------------------

  Future<CallQueryResult?> queryCall(String query) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/calls/query',
        data: {'query': query},
      );
      return CallQueryResult.fromJson(response.data!);
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // Confirm (or dismiss) a calendar action extracted from a call
  // -------------------------------------------------------------------------

  Future<void> confirmCalendarAction(
    String callId,
    int actionIndex,
    bool confirmed,
    String calendarType,
  ) async {
    try {
      await _dio.post<void>(
        '/calendar/confirm-action',
        data: {
          'call_id': callId,
          'action_index': actionIndex,
          'confirmed': confirmed,
          'calendar_type': calendarType,
        },
      );
      // Update action locally
      final updatedCalls = state.calls.map((c) {
        if (c.callId != callId) return c;
        final updatedActions = List<ExtractedAction>.from(c.extractedActions);
        if (actionIndex >= 0 && actionIndex < updatedActions.length) {
          updatedActions[actionIndex] =
              updatedActions[actionIndex].copyWith(confirmed: confirmed);
        }
        return c.copyWith(extractedActions: updatedActions);
      }).toList();
      state = state.copyWith(calls: updatedCalls);
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Delete a call record
  // -------------------------------------------------------------------------

  Future<void> deleteCall(String callId) async {
    try {
      await _dio.delete<void>('/calls/$callId');
      state = state.copyWith(
        calls: state.calls.where((c) => c.callId != callId).toList(),
        total: state.total > 0 ? state.total - 1 : 0,
      );
    } on DioException catch (e) {
      state = state.copyWith(error: _formatError(e));
      rethrow;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Active call management (FCM-triggered)
  // -------------------------------------------------------------------------

  void setActiveCall(CallRecord call) {
    state = state.copyWith(activeCall: call);
  }

  void clearActiveCall() {
    state = state.copyWith(clearActiveCall: true);
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  String _formatError(DioException e) {
    final statusCode = e.response?.statusCode;
    final message =
        (e.response?.data as Map<String, dynamic>?)?['detail'] as String?;
    if (message != null) return message;
    if (statusCode != null) return 'Request failed ($statusCode)';
    return e.message ?? 'Network error';
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Primary provider for the calls feature.
final callsProvider =
    StateNotifierProvider<CallsNotifier, CallsState>((ref) {
  final dio = ref.watch(dioProvider);
  return CallsNotifier(dio);
});

/// FutureProvider.family for fetching a single call's detail on-demand.
final callDetailProvider =
    FutureProvider.family<CallRecord?, String>((ref, callId) async {
  final notifier = ref.read(callsProvider.notifier);
  return notifier.getCallDetail(callId);
});

/// Derived provider that exposes only the currently-ringing call.
final activeCallProvider = Provider<CallRecord?>((ref) {
  return ref.watch(callsProvider).activeCall;
});
