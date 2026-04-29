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

enum GuestProfileMatchType {
  phone,
  email,
  instagram,
  name,
}

@immutable
class GuestProfileRecord {
  const GuestProfileRecord({
    required this.id,
    required this.ownerUserId,
    required this.displayName,
    required this.normalizedName,
    this.phoneE164,
    this.emailLower,
    this.instagramHandle,
    this.rowVersion = 1,
  });

  factory GuestProfileRecord.fromJson(Map<String, dynamic> json) {
    return GuestProfileRecord(
      id: _requiredString(json, 'id'),
      ownerUserId: _requiredString(json, 'owner_user_id'),
      displayName: _requiredString(json, 'display_name'),
      normalizedName: _requiredString(json, 'normalized_name'),
      phoneE164: _optionalString(json, 'phone_e164'),
      emailLower: _optionalString(json, 'email_lower'),
      instagramHandle: _optionalString(json, 'instagram_handle'),
      rowVersion: _intOrDefault(json, 'row_version', 1),
    );
  }

  final String id;
  final String ownerUserId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
  final int rowVersion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_user_id': ownerUserId,
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'instagram_handle': instagramHandle,
      'row_version': rowVersion,
    };
  }
}

@immutable
class GuestProfileMatch {
  const GuestProfileMatch({
    required this.profile,
    required this.matchType,
  });

  final GuestProfileRecord profile;
  final GuestProfileMatchType matchType;
}

@immutable
class GuestProfileLookupInput {
  const GuestProfileLookupInput({
    required this.normalizedName,
    this.phoneE164,
    this.emailLower,
    this.instagramHandle,
  });

  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
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
    this.instagramHandle,
    this.guestProfileId,
    this.note,
  });

  final String eventId;
  final String displayName;
  final String normalizedName;
  final String? guestProfileId;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final String? note;

  Map<String, dynamic> toInsertJson({String? guestProfileId}) {
    final resolvedGuestProfileId = guestProfileId ?? this.guestProfileId;
    return {
      'event_id': eventId,
      if (resolvedGuestProfileId != null)
        'guest_profile_id': resolvedGuestProfileId,
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
    this.instagramHandle,
    this.note,
  });

  final String id;
  final String eventId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
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
    required this.guestProfileId,
    required this.displayName,
    required this.normalizedName,
    required this.attendanceStatus,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    required this.hasScoredPlay,
    this.phoneE164,
    this.emailLower,
    this.instagramHandle,
    this.note,
    this.checkedInAt,
    this.rowVersion = 1,
  });

  factory EventGuestRecord.fromJson(Map<String, dynamic> json) {
    final profile = _optionalGuestProfile(json);
    return EventGuestRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      guestProfileId: _optionalString(json, 'guest_profile_id') ??
          profile?.id ??
          _requiredString(json, 'id'),
      displayName:
          profile?.displayName ?? _requiredString(json, 'display_name'),
      normalizedName:
          profile?.normalizedName ?? _requiredString(json, 'normalized_name'),
      phoneE164: profile?.phoneE164 ?? _optionalString(json, 'phone_e164'),
      emailLower: profile?.emailLower ?? _optionalString(json, 'email_lower'),
      instagramHandle:
          profile?.instagramHandle ?? _optionalString(json, 'instagram_handle'),
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
  final String guestProfileId;
  final String displayName;
  final String normalizedName;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
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
      'guest_profile_id': guestProfileId,
      'display_name': displayName,
      'normalized_name': normalizedName,
      'phone_e164': phoneE164,
      'email_lower': emailLower,
      'instagram_handle': instagramHandle,
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
    required this.transactionOn,
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
      transactionOn: _coverEntryTransactionDate(json),
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
  final DateTime transactionOn;
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
      'transaction_on': _dateToJson(transactionOn),
      'note': note,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

DateTime _coverEntryTransactionDate(Map<String, dynamic> json) {
  if (json['transaction_on'] != null) {
    return _requiredDate(json, 'transaction_on');
  }

  final recordedAt = _optionalDateTime(json, 'recorded_at');
  if (recordedAt == null) {
    throw const FormatException(
      'Expected transaction_on date or recorded_at timestamp.',
    );
  }

  return DateTime(recordedAt.year, recordedAt.month, recordedAt.day);
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected $key to be a date in yyyy-MM-dd format.');
  }

  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String _dateToJson(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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

GuestProfileRecord? _optionalGuestProfile(Map<String, dynamic> json) {
  final value = json['guest_profile'] ?? json['guest_profiles'];
  if (value == null) {
    return null;
  }

  if (value is Map<String, dynamic>) {
    return GuestProfileRecord.fromJson(value);
  }

  if (value is Map) {
    return GuestProfileRecord.fromJson(value.cast<String, dynamic>());
  }

  throw FormatException('Expected guest profile row or null.');
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
