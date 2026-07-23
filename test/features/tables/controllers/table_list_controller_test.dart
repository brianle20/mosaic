import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/repositories/supabase_finals_repository.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';

class _FakeTableRepository extends ThrowingTableRepository {
  _FakeTableRepository({
    required this.cachedTables,
    this.tableLoader,
  });

  final List<EventTableRecord> cachedTables;
  final Future<List<EventTableRecord>> Function(String eventId)? tableLoader;
  Object? remoteError;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    final loader = tableLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return [...cachedTables];
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      [...cachedTables];

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository extends ThrowingSessionRepository {
  _FakeSessionRepository({
    required this.cachedSessions,
    this.cachedDetails = const {},
    this.loadedDetails = const {},
    this.sessionsAfterBulkStart = const [],
    this.detailLoader,
    this.sessionLoader,
  });

  List<TableSessionRecord> cachedSessions;
  final Map<String, SessionDetailRecord> cachedDetails;
  final Map<String, SessionDetailRecord> loadedDetails;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  final Future<SessionDetailRecord> Function(String sessionId)? detailLoader;
  final Future<List<TableSessionRecord>> Function(String eventId)?
      sessionLoader;
  Object? remoteError;
  int bulkStartCallCount = 0;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    final loader = sessionLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return [...cachedSessions];
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    final loader = detailLoader;
    if (loader != null) {
      return loader(sessionId);
    }
    return loadedDetails[sessionId] ?? cachedDetails[sessionId]!;
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
    String sessionId,
  ) async =>
      cachedDetails[sessionId];

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      [...cachedSessions];

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    bulkStartCallCount += 1;
    cachedSessions = sessionsAfterBulkStart;
    return sessionsAfterBulkStart;
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository(this.guests);

  final List<EventGuestRecord> guests;
  Object? remoteError;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    return [...guests];
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      [...guests];

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.summary,
    this.bonusRoundState,
    this.assignments = const [],
  });

  TournamentRoundSummary? summary;
  BonusRoundState? bonusRoundState;
  List<SeatingAssignmentRecord> assignments;
  Object? remoteError;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      [...assignments];

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    return [...assignments];
  }

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      summary ?? TournamentRoundSummary.empty();

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    return summary ?? TournamentRoundSummary.empty();
  }

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async {
    if (remoteError != null) {
      throw remoteError!;
    }
    return bonusRoundState;
  }

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> startTableOfChampionsPlayIn({
    required String eventId,
    required String tableId,
  }) async =>
      const [];
}

class _FakeFinalsRepository extends ThrowingFinalsRepository {
  _FakeFinalsRepository(this.state);

  FinalsState state;
  Object? loadError;
  Object? actionError;
  Completer<FinalsState>? actionCompleter;
  int loadCount = 0;
  int resumeCount = 0;
  int startContestCount = 0;
  ResumeFinalsStartInput? lastResumeInput;
  StartFinalsContestInput? lastContestInput;

  @override
  Future<FinalsState> loadFinalsState(String eventId) async {
    loadCount += 1;
    if (loadError case final error?) throw error;
    return state;
  }

  @override
  Future<FinalsState> resumeFinalsStart(ResumeFinalsStartInput input) async {
    resumeCount += 1;
    lastResumeInput = input;
    if (actionError case final error?) throw error;
    return actionCompleter == null ? state : actionCompleter!.future;
  }

  @override
  Future<FinalsState> startContest(StartFinalsContestInput input) async {
    startContestCount += 1;
    lastContestInput = input;
    if (actionError case final error?) throw error;
    return actionCompleter == null ? state : actionCompleter!.future;
  }
}

FinalsState _sqlShapedRecoveryState() => FinalsState.fromJson(const {
      'flow_version': 'legacy',
      'state_version': 0,
      'format': 'parallel_finals',
      'overall_status': 'recoverable_missing_sessions',
      'eligible_player_count': 8,
      'champions_slots': [],
      'contests': [],
      'allowed_actions': [
        {
          'action': 'start_finals_tables',
          'label': 'Start Finals Tables',
          'recovery_token': 'recovery-token-from-sql',
        },
      ],
      'blocking_reason': null,
      'recovery_token': 'recovery-token-from-sql',
      'champion': null,
      'redemption_winner': null,
      'sessions': [],
    });

void main() {
  group('authoritative Finals orchestration', () {
    test('SQL-shaped recovery action dispatches from Tables without inference',
        () async {
      final state = _sqlShapedRecoveryState();
      final repository = _FakeFinalsRepository(state);
      final controller = _finalsController(repository);
      await controller.load('evt_01');

      await controller.executeFinalsAction(state.primaryAction!);

      expect(repository.resumeCount, 1);
      expect(
          repository.lastResumeInput?.recoveryToken, 'recovery-token-from-sql');
    });

    test('loads the exact legacy recovery action and summary', () async {
      final finalsRepository = _FakeFinalsRepository(
        _finalsState(
          status: FinalsOverallStatus.recoverableMissingSessions,
          recoveryToken: 'recovery-token',
          actions: const [
            FinalsAction(
              kind: FinalsActionKind.startFinalsTables,
              label: 'Start Finals Tables',
              recoveryToken: 'recovery-token',
            ),
          ],
          contests: [
            _contest(
              id: 'redemption',
              title: 'Table of Redemption',
              status: FinalsContestStatus.ready,
              tableLabel: 'Table 2',
            ),
            _contest(
              id: 'champions',
              title: 'Table of Champions',
              status: FinalsContestStatus.ready,
              tableLabel: 'Table 1',
            ),
          ],
        ),
      );
      final controller = _finalsController(finalsRepository);

      await controller.load('evt_01');

      expect(controller.finalsState, same(finalsRepository.state));
      expect(controller.primaryFinalsAction?.label, 'Start Finals Tables');
      expect(controller.finalsSummary?.notStartedCount, 2);
      expect(controller.canStartAllTables, isFalse);
    });

    test('loads partial and blocked legacy state without inference', () async {
      final finalsRepository = _FakeFinalsRepository(
        _finalsState(
          status: FinalsOverallStatus.recoverableMissingSessions,
          recoveryToken: 'partial-token',
          actions: const [
            FinalsAction(
              kind: FinalsActionKind.resumeFinalsStart,
              label: 'Resume Finals Start',
              recoveryToken: 'partial-token',
            ),
          ],
        ),
      );
      final controller = _finalsController(finalsRepository);
      await controller.load('evt_01');
      expect(controller.primaryFinalsAction?.label, 'Resume Finals Start');

      finalsRepository.state = _finalsState(
        status: FinalsOverallStatus.blockedLegacyState,
        blockingReason: 'Finals seating is incomplete.',
      );
      await controller.load('evt_01', silent: true);
      expect(controller.primaryFinalsAction, isNull);
      expect(controller.finalsSummary?.blockingReason,
          'Finals seating is incomplete.');
    });

    test('exposes ready role actions, active sessions, and completed results',
        () async {
      final readyCases = <(FinalsContestType, String)>[
        (FinalsContestType.tableOfRedemption, 'Start Table of Redemption'),
        (FinalsContestType.tableOfChampions, 'Start Table of Champions'),
        (
          FinalsContestType.championsSuddenDeath,
          'Start Champions Sudden Death'
        ),
      ];
      for (final (type, label) in readyCases) {
        final repository = _FakeFinalsRepository(
          _finalsState(
            actions: [
              FinalsAction(
                kind: FinalsActionKind.startContest,
                label: label,
                contestId: 'contest',
                tableId: 'tbl_01',
                expectedStateVersion: 7,
              ),
            ],
            contests: [
              _contest(
                id: 'contest',
                type: type,
                title: label.substring(6),
                status: FinalsContestStatus.ready,
              ),
            ],
          ),
        );
        final controller = _finalsController(repository);
        await controller.load('evt_01');
        expect(controller.primaryFinalsAction?.label, label);
      }

      final repository = _FakeFinalsRepository(
        _finalsState(
          status: FinalsOverallStatus.complete,
          champion: const FinalsResult(
            eventGuestId: 'guest_01',
            displayName: 'Ava',
          ),
          contests: [
            _contest(
              id: 'complete',
              title: 'Table of Champions',
              status: FinalsContestStatus.complete,
              sessionId: 'session-history',
              completedAt: DateTime.parse('2026-07-11T20:00:00Z'),
            ),
            _contest(
              id: 'active',
              title: 'Table of Redemption',
              status: FinalsContestStatus.active,
              sessionId: 'session-live',
            ),
          ],
        ),
      );
      final controller = _finalsController(repository);
      await controller.load('evt_01');
      expect(controller.finalsSummary?.activeContests.single.sessionId,
          'session-live');
      expect(controller.finalsSummary?.completedContests.single.resultLabel,
          'Champion: Ava');
      expect(controller.primaryFinalsAction, isNull);
    });

    test('duplicate actions share one in-flight request', () async {
      final action = const FinalsAction(
        kind: FinalsActionKind.startFinalsTables,
        label: 'Start Finals Tables',
        recoveryToken: 'recovery-token',
      );
      final repository = _FakeFinalsRepository(
        _finalsState(actions: [action], recoveryToken: 'recovery-token'),
      )..actionCompleter = Completer<FinalsState>();
      final controller = _finalsController(repository);
      await controller.load('evt_01');

      final first = controller.executeFinalsAction(action);
      final second = controller.executeFinalsAction(action);

      expect(identical(first, second), isTrue);
      expect(repository.resumeCount, 1);
      expect(controller.isExecutingFinalsAction, isTrue);
      repository.actionCompleter!.complete(repository.state);
      await first;
      expect(controller.isExecutingFinalsAction, isFalse);
    });

    test('never dispatches an action not returned by the server', () async {
      final serverAction = const FinalsAction(
        kind: FinalsActionKind.startFinalsTables,
        label: 'Start Finals Tables',
        recoveryToken: 'recovery-token',
      );
      final repository = _FakeFinalsRepository(
        _finalsState(
          actions: [serverAction],
          recoveryToken: 'recovery-token',
        ),
      );
      final controller = _finalsController(repository);
      await controller.load('evt_01');

      final result = await controller.executeFinalsAction(
        FinalsAction(
          kind: FinalsActionKind.startFinalsTables,
          label: 'Start Finals Tables',
          recoveryToken: 'recovery-token',
        ),
      );

      expect(result, same(repository.state));
      expect(repository.resumeCount, 0);
    });

    test('action and silent refresh errors preserve usable Finals state',
        () async {
      final action = const FinalsAction(
        kind: FinalsActionKind.startFinalsTables,
        label: 'Start Finals Tables',
        recoveryToken: 'recovery-token',
      );
      final initial = _finalsState(
        actions: [action],
        recoveryToken: 'recovery-token',
      );
      final repository = _FakeFinalsRepository(initial);
      final controller = _finalsController(repository);
      await controller.load('evt_01');

      repository.loadError = StateError('offline');
      await controller.load('evt_01', silent: true);
      expect(controller.finalsState, same(initial));
      expect(controller.error, isNull);

      repository.loadError = null;
      repository.actionError =
          const FinalsCommandException('Finals seating is incomplete.');
      expect(await controller.executeFinalsAction(action), isNull);
      expect(controller.finalsState, same(initial));
      expect(controller.primaryFinalsAction, same(action));
      expect(controller.finalsActionError, 'Finals seating is incomplete.');
    });

    test('initial Finals read failure never falls back to inferred assignments',
        () async {
      final table = _tableRecord('tbl_01', 'Table 1');
      final repository = _FakeFinalsRepository(_finalsState())
        ..loadError = StateError('offline');
      final controller = TableListController(
        tableRepository: _FakeTableRepository(cachedTables: [table]),
        sessionRepository: _FakeSessionRepository(cachedSessions: const []),
        guestRepository: _FakeGuestRepository(const []),
        seatingRepository: _FakeSeatingRepository(
          assignments: [
            _bonusAssignment(
              table: table,
              seatIndex: 0,
              displayName: 'Ava',
              seedRank: 1,
            ),
            _bonusAssignment(
              table: table,
              seatIndex: 1,
              displayName: 'Ben',
              seedRank: 2,
            ),
          ],
        ),
        finalsRepository: repository,
        scoringPhase: EventScoringPhase.bonus,
      );

      await controller.load('evt_01');

      expect(controller.finalsState, isNull);
      expect(controller.finalsSummary, isNull);
      expect(controller.tournamentRoundSummary.hasCurrentRound, isFalse);
      expect(controller.currentRoundCards, isEmpty);
      expect(controller.error, 'offline');
    });

    test('six-player Redemption result includes the advancing runner-up',
        () async {
      final repository = _FakeFinalsRepository(
        _finalsState(
          status: FinalsOverallStatus.active,
          eligiblePlayerCount: 6,
          format: FinalsFormat.redemptionAdvancement,
          redemptionWinner: const FinalsResult(
            eventGuestId: 'guest_01',
            displayName: 'Ava',
          ),
          contests: [
            _contest(
              id: 'redemption',
              type: FinalsContestType.tableOfRedemption,
              title: 'Table of Redemption',
              status: FinalsContestStatus.complete,
              participants: const [
                FinalsParticipant(
                  eventGuestId: 'guest_01',
                  displayName: 'Ava',
                  entrySeed: 3,
                  seatIndex: 0,
                  outcome: FinalsParticipantOutcome.winner,
                  advancedChampionsSlot: 3,
                  outcomeOrder: 1,
                ),
                FinalsParticipant(
                  eventGuestId: 'guest_02',
                  displayName: 'Ben',
                  entrySeed: 4,
                  seatIndex: 1,
                  outcome: FinalsParticipantOutcome.runnerUp,
                  advancedChampionsSlot: 4,
                  outcomeOrder: 2,
                ),
              ],
            ),
          ],
        ),
      );
      final controller = _finalsController(repository);

      await controller.load('evt_01');

      expect(
        controller.finalsSummary?.completedContests.single.resultLabel,
        'Redemption winner: Ava • Runner-up: Ben',
      );
    });

    test('standalone Redemption tie labels every winner', () async {
      final repository = _FakeFinalsRepository(
        _finalsState(
          status: FinalsOverallStatus.complete,
          contests: [
            _contest(
              id: 'redemption',
              type: FinalsContestType.tableOfRedemption,
              title: 'Table of Redemption',
              status: FinalsContestStatus.complete,
              participants: const [
                FinalsParticipant(
                  eventGuestId: 'guest_01',
                  displayName: 'Ava',
                  entrySeed: 5,
                  seatIndex: 0,
                  outcome: FinalsParticipantOutcome.winner,
                  advancedChampionsSlot: null,
                  outcomeOrder: 1,
                ),
                FinalsParticipant(
                  eventGuestId: 'guest_02',
                  displayName: 'Ben',
                  entrySeed: 6,
                  seatIndex: 1,
                  outcome: FinalsParticipantOutcome.winner,
                  advancedChampionsSlot: null,
                  outcomeOrder: 1,
                ),
              ],
            ),
          ],
        ),
      );
      final controller = _finalsController(repository);

      await controller.load('evt_01');

      expect(
        controller.finalsSummary?.completedContests.single.resultLabel,
        'Redemption winners: Ava, Ben',
      );
    });

    test('rebinds a ready contest only to a filtered usable table', () async {
      final action = const FinalsAction(
        kind: FinalsActionKind.startContest,
        label: 'Start Table of Champions',
        contestId: 'contest',
        availableTableIds: ['tbl_ready'],
        expectedStateVersion: 7,
      );
      final repository = _FakeFinalsRepository(
        _finalsState(
          actions: [action],
          contests: [
            _contest(
              id: 'contest',
              title: 'Table of Champions',
              status: FinalsContestStatus.ready,
            ),
          ],
        ),
      );
      final busySession = _session(
        id: 'busy',
        tableId: 'tbl_busy',
        scoringPhase: EventScoringPhase.bonus,
      );
      final controller = TableListController(
        tableRepository: _FakeTableRepository(cachedTables: [
          _tableRecord('tbl_busy', 'Busy Table'),
          _tableRecord('tbl_ready', 'Garden Table'),
          _tableRecord('tbl_not_authorized', 'Retired Table'),
        ]),
        sessionRepository: _FakeSessionRepository(
          cachedSessions: [busySession],
          cachedDetails: {
            'busy': _detail(busySession),
          },
          loadedDetails: {
            'busy': _detail(busySession),
          },
        ),
        guestRepository: _FakeGuestRepository(const []),
        finalsRepository: repository,
        scoringPhase: EventScoringPhase.bonus,
      );
      await controller.load('evt_01');

      expect(
        controller.usableTablesForFinalsAction(action).map((table) => table.id),
        ['tbl_ready'],
      );
      await controller.executeFinalsAction(action, tableId: 'tbl_ready');
      expect(repository.lastContestInput?.tableId, 'tbl_ready');
    });

    test('participant conflict removes every table picker candidate', () async {
      const action = FinalsAction(
        kind: FinalsActionKind.startContest,
        label: 'Start Table of Champions',
        contestId: 'contest',
        expectedStateVersion: 7,
      );
      final repository = _FakeFinalsRepository(
        _finalsState(
          actions: const [action],
          contests: [
            _contest(
              id: 'contest',
              title: 'Table of Champions',
              status: FinalsContestStatus.ready,
              participants: const [
                FinalsParticipant(
                  eventGuestId: 'guest_conflict',
                  displayName: 'Ava',
                  entrySeed: 1,
                  seatIndex: null,
                  outcome: FinalsParticipantOutcome.pending,
                  advancedChampionsSlot: null,
                  outcomeOrder: null,
                ),
              ],
            ),
          ],
        ),
      );
      final activeSession = _session(
        id: 'active-conflict',
        tableId: 'tbl_active',
        scoringPhase: EventScoringPhase.bonus,
      );
      final conflictDetail = SessionDetailRecord(
        session: activeSession,
        seats: [_seat(0, 'guest_conflict')],
        hands: const [],
        settlements: const [],
      );
      final controller = TableListController(
        tableRepository: _FakeTableRepository(cachedTables: [
          _tableRecord('tbl_active', 'Active Table'),
          _tableRecord('tbl_ready', 'Garden Table'),
        ]),
        sessionRepository: _FakeSessionRepository(
          cachedSessions: [activeSession],
          cachedDetails: {'active-conflict': conflictDetail},
          loadedDetails: {'active-conflict': conflictDetail},
        ),
        guestRepository: _FakeGuestRepository(const []),
        finalsRepository: repository,
        scoringPhase: EventScoringPhase.bonus,
      );
      await controller.load('evt_01');

      expect(controller.usableTablesForFinalsAction(action), isEmpty);
    });
  });

  test('silent recovery preserves populated table state when cache is empty',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: table.id,
      scoringPhase: EventScoringPhase.tournament,
    );
    final detail = _detail(session);
    final summary = _roundSummary(
      status: TournamentRoundStatus.active,
      active: 1,
      currentTables: [
        const TournamentRoundTableSummary(
          eventTableId: 'tbl_01',
          tableLabel: 'Table 1',
          tableDisplayOrder: 1,
          status: TournamentRoundTableStatus.active,
          assignedPlayers: [],
          activeSessionId: 'ses_01',
        ),
      ],
    );
    final tableRepository = _FakeTableRepository(cachedTables: [table]);
    final sessionRepository = _FakeSessionRepository(
      cachedSessions: [session],
      cachedDetails: {'ses_01': detail},
      loadedDetails: {'ses_01': detail},
    );
    final guestRepository = _FakeGuestRepository([
      _guest('guest_01', 'Cached player'),
    ]);
    final seatingRepository = _FakeSeatingRepository(summary: summary);
    final controller = TableListController(
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      guestRepository: guestRepository,
      seatingRepository: seatingRepository,
    );

    await controller.load('evt_01');
    expect(controller.tables.single.id, table.id);
    expect(controller.activeSessionsByTableId.keys.single, table.id);
    expect(controller.guestNamesById['guest_01'], 'Cached player');
    expect(controller.tournamentRoundSummary.hasCurrentRound, isTrue);
    expect(controller.sessionDetailsBySessionId['ses_01'], detail);

    tableRepository.cachedTables.clear();
    tableRepository.remoteError = StateError('offline');
    sessionRepository.cachedSessions.clear();
    sessionRepository.remoteError = StateError('offline');
    guestRepository.guests.clear();
    guestRepository.remoteError = StateError('offline');
    seatingRepository.summary = null;
    seatingRepository.remoteError = StateError('offline');

    await controller.load('evt_01', silent: true);

    expect(controller.tables.single.id, table.id);
    expect(controller.activeSessionsByTableId.keys.single, table.id);
    expect(controller.guestNamesById['guest_01'], 'Cached player');
    expect(controller.tournamentRoundSummary.hasCurrentRound, isTrue);
    expect(controller.sessionDetailsBySessionId['ses_01'], detail);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('silent recovery preserves populated bonus state when cache is empty',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_sudden',
      'event_id': 'evt_01',
      'label': 'Table 9',
      'display_order': 9,
      'nfc_tag_id': 'tag_09',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final assignment = _bonusAssignment(
      table: table,
      seatIndex: 0,
      displayName: 'Alice Chen',
      seedRank: 1,
      role: BonusTableRole.tableOfChampionsSuddenDeath,
    );
    final seatingRepository = _FakeSeatingRepository(
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        suddenDeathStatus: 'required',
        suddenDeathTableId: 'tbl_sudden',
        tiedTopPlayers: [
          BonusRoundTiedPlayer(
            eventGuestId: 'guest_01',
            displayName: 'Alice Chen',
            seedRank: 1,
          ),
        ],
      ),
      assignments: [assignment],
    );
    final tableRepository = _FakeTableRepository(cachedTables: [table]);
    final sessionRepository = _FakeSessionRepository(
      cachedSessions: <TableSessionRecord>[],
    );
    final guestRepository = _FakeGuestRepository(const []);
    final controller = TableListController(
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      guestRepository: guestRepository,
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    await controller.load('evt_01');
    expect(controller.isSuddenDeathRequired, isTrue);
    expect(controller.bonusAssignments, [assignment]);

    tableRepository.cachedTables.clear();
    tableRepository.remoteError = StateError('offline');
    sessionRepository.cachedSessions.clear();
    sessionRepository.remoteError = StateError('offline');
    seatingRepository.assignments.clear();
    seatingRepository.summary = null;
    seatingRepository.remoteError = StateError('offline');

    await controller.load('evt_01', silent: true);

    expect(controller.tables.single.id, table.id);
    expect(controller.bonusAssignments, [assignment]);
    expect(controller.isSuddenDeathRequired, isTrue);
    expect(controller.currentRoundCards.single.table.id, table.id);
    expect(controller.error, isNull);
  });

  test('silent recovery clears stale table state after remote empty success',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: table.id,
      scoringPhase: EventScoringPhase.tournament,
    );
    final tableRepository = _FakeTableRepository(cachedTables: [table]);
    final sessionRepository = _FakeSessionRepository(
      cachedSessions: [session],
      cachedDetails: {'ses_01': _detail(session)},
      loadedDetails: {'ses_01': _detail(session)},
    );
    final guestRepository = _FakeGuestRepository([
      _guest('guest_01', 'Player'),
    ]);
    final seatingRepository = _FakeSeatingRepository(
      summary: _roundSummary(
        status: TournamentRoundStatus.active,
        active: 1,
        currentTables: [
          const TournamentRoundTableSummary(
            eventTableId: 'tbl_01',
            tableLabel: 'Table 1',
            tableDisplayOrder: 1,
            status: TournamentRoundTableStatus.active,
            assignedPlayers: [],
            activeSessionId: 'ses_01',
          ),
        ],
      ),
    );
    final controller = TableListController(
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      guestRepository: guestRepository,
      seatingRepository: seatingRepository,
    );

    await controller.load('evt_01');
    tableRepository.cachedTables.clear();
    sessionRepository.cachedSessions.clear();
    guestRepository.guests.clear();
    seatingRepository.summary = null;

    await controller.load('evt_01', silent: true);

    expect(controller.tables, isEmpty);
    expect(controller.activeSessionsByTableId, isEmpty);
    expect(controller.sessionsByTableId, isEmpty);
    expect(controller.guestNamesById, isEmpty);
    expect(controller.sessionDetailsBySessionId, isEmpty);
    expect(controller.tournamentRoundSummary.hasCurrentRound, isFalse);
    expect(controller.error, isNull);
  });

  test('silent recovery clears stale bonus assignments after remote empty',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final assignment = _bonusAssignment(
      table: table,
      seatIndex: 0,
      displayName: 'Player',
      seedRank: 1,
      role: BonusTableRole.tableOfChampions,
    );
    final tableRepository = _FakeTableRepository(cachedTables: [table]);
    final seatingRepository = _FakeSeatingRepository(
      assignments: [assignment],
    );
    final controller = TableListController(
      tableRepository: tableRepository,
      sessionRepository: _FakeSessionRepository(
        cachedSessions: <TableSessionRecord>[],
      ),
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    await controller.load('evt_01');
    expect(controller.bonusAssignments, [assignment]);

    tableRepository.cachedTables.clear();
    seatingRepository.assignments.clear();

    await controller.load('evt_01', silent: true);

    expect(controller.bonusAssignments, isEmpty);
    expect(controller.tournamentRoundSummary.hasCurrentRound, isFalse);
  });

  test('loads cached tables and active sessions when remote fetches fail',
      () async {
    final cachedTable = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'mode': 'points',
      'display_order': 1,
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
      'status': 'active',
    });
    final cachedSession = TableSessionRecord.fromJson(const {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': 'active',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 0,
      'completed_games_count': 0,
      'hand_count': 0,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    });

    final controller = TableListController(
      tableRepository: _FakeTableRepository(
        cachedTables: [cachedTable],
        tableLoader: (_) async => throw Exception('table fetch failed'),
      ),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [cachedSession],
        sessionLoader: (_) async => throw Exception('session fetch failed'),
      ),
      guestRepository: _FakeGuestRepository(const []),
    );

    await controller.load('evt_01');

    expect(controller.tables.map((table) => table.id), ['tbl_01']);
    expect(controller.activeSessionsByTableId.keys, ['tbl_01']);
    expect(controller.error, isNull);
  });

  test('builds birdseye summaries for active table sessions', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      currentDealerSeatIndex: 2,
      handCount: 3,
    );
    final detail = SessionDetailRecord(
      session: session,
      seats: [
        _seat(0, 'guest_east'),
        _seat(1, 'guest_south'),
        _seat(2, 'guest_west'),
        _seat(3, 'guest_north'),
      ],
      hands: [
        _hand(
          id: 'hand_01',
          handNumber: 1,
          winnerSeatIndex: 0,
          winType: 'discard',
          fanCount: 3,
          eastSeatIndex: 2,
        ),
        _hand(
          id: 'hand_02',
          handNumber: 2,
          winnerSeatIndex: 3,
          winType: 'self_draw',
          fanCount: 4,
          eastSeatIndex: 2,
        ),
        _hand(
          id: 'hand_03',
          handNumber: 3,
          winnerSeatIndex: 1,
          winType: 'self_draw',
          fanCount: 5,
          eastSeatIndex: 2,
        ),
      ],
      settlements: const [],
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    final liveSummary = controller.cards.single.liveSummary!;
    expect(liveSummary.sessionId, 'ses_01');
    expect(liveSummary.status, SessionStatus.active);
    expect(liveSummary.roundWindLabel, 'Round Wind: East');
    expect(liveSummary.dealerLabel, 'Dealer: Chris Lee');
    expect(liveSummary.progressLabel, 'Hand 3');
    expect(liveSummary.lastHand.title, 'Ben Wong self-draw');
    expect(
      liveSummary.lastHand.detail,
      '5 fan recorded. Ready for the next hand.',
    );
    expect(liveSummary.seats.map((seat) => seat.guestName), [
      'Alice Chen',
      'Ben Wong',
      'Chris Lee',
      'Dana Park',
    ]);
    expect(
      liveSummary.seats.singleWhere((seat) => seat.isDealer).windLabel,
      'East',
    );
    expect(liveSummary.seats.map((seat) => seat.windLabel), [
      'West',
      'North',
      'East',
      'South',
    ]);
  });

  test('builds countdown round timer labels for active table cards', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      scoringPhase: EventScoringPhase.tournament,
      startedAt: '2026-05-20T12:10:00Z',
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': _detail(session)},
        loadedDetails: {'ses_01': _detail(session)},
      ),
      guestRepository: _FakeGuestRepository(const []),
      now: () => DateTime.parse('2026-05-20T12:45:00Z'),
    );

    await controller.load('evt_01');

    final summary = controller.cards.single.liveSummary!;
    expect(summary.roundTimeLabel, '25:00');
    expect(summary.isRoundExpired, isFalse);
    expect(summary.isRoundEndingSoon, isFalse);
  });

  test('hides round timer labels for qualification table cards', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      scoringPhase: EventScoringPhase.qualification,
      startedAt: '2026-05-20T12:00:00Z',
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': _detail(session)},
        loadedDetails: {'ses_01': _detail(session)},
      ),
      guestRepository: _FakeGuestRepository(const []),
      now: () => DateTime.parse('2026-05-20T13:01:00Z'),
    );

    await controller.load('evt_01');

    final summary = controller.cards.single.liveSummary!;
    expect(summary.showRoundTimer, isFalse);
    expect(summary.roundTimeLabel, isEmpty);
    expect(summary.isRoundExpired, isFalse);
    expect(summary.isRoundEndingSoon, isFalse);
  });

  test('uses latest recorded hand and ignores voided later hands', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_01', handCount: 3);
    final detail = SessionDetailRecord(
      session: session,
      seats: [
        _seat(0, 'guest_east'),
        _seat(1, 'guest_south'),
        _seat(2, 'guest_west'),
        _seat(3, 'guest_north'),
      ],
      hands: [
        _hand(
          id: 'hand_02',
          handNumber: 2,
          winnerSeatIndex: 1,
          winType: 'discard',
          status: 'recorded',
        ),
        _hand(
          id: 'hand_03',
          handNumber: 3,
          winnerSeatIndex: 2,
          winType: 'self_draw',
          status: 'voided',
        ),
      ],
      settlements: const [],
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    final liveSummary = controller.cards.single.liveSummary!;
    expect(liveSummary.lastHand.title, 'Ben Wong discard');
    expect(liveSummary.progressLabel, 'Hand 1');
  });

  test('summarizes draw dealer rotation on live table cards', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      currentDealerSeatIndex: 1,
      handCount: 1,
    );
    final detail = _detail(
      session,
      hands: [_drawHand(dealerRotated: true)],
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    final liveSummary = controller.cards.single.liveSummary!;
    expect(liveSummary.lastHand.title, 'Draw');
    expect(
        liveSummary.lastHand.detail, 'East rotates. Ready for the next hand.');
  });

  test('summarizes attached false win penalties on live table cards', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_01', handCount: 1);
    final detail = _detail(
      session,
      hands: [
        _hand(
          id: 'hand_01',
          handNumber: 1,
          winnerSeatIndex: 0,
          winType: 'discard',
        ),
      ],
      falseWinPenalties: [
        _falseWinPenalty(
          handResultId: 'hand_01',
          penaltySeatIndex: 1,
          status: 'attached',
        ),
        _falseWinPenalty(
          handResultId: 'hand_01',
          penaltySeatIndex: 2,
          status: 'attached',
        ),
      ],
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    final liveSummary = controller.cards.single.liveSummary!;
    expect(liveSummary.lastHand.title, 'Alice Chen discard');
    expect(
      liveSummary.lastHand.detail,
      '3 fan recorded. Ben Wong false win · Chris Lee false win. '
      'Ready for the next hand.',
    );
  });

  test('uses tournament assignment round for live table round wind', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      scoringPhase: EventScoringPhase.tournament,
      assignmentRound: 4,
    );
    final detail = _detail(session);

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    expect(
      controller.cards.single.liveSummary!.roundWindLabel,
      'Round Wind: North',
    );
  });

  test('summarizes false win penalty on live table cards', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_01', handCount: 1);
    final detail = _detail(
      session,
      hands: [_falseWinPenaltyHand()],
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [session],
        cachedDetails: {'ses_01': detail},
        loadedDetails: {'ses_01': detail},
      ),
      guestRepository: _FakeGuestRepository([
        _guest('guest_east', 'Alice Chen'),
        _guest('guest_south', 'Ben Wong'),
        _guest('guest_west', 'Chris Lee'),
        _guest('guest_north', 'Dana Park'),
      ]),
    );

    await controller.load('evt_01');

    final liveSummary = controller.cards.single.liveSummary!;
    expect(liveSummary.lastHand.title, 'Ben Wong false win penalty');
    expect(
      liveSummary.lastHand.detail,
      '6 fan penalty. East retains. Ready for the next hand.',
    );
  });

  test('keeps table session history sorted newest first', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final oldSession = _session(
      id: 'ses_01',
      tableId: 'tbl_01',
      status: 'completed',
      sessionNumberForTable: 1,
      startedAt: '2026-04-24T18:00:00-07:00',
    );
    final currentSession = _session(
      id: 'ses_02',
      tableId: 'tbl_01',
      sessionNumberForTable: 2,
      startedAt: '2026-04-24T19:00:00-07:00',
    );
    final otherTableSession = _session(
      id: 'ses_03',
      tableId: 'tbl_02',
      sessionNumberForTable: 1,
      startedAt: '2026-04-24T20:00:00-07:00',
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [oldSession, currentSession, otherTableSession],
        cachedDetails: {'ses_02': _detail(currentSession)},
        loadedDetails: {'ses_02': _detail(currentSession)},
      ),
      guestRepository: _FakeGuestRepository(const []),
    );

    await controller.load('evt_01');

    expect(
      controller.sessionsForTable('tbl_01').map((session) => session.id),
      ['ses_02', 'ses_01'],
    );
  });

  test('loads live session details concurrently', () async {
    final firstTable = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final secondTable = EventTableRecord.fromJson(const {
      'id': 'tbl_02',
      'event_id': 'evt_01',
      'label': 'Table 2',
      'display_order': 2,
      'nfc_tag_id': 'tag_02',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final firstSession = _session(id: 'ses_01', tableId: 'tbl_01');
    final secondSession = _session(id: 'ses_02', tableId: 'tbl_02');
    final firstDetail = _detail(firstSession);
    final secondDetail = _detail(secondSession);
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final startedSessionIds = <String>[];

    final controller = TableListController(
      tableRepository: _FakeTableRepository(
        cachedTables: [firstTable, secondTable],
      ),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [firstSession, secondSession],
        detailLoader: (sessionId) async {
          startedSessionIds.add(sessionId);
          if (sessionId == 'ses_01') {
            firstStarted.complete();
            await releaseFirst.future;
            return firstDetail;
          }

          return secondDetail;
        },
      ),
      guestRepository: _FakeGuestRepository(const []),
    );

    final loadFuture = controller.load('evt_01');
    await firstStarted.future;
    await Future<void>.delayed(Duration.zero);

    expect(startedSessionIds, containsAll(['ses_01', 'ses_02']));

    releaseFirst.complete();
    await loadFuture;
    expect(controller.cards.length, 2);
  });

  test('loads bonus round state and exposes required sudden death table',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_sudden',
      'event_id': 'evt_01',
      'label': 'Table 9',
      'display_order': 9,
      'nfc_tag_id': 'tag_09',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final seatingRepository = _FakeSeatingRepository(
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        suddenDeathStatus: 'required',
        suddenDeathTableId: 'tbl_sudden',
        tiedTopPlayers: [
          BonusRoundTiedPlayer(
            eventGuestId: 'guest_01',
            displayName: 'Alice Chen',
            seedRank: 1,
          ),
          BonusRoundTiedPlayer(
            eventGuestId: 'guest_02',
            displayName: 'Ben Wong',
            seedRank: 2,
          ),
        ],
      ),
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(cachedSessions: const []),
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    await controller.load('evt_01');

    expect(controller.bonusRoundState?.suddenDeathStatus, 'required');
    expect(controller.tournamentRoundSummary.hasCurrentRound, isTrue);
    expect(controller.currentRoundCards.single.table.id, 'tbl_sudden');
    expect(
      controller.currentRoundCards.single.assignmentTitle,
      'Table of Champions Sudden Death',
    );
    expect(
      controller.currentRoundCards.single.currentRoundSummary?.assignedPlayers
          .map((player) => player.displayName),
      ['Alice Chen', 'Ben Wong'],
    );
  });

  test('loads bonus round state and exposes required play-in table', () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_play_in',
      'event_id': 'evt_01',
      'label': 'Table 8',
      'display_order': 8,
      'nfc_tag_id': 'tag_08',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final seatingRepository = _FakeSeatingRepository(
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        playInStatus: 'required',
        playInTableId: 'tbl_play_in',
        playInPlayers: [
          BonusRoundPlayInPlayer(
            eventGuestId: 'guest_04',
            displayName: 'Dana Li',
            seedRank: 4,
          ),
          BonusRoundPlayInPlayer(
            eventGuestId: 'guest_05',
            displayName: 'Evan Ng',
            seedRank: 5,
          ),
          BonusRoundPlayInPlayer(
            eventGuestId: 'guest_06',
            displayName: 'Fran Ho',
            seedRank: 6,
          ),
        ],
      ),
    );

    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(cachedSessions: const []),
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    await controller.load('evt_01');

    expect(controller.bonusRoundState?.playInStatus, 'required');
    expect(controller.isPlayInRequired, isTrue);
    expect(controller.tournamentRoundSummary.hasCurrentRound, isTrue);
    expect(controller.currentRoundCards.single.table.id, 'tbl_play_in');
    expect(
      controller.currentRoundCards.single.assignmentTitle,
      'Table of Champions Play-In',
    );
    expect(
      controller.currentRoundCards.single.currentRoundSummary?.assignedPlayers
          .map((player) => player.displayName),
      ['Dana Li', 'Evan Ng', 'Fran Ho'],
    );
  });

  test('starts all seated tournament tables and reloads live sessions',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final startedSession = _session(
      id: 'ses_round_02',
      tableId: 'tbl_01',
      scoringPhase: EventScoringPhase.tournament,
      assignmentRound: 2,
    );
    final sessionRepository = _FakeSessionRepository(
      cachedSessions: const [],
      sessionsAfterBulkStart: [startedSession],
      loadedDetails: {'ses_round_02': _detail(startedSession)},
    );
    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: sessionRepository,
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: _FakeSeatingRepository(
        summary: _roundSummary(
          status: TournamentRoundStatus.seating,
          assigned: 1,
          notStarted: 1,
          currentTables: [
            TournamentRoundTableSummary(
              eventTableId: 'tbl_01',
              tableLabel: 'Table 1',
              tableDisplayOrder: 1,
              status: TournamentRoundTableStatus.notStarted,
              assignedPlayers: const [],
            ),
          ],
        ),
      ),
    );

    await controller.load('evt_01');

    expect(controller.canStartAllTables, isTrue);

    await controller.startAllTables('evt_01');

    expect(sessionRepository.bulkStartCallCount, 1);
    expect(controller.activeSessionsByTableId.keys, ['tbl_01']);
    expect(controller.canStartAllTables, isFalse);
    expect(controller.error, isNull);
  });

  test('active sudden death ignores completed champions session on same table',
      () async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_champions',
      'event_id': 'evt_01',
      'label': 'Table 1A',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final completedChampionsSession = _session(
      id: 'ses_champions',
      tableId: table.id,
      status: 'completed',
      scoringPhase: EventScoringPhase.bonus,
      bonusTableRole: BonusTableRole.tableOfChampions,
    );
    final seatingRepository = _FakeSeatingRepository(
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        suddenDeathStatus: 'active',
        suddenDeathTableId: 'tbl_champions',
      ),
      assignments: [
        _bonusAssignment(
          table: table,
          seatIndex: 0,
          displayName: 'Alice Chen',
          seedRank: 1,
          role: BonusTableRole.tableOfChampionsSuddenDeath,
        ),
        _bonusAssignment(
          table: table,
          seatIndex: 1,
          displayName: 'Ben Wong',
          seedRank: 2,
          role: BonusTableRole.tableOfChampionsSuddenDeath,
        ),
      ],
    );
    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [completedChampionsSession],
      ),
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    await controller.load('evt_01');

    expect(controller.isSuddenDeathActive, isTrue);
    expect(controller.tournamentRoundSummary.completeTableCount, 0);
    expect(controller.tournamentRoundSummary.notStartedTableCount, 1);
    expect(
      controller.currentRoundCards.single.currentRoundSummary?.status,
      TournamentRoundTableStatus.notStarted,
    );
  });
}

TournamentRoundSummary _roundSummary({
  TournamentRoundStatus status = TournamentRoundStatus.active,
  int assigned = 0,
  int complete = 0,
  int active = 0,
  int paused = 0,
  int notStarted = 0,
  List<TournamentRoundTableSummary> currentTables = const [],
}) {
  final assignedCount = assigned == 0 ? currentTables.length : assigned;
  return TournamentRoundSummary(
    round: TournamentRoundRecord(
      id: 'round_02',
      eventId: 'evt_01',
      roundNumber: 2,
      scoringPhase: EventScoringPhase.tournament,
      status: status,
      assignmentRound: 2,
    ),
    assignedTableCount: assignedCount,
    completeTableCount: complete,
    activeTableCount: active,
    pausedTableCount: paused,
    notStartedTableCount: notStarted,
    currentRoundTables: currentTables,
    otherTables: const [],
  );
}

EventGuestRecord _guest(String id, String name) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': name,
    'normalized_name': name.toLowerCase().replaceAll(' ', '_'),
    'attendance_status': 'checked_in',
    'cover_status': 'paid',
    'cover_amount_cents': 3500,
    'is_comped': false,
    'has_scored_play': true,
  });
}

TableSessionRecord _session({
  required String id,
  required String tableId,
  String status = 'active',
  int sessionNumberForTable = 1,
  int currentDealerSeatIndex = 0,
  int handCount = 0,
  EventScoringPhase scoringPhase = EventScoringPhase.qualification,
  BonusTableRole? bonusTableRole,
  int? assignmentRound,
  String startedAt = '2026-04-24T19:00:00-07:00',
}) {
  return TableSessionRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'event_table_id': tableId,
    'session_number_for_table': sessionNumberForTable,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': const {},
    'status': status,
    'scoring_phase': eventScoringPhaseToJson(scoringPhase),
    'bonus_table_role': bonusTableRole == null
        ? null
        : switch (bonusTableRole) {
            BonusTableRole.tableOfChampions => 'table_of_champions',
            BonusTableRole.tableOfRedemption => 'table_of_redemption',
            BonusTableRole.tableOfChampionsSuddenDeath =>
              'table_of_champions_sudden_death',
            BonusTableRole.tableOfChampionsPlayIn =>
              'table_of_champions_play_in',
          },
    'assignment_round': assignmentRound,
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': currentDealerSeatIndex,
    'dealer_pass_count': 0,
    'completed_games_count': 0,
    'hand_count': handCount,
    'started_at': startedAt,
    'started_by_user_id': 'usr_01',
  });
}

TableSessionSeatRecord _seat(int index, String guestId) {
  return TableSessionSeatRecord.fromJson({
    'id': 'seat_$index',
    'table_session_id': 'ses_01',
    'seat_index': index,
    'initial_wind': ['east', 'south', 'west', 'north'][index],
    'event_guest_id': guestId,
  });
}

SessionDetailRecord _detail(
  TableSessionRecord session, {
  List<HandResultRecord> hands = const [],
  List<FalseWinPenaltyRecord> falseWinPenalties = const [],
}) {
  return SessionDetailRecord(
    session: session,
    seats: [
      _seat(0, 'guest_east'),
      _seat(1, 'guest_south'),
      _seat(2, 'guest_west'),
      _seat(3, 'guest_north'),
    ],
    hands: hands,
    settlements: const [],
    falseWinPenalties: falseWinPenalties,
  );
}

HandResultRecord _hand({
  required String id,
  required int handNumber,
  required int winnerSeatIndex,
  required String winType,
  String status = 'recorded',
  int fanCount = 3,
  int eastSeatIndex = 0,
}) {
  return HandResultRecord.fromJson({
    'id': id,
    'table_session_id': 'ses_01',
    'hand_number': handNumber,
    'result_type': 'win',
    'winner_seat_index': winnerSeatIndex,
    'win_type': winType,
    'discarder_seat_index': winType == 'discard' ? 0 : null,
    'fan_count': fanCount,
    'base_points': 32,
    'east_seat_index_before_hand': eastSeatIndex,
    'east_seat_index_after_hand': eastSeatIndex,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': status,
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:30:00-07:00',
  });
}

HandResultRecord _drawHand({required bool dealerRotated}) {
  return HandResultRecord.fromJson({
    'id': 'hand_draw',
    'table_session_id': 'ses_01',
    'hand_number': 1,
    'result_type': 'washout',
    'winner_seat_index': null,
    'win_type': null,
    'discarder_seat_index': null,
    'fan_count': null,
    'base_points': null,
    'dealer_was_waiting_at_draw': false,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': dealerRotated ? 1 : 0,
    'dealer_rotated': dealerRotated,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:30:00-07:00',
  });
}

HandResultRecord _falseWinPenaltyHand() {
  return HandResultRecord.fromJson({
    'id': 'hand_false_win',
    'table_session_id': 'ses_01',
    'hand_number': 1,
    'result_type': 'false_win_penalty',
    'winner_seat_index': null,
    'win_type': null,
    'discarder_seat_index': null,
    'penalty_seat_index': 1,
    'fan_count': 6,
    'base_points': 32,
    'east_seat_index_before_hand': 0,
    'east_seat_index_after_hand': 0,
    'dealer_rotated': false,
    'session_completed_after_hand': false,
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:30:00-07:00',
  });
}

FalseWinPenaltyRecord _falseWinPenalty({
  required String handResultId,
  required int penaltySeatIndex,
  required String status,
}) {
  return FalseWinPenaltyRecord.fromJson({
    'id': 'penalty_${handResultId}_$penaltySeatIndex',
    'table_session_id': 'ses_01',
    'hand_result_id': handResultId,
    'penalty_seat_index': penaltySeatIndex,
    'fan_count': 6,
    'status': status,
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:04:00-07:00',
  });
}

TableListController _finalsController(FinalsRepository finalsRepository) {
  return TableListController(
    tableRepository: _FakeTableRepository(cachedTables: const []),
    sessionRepository: _FakeSessionRepository(cachedSessions: const []),
    guestRepository: _FakeGuestRepository(const []),
    finalsRepository: finalsRepository,
    scoringPhase: EventScoringPhase.bonus,
  );
}

FinalsState _finalsState({
  FinalsOverallStatus status = FinalsOverallStatus.active,
  List<FinalsAction> actions = const [],
  List<FinalsContest> contests = const [],
  String? blockingReason,
  String? recoveryToken,
  FinalsResult? champion,
  FinalsResult? redemptionWinner,
  int eligiblePlayerCount = 8,
  FinalsFormat format = FinalsFormat.parallelFinals,
}) {
  return FinalsState(
    flowVersion: FinalsFlowVersion.orchestrated,
    stateVersion: 7,
    format: format,
    overallStatus: status,
    eligiblePlayerCount: eligiblePlayerCount,
    championsSlots: const [],
    contests: contests,
    allowedActions: actions,
    blockingReason: blockingReason,
    recoveryToken: recoveryToken,
    champion: champion,
    redemptionWinner: redemptionWinner,
    sessions: const [],
  );
}

FinalsContest _contest({
  required String id,
  FinalsContestType type = FinalsContestType.tableOfChampions,
  required String title,
  required FinalsContestStatus status,
  String? tableLabel,
  String? sessionId,
  DateTime? completedAt,
  List<FinalsParticipant> participants = const [],
}) {
  return FinalsContest(
    id: id,
    type: type,
    title: title,
    status: status,
    tableLabel: tableLabel,
    tableSessionId: sessionId,
    slotsToFill: 0,
    slotStartIndex: null,
    sequenceNumber: 1,
    startedAt:
        sessionId == null ? null : DateTime.parse('2026-07-11T19:00:00Z'),
    completedAt: completedAt,
    participants: participants,
  );
}

EventTableRecord _tableRecord(String id, String label) {
  return EventTableRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'label': label,
    'display_order': 1,
    'nfc_tag_id': 'tag_$id',
    'default_ruleset_id': 'HK_STANDARD',
    'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'default_rotation_policy_config_json': const {},
  });
}

SeatingAssignmentRecord _bonusAssignment({
  required EventTableRecord table,
  required int seatIndex,
  required String displayName,
  required int seedRank,
  BonusTableRole role = BonusTableRole.tableOfChampions,
}) {
  return SeatingAssignmentRecord(
    id: 'asg_${table.id}_$seatIndex',
    eventId: 'evt_01',
    eventTableId: table.id,
    tableLabel: table.label,
    eventGuestId: 'guest_$seatIndex',
    displayName: displayName,
    seatIndex: seatIndex,
    assignmentRound: 4,
    status: 'active',
    assignmentType: SeatingAssignmentType.bonus,
    bonusRoundId: 'bonus_01',
    bonusTableRole: role,
    seedRank: seedRank,
  );
}
