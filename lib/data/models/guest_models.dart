import 'package:meta/meta.dart';
import 'package:mosaic/data/models/tag_models.dart';

enum AttendanceStatus {
  expected,
  checkedIn,
  checkedOut,
  noShow,
}

enum CoverStatus {
  unpaid,
  paid,
  partial,
  comped,
  refunded,
}

enum CoverEntryMethod {
  cash,
  venmo,
  zelle,
  other,
  comp,
  refund,
}

@immutable
class CreateGuestInput {
  const CreateGuestInput({
    required this.eventId,
    required this.displayName,
    required this.normalizedName,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    this.phoneE164,
    this.emailLower,
    this.note,
  });

  final String eventId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final String? note;

  Map<String, dynamic> toInsertJson() {
    return {
      'event_id': eventId,
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'attendance_status': 'expected',
      'cover_status': _coverStatusToJson(coverStatus),
      'cover_amount_cents': coverAmountCents,
      'is_comped': isComped,
      'has_scored_play': false,
      'note': note,
    };
  }
}

@immutable
class UpdateGuestInput {
  const UpdateGuestInput({
    required this.id,
    required this.eventId,
    required this.displayName,
    required this.normalizedName,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    this.phoneE164,
    this.emailLower,
    this.note,
  });

  final String id;
  final String eventId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final String? note;

  Map<String, dynamic> toUpdateJson() {
    return {
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'cover_status': _coverStatusToJson(coverStatus),
      'cover_amount_cents': coverAmountCents,
      'is_comped': isComped,
      'note': note,
    };
  }
}

@immutable
class EventGuestRecord {
  const EventGuestRecord({
    required this.id,
    required this.eventId,
    required this.displayName,
    required this.normalizedName,
    required this.attendanceStatus,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    required this.hasScoredPlay,
    this.phoneE164,
    this.emailLower,
    this.note,
    this.checkedInAt,
    this.rowVersion = 1,
  });

  factory EventGuestRecord.fromJson(Map<String, dynamic> json) {
    return EventGuestRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      displayName: _requiredString(json, 'display_name'),
      normalizedName: _requiredString(json, 'normalized_name'),
      phoneE164: _optionalString(json, 'phone_e164'),
      emailLower: _optionalString(json, 'email_lower'),
      attendanceStatus: _attendanceStatusFromJson(
        _requiredString(json, 'attendance_status'),
      ),
      coverStatus: _coverStatusFromJson(_requiredString(json, 'cover_status')),
      coverAmountCents: _requiredInt(json, 'cover_amount_cents'),
      isComped: _requiredBool(json, 'is_comped'),
      hasScoredPlay: _requiredBool(json, 'has_scored_play'),
      note: _optionalString(json, 'note'),
      checkedInAt: _optionalDateTime(json, 'checked_in_at'),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String eventId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final AttendanceStatus attendanceStatus;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final bool hasScoredPlay;
  final String? note;
  final DateTime? checkedInAt;
  final int rowVersion;

  bool get isEligibleForPlayerTagAssignment {
    return coverStatus == CoverStatus.paid || coverStatus == CoverStatus.comped;
  }

  bool get isCheckedIn => attendanceStatus == AttendanceStatus.checkedIn;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'attendance_status': _attendanceStatusToJson(attendanceStatus),
      'cover_status': _coverStatusToJson(coverStatus),
      'cover_amount_cents': coverAmountCents,
      'is_comped': isComped,
      'has_scored_play': hasScoredPlay,
      'note': note,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'row_version': rowVersion,
    };
  }
}

@immutable
class GuestDetailRecord {
  const GuestDetailRecord({
    required this.guest,
    this.coverEntries = const [],
    this.activeTagAssignment,
  });

  final EventGuestRecord guest;
  final List<GuestCoverEntryRecord> coverEntries;
  final GuestTagAssignmentSummary? activeTagAssignment;

  bool get hasAssignedPlayerTag => activeTagAssignment?.isActive ?? false;
}

@immutable
class GuestCoverEntryRecord {
  const GuestCoverEntryRecord({
    required this.id,
    required this.eventId,
    required this.eventGuestId,
    required this.amountCents,
    required this.method,
    required this.recordedByUserId,
    required this.recordedAt,
    this.note,
    this.createdAt,
  });

  factory GuestCoverEntryRecord.fromJson(Map<String, dynamic> json) {
    return GuestCoverEntryRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      amountCents: _requiredInt(json, 'amount_cents'),
      method: _coverEntryMethodFromJson(_requiredString(json, 'method')),
      recordedByUserId: _requiredString(json, 'recorded_by_user_id'),
      recordedAt: _requiredDateTime(json, 'recorded_at'),
      note: _optionalString(json, 'note'),
      createdAt: _optionalDateTime(json, 'created_at'),
    );
  }

  final String id;
  final String eventId;
  final String eventGuestId;
  final int amountCents;
  final CoverEntryMethod method;
  final String recordedByUserId;
  final DateTime recordedAt;
  final String? note;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_guest_id': eventGuestId,
      'amount_cents': amountCents,
      'method': _coverEntryMethodToJson(method),
      'recorded_by_user_id': recordedByUserId,
      'recorded_at': recordedAt.toIso8601String(),
      'note': note,
      'created_at': createdAt?.toIso8601String(),
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

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _optionalDateTime(json, key);
  if (value != null) {
    return value;
  }

  throw FormatException('Expected ISO-8601 string for $key.');
}

AttendanceStatus _attendanceStatusFromJson(String value) {
  return switch (value) {
    'expected' => AttendanceStatus.expected,
    'checked_in' => AttendanceStatus.checkedIn,
    'checked_out' => AttendanceStatus.checkedOut,
    'no_show' => AttendanceStatus.noShow,
    _ => throw FormatException('Unknown attendance status: $value'),
  };
}

String _attendanceStatusToJson(AttendanceStatus value) {
  return switch (value) {
    AttendanceStatus.expected => 'expected',
    AttendanceStatus.checkedIn => 'checked_in',
    AttendanceStatus.checkedOut => 'checked_out',
    AttendanceStatus.noShow => 'no_show',
  };
}

CoverStatus _coverStatusFromJson(String value) {
  return switch (value) {
    'unpaid' => CoverStatus.unpaid,
    'paid' => CoverStatus.paid,
    'partial' => CoverStatus.partial,
    'comped' => CoverStatus.comped,
    'refunded' => CoverStatus.refunded,
    _ => throw FormatException('Unknown cover status: $value'),
  };
}

String _coverStatusToJson(CoverStatus value) {
  return switch (value) {
    CoverStatus.unpaid => 'unpaid',
    CoverStatus.paid => 'paid',
    CoverStatus.partial => 'partial',
    CoverStatus.comped => 'comped',
    CoverStatus.refunded => 'refunded',
  };
}

CoverEntryMethod _coverEntryMethodFromJson(String value) {
  return switch (value) {
    'cash' => CoverEntryMethod.cash,
    'venmo' => CoverEntryMethod.venmo,
    'zelle' => CoverEntryMethod.zelle,
    'other' => CoverEntryMethod.other,
    'comp' => CoverEntryMethod.comp,
    'refund' => CoverEntryMethod.refund,
    _ => throw FormatException('Unknown cover entry method: $value'),
  };
}

String _coverEntryMethodToJson(CoverEntryMethod value) {
  return switch (value) {
    CoverEntryMethod.cash => 'cash',
    CoverEntryMethod.venmo => 'venmo',
    CoverEntryMethod.zelle => 'zelle',
    CoverEntryMethod.other => 'other',
    CoverEntryMethod.comp => 'comp',
    CoverEntryMethod.refund => 'refund',
  };
}
