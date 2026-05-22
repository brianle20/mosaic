import 'package:meta/meta.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';

enum EventHandLedgerRowType {
  hand,
  adjustment,
}

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
    this.rowType = EventHandLedgerRowType.hand,
    this.winType,
    this.fanCount,
    this.penaltySeatIndex,
    this.bonusRoundId,
    this.bonusTableRole,
    this.adjustmentId,
    this.adjustmentType,
    this.adjustmentAmountPoints,
    this.adjustmentEventGuestId,
    this.adjustmentDisplayName,
    this.adjustmentContextJson = const {},
  });

  factory EventHandLedgerEntry.fromJson(Map<String, dynamic> json) {
    final rowType = _rowTypeFromJson(
      _stringOrDefault(json, 'ledger_row_type', 'hand'),
    );
    final rawCells = json['cells'] as List<dynamic>? ?? const [];
    final cells = rawCells
        .map((cell) => EventHandLedgerCell.fromJson(
              (cell as Map).cast<String, dynamic>(),
            ))
        .toList(growable: false);

    if (rowType == EventHandLedgerRowType.hand && cells.length != 4) {
      throw FormatException('Expected 4 cells for event hand ledger row.');
    }

    return EventHandLedgerEntry(
      eventId: _requiredString(json, 'event_id'),
      tableId: rowType == EventHandLedgerRowType.hand
          ? _requiredString(json, 'table_id')
          : _stringOrDefault(json, 'table_id', ''),
      tableLabel: _stringOrDefault(json, 'table_label', 'Table'),
      sessionId: rowType == EventHandLedgerRowType.hand
          ? _requiredString(json, 'session_id')
          : _stringOrDefault(json, 'session_id', ''),
      sessionNumberForTable: _intOrDefault(json, 'session_number_for_table', 1),
      handId: rowType == EventHandLedgerRowType.hand
          ? _requiredString(json, 'hand_id')
          : _requiredString(json, 'adjustment_id'),
      handNumber: rowType == EventHandLedgerRowType.hand
          ? _requiredInt(json, 'hand_number')
          : 0,
      enteredAt: _requiredDateTime(json, 'entered_at'),
      resultType: rowType == EventHandLedgerRowType.hand
          ? _handResultTypeFromJson(_requiredString(json, 'result_type'))
          : null,
      status: _handResultStatusFromJson(
        _stringOrDefault(json, 'status', 'recorded'),
      ),
      winType: _optionalWinType(json, 'win_type'),
      fanCount: _optionalInt(json, 'fan_count'),
      penaltySeatIndex: _optionalInt(json, 'penalty_seat_index'),
      hasSettlements: _boolOrDefault(json, 'has_settlements', false),
      cells: cells,
      rowType: rowType,
      bonusRoundId: _optionalString(json, 'bonus_round_id'),
      bonusTableRole: _optionalString(json, 'bonus_table_role'),
      adjustmentId: _optionalString(json, 'adjustment_id'),
      adjustmentType: _optionalString(json, 'adjustment_type'),
      adjustmentAmountPoints: _optionalInt(json, 'adjustment_amount_points'),
      adjustmentEventGuestId:
          _optionalString(json, 'adjustment_event_guest_id'),
      adjustmentDisplayName: _optionalString(json, 'adjustment_display_name'),
      adjustmentContextJson: _jsonObjectOrEmpty(
        json,
        'adjustment_context_json',
      ),
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
  final HandResultType? resultType;
  final HandResultStatus status;
  final EventHandLedgerRowType rowType;
  final HandWinType? winType;
  final int? fanCount;
  final int? penaltySeatIndex;
  final String? bonusRoundId;
  final String? bonusTableRole;
  final String? adjustmentId;
  final String? adjustmentType;
  final int? adjustmentAmountPoints;
  final String? adjustmentEventGuestId;
  final String? adjustmentDisplayName;
  final Map<String, dynamic> adjustmentContextJson;
  final bool hasSettlements;
  final List<EventHandLedgerCell> cells;

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'ledger_row_type': _rowTypeToJson(rowType),
      'table_id': tableId,
      'table_label': tableLabel,
      'session_id': sessionId,
      'session_number_for_table': sessionNumberForTable,
      'hand_id': handId,
      'hand_number': handNumber,
      'entered_at': enteredAt.toIso8601String(),
      'result_type':
          resultType == null ? null : _handResultTypeToJson(resultType!),
      'status': _handResultStatusToJson(status),
      'win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'fan_count': fanCount,
      'penalty_seat_index': penaltySeatIndex,
      'bonus_round_id': bonusRoundId,
      'bonus_table_role': bonusTableRole,
      'adjustment_id': adjustmentId,
      'adjustment_type': adjustmentType,
      'adjustment_amount_points': adjustmentAmountPoints,
      'adjustment_event_guest_id': adjustmentEventGuestId,
      'adjustment_display_name': adjustmentDisplayName,
      'adjustment_context_json': adjustmentContextJson,
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

Map<String, dynamic> _jsonObjectOrEmpty(Map<String, dynamic> json, String key) {
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

EventHandLedgerRowType _rowTypeFromJson(String value) {
  return switch (value) {
    'hand' => EventHandLedgerRowType.hand,
    'adjustment' => EventHandLedgerRowType.adjustment,
    _ => throw FormatException('Unknown hand ledger row type: $value'),
  };
}

String _rowTypeToJson(EventHandLedgerRowType rowType) {
  return switch (rowType) {
    EventHandLedgerRowType.hand => 'hand',
    EventHandLedgerRowType.adjustment => 'adjustment',
  };
}

HandResultType _handResultTypeFromJson(String value) {
  return switch (value) {
    'win' => HandResultType.win,
    'washout' => HandResultType.washout,
    'false_win_penalty' => HandResultType.falseWinPenalty,
    _ => throw FormatException('Unknown hand result type: $value'),
  };
}

String _handResultTypeToJson(HandResultType type) {
  return switch (type) {
    HandResultType.win => 'win',
    HandResultType.washout => 'washout',
    HandResultType.falseWinPenalty => 'false_win_penalty',
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
