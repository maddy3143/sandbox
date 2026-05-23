import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/calls/controllers/calls_controller.dart';

// ---------------------------------------------------------------------------
// CalendarEvent — lightweight DTO for upcoming events
// ---------------------------------------------------------------------------

class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime start;
  final DateTime? end;
  final String? location;
  final List<String> attendees;
  final String provider;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    required this.start,
    this.end,
    this.location,
    this.attendees = const [],
    required this.provider,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      start: DateTime.parse(json['start'] as String),
      end: json['end'] != null
          ? DateTime.parse(json['end'] as String)
          : null,
      location: json['location'] as String?,
      attendees: (json['attendees'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      provider: json['provider'] as String? ?? 'unknown',
    );
  }
}

// ---------------------------------------------------------------------------
// CalendarService
// ---------------------------------------------------------------------------

class CalendarService {
  const CalendarService(this._dio);

  final Dio _dio;

  // -------------------------------------------------------------------------
  // Google Calendar OAuth
  // -------------------------------------------------------------------------

  /// Returns the Google OAuth authorisation URL.
  Future<String> getGoogleAuthUrl() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/calendar/auth/google');
    final url = response.data?['url'] as String?;
    if (url == null) {
      throw const FormatException('Missing "url" field in Google auth response');
    }
    return url;
  }

  /// Exchange the [authCode] returned by Google for access/refresh tokens.
  /// Returns `true` on success.
  Future<bool> connectGoogle(String authCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/calendar/auth/google/callback',
        data: {'code': authCode},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _rethrow('Google Calendar connect failed', e);
    }
  }

  // -------------------------------------------------------------------------
  // Outlook Calendar OAuth
  // -------------------------------------------------------------------------

  /// Returns the Outlook OAuth authorisation URL.
  Future<String> getOutlookAuthUrl() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/calendar/auth/outlook');
    final url = response.data?['url'] as String?;
    if (url == null) {
      throw const FormatException(
        'Missing "url" field in Outlook auth response',
      );
    }
    return url;
  }

  /// Exchange the [authCode] returned by Outlook for access/refresh tokens.
  /// Returns `true` on success.
  Future<bool> connectOutlook(String authCode) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/calendar/auth/outlook/callback',
        data: {'code': authCode},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _rethrow('Outlook Calendar connect failed', e);
    }
  }

  // -------------------------------------------------------------------------
  // Create / confirm event from a call action
  // -------------------------------------------------------------------------

  /// Calls the confirm-action endpoint to create a calendar event.
  ///
  /// [callId] — The call the action belongs to.
  /// [actionIndex] — Zero-based index of the action in `extractedActions`.
  /// [calendarType] — `"google"`, `"outlook"`, or `"device"`.
  ///
  /// Returns `true` if the event was created successfully.
  Future<bool> createEvent({
    required String callId,
    required int actionIndex,
    required String calendarType,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/calendar/confirm-action',
        data: {
          'call_id': callId,
          'action_index': actionIndex,
          'confirmed': true,
          'calendar_type': calendarType,
        },
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      _rethrow('Create calendar event failed', e);
    }
  }

  // -------------------------------------------------------------------------
  // List upcoming events
  // -------------------------------------------------------------------------

  /// Fetch upcoming calendar events from [provider] (`"google"`, `"outlook"`).
  Future<List<CalendarEvent>> getUpcomingEvents(String provider) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/calendar/events',
        queryParameters: {'provider': provider},
      );
      final items =
          (response.data?['items'] as List<dynamic>?) ?? [];
      return items
          .map(
            (e) => CalendarEvent.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      _rethrow('Fetch upcoming events failed', e);
    }
  }

  // -------------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------------

  Never _rethrow(String message, DioException e) {
    final statusCode = e.response?.statusCode;
    final detail =
        (e.response?.data as Map<String, dynamic>?)?['detail'] as String?;
    final description =
        detail ?? (statusCode != null ? '$message ($statusCode)' : message);
    throw Exception(description);
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final calendarServiceProvider = Provider<CalendarService>((ref) {
  final dio = ref.watch(dioProvider);
  return CalendarService(dio);
});
