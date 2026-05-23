import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/calls/controllers/calls_controller.dart';
import '../features/calls/models/call_model.dart';

// ---------------------------------------------------------------------------
// Background handler — must be a top-level function
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled silently.
  // The next app open will load the call history and surface the record.
  debugPrint('[NotificationService] Background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// Notification channel IDs
// ---------------------------------------------------------------------------

class _Channels {
  static const incomingCalls = AndroidNotificationChannel(
    'incoming_calls',
    'Incoming Calls',
    description: 'Full-screen alerts for incoming calls handled by AI',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  static const callSummaries = AndroidNotificationChannel(
    'call_summaries',
    'Call Summaries',
    description: 'Summaries and transcripts delivered after a call ends',
    importance: Importance.defaultImportance,
  );

  static const actionConfirmations = AndroidNotificationChannel(
    'action_confirmations',
    'Action Confirmations',
    description:
        'Reminders to confirm calendar events extracted from calls',
    importance: Importance.defaultImportance,
  );
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Cached navigator key so we can push routes from static context
  static GlobalKey<NavigatorState>? _navigatorKey;

  // -------------------------------------------------------------------------
  // initialize
  // -------------------------------------------------------------------------

  /// Call once from main.dart / app startup.
  static Future<void> initialize(
    WidgetRef ref, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;

    // 1. Register background handler first
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );
    debugPrint(
      '[NotificationService] Permission: ${settings.authorizationStatus}',
    );

    // 3. Create local notification channels (Android)
    await _createChannels();

    // 4. Initialize flutter_local_notifications
    const initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: initSettingsAndroid,
        iOS: initSettingsIOS,
      ),
      onDidReceiveNotificationResponse: (response) {
        _onLocalNotificationTapped(response, ref);
      },
    );

    // 5. Foreground message handler
    FirebaseMessaging.onMessage.listen((message) {
      handleIncomingCallNotification(message, ref);
    });

    // 6. App opened from terminated state via notification tap
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _routeFromMessage(initialMessage, ref);
    }

    // 7. App opened from background via notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _routeFromMessage(message, ref);
    });

    // 8. Token refresh — re-register with backend
    _fcm.onTokenRefresh.listen((newToken) {
      _registerTokenWithBackend(ref, newToken);
    });

    // 9. Register current token
    final token = await getDeviceToken();
    if (token != null) {
      await _registerTokenWithBackend(ref, token);
    }
  }

  // -------------------------------------------------------------------------
  // getDeviceToken
  // -------------------------------------------------------------------------

  static Future<String?> getDeviceToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('[NotificationService] Failed to get FCM token: $e');
      return null;
    }
  }

  // -------------------------------------------------------------------------
  // handleIncomingCallNotification
  // -------------------------------------------------------------------------

  static void handleIncomingCallNotification(
    RemoteMessage message,
    WidgetRef ref,
  ) {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'incoming_call') {
      // Parse minimal call data from the notification payload
      final callId = data['call_id'] as String?;
      final callSid = data['call_sid'] as String? ?? '';
      final fromNumber = data['from_number'] as String? ?? 'Unknown';
      final callerName = data['caller_name'] as String?;

      if (callId == null) return;

      // Build a lightweight CallRecord to set as active
      final activeCall = CallRecord(
        callId: callId,
        callSid: callSid,
        fromNumber: fromNumber,
        toNumber: data['to_number'] as String? ?? '',
        callerName: callerName,
        status: CallStatus.incoming,
        startedAt: DateTime.now(),
        userId: data['user_id'] as String? ?? '',
      );

      ref.read(callsProvider.notifier).setActiveCall(activeCall);

      // Show full-screen notification (Android) or local notification (iOS)
      _showIncomingCallLocalNotification(
        callId: callId,
        fromNumber: fromNumber,
        callerName: callerName,
        data: data,
      );

      // Navigate to IncomingCallScreen while app is in foreground
      _navigateToIncomingCall(
        callId: callId,
        fromNumber: fromNumber,
        callerName: callerName,
      );
    } else if (type == 'call_summary') {
      _showCallSummaryNotification(data: data);
    } else if (type == 'action_confirmation') {
      _showActionConfirmationNotification(data: data);
    }
  }

  // -------------------------------------------------------------------------
  // setupBackgroundHandler
  // -------------------------------------------------------------------------

  static Future<void> setupBackgroundHandler() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static Future<void> _createChannels() async {
    final plugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await plugin?.createNotificationChannel(_Channels.incomingCalls);
    await plugin?.createNotificationChannel(_Channels.callSummaries);
    await plugin?.createNotificationChannel(_Channels.actionConfirmations);
  }

  static Future<void> _showIncomingCallLocalNotification({
    required String callId,
    required String fromNumber,
    String? callerName,
    required Map<String, dynamic> data,
  }) async {
    final displayName = (callerName?.isNotEmpty == true)
        ? callerName!
        : fromNumber;

    const androidDetails = AndroidNotificationDetails(
      'incoming_calls',
      'Incoming Calls',
      channelDescription: 'Full-screen alerts for incoming calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      autoCancel: false,
      ongoing: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      callId.hashCode,
      'Incoming Call',
      displayName,
      details,
      payload: jsonEncode({'type': 'incoming_call', 'call_id': callId, ...data}),
    );
  }

  static Future<void> _showCallSummaryNotification({
    required Map<String, dynamic> data,
  }) async {
    final callerName = data['caller_name'] as String? ?? 'Unknown';
    final summary =
        data['summary'] as String? ?? 'Your AI assistant handled a call.';
    final callId = data['call_id'] as String? ?? '';

    const androidDetails = AndroidNotificationDetails(
      'call_summaries',
      'Call Summaries',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      callId.hashCode + 1,
      'Call with $callerName — Summary',
      summary,
      details,
      payload: jsonEncode({'type': 'call_detail', 'call_id': callId}),
    );
  }

  static Future<void> _showActionConfirmationNotification({
    required Map<String, dynamic> data,
  }) async {
    final title = data['action_title'] as String? ?? 'Action item';
    final callId = data['call_id'] as String? ?? '';

    const androidDetails = AndroidNotificationDetails(
      'action_confirmations',
      'Action Confirmations',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      callId.hashCode + 2,
      'Action pending',
      title,
      details,
      payload: jsonEncode({'type': 'call_detail', 'call_id': callId}),
    );
  }

  static void _onLocalNotificationTapped(
    NotificationResponse response,
    WidgetRef ref,
  ) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final callId = data['call_id'] as String?;

      if (type == 'incoming_call' && callId != null) {
        _navigateToIncomingCall(
          callId: callId,
          fromNumber: data['from_number'] as String? ?? '',
          callerName: data['caller_name'] as String?,
        );
      } else if (type == 'call_detail' && callId != null) {
        _navigatorKey?.currentContext
            ?.go('/calls/$callId');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error parsing notification payload: $e');
    }
  }

  static void _routeFromMessage(RemoteMessage message, WidgetRef ref) {
    final data = message.data;
    final type = data['type'] as String?;
    final callId = data['call_id'] as String?;

    if (callId == null) return;

    if (type == 'incoming_call') {
      _navigateToIncomingCall(
        callId: callId,
        fromNumber: data['from_number'] as String? ?? '',
        callerName: data['caller_name'] as String?,
      );
    } else {
      _navigatorKey?.currentContext?.go('/calls/$callId');
    }
  }

  static void _navigateToIncomingCall({
    required String callId,
    required String fromNumber,
    String? callerName,
  }) {
    final context = _navigatorKey?.currentContext;
    if (context == null) return;

    final uri = Uri(
      path: '/calls/incoming',
      queryParameters: {
        'callId': callId,
        'fromNumber': fromNumber,
        if (callerName != null) 'callerName': callerName,
      },
    );
    context.push(uri.toString());
  }

  static Future<void> _registerTokenWithBackend(
    WidgetRef ref,
    String token,
  ) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post<void>(
        '/devices/register',
        data: {
          'fcm_token': token,
          'platform': 'android',
        },
      );
      debugPrint('[NotificationService] FCM token registered with backend');
    } on DioException catch (e) {
      debugPrint(
        '[NotificationService] Failed to register token: ${e.message}',
      );
    }
  }
}
