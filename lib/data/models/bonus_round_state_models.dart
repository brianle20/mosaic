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
    this.playInStatus,
    this.playInTableId,
    this.playInSessionId,
    this.playInWinnerEventGuestId,
    this.playInWinnerSeedRank,
    this.tiedTopPlayers = const [],
    this.playInPlayers = const [],
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
      playInStatus: _optionalString(json, 'play_in_status'),
      playInTableId: _optionalString(json, 'play_in_table_id'),
      playInSessionId: _optionalString(json, 'play_in_session_id'),
      playInWinnerEventGuestId:
          _optionalString(json, 'play_in_winner_event_guest_id'),
      playInWinnerSeedRank: _optionalInt(json, 'play_in_winner_seed_rank'),
      tiedTopPlayers: _tiedPlayersFromJson(json['tied_top_players']),
      playInPlayers: _playInPlayersFromJson(json['play_in_players']),
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
  final String? playInStatus;
  final String? playInTableId;
  final String? playInSessionId;
  final String? playInWinnerEventGuestId;
  final int? playInWinnerSeedRank;
  final List<BonusRoundTiedPlayer> tiedTopPlayers;
  final List<BonusRoundPlayInPlayer> playInPlayers;
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
      'play_in_status': playInStatus,
      'play_in_table_id': playInTableId,
      'play_in_session_id': playInSessionId,
      'play_in_winner_event_guest_id': playInWinnerEventGuestId,
      'play_in_winner_seed_rank': playInWinnerSeedRank,
      'tied_top_players': tiedTopPlayers
          .map((player) => player.toJson())
          .toList(growable: false),
      'play_in_players': playInPlayers
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
class BonusRoundPlayInPlayer {
  const BonusRoundPlayInPlayer({
    this.eventGuestId,
    this.displayName,
    this.bonusScorePoints,
    this.totalPoints,
    this.seedRank,
  });

  factory BonusRoundPlayInPlayer.fromJson(Map<String, dynamic> json) {
    return BonusRoundPlayInPlayer(
      eventGuestId: _optionalString(json, 'event_guest_id'),
      displayName: _optionalString(json, 'display_name'),
      bonusScorePoints: _optionalInt(json, 'bonus_score_points'),
      totalPoints: _optionalInt(json, 'total_points'),
      seedRank: _optionalInt(json, 'seed_rank'),
    );
  }

  final String? eventGuestId;
  final String? displayName;
  final int? bonusScorePoints;
  final int? totalPoints;
  final int? seedRank;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'bonus_score_points': bonusScorePoints,
      'total_points': totalPoints,
      'seed_rank': seedRank,
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

List<BonusRoundPlayInPlayer> _playInPlayersFromJson(Object? value) {
  if (value == null) {
    return const [];
  }

  if (value is! List) {
    throw const FormatException('Expected play_in_players to be a list.');
  }

  return value.map((entry) {
    if (entry is! Map) {
      throw const FormatException('Expected play-in player to be an object.');
    }

    return BonusRoundPlayInPlayer.fromJson(entry.cast<String, dynamic>());
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
