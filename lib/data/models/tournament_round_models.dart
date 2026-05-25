import 'package:meta/meta.dart';
import 'package:mosaic/data/models/event_models.dart';

enum TournamentRoundStatus {
  seating,
  active,
  complete,
  cancelled,
}

enum TournamentRoundTableStatus {
  notStarted,
  active,
  paused,
  complete,
  other,
}

@immutable
class TournamentRoundRecord {
  const TournamentRoundRecord({
    required this.id,
    required this.eventId,
    required this.roundNumber,
    required this.scoringPhase,
    required this.status,
    required this.assignmentRound,
    this.startedAt,
    this.completedAt,
  });

  factory TournamentRoundRecord.fromJson(Map<String, dynamic> json) {
    return TournamentRoundRecord(
      id: _requiredString(json, 'id'),
      eventId: _requiredString(json, 'event_id'),
      roundNumber: _requiredInt(json, 'round_number'),
      scoringPhase: eventScoringPhaseFromJson(
        _requiredString(json, 'scoring_phase'),
      ),
      status: _roundStatusFromJson(_requiredString(json, 'status')),
      assignmentRound: _requiredInt(json, 'assignment_round'),
      startedAt: _optionalDateTime(json, 'started_at'),
      completedAt: _optionalDateTime(json, 'completed_at'),
    );
  }

  final String id;
  final String eventId;
  final int roundNumber;
  final EventScoringPhase scoringPhase;
  final TournamentRoundStatus status;
  final int assignmentRound;
  final DateTime? startedAt;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'round_number': roundNumber,
      'scoring_phase': eventScoringPhaseToJson(scoringPhase),
      'status': _roundStatusToJson(status),
      'assignment_round': assignmentRound,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

@immutable
class TournamentRoundAssignedPlayer {
  const TournamentRoundAssignedPlayer({
    required this.eventGuestId,
    required this.displayName,
    required this.seatIndex,
  });

  factory TournamentRoundAssignedPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentRoundAssignedPlayer(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      seatIndex: _requiredInt(json, 'seat_index'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final int seatIndex;

  Map<String, dynamic> toJson() {
    return {
      'event_guest_id': eventGuestId,
      'display_name': displayName,
      'seat_index': seatIndex,
    };
  }
}

@immutable
class TournamentRoundTableSummary {
  const TournamentRoundTableSummary({
    required this.eventTableId,
    required this.tableLabel,
    required this.tableDisplayOrder,
    required this.status,
    required this.assignedPlayers,
    this.activeSessionId,
    this.latestEndedSessionId,
  });

  factory TournamentRoundTableSummary.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['assigned_players'] as List<dynamic>? ?? const [];
    return TournamentRoundTableSummary(
      eventTableId: _requiredString(json, 'event_table_id'),
      tableLabel: _requiredString(json, 'table_label'),
      tableDisplayOrder: _requiredInt(json, 'table_display_order'),
      status: _tableStatusFromJson(_requiredString(json, 'status')),
      assignedPlayers: rawPlayers
          .map(
            (player) => TournamentRoundAssignedPlayer.fromJson(
              (player as Map).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      activeSessionId: _optionalString(json, 'active_session_id'),
      latestEndedSessionId: _optionalString(json, 'latest_ended_session_id'),
    );
  }

  final String eventTableId;
  final String tableLabel;
  final int tableDisplayOrder;
  final TournamentRoundTableStatus status;
  final List<TournamentRoundAssignedPlayer> assignedPlayers;
  final String? activeSessionId;
  final String? latestEndedSessionId;

  Map<String, dynamic> toJson() {
    return {
      'event_table_id': eventTableId,
      'table_label': tableLabel,
      'table_display_order': tableDisplayOrder,
      'status': _tableStatusToJson(status),
      'assigned_players': assignedPlayers
          .map((player) => player.toJson())
          .toList(growable: false),
      'active_session_id': activeSessionId,
      'latest_ended_session_id': latestEndedSessionId,
    };
  }
}

@immutable
class TournamentRoundSummary {
  const TournamentRoundSummary({
    required this.round,
    required this.assignedTableCount,
    required this.completeTableCount,
    required this.activeTableCount,
    required this.pausedTableCount,
    required this.notStartedTableCount,
    required this.currentRoundTables,
    required this.otherTables,
  });

  factory TournamentRoundSummary.empty() {
    return const TournamentRoundSummary(
      round: null,
      assignedTableCount: 0,
      completeTableCount: 0,
      activeTableCount: 0,
      pausedTableCount: 0,
      notStartedTableCount: 0,
      currentRoundTables: [],
      otherTables: [],
    );
  }

  factory TournamentRoundSummary.fromJson(Map<String, dynamic> json) {
    return TournamentRoundSummary(
      round: _optionalRound(json, 'round'),
      assignedTableCount: _requiredInt(json, 'assigned_table_count'),
      completeTableCount: _requiredInt(json, 'complete_table_count'),
      activeTableCount: _requiredInt(json, 'active_table_count'),
      pausedTableCount: _requiredInt(json, 'paused_table_count'),
      notStartedTableCount: _requiredInt(json, 'not_started_table_count'),
      currentRoundTables: _tableSummaries(json, 'current_round_tables'),
      otherTables: _tableSummaries(json, 'other_tables'),
    );
  }

  final TournamentRoundRecord? round;
  final int assignedTableCount;
  final int completeTableCount;
  final int activeTableCount;
  final int pausedTableCount;
  final int notStartedTableCount;
  final List<TournamentRoundTableSummary> currentRoundTables;
  final List<TournamentRoundTableSummary> otherTables;

  bool get hasCurrentRound => round != null;

  bool get isComplete {
    return round?.status == TournamentRoundStatus.complete ||
        (assignedTableCount > 0 && completeTableCount >= assignedTableCount);
  }

  Map<String, dynamic> toJson() {
    return {
      'round': round?.toJson(),
      'assigned_table_count': assignedTableCount,
      'complete_table_count': completeTableCount,
      'active_table_count': activeTableCount,
      'paused_table_count': pausedTableCount,
      'not_started_table_count': notStartedTableCount,
      'current_round_tables': currentRoundTables
          .map((table) => table.toJson())
          .toList(growable: false),
      'other_tables':
          otherTables.map((table) => table.toJson()).toList(growable: false),
    };
  }
}

TournamentRoundRecord? _optionalRound(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }

  return TournamentRoundRecord.fromJson((value as Map).cast<String, dynamic>());
}

List<TournamentRoundTableSummary> _tableSummaries(
  Map<String, dynamic> json,
  String key,
) {
  final rawTables = json[key] as List<dynamic>? ?? const [];
  return rawTables
      .map(
        (table) => TournamentRoundTableSummary.fromJson(
          (table as Map).cast<String, dynamic>(),
        ),
      )
      .toList(growable: false);
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

TournamentRoundStatus _roundStatusFromJson(String value) {
  return switch (value) {
    'seating' => TournamentRoundStatus.seating,
    'active' => TournamentRoundStatus.active,
    'complete' => TournamentRoundStatus.complete,
    'cancelled' => TournamentRoundStatus.cancelled,
    _ => throw FormatException('Unknown tournament round status: $value'),
  };
}

String _roundStatusToJson(TournamentRoundStatus status) {
  return switch (status) {
    TournamentRoundStatus.seating => 'seating',
    TournamentRoundStatus.active => 'active',
    TournamentRoundStatus.complete => 'complete',
    TournamentRoundStatus.cancelled => 'cancelled',
  };
}

TournamentRoundTableStatus _tableStatusFromJson(String value) {
  return switch (value) {
    'not_started' => TournamentRoundTableStatus.notStarted,
    'active' => TournamentRoundTableStatus.active,
    'paused' => TournamentRoundTableStatus.paused,
    'complete' => TournamentRoundTableStatus.complete,
    'other' => TournamentRoundTableStatus.other,
    _ => throw FormatException('Unknown tournament round table status: $value'),
  };
}

String _tableStatusToJson(TournamentRoundTableStatus status) {
  return switch (status) {
    TournamentRoundTableStatus.notStarted => 'not_started',
    TournamentRoundTableStatus.active => 'active',
    TournamentRoundTableStatus.paused => 'paused',
    TournamentRoundTableStatus.complete => 'complete',
    TournamentRoundTableStatus.other => 'other',
  };
}
