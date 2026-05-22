import 'package:meta/meta.dart';

@immutable
class SeatingAssignmentRecord {
  const SeatingAssignmentRecord({
    required this.id,
    required this.eventId,
    required this.eventTableId,
    required this.tableLabel,
    required this.eventGuestId,
    required this.displayName,
    required this.seatIndex,
    required this.assignmentRound,
    required this.status,
  });

  factory SeatingAssignmentRecord.fromJson(Map<String, dynamic> json) {
    return SeatingAssignmentRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      eventTableId: _requiredString(json, 'event_table_id'),
      tableLabel: _requiredString(json, 'table_label'),
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredStringFromAny(
        json,
        const ['display_name', 'guest_display_name'],
      ),
      seatIndex: _requiredInt(json, 'seat_index'),
      assignmentRound: _requiredInt(json, 'assignment_round'),
      status: _requiredString(json, 'status'),
    );
  }

  final String id;
  final String eventId;
  final String eventTableId;
  final String tableLabel;
  final String eventGuestId;
  final String displayName;
  final int seatIndex;
  final int assignmentRound;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_table_id': eventTableId,
      'table_label': tableLabel,
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'seat_index': seatIndex,
      'assignment_round': assignmentRound,
      'status': status,
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

String _requiredStringFromAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }

  throw FormatException('Expected non-empty string for one of $keys.');
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
