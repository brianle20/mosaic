import 'dart:math' as math;

import 'package:meta/meta.dart';

enum PrizePlanMode {
  none,
  percentage,
  fixed,
}

enum PrizePlanStatus {
  draft,
  validated,
  locked,
}

@immutable
class PrizePlanRecord {
  const PrizePlanRecord({
    required this.id,
    required this.eventId,
    required this.mode,
    required this.status,
    required this.prizeBudgetCents,
    required this.reserveFixedCents,
    required this.reservePercentageBps,
    this.note,
    this.rowVersion = 1,
  });

  factory PrizePlanRecord.fromJson(
    Map<String, dynamic> json, {
    required int prizeBudgetCents,
  }) {
    return PrizePlanRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      mode: _prizePlanModeFromJson(_requiredString(json, 'mode')),
      status: _prizePlanStatusFromJson(_requiredString(json, 'status')),
      prizeBudgetCents: prizeBudgetCents,
      reserveFixedCents: _requiredInt(json, 'reserve_fixed_cents'),
      reservePercentageBps: _requiredInt(json, 'reserve_percentage_bps'),
      note: _optionalString(json, 'note'),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String eventId;
  final PrizePlanMode mode;
  final PrizePlanStatus status;
  final int prizeBudgetCents;
  final int reserveFixedCents;
  final int reservePercentageBps;
  final String? note;
  final int rowVersion;

  int get reservePercentageCents {
    return (prizeBudgetCents * reservePercentageBps) ~/ 10000;
  }

  int get distributableBudgetCents {
    return math.max(
      0,
      prizeBudgetCents - reserveFixedCents - reservePercentageCents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'mode': mode.name,
      'status': status.name,
      'prize_budget_cents': prizeBudgetCents,
      'reserve_fixed_cents': reserveFixedCents,
      'reserve_percentage_bps': reservePercentageBps,
      'note': note,
      'row_version': rowVersion,
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

PrizePlanMode _prizePlanModeFromJson(String value) {
  return switch (value) {
    'none' => PrizePlanMode.none,
    'percentage' => PrizePlanMode.percentage,
    'fixed' => PrizePlanMode.fixed,
    _ => throw FormatException('Unknown prize plan mode: $value'),
  };
}

PrizePlanStatus _prizePlanStatusFromJson(String value) {
  return switch (value) {
    'draft' => PrizePlanStatus.draft,
    'validated' => PrizePlanStatus.validated,
    'locked' => PrizePlanStatus.locked,
    _ => throw FormatException('Unknown prize plan status: $value'),
  };
}
