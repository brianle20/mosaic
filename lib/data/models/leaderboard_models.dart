import 'package:meta/meta.dart';

@immutable
class EventScoreTotalRecord {
  const EventScoreTotalRecord({
    required this.id,
    required this.eventId,
    required this.eventGuestId,
    required this.totalPoints,
    required this.handsWon,
    required this.selfDrawWins,
    required this.discardWins,
    required this.sessionsStarted,
    required this.sessionsCompleted,
  });

  factory EventScoreTotalRecord.fromJson(Map<String, dynamic> json) {
    return EventScoreTotalRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      totalPoints: _requiredInt(json, 'total_points'),
      handsWon: _requiredInt(json, 'hands_won'),
      selfDrawWins: _requiredInt(json, 'self_draw_wins'),
      discardWins: _requiredInt(json, 'discard_wins'),
      sessionsStarted: _requiredInt(json, 'sessions_started'),
      sessionsCompleted: _requiredInt(json, 'sessions_completed'),
    );
  }

  final String id;
  final String eventId;
  final String eventGuestId;
  final int totalPoints;
  final int handsWon;
  final int selfDrawWins;
  final int discardWins;
  final int sessionsStarted;
  final int sessionsCompleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_guest_id': eventGuestId,
      'total_points': totalPoints,
      'hands_won': handsWon,
      'self_draw_wins': selfDrawWins,
      'discard_wins': discardWins,
      'sessions_started': sessionsStarted,
      'sessions_completed': sessionsCompleted,
    };
  }
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.eventGuestId,
    required this.displayName,
    required this.totalPoints,
    required this.handsWon,
    required this.selfDrawWins,
    required this.discardWins,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      totalPoints: _requiredInt(json, 'total_points'),
      handsWon: _requiredInt(json, 'hands_won'),
      selfDrawWins: _requiredInt(json, 'self_draw_wins'),
      discardWins: _requiredInt(json, 'discard_wins'),
      rank: _requiredInt(json, 'rank'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final int totalPoints;
  final int handsWon;
  final int selfDrawWins;
  final int discardWins;
  final int rank;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'total_points': totalPoints,
      'hands_won': handsWon,
      'self_draw_wins': selfDrawWins,
      'discard_wins': discardWins,
      'rank': rank,
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Expected non-empty string for $key.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected int for $key.');
}
