import 'package:meta/meta.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';

enum HandResultType {
  win,
  washout,
  falseWinPenalty,
}

enum HandWinType {
  discard,
  selfDraw,
}

enum HandResultStatus {
  recorded,
  voided,
}

enum FalseWinPenaltyStatus {
  pending,
  attached,
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
    this.penaltySeatIndex,
    this.fanCount,
    this.winBonuses,
    this.basePoints,
    this.dealerWasWaitingAtDraw,
    this.correctionNote,
    this.rowVersion = 1,
    this.clientMutationId,
    this.photoId,
    this.photoClientId,
    this.photoCapturedAt,
    this.photoUploadStatus,
    this.photoStorageBucket,
    this.photoStoragePath,
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
      penaltySeatIndex: _optionalInt(json, 'penalty_seat_index'),
      fanCount: _optionalInt(json, 'fan_count'),
      winBonuses: _optionalWinBonuses(json, 'win_bonuses'),
      basePoints: _optionalInt(json, 'base_points'),
      dealerWasWaitingAtDraw: _optionalBool(json, 'dealer_was_waiting_at_draw'),
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
      clientMutationId: _optionalString(json, 'client_mutation_id'),
      photoId: _optionalString(json, 'photo_id'),
      photoClientId: _optionalString(json, 'photo_client_id'),
      photoCapturedAt: _optionalDateTime(json, 'photo_captured_at'),
      photoUploadStatus: _optionalString(json, 'photo_upload_status'),
      photoStorageBucket: _optionalString(json, 'photo_storage_bucket'),
      photoStoragePath: _optionalString(json, 'photo_storage_path'),
    );
  }

  final String id;
  final String tableSessionId;
  final int handNumber;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? penaltySeatIndex;
  final int? fanCount;
  final List<HandWinBonus>? winBonuses;
  final int? basePoints;
  final bool? dealerWasWaitingAtDraw;
  final int eastSeatIndexBeforeHand;
  final int eastSeatIndexAfterHand;
  final bool dealerRotated;
  final bool sessionCompletedAfterHand;
  final HandResultStatus status;
  final String enteredByUserId;
  final DateTime enteredAt;
  final String? correctionNote;
  final int rowVersion;
  final String? clientMutationId;
  final String? photoId;
  final String? photoClientId;
  final DateTime? photoCapturedAt;
  final String? photoUploadStatus;
  final String? photoStorageBucket;
  final String? photoStoragePath;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_session_id': tableSessionId,
      'hand_number': handNumber,
      'result_type': _handResultTypeToJson(resultType),
      'winner_seat_index': winnerSeatIndex,
      'win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'discarder_seat_index': discarderSeatIndex,
      'penalty_seat_index': penaltySeatIndex,
      'fan_count': fanCount,
      'win_bonuses': winBonuses == null ? null : handWinBonusIds(winBonuses!),
      'base_points': basePoints,
      'dealer_was_waiting_at_draw': dealerWasWaitingAtDraw,
      'east_seat_index_before_hand': eastSeatIndexBeforeHand,
      'east_seat_index_after_hand': eastSeatIndexAfterHand,
      'dealer_rotated': dealerRotated,
      'session_completed_after_hand': sessionCompletedAfterHand,
      'status': _handResultStatusToJson(status),
      'entered_by_user_id': enteredByUserId,
      'entered_at': enteredAt.toIso8601String(),
      'correction_note': correctionNote,
      'row_version': rowVersion,
      'client_mutation_id': clientMutationId,
      'photo_id': photoId,
      'photo_client_id': photoClientId,
      'photo_captured_at': photoCapturedAt?.toIso8601String(),
      'photo_upload_status': photoUploadStatus,
      'photo_storage_bucket': photoStorageBucket,
      'photo_storage_path': photoStoragePath,
    };
  }
}

@immutable
class HandSettlementRecord {
  const HandSettlementRecord({
    required this.id,
    required this.handResultId,
    this.handFalseWinPenaltyId,
    required this.payerEventGuestId,
    required this.payeeEventGuestId,
    required this.amountPoints,
    required this.multiplierFlags,
  });

  factory HandSettlementRecord.fromJson(Map<String, dynamic> json) {
    return HandSettlementRecord(
      id: _requiredString(json, 'id'),
      handResultId: _optionalString(json, 'hand_result_id'),
      handFalseWinPenaltyId: _optionalString(json, 'hand_false_win_penalty_id'),
      payerEventGuestId: _requiredString(json, 'payer_event_guest_id'),
      payeeEventGuestId: _requiredString(json, 'payee_event_guest_id'),
      amountPoints: _requiredInt(json, 'amount_points'),
      multiplierFlags: _stringList(json, 'multiplier_flags_json'),
    );
  }

  final String id;
  final String? handResultId;
  final String? handFalseWinPenaltyId;
  final String payerEventGuestId;
  final String payeeEventGuestId;
  final int amountPoints;
  final List<String> multiplierFlags;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hand_result_id': handResultId,
      'hand_false_win_penalty_id': handFalseWinPenaltyId,
      'payer_event_guest_id': payerEventGuestId,
      'payee_event_guest_id': payeeEventGuestId,
      'amount_points': amountPoints,
      'multiplier_flags_json': multiplierFlags,
    };
  }
}

@immutable
class FalseWinPenaltyRecord {
  const FalseWinPenaltyRecord({
    required this.id,
    required this.tableSessionId,
    required this.penaltySeatIndex,
    required this.fanCount,
    required this.enteredByUserId,
    required this.enteredAt,
    required this.status,
    this.handResultId,
    this.correctionNote,
  });

  factory FalseWinPenaltyRecord.fromJson(Map<String, dynamic> json) {
    return FalseWinPenaltyRecord(
      id: _requiredString(json, 'id'),
      tableSessionId: _requiredString(json, 'table_session_id'),
      handResultId: _optionalString(json, 'hand_result_id'),
      penaltySeatIndex: _requiredInt(json, 'penalty_seat_index'),
      fanCount: _requiredInt(json, 'fan_count'),
      enteredByUserId: _requiredString(json, 'entered_by_user_id'),
      enteredAt: _requiredDateTime(json, 'entered_at'),
      status: _falseWinPenaltyStatusFromJson(
        _requiredString(json, 'status'),
      ),
      correctionNote: _optionalString(json, 'correction_note'),
    );
  }

  final String id;
  final String tableSessionId;
  final String? handResultId;
  final int penaltySeatIndex;
  final int fanCount;
  final String enteredByUserId;
  final DateTime enteredAt;
  final FalseWinPenaltyStatus status;
  final String? correctionNote;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_session_id': tableSessionId,
      'hand_result_id': handResultId,
      'penalty_seat_index': penaltySeatIndex,
      'fan_count': fanCount,
      'entered_by_user_id': enteredByUserId,
      'entered_at': enteredAt.toIso8601String(),
      'status': _falseWinPenaltyStatusToJson(status),
      'correction_note': correctionNote,
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
    this.penaltySeatIndex,
    this.fanCount,
    this.winBonuses,
    this.dealerWasWaitingAtDraw,
    this.correctionNote,
    this.clientMutationId,
    this.expectedRecordedHandCount,
    this.expectedLastRecordedHandId,
    this.photoClientId,
    this.photoLocalPath,
    this.photoCapturedAt,
  });

  final String tableSessionId;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? penaltySeatIndex;
  final int? fanCount;
  final List<HandWinBonus>? winBonuses;
  final bool? dealerWasWaitingAtDraw;
  final String? correctionNote;
  final String? clientMutationId;
  final int? expectedRecordedHandCount;
  final String? expectedLastRecordedHandId;
  final String? photoClientId;
  final String? photoLocalPath;
  final DateTime? photoCapturedAt;

  Map<String, dynamic> toRpcParams() {
    final params = {
      'target_table_session_id': tableSessionId,
      'target_result_type': _handResultTypeToJson(resultType),
      'target_winner_seat_index': winnerSeatIndex,
      'target_win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'target_discarder_seat_index': discarderSeatIndex,
      'target_penalty_seat_index': penaltySeatIndex,
      'target_fan_count': fanCount,
      'target_win_bonuses':
          winBonuses == null ? null : handWinBonusIds(winBonuses!),
      'target_dealer_was_waiting_at_draw': dealerWasWaitingAtDraw,
      'target_correction_note': correctionNote,
      'target_client_mutation_id': clientMutationId,
      'target_expected_recorded_hand_count': expectedRecordedHandCount,
      'target_expected_last_recorded_hand_id': expectedLastRecordedHandId,
    };
    if (photoClientId != null) {
      params['target_photo_client_id'] = photoClientId;
    }
    if (photoCapturedAt != null) {
      params['target_photo_captured_at'] =
          photoCapturedAt!.toUtc().toIso8601String();
    }
    return params;
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
    this.penaltySeatIndex,
    this.fanCount,
    this.winBonuses,
    this.dealerWasWaitingAtDraw,
    this.correctionNote,
  });

  final String handResultId;
  final HandResultType resultType;
  final int? winnerSeatIndex;
  final HandWinType? winType;
  final int? discarderSeatIndex;
  final int? penaltySeatIndex;
  final int? fanCount;
  final List<HandWinBonus>? winBonuses;
  final bool? dealerWasWaitingAtDraw;
  final String? correctionNote;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_hand_result_id': handResultId,
      'target_result_type': _handResultTypeToJson(resultType),
      'target_winner_seat_index': winnerSeatIndex,
      'target_win_type': winType == null ? null : _handWinTypeToJson(winType!),
      'target_discarder_seat_index': discarderSeatIndex,
      'target_penalty_seat_index': penaltySeatIndex,
      'target_fan_count': fanCount,
      'target_win_bonuses':
          winBonuses == null ? null : handWinBonusIds(winBonuses!),
      'target_dealer_was_waiting_at_draw': dealerWasWaitingAtDraw,
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

@immutable
class VoidFalseWinPenaltyInput {
  const VoidFalseWinPenaltyInput({
    required this.handFalseWinPenaltyId,
    this.correctionNote,
  });

  final String handFalseWinPenaltyId;
  final String? correctionNote;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_hand_false_win_penalty_id': handFalseWinPenaltyId,
      'target_correction_note': correctionNote,
    };
  }
}

@immutable
class RecordFalseWinPenaltyInput {
  const RecordFalseWinPenaltyInput({
    required this.tableSessionId,
    required this.penaltySeatIndex,
    this.correctionNote,
    this.clientMutationId,
    this.expectedRecordedHandCount,
    this.expectedLastRecordedHandId,
  });

  final String tableSessionId;
  final int penaltySeatIndex;
  final String? correctionNote;
  final String? clientMutationId;
  final int? expectedRecordedHandCount;
  final String? expectedLastRecordedHandId;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_table_session_id': tableSessionId,
      'target_penalty_seat_index': penaltySeatIndex,
      'target_correction_note': correctionNote,
      'target_client_mutation_id': clientMutationId,
      'target_expected_recorded_hand_count': expectedRecordedHandCount,
      'target_expected_last_recorded_hand_id': expectedLastRecordedHandId,
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

bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  if (value is bool) {
    return value;
  }

  throw FormatException('Expected bool or null for $key.');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 string for $key.');
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

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) {
    return value.map((item) => item.toString()).toList(growable: false);
  }

  throw FormatException('Expected list for $key.');
}

List<HandWinBonus>? _optionalWinBonuses(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is List) {
    final ids = <String>[];
    for (final item in value) {
      if (item is! String) {
        throw FormatException('Expected string list or null for $key.');
      }
      ids.add(item);
    }
    return handWinBonusesFromIds(ids);
  }
  throw FormatException('Expected string list or null for $key.');
}

HandResultType _handResultTypeFromJson(String value) {
  return switch (value) {
    'win' => HandResultType.win,
    'washout' => HandResultType.washout,
    'false_win_penalty' => HandResultType.falseWinPenalty,
    _ => throw FormatException('Unknown hand result type: $value'),
  };
}

String _handResultTypeToJson(HandResultType value) {
  return switch (value) {
    HandResultType.win => 'win',
    HandResultType.washout => 'washout',
    HandResultType.falseWinPenalty => 'false_win_penalty',
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

FalseWinPenaltyStatus _falseWinPenaltyStatusFromJson(String value) {
  return switch (value) {
    'pending' => FalseWinPenaltyStatus.pending,
    'attached' => FalseWinPenaltyStatus.attached,
    'voided' => FalseWinPenaltyStatus.voided,
    _ => throw FormatException('Unknown false win penalty status: $value'),
  };
}

String _falseWinPenaltyStatusToJson(FalseWinPenaltyStatus value) {
  return switch (value) {
    FalseWinPenaltyStatus.pending => 'pending',
    FalseWinPenaltyStatus.attached => 'attached',
    FalseWinPenaltyStatus.voided => 'voided',
  };
}
