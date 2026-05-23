import 'package:json_annotation/json_annotation.dart';

part 'call_model.g.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum CallStatus {
  @JsonValue('incoming') incoming,
  @JsonValue('pending_decision') pendingDecision,
  @JsonValue('user_answering') userAnswering,
  @JsonValue('ai_answering') aiAnswering,
  @JsonValue('in_progress') inProgress,
  @JsonValue('completed') completed,
  @JsonValue('missed') missed,
  @JsonValue('declined') declined,
}

enum CallDecision {
  @JsonValue('answer_myself') answerMyself,
  @JsonValue('let_ai_answer') letAiAnswer,
  @JsonValue('decline') decline,
}

enum ActionType {
  @JsonValue('meeting') meeting,
  @JsonValue('appointment') appointment,
  @JsonValue('reminder') reminder,
  @JsonValue('travel') travel,
  @JsonValue('follow_up') followUp,
  @JsonValue('delivery') delivery,
  @JsonValue('invitation') invitation,
  @JsonValue('work') work,
  @JsonValue('personal') personal,
}

// ---------------------------------------------------------------------------
// ExtractedAction
// ---------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class ExtractedAction {
  final ActionType actionType;
  final String title;
  final String description;
  final String? datetimeStr;
  final String? location;
  final List<String>? attendees;
  final bool confirmed;
  final String? calendarEventId;

  const ExtractedAction({
    required this.actionType,
    required this.title,
    required this.description,
    this.datetimeStr,
    this.location,
    this.attendees,
    this.confirmed = false,
    this.calendarEventId,
  });

  factory ExtractedAction.fromJson(Map<String, dynamic> json) =>
      _$ExtractedActionFromJson(json);

  Map<String, dynamic> toJson() => _$ExtractedActionToJson(this);

  ExtractedAction copyWith({
    ActionType? actionType,
    String? title,
    String? description,
    String? datetimeStr,
    String? location,
    List<String>? attendees,
    bool? confirmed,
    String? calendarEventId,
  }) {
    return ExtractedAction(
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      description: description ?? this.description,
      datetimeStr: datetimeStr ?? this.datetimeStr,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      confirmed: confirmed ?? this.confirmed,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }
}

// ---------------------------------------------------------------------------
// ConversationTurn
// ---------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class ConversationTurn {
  final String role; // 'caller' | 'assistant'
  final String text;
  final String language;
  final DateTime timestamp;
  final String? audioUrl;

  const ConversationTurn({
    required this.role,
    required this.text,
    required this.language,
    required this.timestamp,
    this.audioUrl,
  });

  factory ConversationTurn.fromJson(Map<String, dynamic> json) =>
      _$ConversationTurnFromJson(json);

  Map<String, dynamic> toJson() => _$ConversationTurnToJson(this);
}

// ---------------------------------------------------------------------------
// CallRecord
// ---------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class CallRecord {
  final String callId;
  final String callSid;
  final String fromNumber;
  final String toNumber;
  final String? callerName;
  final CallStatus status;
  final CallDecision? decision;
  final String? languageDetected;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? transcript;
  final List<ConversationTurn> transcriptTurns;
  final String? summary;
  final List<ExtractedAction> extractedActions;
  final String userId;

  const CallRecord({
    required this.callId,
    required this.callSid,
    required this.fromNumber,
    required this.toNumber,
    this.callerName,
    required this.status,
    this.decision,
    this.languageDetected,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.transcript,
    this.transcriptTurns = const [],
    this.summary,
    this.extractedActions = const [],
    required this.userId,
  });

  factory CallRecord.fromJson(Map<String, dynamic> json) =>
      _$CallRecordFromJson(json);

  Map<String, dynamic> toJson() => _$CallRecordToJson(this);

  CallRecord copyWith({
    String? callId,
    String? callSid,
    String? fromNumber,
    String? toNumber,
    String? callerName,
    CallStatus? status,
    CallDecision? decision,
    String? languageDetected,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? transcript,
    List<ConversationTurn>? transcriptTurns,
    String? summary,
    List<ExtractedAction>? extractedActions,
    String? userId,
  }) {
    return CallRecord(
      callId: callId ?? this.callId,
      callSid: callSid ?? this.callSid,
      fromNumber: fromNumber ?? this.fromNumber,
      toNumber: toNumber ?? this.toNumber,
      callerName: callerName ?? this.callerName,
      status: status ?? this.status,
      decision: decision ?? this.decision,
      languageDetected: languageDetected ?? this.languageDetected,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      transcript: transcript ?? this.transcript,
      transcriptTurns: transcriptTurns ?? this.transcriptTurns,
      summary: summary ?? this.summary,
      extractedActions: extractedActions ?? this.extractedActions,
      userId: userId ?? this.userId,
    );
  }

  // ---------------------------------------------------------------------------
  // Convenience getters
  // ---------------------------------------------------------------------------

  /// Returns a human-readable duration string, e.g. "2m 34s".
  String get durationFormatted {
    final secs = durationSeconds;
    if (secs == null || secs <= 0) return '0s';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  /// Returns a human-readable status label.
  String get statusLabel {
    switch (status) {
      case CallStatus.incoming:
        return 'Incoming';
      case CallStatus.pendingDecision:
        return 'Pending';
      case CallStatus.userAnswering:
        return 'You Answered';
      case CallStatus.aiAnswering:
        return 'AI Answering';
      case CallStatus.inProgress:
        return 'In Progress';
      case CallStatus.completed:
        return 'Completed';
      case CallStatus.missed:
        return 'Missed';
      case CallStatus.declined:
        return 'Declined';
    }
  }

  /// Returns a display name for the detected language.
  String get languageDisplayName {
    switch (languageDetected?.toLowerCase()) {
      case 'te':
      case 'tel':
      case 'telugu':
        return 'Telugu';
      case 'hi':
      case 'hin':
      case 'hindi':
        return 'Hindi';
      case 'kn':
      case 'kan':
      case 'kannada':
        return 'Kannada';
      case 'ta':
      case 'tam':
      case 'tamil':
        return 'Tamil';
      case 'ml':
      case 'mal':
      case 'malayalam':
        return 'Malayalam';
      case 'ar':
      case 'ara':
      case 'arabic':
        return 'Arabic';
      case 'en':
      case 'eng':
      case 'english':
        return 'English';
      case 'es':
      case 'spa':
      case 'spanish':
        return 'Spanish';
      case 'fr':
      case 'fra':
      case 'french':
        return 'French';
      default:
        return languageDetected ?? 'Unknown';
    }
  }

  /// Returns a flag emoji for the detected language.
  String get languageFlag {
    switch (languageDetected?.toLowerCase()) {
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
      case 'tam':
      case 'tamil':
      case 'ml':
      case 'mal':
      case 'malayalam':
        return '\u{1F1EE}\u{1F1F3}'; // 🇮🇳
      case 'ar':
      case 'ara':
      case 'arabic':
        return '\u{1F1F8}\u{1F1E6}'; // 🇸🇦
      case 'es':
      case 'spa':
      case 'spanish':
        return '\u{1F1EA}\u{1F1F8}'; // 🇪🇸
      case 'fr':
      case 'fra':
      case 'french':
        return '\u{1F1EB}\u{1F1F7}'; // 🇫🇷
      default:
        return '\u{1F1FA}\u{1F1F8}'; // 🇺🇸
    }
  }

  /// Returns true if any extracted action has not been confirmed.
  bool get hasPendingActions =>
      extractedActions.any((action) => !action.confirmed);

  /// Count of unconfirmed actions.
  int get pendingActionCount =>
      extractedActions.where((action) => !action.confirmed).length;
}

// ---------------------------------------------------------------------------
// CallQueryResult — returned by the natural-language query endpoint
// ---------------------------------------------------------------------------

@JsonSerializable(explicitToJson: true)
class CallQueryResult {
  final String answer;
  final List<CallRecord> relevantCalls;
  final String? queryId;

  const CallQueryResult({
    required this.answer,
    this.relevantCalls = const [],
    this.queryId,
  });

  factory CallQueryResult.fromJson(Map<String, dynamic> json) =>
      _$CallQueryResultFromJson(json);

  Map<String, dynamic> toJson() => _$CallQueryResultToJson(this);
}
