import 'package:meta/meta.dart';

enum NfcTagType {
  player,
  table,
  unknown,
}

enum NfcTagStatus {
  active,
  retired,
}

enum GuestTagAssignmentStatus {
  assigned,
  replaced,
  released,
  lost,
}

@immutable
class NfcTagRecord {
  const NfcTagRecord({
    required this.id,
    required this.uidHex,
    required this.uidFingerprint,
    required this.defaultTagType,
    required this.status,
    this.displayLabel,
    this.note,
  });

  factory NfcTagRecord.fromJson(Map<String, dynamic> json) {
    return NfcTagRecord(
      id: _requiredString(json, 'id'),
      uidHex: _requiredString(json, 'uid_hex'),
      uidFingerprint: _requiredString(json, 'uid_fingerprint'),
      defaultTagType:
          _tagTypeFromJson(_requiredString(json, 'default_tag_type')),
      status: _tagStatusFromJson(_requiredString(json, 'status')),
      displayLabel: _optionalString(json, 'display_label'),
      note: _optionalString(json, 'note'),
    );
  }

  final String id;
  final String uidHex;
  final String uidFingerprint;
  final NfcTagType defaultTagType;
  final NfcTagStatus status;
  final String? displayLabel;
  final String? note;
}

@immutable
class GuestTagAssignmentSummary {
  const GuestTagAssignmentSummary({
    required this.assignmentId,
    required this.eventId,
    required this.eventGuestId,
    required this.status,
    required this.assignedAt,
    required this.tag,
  });

  factory GuestTagAssignmentSummary.fromJson(Map<String, dynamic> json) {
    return GuestTagAssignmentSummary(
      assignmentId: _requiredString(json, 'assignment_id'),
      eventId: _requiredString(json, 'event_id'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      status: _assignmentStatusFromJson(_requiredString(json, 'status')),
      assignedAt: DateTime.parse(_requiredString(json, 'assigned_at')),
      tag: NfcTagRecord.fromJson(
        _requiredMap(json, 'nfc_tag'),
      ),
    );
  }

  final String assignmentId;
  final String eventId;
  final String eventGuestId;
  final GuestTagAssignmentStatus status;
  final DateTime assignedAt;
  final NfcTagRecord tag;

  bool get isActive => status == GuestTagAssignmentStatus.assigned;
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

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.cast<String, dynamic>();
  }

  throw FormatException('Expected map for $key.');
}

NfcTagType _tagTypeFromJson(String value) {
  return switch (value) {
    'player' => NfcTagType.player,
    'table' => NfcTagType.table,
    'unknown' => NfcTagType.unknown,
    _ => throw FormatException('Unknown tag type: $value'),
  };
}

NfcTagStatus _tagStatusFromJson(String value) {
  return switch (value) {
    'active' => NfcTagStatus.active,
    'retired' => NfcTagStatus.retired,
    _ => throw FormatException('Unknown tag status: $value'),
  };
}

GuestTagAssignmentStatus _assignmentStatusFromJson(String value) {
  return switch (value) {
    'assigned' => GuestTagAssignmentStatus.assigned,
    'replaced' => GuestTagAssignmentStatus.replaced,
    'released' => GuestTagAssignmentStatus.released,
    'lost' => GuestTagAssignmentStatus.lost,
    _ => throw FormatException('Unknown assignment status: $value'),
  };
}
