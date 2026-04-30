import 'package:meta/meta.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';

@immutable
class EventHandLedgerCell {
  const EventHandLedgerCell({
    required this.wind,
    required this.seatIndex,
    required this.eventGuestId,
    required this.displayName,
    required this.pointsDelta,
  });

  factory EventHandLedgerCell.fromJson(Map<String, dynamic> json) {
    return EventHandLedgerCell(
      wind: _seatWindFromJson(_requiredString(json, 'wind')),
      seatIndex: _requiredInt(json, 'seat_index'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _stringOrDefault(json, 'display_name', 'Unknown player'),
      pointsDelta: _requiredInt(json, 'points_delta'),
    );
  }

  final SeatWind wind;
  final int seatIndex;
  final String eventGuestId;
  final String displayName;
  final int pointsDelta;

  Map<String, dynamic> toJson() {
    return {
      'wind': _seatWindToJson(wind),
      'seat_index': seatIndex,
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'points_delta': pointsDelta,
    };
  }
}

@immutable
class EventHandLedgerEntry {
  const EventHandLedgerEntry({
    required this.eventId,
    required this.tableId,
    required this.tableLabel,
    required this.sessionId,
    required this.sessionNumberForTable,
    required this.handId,
    required this.handNumber,
    required this.enteredAt,
    required this.resultType,
    required this.status,
    required this.hasSettlements,
    required this.cells,
    this.winType,
    this.fanCount,
  });

  factory EventHandLedgerEntry.fromJson(Map<String, dynamic> json) {
    final rawCells = json['cells'] as List<dynamic>? ?? const [];
    final cells = rawCells
        .map((cell) => EventHandLedgerCell.fromJson(
              (cell as Map).cast<String, dynamic>(),
            ))
        .toList(growable: false);

    if (cells.length != 4) {
      throw FormatException('Expected 4 cells for event hand ledger row.');
    }

    return EventHandLedgerEntry(
      eventId: _requiredString(json, 'event_id'),
      tableId: _requiredString(json, 'table_id'),
      tableLabel: _stringOrDefault(json, 'table_label', 'Table'),
      sessionId: _requiredString(json, 'session_id'),
      sessionNumberForTable: _intOrDefault(json, 'session_number_for_table', 1),
      handId: _requiredString(json, 'hand_id'),
      handNumber: _requiredInt(json, 'hand_number'),
      enteredAt: _requiredDateTime(json, 'entered_at'),
      resultType: _handResultTypeFromJson(_requiredString(json, 'result_type')),
      status: _handResultStatusFromJson(_requiredString(json, 'status')),
      winType: _optionalWinType(json, 'win_type'),
      fanCount: _optionalInt(json, 'fan_count'),
      hasSettlements: _boolOrDefault(json, 'has_settlements', false),
      cells: cells,
    );
  }

  final String eventId;
  final String tableId;
  final String tableLabel;
  final String sessionId;
  final int sessionNumberForTable;
  final String handId;
  final int handNumber;
  final DateTime enteredAt;
  final HandResultType resultType;
  final HandResultStatus status;
  final HandWinType? winType;
  final int? fanCount;
  final bool hasSettlements;
  final List<EventHandLedgerCell> cells;

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'table_id': tableId,
      'table_label': tableLabel,
      'session_id': sessionId,
      'session_number_for_table': sessionNumberForTable,
      'hand_id': handId,
      'hand_number': handNumber,
      'entered_at': enteredAt.toIso8601String(),
      'result_type': _handResultTypeToJson(resultType),
      'status': _handResultStatusToJson(status),
      'win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'fan_count': fanCount,
      'has_settlements': hasSettlements,
      'cells': cells.map((cell) => cell.toJson()).toList(growable: false),
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

bool _boolOrDefault(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  if (value == null) {
    return fallback;
  }
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected bool for $key.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  return DateTime.parse(value);
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

String _seatWindToJson(SeatWind wind) {
  return switch (wind) {
    SeatWind.east => 'east',
    SeatWind.south => 'south',
    SeatWind.west => 'west',
    SeatWind.north => 'north',
  };
}

HandResultType _handResultTypeFromJson(String value) {
  return switch (value) {
    'win' => HandResultType.win,
    'washout' => HandResultType.washout,
    _ => throw FormatException('Unknown hand result type: $value'),
  };
}

String _handResultTypeToJson(HandResultType type) {
  return switch (type) {
    HandResultType.win => 'win',
    HandResultType.washout => 'washout',
  };
}

HandResultStatus _handResultStatusFromJson(String value) {
  return switch (value) {
    'recorded' => HandResultStatus.recorded,
    'voided' => HandResultStatus.voided,
    _ => throw FormatException('Unknown hand result status: $value'),
  };
}

String _handResultStatusToJson(HandResultStatus status) {
  return switch (status) {
    HandResultStatus.recorded => 'recorded',
    HandResultStatus.voided => 'voided',
  };
}

HandWinType? _optionalWinType(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected string or null for $key.');
  }
  return switch (value) {
    'discard' => HandWinType.discard,
    'self_draw' => HandWinType.selfDraw,
    _ => throw FormatException('Unknown win type: $value'),
  };
}

String _handWinTypeToJson(HandWinType winType) {
  return switch (winType) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self_draw',
  };
}
