import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';

class _FakeTableRepository extends ThrowingTableRepository {
  _FakeTableRepository({
    required this.cachedTables,
    this.tableLoader,
  });

  final List<EventTableRecord> cachedTables;
  final Future<List<EventTableRecord>> Function(String eventId)? tableLoader;

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
    final loader = tableLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedTables;
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      cachedTables;

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
    this.detailLoader,
    this.sessionLoader,
  });

  final List<TableSessionRecord> cachedSessions;
  final Map<String, SessionDetailRecord> cachedDetails;
  final Map<String, SessionDetailRecord> loadedDetails;
  final Future<SessionDetailRecord> Function(String sessionId)? detailLoader;
  final Future<List<TableSessionRecord>> Function(String eventId)?
      sessionLoader;

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
    final loader = sessionLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedSessions;
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
      cachedSessions;

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
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

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

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
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

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
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
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

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.bonusRoundState,
    this.suddenDeathAssignments = const [],
  });

  BonusRoundState? bonusRoundState;
  List<SeatingAssignmentRecord> suddenDeathAssignments;
  final startedSuddenDeathTables = <String>[];

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      const [];

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      TournamentRoundSummary.empty();

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async =>
      TournamentRoundSummary.empty();

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async =>
      bonusRoundState;

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) async {
    startedSuddenDeathTables.add(tableId);
    return suddenDeathAssignments;
  }
}

void main() {
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

  test('starts bonus round sudden death through seating repository', () async {
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
      suddenDeathAssignments: [assignment],
    );
    final controller = TableListController(
      tableRepository: _FakeTableRepository(cachedTables: [table]),
      sessionRepository: _FakeSessionRepository(cachedSessions: const []),
      guestRepository: _FakeGuestRepository(const []),
      seatingRepository: seatingRepository,
      scoringPhase: EventScoringPhase.bonus,
    );

    final assignments = await controller.startBonusRoundSuddenDeath(
      eventId: 'evt_01',
      tableId: 'tbl_sudden',
    );

    expect(seatingRepository.startedSuddenDeathTables, ['tbl_sudden']);
    expect(assignments, [assignment]);
    expect(controller.error, isNull);
  });
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
