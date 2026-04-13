import 'package:meta/meta.dart';

enum EventActivityCategory {
  all,
  guests,
  payments,
  sessions,
  prizes,
  event,
  other,
}

@immutable
class EventActivityEntry {
  const EventActivityEntry({
    required this.id,
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.category,
    required this.summaryText,
    required this.metadataJson,
    required this.createdAt,
    this.reason,
  });

  factory EventActivityEntry.fromJson(Map<String, dynamic> json) {
    return EventActivityEntry(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      entityType: _requiredString(json, 'entity_type'),
      entityId: _requiredString(json, 'entity_id'),
      action: _requiredString(json, 'action'),
      category: _categoryFromJson(_requiredString(json, 'category')),
      summaryText: _requiredString(json, 'summary_text'),
      metadataJson: _jsonMap(json['metadata_json']),
      createdAt: _requiredDateTime(json, 'created_at'),
      reason: _optionalString(json, 'reason'),
    );
  }

  final String id;
  final String eventId;
  final String entityType;
  final String entityId;
  final String action;
  final EventActivityCategory category;
  final String summaryText;
  final Map<String, dynamic> metadataJson;
  final DateTime createdAt;
  final String? reason;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'category': category.name,
      'summary_text': summaryText,
      'metadata_json': metadataJson,
      'created_at': createdAt.toIso8601String(),
      'reason': reason,
    };
  }
}

EventActivityCategory _categoryFromJson(String value) {
  return switch (value) {
    'all' => EventActivityCategory.all,
    'guests' => EventActivityCategory.guests,
    'payments' => EventActivityCategory.payments,
    'sessions' => EventActivityCategory.sessions,
    'prizes' => EventActivityCategory.prizes,
    'event' => EventActivityCategory.event,
    'other' => EventActivityCategory.other,
    _ => throw FormatException('Unknown activity category: $value'),
  };
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
  final value = json[key];
  if (value is String) {
    return DateTime.parse(value);
  }

  throw FormatException('Expected ISO-8601 string for $key.');
}

Map<String, dynamic> _jsonMap(dynamic value) {
  if (value == null) {
    return const {};
  }

  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.cast<String, dynamic>();
  }

  throw FormatException('Expected map for metadata_json.');
}
