import 'package:meta/meta.dart';

enum HandResultType {
  win,
  washout,
}

enum HandWinType {
  discard,
  selfDraw,
}

enum HandResultStatus {
  recorded,
  voided,
}

@immutable
class HandResultRecord {
  const HandResultRecord({
    required this.id,
    required this.tableSessionId,
    required this.handNumber,
    required this.resultType,
    required this.eastSeatIndexBeforeHand,
    required this.eastSeatIndexAfterHand,
    required this.dealerRotated,
    required this.sessionCompletedAfterHand,
    required this.status,
    required this.enteredByUserId,
    required this.enteredAt,
    this.winnerSeatIndex,
    this.winType,
    this.discarderSeatIndex,
    this.fanCount,
    this.basePoints,
    this.correctionNote,
    this.rowVersion = 1,
  });

  factory HandResultRecord.fromJson(Map<String, dynamic> json) {
    return HandResultRecord(
      id: _requiredString(json, 'id'),
      tableSessionId: _requiredString(json, 'table_session_id'),
      handNumber: _requiredInt(json, 'hand_number'),
      resultType: _handResultTypeFromJson(_requiredString(json, 'result_type')),
      winnerSeatIndex: _optionalInt(json, 'winner_seat_index'),
      winType: _optionalWinType(json, 'win_type'),
      discarderSeatIndex: _optionalInt(json, 'discarder_seat_index'),
      fanCount: _optionalInt(json, 'fan_count'),
      basePoints: _optionalInt(json, 'base_points'),
      eastSeatIndexBeforeHand:
          _requiredInt(json, 'east_seat_index_before_hand'),
      eastSeatIndexAfterHand: _requiredInt(json, 'east_seat_index_after_hand'),
      dealerRotated: _requiredBool(json, 'dealer_rotated'),
      sessionCompletedAfterHand:
          _requiredBool(json, 'session_completed_after_hand'),
      status: _handResultStatusFromJson(_requiredString(json, 'status')),
      enteredByUserId: _requiredString(json, 'entered_by_user_id'),
      enteredAt: _requiredDateTime(json, 'entered_at'),
      correctionNote: _optionalString(json, 'correction_note'),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String tableSessionId;
  final int handNumber;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? fanCount;
  final int? basePoints;
  final int eastSeatIndexBeforeHand;
  final int eastSeatIndexAfterHand;
  final bool dealerRotated;
  final bool sessionCompletedAfterHand;
  final HandResultStatus status;
  final String enteredByUserId;
  final DateTime enteredAt;
  final String? correctionNote;
  final int rowVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_session_id': tableSessionId,
      'hand_number': handNumber,
      'result_type': _handResultTypeToJson(resultType),
      'winner_seat_index': winnerSeatIndex,
      'win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'discarder_seat_index': discarderSeatIndex,
      'fan_count': fanCount,
      'base_points': basePoints,
      'east_seat_index_before_hand': eastSeatIndexBeforeHand,
      'east_seat_index_after_hand': eastSeatIndexAfterHand,
      'dealer_rotated': dealerRotated,
      'session_completed_after_hand': sessionCompletedAfterHand,
      'status': _handResultStatusToJson(status),
      'entered_by_user_id': enteredByUserId,
      'entered_at': enteredAt.toIso8601String(),
      'correction_note': correctionNote,
      'row_version': rowVersion,
    };
  }
}

@immutable
class HandSettlementRecord {
  const HandSettlementRecord({
    required this.id,
    required this.handResultId,
    required this.payerEventGuestId,
    required this.payeeEventGuestId,
    required this.amountPoints,
    required this.multiplierFlags,
  });

  factory HandSettlementRecord.fromJson(Map<String, dynamic> json) {
    return HandSettlementRecord(
      id: _requiredString(json, 'id'),
      handResultId: _requiredString(json, 'hand_result_id'),
      payerEventGuestId: _requiredString(json, 'payer_event_guest_id'),
      payeeEventGuestId: _requiredString(json, 'payee_event_guest_id'),
      amountPoints: _requiredInt(json, 'amount_points'),
      multiplierFlags: _stringList(json, 'multiplier_flags_json'),
    );
  }

  final String id;
  final String handResultId;
  final String payerEventGuestId;
  final String payeeEventGuestId;
  final int amountPoints;
  final List<String> multiplierFlags;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hand_result_id': handResultId,
      'payer_event_guest_id': payerEventGuestId,
      'payee_event_guest_id': payeeEventGuestId,
      'amount_points': amountPoints,
      'multiplier_flags_json': multiplierFlags,
    };
  }
}

@immutable
class RecordHandResultInput {
  const RecordHandResultInput({
    required this.tableSessionId,
    required this.resultType,
    this.winnerSeatIndex,
    this.winType,
    this.discarderSeatIndex,
    this.fanCount,
    this.correctionNote,
  });

  final String tableSessionId;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? fanCount;
  final String? correctionNote;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_table_session_id': tableSessionId,
      'target_result_type': _handResultTypeToJson(resultType),
      'target_winner_seat_index': winnerSeatIndex,
      'target_win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'target_discarder_seat_index': discarderSeatIndex,
      'target_fan_count': fanCount,
      'target_correction_note': correctionNote,
    };
  }
}

@immutable
class EditHandResultInput {
  const EditHandResultInput({
    required this.handResultId,
    required this.resultType,
    this.winnerSeatIndex,
    this.winType,
    this.discarderSeatIndex,
    this.fanCount,
    this.correctionNote,
  });

  final String handResultId;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? fanCount;
  final String? correctionNote;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_hand_result_id': handResultId,
      'target_result_type': _handResultTypeToJson(resultType),
      'target_winner_seat_index': winnerSeatIndex,
      'target_win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'target_discarder_seat_index': discarderSeatIndex,
      'target_fan_count': fanCount,
      'target_correction_note': correctionNote,
    };
  }
}

@immutable
class VoidHandResultInput {
  const VoidHandResultInput({
    required this.handResultId,
    this.correctionNote,
  });

  final String handResultId;
  final String? correctionNote;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_hand_result_id': handResultId,
      'target_correction_note': correctionNote,
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Expected bool for $key.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 string for $key.');
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }

  throw FormatException('Expected list for $key.');
}

HandResultType _handResultTypeFromJson(String value) {
  return switch (value) {
    'win' => HandResultType.win,
    'washout' => HandResultType.washout,
    _ => throw FormatException('Unknown hand result type: $value'),
  };
}

String _handResultTypeToJson(HandResultType value) {
  return switch (value) {
    HandResultType.win => 'win',
    HandResultType.washout => 'washout',
  };
}

HandWinType? _optionalWinType(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is String) {
    return _handWinTypeFromJson(value);
  }

  throw FormatException('Expected string or null for $key.');
}

HandWinType _handWinTypeFromJson(String value) {
  return switch (value) {
    'discard' => HandWinType.discard,
    'self_draw' => HandWinType.selfDraw,
    _ => throw FormatException('Unknown hand win type: $value'),
  };
}

String _handWinTypeToJson(HandWinType value) {
  return switch (value) {
    HandWinType.discard => 'discard',
    HandWinType.selfDraw => 'self_draw',
  };
}

HandResultStatus _handResultStatusFromJson(String value) {
  return switch (value) {
    'recorded' => HandResultStatus.recorded,
    'voided' => HandResultStatus.voided,
    _ => throw FormatException('Unknown hand result status: $value'),
  };
}

String _handResultStatusToJson(HandResultStatus value) {
  return switch (value) {
    HandResultStatus.recorded => 'recorded',
    HandResultStatus.voided => 'voided',
  };
}
