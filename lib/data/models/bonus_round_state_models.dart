import 'package:meta/meta.dart';

@immutable
class BonusRoundState {
  const BonusRoundState({
    this.bonusRoundId,
    this.eventId,
    this.status,
    this.championsTableId,
    this.redemptionTableId,
    this.suddenDeathStatus,
    this.championResolutionMethod,
    this.suddenDeathTableId,
    this.suddenDeathSessionId,
    this.tiedTopPlayers = const [],
    this.championEventGuestId,
    this.championBonusScorePoints,
    this.championAwardPoints,
    this.championTopUpPoints,
  });

  factory BonusRoundState.fromJson(Map<String, dynamic> json) {
    return BonusRoundState(
      bonusRoundId: _optionalString(json, 'bonus_round_id'),
      eventId: _optionalString(json, 'event_id'),
      status: _optionalString(json, 'status'),
      championsTableId: _optionalString(json, 'champions_table_id'),
      redemptionTableId: _optionalString(json, 'redemption_table_id'),
      suddenDeathStatus: _optionalString(json, 'sudden_death_status'),
      championResolutionMethod:
          _optionalString(json, 'champion_resolution_method'),
      suddenDeathTableId: _optionalString(json, 'sudden_death_table_id'),
      suddenDeathSessionId: _optionalString(json, 'sudden_death_session_id'),
      tiedTopPlayers: _tiedPlayersFromJson(json['tied_top_players']),
      championEventGuestId: _optionalString(json, 'champion_event_guest_id'),
      championBonusScorePoints:
          _optionalInt(json, 'champion_bonus_score_points'),
      championAwardPoints: _optionalInt(json, 'champion_award_points'),
      championTopUpPoints: _optionalInt(json, 'champion_top_up_points'),
    );
  }

  final String? bonusRoundId;
  final String? eventId;
  final String? status;
  final String? championsTableId;
  final String? redemptionTableId;
  final String? suddenDeathStatus;
  final String? championResolutionMethod;
  final String? suddenDeathTableId;
  final String? suddenDeathSessionId;
  final List<BonusRoundTiedPlayer> tiedTopPlayers;
  final String? championEventGuestId;
  final int? championBonusScorePoints;
  final int? championAwardPoints;
  final int? championTopUpPoints;

  Map<String, dynamic> toJson() {
    return {
      'bonus_round_id': bonusRoundId,
      'event_id': eventId,
      'status': status,
      'champions_table_id': championsTableId,
      'redemption_table_id': redemptionTableId,
      'sudden_death_status': suddenDeathStatus,
      'champion_resolution_method': championResolutionMethod,
      'sudden_death_table_id': suddenDeathTableId,
      'sudden_death_session_id': suddenDeathSessionId,
      'tied_top_players': tiedTopPlayers
          .map((player) => player.toJson())
          .toList(growable: false),
      'champion_event_guest_id': championEventGuestId,
      'champion_bonus_score_points': championBonusScorePoints,
      'champion_award_points': championAwardPoints,
      'champion_top_up_points': championTopUpPoints,
    };
  }
}

@immutable
class BonusRoundTiedPlayer {
  const BonusRoundTiedPlayer({
    this.eventGuestId,
    this.displayName,
    this.bonusScorePoints,
    this.seedRank,
  });

  factory BonusRoundTiedPlayer.fromJson(Map<String, dynamic> json) {
    return BonusRoundTiedPlayer(
      eventGuestId: _optionalString(json, 'event_guest_id'),
      displayName: _optionalString(json, 'display_name'),
      bonusScorePoints: _optionalInt(json, 'bonus_score_points'),
      seedRank: _optionalInt(json, 'seed_rank'),
    );
  }

  final String? eventGuestId;
  final String? displayName;
  final int? bonusScorePoints;
  final int? seedRank;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'bonus_score_points': bonusScorePoints,
      'seed_rank': seedRank,
    };
  }
}

List<BonusRoundTiedPlayer> _tiedPlayersFromJson(Object? value) {
  if (value == null) {
    return const [];
  }

  if (value is! List) {
    throw const FormatException('Expected tied_top_players to be a list.');
  }

  return value.map((entry) {
    if (entry is! Map) {
      throw const FormatException('Expected tied player to be an object.');
    }

    return BonusRoundTiedPlayer.fromJson(entry.cast<String, dynamic>());
  }).toList(growable: false);
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  throw FormatException('Expected string or null for $key.');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  throw FormatException('Expected int or null for $key.');
}
