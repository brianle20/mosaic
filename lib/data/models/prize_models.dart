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
class PrizeTierDraftInput {
  const PrizeTierDraftInput({
    required this.place,
    this.label,
    this.percentageBps,
    this.fixedAmountCents,
  });

  final int place;
  final String? label;
  final int? percentageBps;
  final int? fixedAmountCents;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'place': place,
    };
    if (label != null) {
      json['label'] = label;
    }
    if (percentageBps != null) {
      json['percentage_bps'] = percentageBps;
    }
    if (fixedAmountCents != null) {
      json['fixed_amount_cents'] = fixedAmountCents;
    }

    return json;
  }
}

@immutable
class UpsertPrizePlanInput {
  const UpsertPrizePlanInput({
    required this.eventId,
    required this.mode,
    required this.tiers,
    this.note,
  });

  final String eventId;
  final PrizePlanMode mode;
  final String? note;
  final List<PrizeTierDraftInput> tiers;

  Map<String, dynamic> toRpcParams() {
    return {
      'target_event_id': eventId,
      'target_mode': mode.name,
      'target_reserve_fixed_cents': 0,
      'target_reserve_percentage_bps': 0,
      'target_note': note,
      'target_tiers':
          tiers.map((tier) => tier.toJson()).toList(growable: false),
    };
  }
}

@immutable
class PrizePlanRecord {
  const PrizePlanRecord({
    required this.id,
    required this.eventId,
    required this.mode,
    required this.status,
    required this.reserveFixedCents,
    required this.reservePercentageBps,
    this.note,
    this.rowVersion = 1,
  });

  factory PrizePlanRecord.fromJson(Map<String, dynamic> json) {
    return PrizePlanRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      mode: _prizePlanModeFromJson(_requiredString(json, 'mode')),
      status: _prizePlanStatusFromJson(_requiredString(json, 'status')),
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
  final int reserveFixedCents;
  final int reservePercentageBps;
  final String? note;
  final int rowVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'mode': mode.name,
      'status': status.name,
      'reserve_fixed_cents': reserveFixedCents,
      'reserve_percentage_bps': reservePercentageBps,
      'note': note,
      'row_version': rowVersion,
    };
  }
}

@immutable
class PrizePlanDetail {
  const PrizePlanDetail({
    required this.plan,
    required this.tiers,
  });

  factory PrizePlanDetail.fromJson(Map<String, dynamic> json) {
    final tiersJson = (json['tiers'] as List<dynamic>? ?? const <dynamic>[]);
    return PrizePlanDetail(
      plan: PrizePlanRecord.fromJson(
        (json['plan'] as Map).cast<String, dynamic>(),
      ),
      tiers: tiersJson
          .map((tier) =>
              PrizeTierRecord.fromJson((tier as Map).cast<String, dynamic>()))
          .toList(growable: false)
        ..sort((left, right) => left.place.compareTo(right.place)),
    );
  }

  final PrizePlanRecord plan;
  final List<PrizeTierRecord> tiers;

  Map<String, dynamic> toJson() {
    return {
      'plan': plan.toJson(),
      'tiers': tiers.map((tier) => tier.toJson()).toList(growable: false),
    };
  }
}

@immutable
class PrizeTierRecord {
  const PrizeTierRecord({
    required this.id,
    required this.prizePlanId,
    required this.place,
    this.label,
    this.percentageBps,
    this.fixedAmountCents,
  });

  factory PrizeTierRecord.fromJson(Map<String, dynamic> json) {
    return PrizeTierRecord(
      id: _requiredString(json, 'id'),
      prizePlanId: _requiredString(json, 'prize_plan_id'),
      place: _requiredInt(json, 'place'),
      label: _optionalString(json, 'label'),
      percentageBps: _optionalInt(json, 'percentage_bps'),
      fixedAmountCents: _optionalInt(json, 'fixed_amount_cents'),
    );
  }

  final String id;
  final String prizePlanId;
  final int place;
  final String? label;
  final int? percentageBps;
  final int? fixedAmountCents;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prize_plan_id': prizePlanId,
      'place': place,
      'label': label,
      'percentage_bps': percentageBps,
      'fixed_amount_cents': fixedAmountCents,
    };
  }
}

@immutable
class PrizeAwardRecord {
  const PrizeAwardRecord({
    required this.id,
    required this.eventId,
    required this.eventGuestId,
    required this.rankStart,
    required this.rankEnd,
    required this.displayRank,
    required this.awardAmountCents,
    this.displayName,
  });

  factory PrizeAwardRecord.fromJson(Map<String, dynamic> json) {
    return PrizeAwardRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _optionalString(json, 'display_name'),
      rankStart: _requiredInt(json, 'rank_start'),
      rankEnd: _requiredInt(json, 'rank_end'),
      displayRank: _requiredString(json, 'display_rank'),
      awardAmountCents: _requiredInt(json, 'award_amount_cents'),
    );
  }

  final String id;
  final String eventId;
  final String eventGuestId;
  final String? displayName;
  final int rankStart;
  final int rankEnd;
  final String displayRank;
  final int awardAmountCents;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'rank_start': rankStart,
      'rank_end': rankEnd,
      'display_rank': displayRank,
      'award_amount_cents': awardAmountCents,
    };
  }
}

@immutable
class PrizeAwardPreviewRow {
  const PrizeAwardPreviewRow({
    required this.eventGuestId,
    required this.displayName,
    required this.rankStart,
    required this.rankEnd,
    required this.displayRank,
    required this.awardAmountCents,
  });

  factory PrizeAwardPreviewRow.fromJson(Map<String, dynamic> json) {
    return PrizeAwardPreviewRow(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      rankStart: _requiredInt(json, 'rank_start'),
      rankEnd: _requiredInt(json, 'rank_end'),
      displayRank: _requiredString(json, 'display_rank'),
      awardAmountCents: _requiredInt(json, 'award_amount_cents'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final int rankStart;
  final int rankEnd;
  final String displayRank;
  final int awardAmountCents;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'rank_start': rankStart,
      'rank_end': rankEnd,
      'display_rank': displayRank,
      'award_amount_cents': awardAmountCents,
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
