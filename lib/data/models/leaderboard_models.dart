import 'package:meta/meta.dart';
import 'package:mosaic/data/models/guest_models.dart';

@immutable
class EventScoreTotalRecord {
  const EventScoreTotalRecord({
    required this.id,
    required this.eventId,
    required this.eventGuestId,
    required this.totalPoints,
    required this.handsPlayed,
    required this.handsWon,
    required this.selfDrawWins,
    required this.discardWins,
    this.discardLosses = 0,
    required this.sessionsStarted,
    required this.sessionsCompleted,
  });

  factory EventScoreTotalRecord.fromJson(Map<String, dynamic> json) {
    return EventScoreTotalRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      totalPoints: _requiredInt(json, 'total_points'),
      handsPlayed: _requiredInt(json, 'hands_played'),
      handsWon: _requiredInt(json, 'hands_won'),
      selfDrawWins: _requiredInt(json, 'self_draw_wins'),
      discardWins: _requiredInt(json, 'discard_wins'),
      discardLosses: _intOrDefault(json, 'discard_losses'),
      sessionsStarted: _requiredInt(json, 'sessions_started'),
      sessionsCompleted: _requiredInt(json, 'sessions_completed'),
    );
  }

  final String id;
  final String eventId;
  final String eventGuestId;
  final int totalPoints;
  final int handsPlayed;
  final int handsWon;
  final int selfDrawWins;
  final int discardWins;
  final int discardLosses;
  final int sessionsStarted;
  final int sessionsCompleted;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_guest_id': eventGuestId,
      'total_points': totalPoints,
      'hands_played': handsPlayed,
      'hands_won': handsWon,
      'self_draw_wins': selfDrawWins,
      'discard_wins': discardWins,
      'discard_losses': discardLosses,
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
    this.tournamentStatus = EventTournamentStatus.qualified,
    this.isPrizeEligible = true,
    required this.totalPoints,
    required this.handsPlayed,
    required this.handsWon,
    required this.selfDrawWins,
    required this.discardWins,
    this.discardLosses = 0,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      tournamentStatus: _tournamentStatusOrDefault(json),
      isPrizeEligible: _prizeEligibilityOrFallback(json),
      totalPoints: _requiredInt(json, 'total_points'),
      handsPlayed: _requiredInt(json, 'hands_played'),
      handsWon: _requiredInt(json, 'hands_won'),
      selfDrawWins: _requiredInt(json, 'self_draw_wins'),
      discardWins: _requiredInt(json, 'discard_wins'),
      discardLosses: _intOrDefault(json, 'discard_losses'),
      rank: _requiredInt(json, 'rank'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final EventTournamentStatus tournamentStatus;
  final bool isPrizeEligible;
  final int totalPoints;
  final int handsPlayed;
  final int handsWon;
  final int selfDrawWins;
  final int discardWins;
  final int discardLosses;
  final int rank;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'tournament_status': eventTournamentStatusToJson(tournamentStatus),
      'prize_eligible': isPrizeEligible,
      'total_points': totalPoints,
      'hands_played': handsPlayed,
      'hands_won': handsWon,
      'self_draw_wins': selfDrawWins,
      'discard_wins': discardWins,
      'discard_losses': discardLosses,
      'rank': rank,
    };
  }
}

bool _prizeEligibilityOrFallback(Map<String, dynamic> json) {
  final value = json['prize_eligible'];
  if (value is bool) {
    return value;
  }

  return _tournamentStatusOrDefault(json) != EventTournamentStatus.withdrawn &&
      _requiredInt(json, 'hands_played') > 0;
}

EventTournamentStatus _tournamentStatusOrDefault(Map<String, dynamic> json) {
  final value = json['tournament_status'];
  if (value is String && value.trim().isNotEmpty) {
    return eventTournamentStatusFromJson(value);
  }

  return EventTournamentStatus.qualified;
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

int _intOrDefault(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return 0;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected int for $key.');
}
