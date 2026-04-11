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
