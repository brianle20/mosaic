import 'package:meta/meta.dart';

enum SeatingAssignmentType {
  random,
  bonus,
}

enum BonusTableRole {
  tableOfChampions,
  tableOfRedemption,
  tableOfChampionsSuddenDeath,
  tableOfChampionsPlayIn,
}

extension BonusTableRoleJsonValue on BonusTableRole {
  String toJsonValue() => _bonusTableRoleToJson(this);
}

@immutable
class SeatingAssignmentRecord {
  const SeatingAssignmentRecord({
    required this.id,
    required this.eventId,
    required this.eventTableId,
    required this.tableLabel,
    required this.eventGuestId,
    required this.displayName,
    required this.seatIndex,
    required this.assignmentRound,
    required this.status,
    this.assignmentType = SeatingAssignmentType.random,
    this.tournamentRoundId,
    this.bonusRoundId,
    this.bonusTableRole,
    this.seedRank,
  });

  factory SeatingAssignmentRecord.fromJson(Map<String, dynamic> json) {
    return SeatingAssignmentRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventTableId: _requiredString(json, 'event_table_id'),
      tableLabel: _requiredString(json, 'table_label'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredStringFromAny(
        json,
        const ['display_name', 'guest_display_name'],
      ),
      seatIndex: _requiredInt(json, 'seat_index'),
      assignmentRound: _requiredInt(json, 'assignment_round'),
      status: _requiredString(json, 'status'),
      assignmentType: _assignmentTypeFromJson(
        _stringOrDefault(json, 'assignment_type', 'random'),
      ),
      tournamentRoundId: _optionalString(json, 'tournament_round_id'),
      bonusRoundId: _optionalString(json, 'bonus_round_id'),
      bonusTableRole: _optionalBonusTableRole(json, 'bonus_table_role'),
      seedRank: _optionalInt(json, 'seed_rank'),
    );
  }

  final String id;
  final String eventId;
  final String eventTableId;
  final String tableLabel;
  final String eventGuestId;
  final String displayName;
  final int seatIndex;
  final int assignmentRound;
  final String status;
  final SeatingAssignmentType assignmentType;
  final String? tournamentRoundId;
  final String? bonusRoundId;
  final BonusTableRole? bonusTableRole;
  final int? seedRank;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_table_id': eventTableId,
      'table_label': tableLabel,
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'seat_index': seatIndex,
      'assignment_round': assignmentRound,
      'status': status,
      'assignment_type': _assignmentTypeToJson(assignmentType),
      'tournament_round_id': tournamentRoundId,
      'bonus_round_id': bonusRoundId,
      'bonus_table_role': bonusTableRole == null
          ? null
          : _bonusTableRoleToJson(bonusTableRole!),
      'seed_rank': seedRank,
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

String _requiredStringFromAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }

  throw FormatException('Expected non-empty string for one of $keys.');
}

String _stringOrDefault(
  Map<String, dynamic> json,
  String key,
  String fallback,
) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  return fallback;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Expected non-empty string or null for $key.');
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

  throw FormatException('Expected int or null for $key.');
}

SeatingAssignmentType _assignmentTypeFromJson(String value) {
  return switch (value) {
    'random' => SeatingAssignmentType.random,
    'bonus' => SeatingAssignmentType.bonus,
    _ => throw FormatException('Unknown seating assignment type: $value'),
  };
}

String _assignmentTypeToJson(SeatingAssignmentType type) {
  return switch (type) {
    SeatingAssignmentType.random => 'random',
    SeatingAssignmentType.bonus => 'bonus',
  };
}

BonusTableRole? _optionalBonusTableRole(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw FormatException('Expected string or null for $key.');
  }

  return switch (value) {
    'table_of_champions' => BonusTableRole.tableOfChampions,
    'table_of_redemption' => BonusTableRole.tableOfRedemption,
    'table_of_champions_sudden_death' =>
      BonusTableRole.tableOfChampionsSuddenDeath,
    'table_of_champions_play_in' => BonusTableRole.tableOfChampionsPlayIn,
    _ => throw FormatException('Unknown bonus table role: $value'),
  };
}

String _bonusTableRoleToJson(BonusTableRole role) {
  return switch (role) {
    BonusTableRole.tableOfChampions => 'table_of_champions',
    BonusTableRole.tableOfRedemption => 'table_of_redemption',
    BonusTableRole.tableOfChampionsSuddenDeath =>
      'table_of_champions_sudden_death',
    BonusTableRole.tableOfChampionsPlayIn => 'table_of_champions_play_in',
  };
}
