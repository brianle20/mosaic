import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';
import '../../../helpers/repository_fakes.dart';

class _FakeEventRepository extends ThrowingEventRepository {
  _FakeEventRepository({
    required this.cachedEvents,
    this.eventLoader,
  });

  final List<EventRecord> cachedEvents;
  final Future<EventRecord?> Function(String eventId)? eventLoader;
  Object? remoteError;
  EventRecord Function(String eventId)? cancelHandler;
  EventRecord Function(String eventId)? revertToDraftHandler;
  EventRecord Function(String eventId)? copyForTestingHandler;
  EventRecord Function(String eventId, EventScoringPhase phase)?
      scoringPhaseHandler;
  void Function(String eventId)? deleteHandler;

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) async {
    final handler = cancelHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) async {
    final handler = revertToDraftHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> copyEventForTesting(String eventId) async {
    final handler = copyForTestingHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final handler = deleteHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    handler(eventId);
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async {
    final remoteError = this.remoteError;
    if (remoteError != null) {
      throw remoteError;
    }
    final loader = eventLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedEvents.where((event) => event.id == eventId).firstOrNull;
  }

  @override
  Future<List<EventRecord>> listEvents() {
    throw UnimplementedError();
  }

  @override
  Future<List<EventRecord>> readCachedEvents() async => cachedEvents;

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> updateEventScoringPhase({
    required String eventId,
    required EventScoringPhase phase,
  }) async {
    final handler = scoringPhaseHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId, phase);
  }

  @override
  Future<EventRecord> startEvent(String eventId) {
    throw UnimplementedError();
  }
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository({
    required this.cachedGuests,
    this.guestLoader,
  });

  final List<EventGuestRecord> cachedGuests;
  final Future<List<EventGuestRecord>> Function(String eventId)? guestLoader;
  Object? remoteError;

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final remoteError = this.remoteError;
    if (remoteError != null) {
      throw remoteError;
    }
    final loader = guestLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedGuests;
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      cachedGuests;

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
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

class _FakeLeaderboardRepository extends ThrowingLeaderboardRepository {
  _FakeLeaderboardRepository({
    required this.cachedEntries,
    required this.remoteEntries,
  });

  final List<LeaderboardEntry> cachedEntries;
  final List<LeaderboardEntry> remoteEntries;
  Object? remoteError;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      _loadRemoteLeaderboard();

  Future<List<LeaderboardEntry>> _loadRemoteLeaderboard() async {
    final remoteError = this.remoteError;
    if (remoteError != null) {
      throw remoteError;
    }
    return remoteEntries;
  }

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      cachedEntries;
}

class _FakeSessionRepository extends ThrowingSessionRepository {
  _FakeSessionRepository(this.sessions);

  final List<TableSessionRecord> sessions;
  final List<EventHandLedgerEntry> cachedLedger = [];
  final List<EventHandLedgerEntry> remoteLedger = [];
  Object? ledgerError;
  Object? sessionsError;

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId) async {
    final ledgerError = this.ledgerError;
    if (ledgerError != null) {
      throw ledgerError;
    }
    return remoteLedger;
  }

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      cachedLedger;

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    final sessionsError = this.sessionsError;
    if (sessionsError != null) {
      throw sessionsError;
    }
    return sessions;
  }

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
}

class _FakePrizeRepository extends ThrowingPrizeRepository {
  _FakePrizeRepository({this.cachedPlan, this.remotePlan});

  PrizePlanDetail? cachedPlan;
  PrizePlanDetail? remotePlan;
  Object? remoteError;

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async =>
      cachedPlan;

  @override
  Future<PrizePlanDetail?> loadPrizePlan({required String eventId}) async {
    final error = remoteError;
    if (error != null) {
      throw error;
    }
    return remotePlan;
  }
}

class _FakeTableRepository extends ThrowingTableRepository {
  _FakeTableRepository(this.tables);

  final List<EventTableRecord> tables;
  Object? remoteError;

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    final remoteError = this.remoteError;
    if (remoteError != null) {
      throw remoteError;
    }
    return tables;
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      tables;
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.onGenerate,
    this.onLoadRoundSummary,
    this.cachedRoundSummary,
    this.bonusRoundState,
    this.assignments = const [],
  });

  final Future<List<SeatingAssignmentRecord>> Function(String eventId)?
      onGenerate;
  final Future<TournamentRoundSummary> Function(String eventId)?
      onLoadRoundSummary;
  final TournamentRoundSummary? cachedRoundSummary;
  final BonusRoundState? bonusRoundState;
  final List<SeatingAssignmentRecord> assignments;
  Object? roundError;
  Object? bonusStateError;
  Object? assignmentsError;

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    final handler = onGenerate;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async {
    final roundError = this.roundError;
    if (roundError != null) {
      throw roundError;
    }
    final handler = onLoadRoundSummary;
    if (handler != null) {
      return handler(eventId);
    }
    return cachedRoundSummary ?? TournamentRoundSummary.empty();
  }

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      cachedRoundSummary;

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async {
    final bonusStateError = this.bonusStateError;
    if (bonusStateError != null) {
      throw bonusStateError;
    }
    return bonusRoundState;
  }

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async {
    final assignmentsError = this.assignmentsError;
    if (assignmentsError != null) {
      throw assignmentsError;
    }
    return assignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      assignments;
}

TournamentRoundSummary _roundSummary(int roundNumber) {
  return TournamentRoundSummary(
    round: TournamentRoundRecord(
      id: 'round_$roundNumber',
      eventId: 'evt_01',
      roundNumber: roundNumber,
      scoringPhase: EventScoringPhase.tournament,
      status: TournamentRoundStatus.active,
      assignmentRound: roundNumber,
    ),
    assignedTableCount: 1,
    completeTableCount: 0,
    activeTableCount: 1,
    pausedTableCount: 0,
    notStartedTableCount: 0,
    currentRoundTables: const [],
    otherTables: const [],
  );
}

EventRecord _dashboardEvent({String title = 'Current Event'}) {
  return EventRecord.fromJson({
    'id': 'evt_01',
    'owner_user_id': 'usr_01',
    'title': title,
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'active',
    'checkin_open': true,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
    'current_scoring_phase': 'tournament',
  });
}

EventHandLedgerEntry _championAwardLedgerEntry({
  String displayName = 'Current Champion',
}) {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'ledger_row_type': 'adjustment',
    'adjustment_id': 'adj_current',
    'entered_at': '2026-04-24T20:00:00-07:00',
    'adjustment_type': 'finals_champion_award',
    'adjustment_amount_points': 20,
    'adjustment_event_guest_id': 'gst_01',
    'adjustment_display_name': displayName,
    'status': 'recorded',
    'cells': const [],
  });
}

PrizePlanDetail _prizePlan({required int fixedAmountCents}) {
  return PrizePlanDetail(
    plan: const PrizePlanRecord(
      id: 'pp_01',
      eventId: 'evt_01',
      mode: PrizePlanMode.fixed,
      status: PrizePlanStatus.draft,
      reserveFixedCents: 0,
      reservePercentageBps: 0,
    ),
    tiers: [
      PrizeTierRecord(
        id: 'tier_01',
        prizePlanId: 'pp_01',
        place: 1,
        fixedAmountCents: fixedAmountCents,
      ),
    ],
  );
}

LeaderboardEntry _championLeaderboardEntry() {
  return const LeaderboardEntry(
    eventGuestId: 'gst_01',
    displayName: 'Current Champion',
    totalPoints: 120,
    handsPlayed: 4,
    handsWon: 2,
    selfDrawWins: 1,
    discardWins: 1,
    rank: 1,
  );
}

EventTableRecord _table({
  required String id,
  required String label,
  int displayOrder = 1,
}) {
  return EventTableRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'label': label,
    'display_order': displayOrder,
    'nfc_tag_id': 'tag_$id',
    'default_ruleset_id': 'HK_STANDARD',
    'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'default_rotation_policy_config_json': const {},
  });
}

TableSessionRecord _session({
  required String id,
  required String tableId,
  required String status,
  required BonusTableRole bonusTableRole,
}) {
  return TableSessionRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'event_table_id': tableId,
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': const {},
    'status': status,
    'scoring_phase': 'bonus',
    'bonus_table_role': switch (bonusTableRole) {
      BonusTableRole.tableOfChampions => 'table_of_champions',
      BonusTableRole.tableOfRedemption => 'table_of_redemption',
      BonusTableRole.tableOfChampionsSuddenDeath =>
        'table_of_champions_sudden_death',
      BonusTableRole.tableOfChampionsPlayIn => 'table_of_champions_play_in',
    },
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': 0,
    'dealer_pass_count': 0,
    'completed_games_count': 0,
    'hand_count': 4,
    'started_at': '2026-04-24T19:00:00-07:00',
    'started_by_user_id': 'usr_01',
  });
}

SeatingAssignmentRecord _bonusAssignment({
  required EventTableRecord table,
  required String guestId,
  required String displayName,
  required int seatIndex,
  required BonusTableRole role,
}) {
  return SeatingAssignmentRecord(
    id: 'asg_${table.id}_$seatIndex',
    eventId: 'evt_01',
    eventTableId: table.id,
    tableLabel: table.label,
    eventGuestId: guestId,
    displayName: displayName,
    seatIndex: seatIndex,
    assignmentRound: 4,
    status: 'active',
    assignmentType: SeatingAssignmentType.bonus,
    bonusRoundId: 'bonus_01',
    bonusTableRole: role,
  );
}

EventGuestRecord _eventGuest({
  required String id,
  required String displayName,
  required String attendanceStatus,
  required String tournamentStatus,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': displayName,
    'normalized_name': displayName.toLowerCase(),
    'attendance_status': attendanceStatus,
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': tournamentStatus,
  });
}

void main() {
  test('exposes role capability booleans for event scorers', () {
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: const []),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      callerRole: MosaicAccessRole.eventScorer,
    );

    expect(controller.canManageEvent, isFalse);
    expect(controller.canManageStaff, isFalse);
    expect(controller.canCheckInGuests, isFalse);
    expect(controller.canScoreLegacyQualification, isTrue);
    expect(controller.canScoreTournament, isTrue);
    expect(controller.canScoreBonus, isTrue);
  });

  test('owners can manage and check in guests', () {
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: const []),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      callerRole: MosaicAccessRole.owner,
    );

    expect(controller.canManageEvent, isTrue);
    expect(controller.canManageStaff, isTrue);
    expect(controller.canCheckInGuests, isTrue);
    expect(controller.canScoreTournament, isTrue);
    expect(controller.canScoreBonus, isTrue);
  });

  test('event scorers can score legacy qualification phase rows', () {
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: const []),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      callerRole: MosaicAccessRole.eventScorer,
    );

    expect(controller.canManageEvent, isFalse);
    expect(controller.canManageStaff, isFalse);
    expect(controller.canScoreLegacyQualification, isTrue);
    expect(controller.canScoreTournament, isTrue);
    expect(controller.canScoreBonus, isTrue);
  });

  test('loads cached dashboard data when remote fetches fail', () async {
    final cachedEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final cachedGuest = EventGuestRecord.fromJson(const {
      'id': 'gst_01',
      'event_id': 'evt_01',
      'display_name': 'Alice Wong',
      'normalized_name': 'alice wong',
      'attendance_status': 'expected',
      'cover_status': 'paid',
      'cover_amount_cents': 2000,
      'is_comped': false,
      'has_scored_play': false,
    });

    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [cachedEvent],
        eventLoader: (_) async => throw Exception('event fetch failed'),
      ),
      guestRepository: _FakeGuestRepository(
        cachedGuests: [cachedGuest],
        guestLoader: (_) async => throw Exception('guest fetch failed'),
      ),
    );

    await controller.load('evt_01');

    expect(controller.event?.id, 'evt_01');
    expect(controller.guestCount, 1);
    expect(controller.error, isNull);
  });

  test('silent refresh preserves populated dashboard values on partial failure',
      () async {
    final eventRepository = _FakeEventRepository(
      cachedEvents: [_dashboardEvent()],
      eventLoader: (_) async => _dashboardEvent(),
    );
    final guestRepository = _FakeGuestRepository(
      cachedGuests: [
        _eventGuest(
          id: 'gst_01',
          displayName: 'Current Champion',
          attendanceStatus: 'checked_in',
          tournamentStatus: 'qualified',
        ),
      ],
    );
    final leaderboardRepository = _FakeLeaderboardRepository(
      cachedEntries: [_championLeaderboardEntry()],
      remoteEntries: [_championLeaderboardEntry()],
    );
    final sessionRepository = _FakeSessionRepository(const []);
    sessionRepository.remoteLedger.add(_championAwardLedgerEntry());
    var roundRemoteFails = false;
    final currentRound = _roundSummary(7);
    final seatingRepository = _FakeSeatingRepository(
      cachedRoundSummary: _roundSummary(1),
      onLoadRoundSummary: (_) async {
        if (roundRemoteFails) {
          throw Exception('round fetch failed');
        }
        return currentRound;
      },
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_current',
        eventId: 'evt_01',
        status: 'completed',
        championEventGuestId: 'gst_01',
      ),
    );
    final tableRepository = _FakeTableRepository([]);
    final controller = EventDashboardController(
      eventRepository: eventRepository,
      guestRepository: guestRepository,
      leaderboardRepository: leaderboardRepository,
      tableRepository: tableRepository,
      sessionRepository: sessionRepository,
      seatingRepository: seatingRepository,
    );

    await controller.load('evt_01');
    final currentFinals = _roundSummary(8);
    controller.finalsRoundSummary = currentFinals;
    sessionRepository.cachedLedger.add(
      _championAwardLedgerEntry(displayName: 'Stale Champion'),
    );
    expect(controller.bonusRoundResults.finalChampion?.displayName,
        'Current Champion');

    eventRepository.cachedEvents.clear();
    eventRepository.remoteError = Exception('event fetch failed');
    guestRepository.cachedGuests.clear();
    guestRepository.remoteError = Exception('guest fetch failed');
    tableRepository.tables.clear();
    tableRepository.remoteError = Exception('table fetch failed');
    leaderboardRepository.cachedEntries.clear();
    leaderboardRepository.remoteError = Exception('leaderboard fetch failed');
    sessionRepository.remoteLedger.clear();
    sessionRepository.ledgerError = Exception('ledger fetch failed');
    sessionRepository.sessionsError = Exception('sessions fetch failed');
    seatingRepository.roundError = Exception('round fetch failed');
    seatingRepository.bonusStateError = Exception('bonus state failed');
    seatingRepository.assignmentsError = Exception('assignments failed');
    roundRemoteFails = true;

    await controller.load('evt_01', silent: true);

    expect(controller.tournamentRoundSummary, same(currentRound));
    expect(controller.finalsRoundSummary, same(currentFinals));
    expect(controller.bonusRoundState?.bonusRoundId, 'bonus_current');
    expect(controller.bonusRoundResults.finalChampion?.displayName,
        'Current Champion');
    expect(controller.leaderLabel, 'Current Champion');
    expect(controller.isLoading, isFalse);
  });

  test('stale normal load cannot restore loading after silent recovery',
      () async {
    final initialEventStarted = Completer<void>();
    final staleEvent = _dashboardEvent(title: 'Stale Event');
    final recoveryEvent = _dashboardEvent(title: 'Recovered Event');
    final staleEventResult = Completer<EventRecord?>();
    var eventCallCount = 0;
    final eventRepository = _FakeEventRepository(
      cachedEvents: [staleEvent],
      eventLoader: (_) {
        eventCallCount += 1;
        if (eventCallCount == 1) {
          initialEventStarted.complete();
          return staleEventResult.future;
        }
        return Future<EventRecord?>.value(recoveryEvent);
      },
    );
    final controller = EventDashboardController(
      eventRepository: eventRepository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );

    final initialLoad = controller.load('evt_01');
    await initialEventStarted.future;
    expect(controller.isLoading, isTrue);

    await controller.load('evt_01', silent: true);
    expect(controller.event?.title, 'Recovered Event');
    expect(controller.isLoading, isFalse);

    staleEventResult.complete(null);
    await initialLoad;

    expect(controller.event?.title, 'Recovered Event');
    expect(controller.isLoading, isFalse);
  });

  test('silent refresh clears prize pool when remote has no plan', () async {
    final prizeRepository = _FakePrizeRepository(
      cachedPlan: _prizePlan(fixedAmountCents: 5000),
      remotePlan: _prizePlan(fixedAmountCents: 5000),
    );
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [_dashboardEvent()],
      ),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      prizeRepository: prizeRepository,
    );

    await controller.load('evt_01');
    expect(controller.prizePoolCents, 5000);

    prizeRepository.remotePlan = null;
    await controller.load('evt_01', silent: true);

    expect(controller.prizePoolCents, isNull);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('silent refresh preserves prize pool when remote plan load fails',
      () async {
    final prizeRepository = _FakePrizeRepository(
      cachedPlan: _prizePlan(fixedAmountCents: 5000),
      remotePlan: _prizePlan(fixedAmountCents: 5000),
    );
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [_dashboardEvent()],
      ),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      prizeRepository: prizeRepository,
    );

    await controller.load('evt_01');
    expect(controller.prizePoolCents, 5000);

    prizeRepository.remoteError = Exception('prize plan fetch failed');
    await controller.load('evt_01', silent: true);

    expect(controller.prizePoolCents, 5000);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('dashboard guest counts exclude withdrawn guests', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final guests = [
      _eventGuest(
        id: 'gst_qualifying',
        displayName: 'Active Qualifier',
        attendanceStatus: 'expected',
        tournamentStatus: 'qualifying',
      ),
      _eventGuest(
        id: 'gst_open_play',
        displayName: 'Open Play Guest',
        attendanceStatus: 'checked_in',
        tournamentStatus: 'open_play_only',
      ),
      _eventGuest(
        id: 'gst_withdrawn',
        displayName: 'Withdrawn Guest',
        attendanceStatus: 'checked_in',
        tournamentStatus: 'withdrawn',
      ),
    ];

    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: guests),
    );

    await controller.load('evt_01');

    expect(controller.guestCount, 2);
    expect(controller.checkedInGuestCount, 1);
    expect(controller.qualifyingGuestCount, 1);
    expect(controller.qualifiedGuestCount, 0);
  });

  test('leader label uses the top qualified leaderboard player', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: [],
        remoteEntries: [
          LeaderboardEntry(
            eventGuestId: 'gst_spike',
            displayName: 'One Hand Spike',
            totalPoints: 50,
            handsPlayed: 1,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            totalPoints: 40,
            handsPlayed: 8,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 2,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_grinder',
            displayName: 'Late Grinder',
            totalPoints: 10,
            handsPlayed: 30,
            handsWon: 3,
            selfDrawWins: 2,
            discardWins: 1,
            rank: 3,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(controller.leaderLabel, 'Brian Le');
  });

  test('defaults to tournament phase when event has no stored phase', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );

    await controller.load('evt_01');

    expect(controller.event?.currentScoringPhase, EventScoringPhase.tournament);
  });

  test('loads bonus round sudden death state with finals data', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'bonus',
    });
    const suddenDeathState = BonusRoundState(
      bonusRoundId: 'bonus_01',
      eventId: 'evt_01',
      status: 'active',
      suddenDeathStatus: 'required',
      championResolutionMethod: 'sudden_death',
      tiedTopPlayers: [
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          bonusScorePoints: 120,
          seedRank: 1,
        ),
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_bob',
          displayName: 'Bob Lee',
          bonusScorePoints: 120,
          seedRank: 2,
        ),
      ],
    );
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        bonusRoundState: suddenDeathState,
      ),
    );

    await controller.load('evt_01');

    expect(controller.bonusRoundState, suddenDeathState);
    expect(controller.isSuddenDeathRequired, isTrue);
    expect(controller.isSuddenDeathActive, isFalse);
    expect(controller.isSuddenDeathCompleted, isFalse);
    expect(controller.bonusRoundResults.hasResults, isTrue);
    expect(
      controller.bonusRoundResults.suddenDeathStatus?.detailLabel,
      contains('Alice Wong'),
    );
  });

  test('loads active bonus round sudden death state with finals data',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'bonus',
    });
    const suddenDeathState = BonusRoundState(
      bonusRoundId: 'bonus_01',
      eventId: 'evt_01',
      status: 'active',
      suddenDeathStatus: 'active',
      championResolutionMethod: 'sudden_death',
      suddenDeathTableId: 'tbl_sudden',
      suddenDeathSessionId: 'ses_sudden',
      tiedTopPlayers: [
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          bonusScorePoints: 120,
          seedRank: 1,
        ),
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_bob',
          displayName: 'Bob Lee',
          bonusScorePoints: 120,
          seedRank: 2,
        ),
      ],
    );
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        bonusRoundState: suddenDeathState,
      ),
    );

    await controller.load('evt_01');

    expect(controller.bonusRoundState, suddenDeathState);
    expect(controller.isSuddenDeathRequired, isFalse);
    expect(controller.isSuddenDeathActive, isTrue);
    expect(controller.isSuddenDeathCompleted, isFalse);
    expect(
      controller.bonusRoundResults.suddenDeathStatus?.statusLabel,
      'Sudden death active',
    );
  });

  test('active sudden death ignores completed champions session on same table',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'bonus',
    });
    final championsTable = _table(id: 'tbl_champions', label: 'Table 1A');
    const suddenDeathState = BonusRoundState(
      bonusRoundId: 'bonus_01',
      eventId: 'evt_01',
      status: 'active',
      suddenDeathStatus: 'active',
      championResolutionMethod: 'sudden_death',
      suddenDeathTableId: 'tbl_champions',
      tiedTopPlayers: [
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_alice',
          displayName: 'Alice Wong',
          bonusScorePoints: 120,
          seedRank: 1,
        ),
        BonusRoundTiedPlayer(
          eventGuestId: 'gst_bob',
          displayName: 'Bob Lee',
          bonusScorePoints: 120,
          seedRank: 2,
        ),
      ],
    );
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        bonusRoundState: suddenDeathState,
        assignments: [
          _bonusAssignment(
            table: championsTable,
            guestId: 'gst_alice',
            displayName: 'Alice Wong',
            seatIndex: 0,
            role: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
          _bonusAssignment(
            table: championsTable,
            guestId: 'gst_bob',
            displayName: 'Bob Lee',
            seatIndex: 1,
            role: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
        ],
      ),
      sessionRepository: _FakeSessionRepository([
        _session(
          id: 'ses_champions',
          tableId: championsTable.id,
          status: 'completed',
          bonusTableRole: BonusTableRole.tableOfChampions,
        ),
      ]),
      tableRepository: _FakeTableRepository([championsTable]),
    );

    await controller.load('evt_01');

    expect(controller.isSuddenDeathActive, isTrue);
    expect(controller.finalsRoundSummary.completeTableCount, 0);
    expect(controller.finalsRoundSummary.notStartedTableCount, 1);
    expect(
      controller.finalsRoundSummary.currentRoundTables.single.status,
      TournamentRoundTableStatus.notStarted,
    );
  });

  test('updates event scoring phase through repository', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.setScoringPhase(EventScoringPhase.tournament);

    expect(controller.event?.currentScoringPhase, EventScoringPhase.tournament);
    expect(controller.lifecycleError, isNull);
  });

  test('blocks scoring phase changes while a session is live', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    var didUpdatePhase = false;
    repository.scoringPhaseHandler = (_, __) {
      didUpdatePhase = true;
      return event;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      sessionRepository: _FakeSessionRepository([
        TableSessionRecord.fromJson(const {
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
          'scoring_phase': 'qualification',
          'started_at': '2026-04-24T19:05:00-07:00',
          'started_by_user_id': 'usr_01',
        }),
      ]),
    );
    await controller.load('evt_01');

    await controller.setScoringPhase(EventScoringPhase.tournament);

    expect(didUpdatePhase, isFalse);
    expect(
        controller.event?.currentScoringPhase, EventScoringPhase.qualification);
    expect(controller.lifecycleError,
        contains(scoringPhaseLiveSessionBlockedMessage));
  });

  test('startTournament generates draft seating for preview', () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final operations = <String>[];
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      operations.add('phase:${eventScoringPhaseToJson(phase)}');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (eventId) async {
          operations.add('generate:$eventId');
          return const [];
        },
      ),
    );
    await controller.load('evt_01');

    final assignments = await controller.startTournament();

    expect(assignments, isEmpty);
    expect(controller.event?.currentScoringPhase, EventScoringPhase.tournament);
    expect(controller.lifecycleError, isNull);
    expect(operations, ['generate:evt_01']);
  });

  test('startTournament keeps legacy qualification phase when generation fails',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final operations = <String>[];
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (eventId, phase) {
      operations.add('phase:${eventScoringPhaseToJson(phase)}');
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (eventId) async {
          operations.add('generate:$eventId');
          throw StateError(
              'Add or tag more tables before starting this round.');
        },
      ),
    );
    await controller.load('evt_01');

    final assignments = await controller.startTournament();

    expect(assignments, isNull);
    expect(
        controller.event?.currentScoringPhase, EventScoringPhase.qualification);
    expect(controller.lifecycleError,
        contains('Add or tag more tables before starting this round.'));
    expect(
      controller.lifecycleError,
      isNot(contains('Tournament mode remains active')),
    );
    expect(operations, ['generate:evt_01']);
  });

  test('startTournament can use repositories attached after controller init',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [event]);
    repository.scoringPhaseHandler = (_, phase) {
      return EventRecord.fromJson({
        ...event.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    controller.updateRuntimeRepositories(
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (_) async {
          return const [];
        },
      ),
    );
    final assignments = await controller.startTournament();

    expect(assignments, isEmpty);
    expect(controller.lifecycleError, isNull);
  });

  test('startNextTournamentRound generates draft seating for preview',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'tournament',
    });
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(cachedEvents: [event]),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        onGenerate: (_) async => const [],
      ),
    );
    await controller.load('evt_01');

    final assignments = await controller.startNextTournamentRound();

    expect(assignments, isEmpty);
    expect(controller.lifecycleError, isNull);
  });

  test('in-flight load cannot overwrite round state after next round starts',
      () async {
    final event = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
      'current_scoring_phase': 'tournament',
    });
    final remoteEvent = Completer<EventRecord?>();
    var roundLoadCount = 0;
    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [event],
        eventLoader: (_) => remoteEvent.future,
      ),
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
      seatingRepository: _FakeSeatingRepository(
        cachedRoundSummary: _roundSummary(1),
        onGenerate: (_) async => const [],
        onLoadRoundSummary: (_) async {
          roundLoadCount += 1;
          return roundLoadCount == 1 ? _roundSummary(3) : _roundSummary(1);
        },
      ),
    );

    final loadFuture = controller.load('evt_01');
    await Future<void>.delayed(Duration.zero);

    final assignments = await controller.startNextTournamentRound();
    remoteEvent.complete(event);
    await loadFuture;

    expect(assignments, isEmpty);
    expect(controller.tournamentRoundSummary.round?.roundNumber, 3);
    expect(controller.isLoading, isFalse);
  });

  test('cancelEvent updates the event to cancelled', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.cancelHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'cancelled',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.cancelEvent();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.cancelled);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });

  test('deleteEvent removes a draft event', () async {
    final draftEvent = EventRecord.fromJson(const {
      'id': 'evt_00',
      'owner_user_id': 'usr_01',
      'title': 'Draft Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    var deletedEventId = '';
    final repository = _FakeEventRepository(cachedEvents: [draftEvent]);
    repository.deleteHandler = (eventId) {
      deletedEventId = eventId;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_00');

    final deleted = await controller.deleteEvent();

    expect(deleted, isTrue);
    expect(deletedEventId, 'evt_00');
    expect(controller.event, isNull);
    expect(controller.lifecycleError, isNull);
  });

  test('revertToDraft updates an active event to draft', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.revertToDraftHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'draft',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.revertToDraft();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.draft);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });

  test('copyEventForTesting returns the copied draft event', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD',
      'prevailing_wind': 'east',
    });
    final copiedEvent = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'id': 'evt_copy',
      'title': 'Friday Night Mahjong Copy',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'current_scoring_phase': 'qualification',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.copyForTestingHandler = (eventId) {
      expect(eventId, 'evt_01');
      return copiedEvent;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    final result = await controller.copyEventForTesting();

    expect(result, copiedEvent);
    expect(controller.event, activeEvent);
    expect(controller.lifecycleError, isNull);
    expect(controller.isSubmittingLifecycle, isFalse);
  });
}
