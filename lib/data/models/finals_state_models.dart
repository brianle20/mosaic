import 'package:flutter/foundation.dart';

enum FinalsFlowVersion { legacy, orchestrated }

enum FinalsFormat {
  championsOnly,
  automaticRedemption,
  redemptionAdvancement,
  parallelFinals,
}

enum FinalsOverallStatus {
  notStarted,
  active,
  complete,
  cancelled,
  recoverableMissingSessions,
  blockedLegacyState,
}

enum FinalsContestType {
  directQualificationTiebreak,
  tableOfRedemption,
  redemptionAdvancementTiebreak,
  redemptionWinnerTiebreak,
  tableOfChampions,
  championsSuddenDeath,
}

enum FinalsContestStatus { pending, ready, active, complete, cancelled }

enum FinalsActionKind { startContest, startFinalsTables, resumeFinalsStart }

enum FinalsQualificationMethod { directSeed, redemptionFinish, tiebreakWin }

enum FinalsParticipantOutcome {
  pending,
  advanced,
  winner,
  runnerUp,
  eliminated
}

@immutable
class BeginFinalsInput {
  const BeginFinalsInput({
    required this.eventId,
    required this.championsTableId,
    this.redemptionTableId,
    this.expectedStateVersion,
    required this.expectedPreviewToken,
  });

  final String eventId;
  final String championsTableId;
  final String? redemptionTableId;
  final int? expectedStateVersion;
  final String expectedPreviewToken;
}

@immutable
class StartFinalsContestInput {
  const StartFinalsContestInput({
    required this.contestId,
    this.tableId,
    required this.expectedStateVersion,
  });

  final String contestId;
  final String? tableId;
  final int expectedStateVersion;
}

@immutable
class ResumeFinalsStartInput {
  const ResumeFinalsStartInput({
    required this.eventId,
    required this.recoveryToken,
  });

  final String eventId;
  final String recoveryToken;
}

@immutable
class FinalsSetupPlayer {
  const FinalsSetupPlayer({
    required this.eventGuestId,
    required this.displayName,
    required this.seedRank,
    required this.totalPoints,
  });

  factory FinalsSetupPlayer.fromJson(Map<String, dynamic> json) {
    return FinalsSetupPlayer(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      seedRank: _requiredInt(json, 'seed_rank'),
      totalPoints: _requiredInt(json, 'total_points'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final int seedRank;
  final int totalPoints;
}

@immutable
class FinalsSetupPreview {
  FinalsSetupPreview({
    required this.previewToken,
    required this.eligiblePlayerCount,
    required this.format,
    required this.directSlots,
    required List<FinalsSetupPlayer> redemptionPlayers,
    required List<FinalsSetupPlayer> cutoffTiePlayers,
    required this.requiresChampionsTable,
    required this.requiresRedemptionTable,
    required List<String> availableTableIds,
    required List<String> orderCopy,
  })  : redemptionPlayers = List.unmodifiable(redemptionPlayers),
        cutoffTiePlayers = List.unmodifiable(cutoffTiePlayers),
        availableTableIds = List.unmodifiable(availableTableIds),
        orderCopy = List.unmodifiable(orderCopy);

  factory FinalsSetupPreview.fromJson(Map<String, dynamic> json) {
    return FinalsSetupPreview(
      previewToken: _requiredString(json, 'preview_token'),
      eligiblePlayerCount: _requiredInt(json, 'eligible_player_count'),
      format: _optionalEnum(
        json,
        'format',
        _finalsFormatValues,
      ),
      directSlots: _requiredInt(json, 'direct_slots'),
      redemptionPlayers: _objectList(
        json,
        'redemption_players',
        FinalsSetupPlayer.fromJson,
      ),
      cutoffTiePlayers: _objectList(
        json,
        'cutoff_tie_players',
        FinalsSetupPlayer.fromJson,
      ),
      requiresChampionsTable: _requiredBool(
        json,
        'requires_champions_table',
      ),
      requiresRedemptionTable: _requiredBool(
        json,
        'requires_redemption_table',
      ),
      availableTableIds: _stringList(json, 'available_table_ids'),
      orderCopy: _stringList(json, 'order_copy'),
    );
  }

  final int eligiblePlayerCount;
  final String previewToken;
  final FinalsFormat? format;
  final int directSlots;
  final List<FinalsSetupPlayer> redemptionPlayers;
  final List<FinalsSetupPlayer> cutoffTiePlayers;
  final bool requiresChampionsTable;
  final bool requiresRedemptionTable;
  final List<String> availableTableIds;
  final List<String> orderCopy;
}

@immutable
class FinalsAction {
  const FinalsAction({
    required this.kind,
    required this.label,
    this.contestId,
    this.tableId,
    this.sessionId,
    this.expectedStateVersion,
    this.recoveryToken,
    this.availableTableIds = const [],
  });

  factory FinalsAction.fromJson(Map<String, dynamic> json) {
    return FinalsAction(
      kind: _requiredEnum(json, 'action', _finalsActionKindValues),
      label: _requiredString(json, 'label'),
      contestId: _optionalString(json, 'contest_id'),
      tableId: _optionalString(json, 'table_id'),
      sessionId: _optionalString(json, 'session_id'),
      expectedStateVersion: _optionalInt(json, 'expected_state_version'),
      recoveryToken: _optionalString(json, 'recovery_token'),
      availableTableIds: json.containsKey('available_table_ids')
          ? List.unmodifiable(_stringList(json, 'available_table_ids'))
          : const [],
    );
  }

  final FinalsActionKind kind;
  final String label;
  final String? contestId;
  final String? tableId;
  final String? sessionId;
  final int? expectedStateVersion;
  final String? recoveryToken;
  final List<String> availableTableIds;
}

@immutable
class FinalsParticipant {
  const FinalsParticipant({
    required this.eventGuestId,
    required this.displayName,
    required this.entrySeed,
    required this.seatIndex,
    required this.outcome,
    required this.advancedChampionsSlot,
    required this.outcomeOrder,
  });

  factory FinalsParticipant.fromJson(Map<String, dynamic> json) {
    return FinalsParticipant(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      entrySeed: _requiredInt(json, 'entry_seed'),
      seatIndex: _optionalInt(json, 'seat_index'),
      outcome: _requiredEnum(json, 'outcome', _participantOutcomeValues),
      advancedChampionsSlot: _optionalInt(json, 'advanced_champions_slot'),
      outcomeOrder: _optionalInt(json, 'outcome_order'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final int entrySeed;
  final int? seatIndex;
  final FinalsParticipantOutcome outcome;
  final int? advancedChampionsSlot;
  final int? outcomeOrder;
}

@immutable
class FinalsContest {
  FinalsContest({
    required this.id,
    required this.type,
    required this.title,
    required this.status,
    required this.tableLabel,
    required this.tableSessionId,
    required this.slotsToFill,
    required this.slotStartIndex,
    required this.sequenceNumber,
    required this.startedAt,
    required this.completedAt,
    required List<FinalsParticipant> participants,
  }) : participants = List.unmodifiable(participants);

  factory FinalsContest.fromJson(Map<String, dynamic> json) {
    return FinalsContest(
      id: _requiredString(json, 'id'),
      type: _requiredEnum(json, 'contest_type', _contestTypeValues),
      title: _requiredString(json, 'title'),
      status: _requiredEnum(json, 'status', _contestStatusValues),
      tableLabel: _optionalString(json, 'table_label'),
      tableSessionId: _optionalString(json, 'table_session_id'),
      slotsToFill: _requiredInt(json, 'slots_to_fill'),
      slotStartIndex: _optionalInt(json, 'slot_start_index'),
      sequenceNumber: _requiredInt(json, 'sequence_number'),
      startedAt: _optionalDateTime(json, 'started_at'),
      completedAt: _optionalDateTime(json, 'completed_at'),
      participants: _objectList(
        json,
        'participants',
        FinalsParticipant.fromJson,
      ),
    );
  }

  final String id;
  final FinalsContestType type;
  final String title;
  final FinalsContestStatus status;
  final String? tableLabel;
  final String? tableSessionId;
  final int slotsToFill;
  final int? slotStartIndex;
  final int sequenceNumber;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<FinalsParticipant> participants;
}

@immutable
class FinalsChampionsSlot {
  const FinalsChampionsSlot({
    required this.slotIndex,
    required this.eventGuestId,
    required this.displayName,
    required this.qualificationMethod,
    required this.sourceContestId,
    required this.sourceFinishOrder,
  });

  factory FinalsChampionsSlot.fromJson(Map<String, dynamic> json) {
    return FinalsChampionsSlot(
      slotIndex: _requiredInt(json, 'slot_index'),
      eventGuestId: _optionalString(json, 'event_guest_id'),
      displayName: _optionalString(json, 'display_name'),
      qualificationMethod: _optionalEnum(
        json,
        'qualification_method',
        _qualificationMethodValues,
      ),
      sourceContestId: _optionalString(json, 'source_contest_id'),
      sourceFinishOrder: _optionalInt(json, 'source_finish_order'),
    );
  }

  final int slotIndex;
  final String? eventGuestId;
  final String? displayName;
  final FinalsQualificationMethod? qualificationMethod;
  final String? sourceContestId;
  final int? sourceFinishOrder;
}

@immutable
class FinalsResult {
  const FinalsResult({
    required this.eventGuestId,
    required this.displayName,
    this.resolutionMethod,
  });

  factory FinalsResult.fromJson(Map<String, dynamic> json) {
    return FinalsResult(
      eventGuestId: _requiredString(json, 'event_guest_id'),
      displayName: _requiredString(json, 'display_name'),
      resolutionMethod: _optionalString(json, 'resolution_method'),
    );
  }

  final String eventGuestId;
  final String displayName;
  final String? resolutionMethod;
}

@immutable
class FinalsSessionReference {
  const FinalsSessionReference({
    required this.id,
    required this.bonusTableRole,
    required this.tableLabel,
    required this.status,
    required this.startedAt,
  });

  factory FinalsSessionReference.fromJson(Map<String, dynamic> json) {
    return FinalsSessionReference(
      id: _requiredString(json, 'id'),
      bonusTableRole: _optionalString(json, 'bonus_table_role'),
      tableLabel: _optionalString(json, 'table_label'),
      status: _requiredString(json, 'status'),
      startedAt: _optionalDateTime(json, 'started_at'),
    );
  }

  final String id;
  final String? bonusTableRole;
  final String? tableLabel;
  final String status;
  final DateTime? startedAt;
}

@immutable
class FinalsState {
  FinalsState({
    required this.flowVersion,
    required this.stateVersion,
    required this.format,
    required this.overallStatus,
    required this.eligiblePlayerCount,
    required List<FinalsChampionsSlot> championsSlots,
    required List<FinalsContest> contests,
    required List<FinalsAction> allowedActions,
    required this.blockingReason,
    required this.recoveryToken,
    required this.champion,
    required this.redemptionWinner,
    required List<FinalsSessionReference> sessions,
  })  : championsSlots = List.unmodifiable(championsSlots),
        contests = List.unmodifiable(contests),
        allowedActions = List.unmodifiable(allowedActions),
        sessions = List.unmodifiable(sessions);

  factory FinalsState.fromJson(Map<String, dynamic> json) {
    return FinalsState(
      flowVersion: _optionalEnum(
        json,
        'flow_version',
        _flowVersionValues,
      ),
      stateVersion: _requiredInt(json, 'state_version'),
      format: _optionalEnum(json, 'format', _finalsFormatValues),
      overallStatus: _requiredEnum(
        json,
        'overall_status',
        _overallStatusValues,
      ),
      eligiblePlayerCount: _optionalInt(json, 'eligible_player_count'),
      championsSlots: _objectList(
        json,
        'champions_slots',
        FinalsChampionsSlot.fromJson,
      ),
      contests: _objectList(json, 'contests', FinalsContest.fromJson),
      allowedActions: _objectList(
        json,
        'allowed_actions',
        FinalsAction.fromJson,
      ),
      blockingReason: _optionalString(json, 'blocking_reason'),
      recoveryToken: _optionalString(json, 'recovery_token'),
      champion: _optionalObject(json, 'champion', FinalsResult.fromJson),
      redemptionWinner: _optionalObject(
        json,
        'redemption_winner',
        FinalsResult.fromJson,
      ),
      sessions: json.containsKey('sessions')
          ? _objectList(
              json,
              'sessions',
              FinalsSessionReference.fromJson,
            )
          : const [],
    );
  }

  final FinalsFlowVersion? flowVersion;
  final int stateVersion;
  final FinalsFormat? format;
  final FinalsOverallStatus overallStatus;
  final int? eligiblePlayerCount;
  final List<FinalsChampionsSlot> championsSlots;
  final List<FinalsContest> contests;
  final List<FinalsAction> allowedActions;
  final String? blockingReason;
  final String? recoveryToken;
  final FinalsResult? champion;
  final FinalsResult? redemptionWinner;
  final List<FinalsSessionReference> sessions;

  List<FinalsResult> get redemptionWinners {
    final winningParticipants = [
      for (final contest in contests)
        if (contest.type == FinalsContestType.tableOfRedemption &&
            contest.status == FinalsContestStatus.complete)
          for (final participant in contest.participants)
            if (participant.outcome == FinalsParticipantOutcome.winner)
              participant,
    ];
    final contestWinners = [
      for (final participant in winningParticipants)
        FinalsResult(
          eventGuestId: participant.eventGuestId,
          displayName: participant.displayName,
          resolutionMethod: winningParticipants.length > 1
              ? 'table_score_tie'
              : 'table_score',
        ),
    ];
    if (contestWinners.isNotEmpty) {
      return List.unmodifiable(contestWinners);
    }
    return List.unmodifiable([
      if (redemptionWinner case final winner?) winner,
    ]);
  }

  FinalsAction? get primaryAction =>
      allowedActions.isEmpty ? null : allowedActions.first;

  Set<String> get activeSessionIds => Set.unmodifiable({
        for (final contest in contests)
          if (contest.status == FinalsContestStatus.active)
            if (contest.tableSessionId case final sessionId?) sessionId,
        for (final session in sessions)
          if (session.status == 'active' || session.status == 'paused')
            session.id,
      });
}

const _flowVersionValues = {
  'legacy': FinalsFlowVersion.legacy,
  'orchestrated': FinalsFlowVersion.orchestrated,
};

const _finalsFormatValues = {
  'champions_only': FinalsFormat.championsOnly,
  'automatic_redemption': FinalsFormat.automaticRedemption,
  'redemption_advancement': FinalsFormat.redemptionAdvancement,
  'parallel_finals': FinalsFormat.parallelFinals,
};

const _overallStatusValues = {
  'not_started': FinalsOverallStatus.notStarted,
  'active': FinalsOverallStatus.active,
  'complete': FinalsOverallStatus.complete,
  'cancelled': FinalsOverallStatus.cancelled,
  'recoverable_missing_sessions':
      FinalsOverallStatus.recoverableMissingSessions,
  'blocked_legacy_state': FinalsOverallStatus.blockedLegacyState,
};

const _contestTypeValues = {
  'direct_qualification_tiebreak':
      FinalsContestType.directQualificationTiebreak,
  'table_of_redemption': FinalsContestType.tableOfRedemption,
  'redemption_advancement_tiebreak':
      FinalsContestType.redemptionAdvancementTiebreak,
  'redemption_winner_tiebreak': FinalsContestType.redemptionWinnerTiebreak,
  'table_of_champions': FinalsContestType.tableOfChampions,
  'champions_sudden_death': FinalsContestType.championsSuddenDeath,
};

const _contestStatusValues = {
  'pending': FinalsContestStatus.pending,
  'ready': FinalsContestStatus.ready,
  'active': FinalsContestStatus.active,
  'complete': FinalsContestStatus.complete,
  'cancelled': FinalsContestStatus.cancelled,
};

const _finalsActionKindValues = {
  'start_contest': FinalsActionKind.startContest,
  'start_finals_tables': FinalsActionKind.startFinalsTables,
  'resume_finals_start': FinalsActionKind.resumeFinalsStart,
};

const _qualificationMethodValues = {
  'direct_seed': FinalsQualificationMethod.directSeed,
  'redemption_finish': FinalsQualificationMethod.redemptionFinish,
  'tiebreak_win': FinalsQualificationMethod.tiebreakWin,
};

const _participantOutcomeValues = {
  'pending': FinalsParticipantOutcome.pending,
  'advanced': FinalsParticipantOutcome.advanced,
  'winner': FinalsParticipantOutcome.winner,
  'runner_up': FinalsParticipantOutcome.runnerUp,
  'eliminated': FinalsParticipantOutcome.eliminated,
};

T _requiredEnum<T>(
  Map<String, dynamic> json,
  String key,
  Map<String, T> values,
) {
  final value = _requiredString(json, key);
  final parsed = values[value];
  if (parsed == null) {
    throw FormatException('Unsupported value for $key.');
  }
  return parsed;
}

T? _optionalEnum<T>(
  Map<String, dynamic> json,
  String key,
  Map<String, T> values,
) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final parsed = values[value];
  if (parsed == null) {
    throw FormatException('Unsupported value for $key.');
  }
  return parsed;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) throw FormatException('Expected string for $key.');
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected string or null for $key.');
  }
  return value.trim();
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = _optionalInt(json, key);
  if (value == null) throw FormatException('Expected integer for $key.');
  return value;
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) {
    throw FormatException('Expected integer or null for $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Expected boolean for $key.');
  return value;
}

DateTime? _optionalDateTime(Map<String, dynamic> json, String key) {
  final value = _optionalString(json, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Expected timestamp for $key.');
  return parsed;
}

List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parser,
) {
  final value = json[key];
  if (value is! List) throw FormatException('Expected list for $key.');
  return value.map((entry) {
    if (entry is! Map) {
      throw FormatException('Expected object entries for $key.');
    }
    return parser(entry.cast<String, dynamic>());
  }).toList(growable: false);
}

List<String> _stringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Expected list for $key.');
  return value.map((entry) {
    if (entry is! String || entry.trim().isEmpty) {
      throw FormatException('Expected string entries for $key.');
    }
    return entry.trim();
  }).toList(growable: false);
}

T? _optionalObject<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parser,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('Expected object or null for $key.');
  return parser(value.cast<String, dynamic>());
}
