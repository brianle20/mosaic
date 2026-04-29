import 'package:meta/meta.dart';
import 'package:mosaic/data/models/session_models.dart';

@immutable
class EventTableRecord {
  const EventTableRecord({
    required this.id,
    required this.eventId,
    required this.label,
    required this.displayOrder,
    required this.defaultRulesetId,
    required this.defaultRotationPolicyType,
    required this.defaultRotationPolicyConfig,
    this.nfcTagId,
  });

  factory EventTableRecord.fromJson(Map<String, dynamic> json) {
    return EventTableRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      label: _requiredString(json, 'label'),
      displayOrder: _requiredInt(json, 'display_order'),
      nfcTagId: _optionalString(json, 'nfc_tag_id'),
      defaultRulesetId: _requiredString(json, 'default_ruleset_id'),
      defaultRotationPolicyType: rotationPolicyTypeFromJson(
        _requiredString(json, 'default_rotation_policy_type'),
      ),
      defaultRotationPolicyConfig: _jsonObject(
        json,
        'default_rotation_policy_config_json',
      ),
    );
  }

  final String id;
  final String eventId;
  final String label;
  final int displayOrder;
  final String? nfcTagId;
  final String defaultRulesetId;
  final RotationPolicyType defaultRotationPolicyType;
  final Map<String, dynamic> defaultRotationPolicyConfig;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'label': label,
      'display_order': displayOrder,
      'nfc_tag_id': nfcTagId,
      'default_ruleset_id': defaultRulesetId,
      'default_rotation_policy_type':
          rotationPolicyTypeToJson(defaultRotationPolicyType),
      'default_rotation_policy_config_json': defaultRotationPolicyConfig,
    };
  }
}

@immutable
class CreateEventTableInput {
  const CreateEventTableInput({
    required this.eventId,
    required this.label,
    required this.displayOrder,
    this.defaultRulesetId = 'HK_STANDARD_V1',
    this.defaultRotationPolicyType =
        RotationPolicyType.dealerCycleReturnToInitialEast,
    this.defaultRotationPolicyConfig = const {},
  });

  final String eventId;
  final String label;
  final int displayOrder;
  final String defaultRulesetId;
  final RotationPolicyType defaultRotationPolicyType;
  final Map<String, dynamic> defaultRotationPolicyConfig;

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'label': label.trim(),
      'display_order': displayOrder,
      'default_ruleset_id': defaultRulesetId,
      'default_rotation_policy_type':
          rotationPolicyTypeToJson(defaultRotationPolicyType),
      'default_rotation_policy_config_json': defaultRotationPolicyConfig,
    };
  }
}

@immutable
class UpdateEventTableInput {
  const UpdateEventTableInput({
    required this.id,
    required this.eventId,
    required this.label,
    required this.displayOrder,
  });

  final String id;
  final String eventId;
  final String label;
  final int displayOrder;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'label': label.trim(),
      'display_order': displayOrder,
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

Map<String, dynamic> _jsonObject(Map<String, dynamic> json, String key) {
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
