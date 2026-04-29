import 'package:meta/meta.dart';

enum EventLifecycleStatus {
  draft,
  active,
  completed,
  finalized,
  cancelled,
}

enum PrevailingWind {
  east,
  south,
  west,
  north,
}

@immutable
class CreateEventInput {
  const CreateEventInput({
    required this.title,
    required this.startsAt,
    required this.timezone,
    required this.coverChargeCents,
    required this.prizeBudgetCents,
    this.description,
    this.venueName,
    this.venueAddress,
    this.prizeBudgetNote,
    this.defaultRulesetId = 'HK_STANDARD_V1',
  });

  final String title;
  final String? description;
  final String? venueName;
  final String? venueAddress;
  final String timezone;
  final DateTime startsAt;
  final int coverChargeCents;
  final int prizeBudgetCents;
  final String? prizeBudgetNote;
  final String defaultRulesetId;

  Map<String, dynamic> toInsertJson({required String ownerUserId}) {
    return {
      'owner_user_id': ownerUserId,
      'title': title,
      'description': description,
      'venue_name': venueName,
      'venue_address': venueAddress,
      'timezone': timezone,
      'starts_at': startsAt.toIso8601String(),
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'cover_charge_cents': coverChargeCents,
      'prize_budget_cents': prizeBudgetCents,
      'prize_budget_note': prizeBudgetNote,
      'default_ruleset_id': defaultRulesetId,
      'prevailing_wind': 'east',
    };
  }
}

@immutable
class EventRecord {
  const EventRecord({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.timezone,
    required this.startsAt,
    required this.createdAt,
    required this.lifecycleStatus,
    required this.checkinOpen,
    required this.scoringOpen,
    required this.coverChargeCents,
    required this.prizeBudgetCents,
    required this.defaultRulesetId,
    required this.prevailingWind,
    this.description,
    this.venueName,
    this.venueAddress,
    this.endsAt,
    this.prizeBudgetNote,
    this.rowVersion = 1,
  });

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      id: _requiredString(json, 'id'),
      ownerUserId: _requiredString(json, 'owner_user_id'),
      title: _requiredString(json, 'title'),
      description: _optionalString(json, 'description'),
      venueName: _optionalString(json, 'venue_name'),
      venueAddress: _optionalString(json, 'venue_address'),
      timezone: _requiredString(json, 'timezone'),
      startsAt: _requiredDateTime(json, 'starts_at'),
      createdAt: _optionalDateTime(json, 'created_at') ??
          _requiredDateTime(json, 'starts_at'),
      endsAt: _optionalDateTime(json, 'ends_at'),
      lifecycleStatus: _eventLifecycleStatusFromJson(
        _requiredString(json, 'lifecycle_status'),
      ),
      checkinOpen: _requiredBool(json, 'checkin_open'),
      scoringOpen: _requiredBool(json, 'scoring_open'),
      coverChargeCents: _requiredInt(json, 'cover_charge_cents'),
      prizeBudgetCents: _requiredInt(json, 'prize_budget_cents'),
      prizeBudgetNote: _optionalString(json, 'prize_budget_note'),
      defaultRulesetId: _requiredString(json, 'default_ruleset_id'),
      prevailingWind: _prevailingWindFromJson(
        _requiredString(json, 'prevailing_wind'),
      ),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String ownerUserId;
  final String title;
  final String? description;
  final String? venueName;
  final String? venueAddress;
  final String timezone;
  final DateTime startsAt;
  final DateTime createdAt;
  final DateTime? endsAt;
  final EventLifecycleStatus lifecycleStatus;
  final bool checkinOpen;
  final bool scoringOpen;
  final int coverChargeCents;
  final int prizeBudgetCents;
  final String? prizeBudgetNote;
  final String defaultRulesetId;
  final PrevailingWind prevailingWind;
  final int rowVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_user_id': ownerUserId,
      'title': title,
      'description': description,
      'venue_name': venueName,
      'venue_address': venueAddress,
      'timezone': timezone,
      'starts_at': startsAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'lifecycle_status': lifecycleStatus.name,
      'checkin_open': checkinOpen,
      'scoring_open': scoringOpen,
      'cover_charge_cents': coverChargeCents,
      'prize_budget_cents': prizeBudgetCents,
      'prize_budget_note': prizeBudgetNote,
      'default_ruleset_id': defaultRulesetId,
      'prevailing_wind': prevailingWind.name,
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Expected bool for $key.');
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

EventLifecycleStatus _eventLifecycleStatusFromJson(String value) {
  return switch (value) {
    'draft' => EventLifecycleStatus.draft,
    'active' => EventLifecycleStatus.active,
    'completed' => EventLifecycleStatus.completed,
    'finalized' => EventLifecycleStatus.finalized,
    'cancelled' => EventLifecycleStatus.cancelled,
    _ => throw FormatException('Unknown event lifecycle status: $value'),
  };
}

PrevailingWind _prevailingWindFromJson(String value) {
  return switch (value) {
    'east' => PrevailingWind.east,
    'south' => PrevailingWind.south,
    'west' => PrevailingWind.west,
    'north' => PrevailingWind.north,
    _ => throw FormatException('Unknown prevailing wind: $value'),
  };
}
