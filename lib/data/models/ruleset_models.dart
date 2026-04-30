import 'package:meta/meta.dart';

enum RulesetStatus {
  active,
  retired,
}

@immutable
class RulesetRecord {
  const RulesetRecord({
    required this.id,
    required this.name,
    required this.status,
    required this.definitionJson,
  });

  factory RulesetRecord.fromJson(Map<String, dynamic> json) {
    return RulesetRecord(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      status: _rulesetStatusFromJson(_requiredString(json, 'status')),
      definitionJson: _jsonObject(json, 'definition_json'),
    );
  }

  final String id;
  final String name;
  final RulesetStatus status;
  final Map<String, dynamic> definitionJson;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status.name,
      'definition_json': definitionJson,
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

RulesetStatus _rulesetStatusFromJson(String value) {
  return switch (value) {
    'active' => RulesetStatus.active,
    'retired' => RulesetStatus.retired,
    _ => throw FormatException('Unknown ruleset status: $value'),
  };
}
