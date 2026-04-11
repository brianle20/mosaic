import 'package:meta/meta.dart';

enum RotationPolicyType {
  dealerCycleReturnToInitialEast,
}

enum SessionStatus {
  active,
  paused,
  completed,
  endedEarly,
  aborted,
}

enum SeatWind {
  east,
  south,
  west,
  north,
}

@immutable
class TableSessionRecord {
  const TableSessionRecord({
    required this.id,
    required this.eventId,
    required this.eventTableId,
    required this.sessionNumberForTable,
    required this.rulesetId,
    required this.rulesetVersion,
    required this.rotationPolicyType,
    required this.rotationPolicyConfig,
    required this.status,
    required this.initialEastSeatIndex,
    required this.currentDealerSeatIndex,
    required this.dealerPassCount,
    required this.completedGamesCount,
    required this.handCount,
    required this.startedAt,
    required this.startedByUserId,
    this.endedAt,
    this.endedByUserId,
    this.endReason,
    this.rowVersion = 1,
  });

  factory TableSessionRecord.fromJson(Map<String, dynamic> json) {
    return TableSessionRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventTableId: _requiredString(json, 'event_table_id'),
      sessionNumberForTable: _requiredInt(json, 'session_number_for_table'),
      rulesetId: _requiredString(json, 'ruleset_id'),
      rulesetVersion: _requiredInt(json, 'ruleset_version'),
      rotationPolicyType: _rotationPolicyTypeFromJson(
        _requiredString(json, 'rotation_policy_type'),
      ),
      rotationPolicyConfig: _jsonObject(json, 'rotation_policy_config_json'),
      status: _sessionStatusFromJson(_requiredString(json, 'status')),
      initialEastSeatIndex: _requiredInt(json, 'initial_east_seat_index'),
      currentDealerSeatIndex: _requiredInt(json, 'current_dealer_seat_index'),
      dealerPassCount: _requiredInt(json, 'dealer_pass_count'),
      completedGamesCount: _requiredInt(json, 'completed_games_count'),
      handCount: _requiredInt(json, 'hand_count'),
      startedAt: _requiredDateTime(json, 'started_at'),
      startedByUserId: _requiredString(json, 'started_by_user_id'),
      endedAt: _optionalDateTime(json, 'ended_at'),
      endedByUserId: _optionalString(json, 'ended_by_user_id'),
      endReason: _optionalString(json, 'end_reason'),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String eventId;
  final String eventTableId;
  final int sessionNumberForTable;
  final String rulesetId;
  final int rulesetVersion;
  final RotationPolicyType rotationPolicyType;
  final Map<String, dynamic> rotationPolicyConfig;
  final SessionStatus status;
  final int initialEastSeatIndex;
  final int currentDealerSeatIndex;
  final int dealerPassCount;
  final int completedGamesCount;
  final int handCount;
  final DateTime startedAt;
  final String startedByUserId;
  final DateTime? endedAt;
  final String? endedByUserId;
  final String? endReason;
  final int rowVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_table_id': eventTableId,
      'session_number_for_table': sessionNumberForTable,
      'ruleset_id': rulesetId,
      'ruleset_version': rulesetVersion,
      'rotation_policy_type': _rotationPolicyTypeToJson(rotationPolicyType),
      'rotation_policy_config_json': rotationPolicyConfig,
      'status': _sessionStatusToJson(status),
      'initial_east_seat_index': initialEastSeatIndex,
      'current_dealer_seat_index': currentDealerSeatIndex,
      'dealer_pass_count': dealerPassCount,
      'completed_games_count': completedGamesCount,
      'hand_count': handCount,
      'started_at': startedAt.toIso8601String(),
      'started_by_user_id': startedByUserId,
      'ended_at': endedAt?.toIso8601String(),
      'ended_by_user_id': endedByUserId,
      'end_reason': endReason,
      'row_version': rowVersion,
    };
  }
}

@immutable
class TableSessionSeatRecord {
  const TableSessionSeatRecord({
    required this.id,
    required this.tableSessionId,
    required this.seatIndex,
    required this.initialWind,
    required this.eventGuestId,
  });

  factory TableSessionSeatRecord.fromJson(Map<String, dynamic> json) {
    return TableSessionSeatRecord(
      id: _requiredString(json, 'id'),
      tableSessionId: _requiredString(json, 'table_session_id'),
      seatIndex: _requiredInt(json, 'seat_index'),
      initialWind: _seatWindFromJson(_requiredString(json, 'initial_wind')),
      eventGuestId: _requiredString(json, 'event_guest_id'),
    );
  }

  final String id;
  final String tableSessionId;
  final int seatIndex;
  final SeatWind initialWind;
  final String eventGuestId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_session_id': tableSessionId,
      'seat_index': seatIndex,
      'initial_wind': _seatWindToJson(initialWind),
      'event_guest_id': eventGuestId,
    };
  }
}

@immutable
class StartedTableSessionRecord {
  const StartedTableSessionRecord({
    required this.session,
    required this.seats,
  });

  factory StartedTableSessionRecord.fromJson({
    required Map<String, dynamic> sessionJson,
    required List<dynamic> seatsJson,
  }) {
    final seats = seatsJson
        .map((seat) => TableSessionSeatRecord.fromJson(seat as Map<String, dynamic>))
        .toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));

    return StartedTableSessionRecord(
      session: TableSessionRecord.fromJson(sessionJson),
      seats: seats,
    );
  }

  final TableSessionRecord session;
  final List<TableSessionSeatRecord> seats;
}

@immutable
class StartTableSessionInput {
  const StartTableSessionInput({
    required this.eventTableId,
    required this.scannedTableUid,
    required this.eastPlayerUid,
    required this.southPlayerUid,
    required this.westPlayerUid,
    required this.northPlayerUid,
  });

  final String eventTableId;
  final String scannedTableUid;
  final String eastPlayerUid;
  final String southPlayerUid;
  final String westPlayerUid;
  final String northPlayerUid;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_event_table_id': eventTableId,
      'scanned_table_uid': scannedTableUid,
      'east_player_uid': eastPlayerUid,
      'south_player_uid': southPlayerUid,
      'west_player_uid': westPlayerUid,
      'north_player_uid': northPlayerUid,
    };
  }
}

SeatWind seatWindForIndex(int index) {
  return switch (index) {
    0 => SeatWind.east,
    1 => SeatWind.south,
    2 => SeatWind.west,
    3 => SeatWind.north,
    _ => throw RangeError.range(index, 0, 3, 'index'),
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Expected non-empty string for $key.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return value;
  }

  throw FormatException('Expected string or null for $key.');
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

int _intOrDefault(Map<String, dynamic> json, String key, int fallback) {
  final value = json[key];
  if (value == null) {
    return fallback;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Expected int or null for $key.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  return DateTime.parse(_requiredString(json, key));
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 string or null for $key.');
}

Map<String, dynamic> _jsonObject(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return const {};
  }

  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }

  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((mapKey, mapValue) => MapEntry(mapKey.toString(), mapValue)),
    );
  }

  throw FormatException('Expected JSON object for $key.');
}

RotationPolicyType _rotationPolicyTypeFromJson(String value) {
  return switch (value) {
    'dealer_cycle_return_to_initial_east' =>
      RotationPolicyType.dealerCycleReturnToInitialEast,
    _ => throw FormatException('Unknown rotation policy type: $value'),
  };
}

RotationPolicyType rotationPolicyTypeFromJson(String value) {
  return _rotationPolicyTypeFromJson(value);
}

String _rotationPolicyTypeToJson(RotationPolicyType value) {
  return switch (value) {
    RotationPolicyType.dealerCycleReturnToInitialEast =>
      'dealer_cycle_return_to_initial_east',
  };
}

String rotationPolicyTypeToJson(RotationPolicyType value) {
  return _rotationPolicyTypeToJson(value);
}

SessionStatus _sessionStatusFromJson(String value) {
  return switch (value) {
    'active' => SessionStatus.active,
    'paused' => SessionStatus.paused,
    'completed' => SessionStatus.completed,
    'ended_early' => SessionStatus.endedEarly,
    'aborted' => SessionStatus.aborted,
    _ => throw FormatException('Unknown session status: $value'),
  };
}

String _sessionStatusToJson(SessionStatus value) {
  return switch (value) {
    SessionStatus.active => 'active',
    SessionStatus.paused => 'paused',
    SessionStatus.completed => 'completed',
    SessionStatus.endedEarly => 'ended_early',
    SessionStatus.aborted => 'aborted',
  };
}

SeatWind _seatWindFromJson(String value) {
  return switch (value) {
    'east' => SeatWind.east,
    'south' => SeatWind.south,
    'west' => SeatWind.west,
    'north' => SeatWind.north,
    _ => throw FormatException('Unknown seat wind: $value'),
  };
}

String _seatWindToJson(SeatWind value) {
  return switch (value) {
    SeatWind.east => 'east',
    SeatWind.south => 'south',
    SeatWind.west => 'west',
    SeatWind.north => 'north',
  };
}
