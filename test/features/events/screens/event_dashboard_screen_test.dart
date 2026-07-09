import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/activity/screens/activity_screen.dart';
import 'package:mosaic/features/events/screens/bonus_round_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:mosaic/features/scoring/screens/event_hand_ledger_screen.dart';
import 'package:mosaic/features/scoring/screens/hand_evidence_review_screen.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';
import 'package:mosaic/features/tables/screens/seating_assignment_screen.dart';
import 'package:mosaic/services/nfc/native_nfc_reader.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/app_actions.dart';
import 'package:mosaic/widgets/app_surfaces.dart';

class _EventRepository extends ThrowingEventRepository {
  _EventRepository(
    this.event, {
    this.onComplete,
    this.onFinalize,
    this.onStart,
    this.onUpdateScoringPhase,
    this.onCancel,
    this.onRevertToDraft,
    this.onDelete,
    this.onCopyForTesting,
  });

  EventRecord event;
  final Future<EventRecord> Function(String eventId)? onComplete;
  final Future<EventRecord> Function(String eventId)? onFinalize;
  final Future<EventRecord> Function(String eventId)? onStart;
  final Future<EventRecord> Function(String eventId)? onCancel;
  final Future<EventRecord> Function(String eventId)? onRevertToDraft;
  final Future<void> Function(String eventId)? onDelete;
  final Future<EventRecord> Function(String eventId)? onCopyForTesting;
  final Future<EventRecord> Function(String eventId, EventScoringPhase phase)?
      onUpdateScoringPhase;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> copyEventForTesting(String eventId) async {
    final handler = onCopyForTesting;
    if (handler != null) {
      return handler(eventId);
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) async {
    final handler = onCancel;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) async {
    final handler = onRevertToDraft;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final handler = onDelete;
    if (handler != null) {
      await handler(eventId);
      return;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> startEvent(String eventId) async {
    final handler = onStart;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> updateEventScoringPhase({
    required String eventId,
    required EventScoringPhase phase,
  }) async {
    final handler = onUpdateScoringPhase;
    if (handler != null) {
      event = await handler(eventId, phase);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> completeEvent(String eventId) async {
    final handler = onComplete;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) async {
    final handler = onFinalize;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async =>
      event.id == eventId ? event : null;

  @override
  Future<List<EventRecord>> listEvents() async => [event];

  @override
  Future<List<EventRecord>> readCachedEvents() async => [event];
}

class _GuestRepository extends ThrowingGuestRepository {
  const _GuestRepository({
    this.guests = const [],
  });

  final List<EventGuestRecord> guests;

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

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
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

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

class _LeaderboardRepository extends ThrowingLeaderboardRepository {
  const _LeaderboardRepository({this.entries = const []});

  final List<LeaderboardEntry> entries;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      entries;

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      entries;
}

class _ActivityRepository extends ThrowingActivityRepository {
  @override
  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  ) async =>
      const [];

  @override
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  ) async =>
      const [];
}

class _SeatingRepository extends ThrowingSeatingRepository {
  const _SeatingRepository({
    this.generatedAssignments = const [],
    this.roundSummary,
    this.assignments = const [],
    this.bonusRoundState,
  });

  final List<SeatingAssignmentRecord> generatedAssignments;
  final TournamentRoundSummary? roundSummary;
  final List<SeatingAssignmentRecord> assignments;
  final BonusRoundState? bonusRoundState;

  static int generatedTournamentRoundCount = 0;
  static int generatedRandomAssignmentCount = 0;

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(
          String eventId) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async {
    generatedRandomAssignmentCount += 1;
    return generatedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    generatedTournamentRoundCount += 1;
    return generatedAssignments;
  }

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async =>
      roundSummary ?? TournamentRoundSummary.empty();

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      roundSummary;

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) async =>
      const [];

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      assignments;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      assignments;

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async =>
      bonusRoundState;
}

class _PrizeRepository extends ThrowingPrizeRepository {
  _PrizeRepository({
    PrizePlanDetail? loadedPlan,
    List<PrizePlanDetail?> loadedPlans = const [],
  })  : _loadedPlan = loadedPlan,
        _loadedPlans = List.of(loadedPlans);

  PrizePlanDetail? _loadedPlan;
  final List<PrizePlanDetail?> _loadedPlans;

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizePlanDetail?> loadPrizePlan({required String eventId}) async {
    if (_loadedPlans.isNotEmpty) {
      _loadedPlan = _loadedPlans.removeAt(0);
    }

    return _loadedPlan;
  }

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) async =>
      const [];

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async =>
      _loadedPlan;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
    String eventId,
  ) async =>
      const [];

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) {
    throw UnimplementedError();
  }
}

class _TableRepository extends ThrowingTableRepository {
  _TableRepository({
    List<EventTableRecord> tables = const [],
    this.resolvedTable,
    this.resolveError,
  }) : tables = List<EventTableRecord>.from(tables);

  final List<EventTableRecord> tables;
  final EventTableRecord? resolvedTable;
  final Object? resolveError;

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
  Future<List<EventTableRecord>> listTables(String eventId) async => tables;

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      tables;

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) async {
    final error = resolveError;
    if (error != null) {
      throw error;
    }

    final table = resolvedTable;
    if (table != null) {
      return table;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _SessionRepository extends ThrowingSessionRepository {
  const _SessionRepository({
    this.sessions = const [],
    this.ledgerRows = const [],
  });

  final List<TableSessionRecord> sessions;
  final List<EventHandLedgerEntry> ledgerRows;

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
      ledgerRows;

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      sessions;

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    final session = sessions.firstWhere((session) => session.id == sessionId);
    return SessionDetailRecord(
      session: session,
      seats: const [
        TableSessionSeatRecord(
          id: 'seat_1',
          tableSessionId: 'sess_01',
          seatIndex: 0,
          initialWind: SeatWind.east,
          eventGuestId: 'guest_east',
        ),
        TableSessionSeatRecord(
          id: 'seat_2',
          tableSessionId: 'sess_01',
          seatIndex: 1,
          initialWind: SeatWind.south,
          eventGuestId: 'guest_south',
        ),
        TableSessionSeatRecord(
          id: 'seat_3',
          tableSessionId: 'sess_01',
          seatIndex: 2,
          initialWind: SeatWind.west,
          eventGuestId: 'guest_west',
        ),
        TableSessionSeatRecord(
          id: 'seat_4',
          tableSessionId: 'sess_01',
          seatIndex: 3,
          initialWind: SeatWind.north,
          eventGuestId: 'guest_north',
        ),
      ],
      hands: const [],
      settlements: const [],
      tableLabel: 'Table 1',
    );
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
      null;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      ledgerRows;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _NfcService implements NfcService {
  const _NfcService({
    this.tableScanResult,
    this.tableScanError,
  });

  final TagScanResult? tableScanResult;
  final Object? tableScanError;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    final tableScanError = this.tableScanError;
    if (tableScanError != null) {
      throw tableScanError;
    }
    return tableScanResult;
  }
}

class _CompletingTableScanNfcService implements NfcService {
  _CompletingTableScanNfcService(this.tableScanCompleter);

  final Completer<TagScanResult?> tableScanCompleter;
  int tableScanCallCount = 0;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) {
    tableScanCallCount += 1;
    return tableScanCompleter.future;
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  bool didPopRoute = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopRoute = true;
    super.didPop(route, previousRoute);
  }
}

class _MosaicProfileRepository implements MosaicProfileRepository {
  const _MosaicProfileRepository();

  @override
  Future<List<HandEvidenceReviewRecord>> listHandEvidenceReview(
    String eventId,
  ) async =>
      const [];

  @override
  Future<Uri?> createHandPhotoSignedUrl(HandPhotoRecord photo) async => null;

  @override
  Future<HandTileEntryRecord> upsertHandTileEntry({
    required String handResultId,
    required Map<String, dynamic> tilesJson,
    required int? calculatedFanCount,
    required HandTileReviewStatus reviewStatus,
    required String calculationVersion,
  }) {
    throw UnimplementedError();
  }
}

Future<void> _expectHandLedgerCorrectionFlag(
  WidgetTester tester, {
  required EventRecord event,
  required bool expectedCanCorrectHands,
}) async {
  final router = AppRouter(
    eventRepository: _EventRepository(event),
    guestRepository: _GuestRepository(),
    tableRepository: _TableRepository(),
    sessionRepository: _SessionRepository(),
    leaderboardRepository: _LeaderboardRepository(),
    activityRepository: _ActivityRepository(),
    prizeRepository: _PrizeRepository(),
    seatingRepository: const _SeatingRepository(),
    mosaicProfileRepository: const _MosaicProfileRepository(),
    nfcService: const _NfcService(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: EventDashboardScreen(
        args: EventDashboardArgs(eventId: event.id),
        eventRepository: _EventRepository(event),
        guestRepository: _GuestRepository(),
        leaderboardRepository: _LeaderboardRepository(),
      ),
      onGenerateRoute: router.onGenerateRoute,
    ),
  );
  await tester.pumpAndSettle();

  await tester.ensureVisible(find.text('Hand Ledger'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hand Ledger'));
  await tester.pumpAndSettle();

  expect(find.byType(EventHandLedgerScreen), findsOneWidget);
  expect(find.text('No hands recorded yet.'), findsOneWidget);
  final screen = tester.widget<EventHandLedgerScreen>(
    find.byType(EventHandLedgerScreen),
  );
  expect(screen.canCorrectHands, expectedCanCorrectHands);
}

PrizePlanDetail _fixedPrizePlan(List<int> fixedAmountCents) {
  return PrizePlanDetail(
    plan: PrizePlanRecord.fromJson(
      const {
        'id': 'pp_01',
        'event_id': 'evt_01',
        'mode': 'fixed',
        'status': 'draft',
        'reserve_fixed_cents': 0,
        'reserve_percentage_bps': 0,
      },
    ),
    tiers: List.generate(
      fixedAmountCents.length,
      (index) => PrizeTierRecord(
        id: 'tier_${index + 1}',
        prizePlanId: 'pp_01',
        place: index + 1,
        fixedAmountCents: fixedAmountCents[index],
      ),
    ),
  );
}

EventTableRecord _table({
  String id = 'tbl_01',
  String eventId = 'evt_01',
  String label = 'Table 1',
}) {
  return EventTableRecord.fromJson({
    'id': id,
    'event_id': eventId,
    'label': label,
    'display_order': 1,
    'nfc_tag_id': 'tag_table_01',
    'default_ruleset_id': 'HK_STANDARD',
    'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'default_rotation_policy_config_json': const {},
  });
}

LeaderboardEntry _leaderboardEntry({
  String eventGuestId = 'gst_01',
  String displayName = 'Alice Wong',
  int totalPoints = 125,
  int handsPlayed = 3,
  int rank = 1,
}) {
  return LeaderboardEntry(
    eventGuestId: eventGuestId,
    displayName: displayName,
    totalPoints: totalPoints,
    handsPlayed: handsPlayed,
    handsWon: 2,
    selfDrawWins: 1,
    discardWins: 1,
    rank: rank,
  );
}

EventGuestRecord _dashboardGuest({
  required String id,
  required String name,
  required AttendanceStatus attendanceStatus,
  required EventTournamentStatus tournamentStatus,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_04',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': switch (attendanceStatus) {
      AttendanceStatus.expected => 'expected',
      AttendanceStatus.checkedIn => 'checked_in',
      AttendanceStatus.checkedOut => 'checked_out',
      AttendanceStatus.noShow => 'no_show',
    },
    'cover_status': 'paid',
    'cover_amount_cents': 2000,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
  });
}

EventHandLedgerEntry _championAwardEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'entered_at': '2026-04-24T22:15:00-07:00',
    'ledger_row_type': 'adjustment',
    'adjustment_id': 'adj_01',
    'adjustment_type': 'finals_champion_award',
    'adjustment_amount_points': 37,
    'adjustment_event_guest_id': 'gst_alice',
    'adjustment_display_name': 'Alice Wong',
    'adjustment_context_json': {
      'champion_bonus_score_points': 24,
      'champion_top_up_points': 13,
    },
    'cells': const [],
  });
}

EventHandLedgerEntry _redemptionHandEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'table_id': 'tbl_02',
    'table_label': 'Table 2',
    'session_id': 'ses_02',
    'session_number_for_table': 1,
    'hand_id': 'hand_01',
    'hand_number': 1,
    'entered_at': '2026-04-24T22:20:00-07:00',
    'result_type': 'win',
    'status': 'recorded',
    'win_type': 'discard',
    'fan_count': 3,
    'has_settlements': true,
    'ledger_row_type': 'hand',
    'bonus_round_id': 'bonus_01',
    'bonus_table_role': 'table_of_redemption',
    'cells': const [
      {
        'wind': 'east',
        'seat_index': 0,
        'event_guest_id': 'gst_brian',
        'display_name': 'Brian Lee',
        'points_delta': 18,
      },
      {
        'wind': 'south',
        'seat_index': 1,
        'event_guest_id': 'gst_carla',
        'display_name': 'Carla Park',
        'points_delta': -6,
      },
      {
        'wind': 'west',
        'seat_index': 2,
        'event_guest_id': 'gst_dan',
        'display_name': 'Dan Yu',
        'points_delta': -6,
      },
      {
        'wind': 'north',
        'seat_index': 3,
        'event_guest_id': 'gst_emi',
        'display_name': 'Emi Chen',
        'points_delta': -6,
      },
    ],
  });
}

TableSessionRecord _session({
  required String id,
  String eventId = 'evt_01',
  String tableId = 'tbl_01',
  SessionStatus status = SessionStatus.active,
  EventScoringPhase scoringPhase = EventScoringPhase.tournament,
}) {
  return TableSessionRecord(
    id: id,
    eventId: eventId,
    eventTableId: tableId,
    sessionNumberForTable: 1,
    rulesetId: 'HK_STANDARD',
    rotationPolicyType: RotationPolicyType.dealerCycleReturnToInitialEast,
    rotationPolicyConfig: const {},
    status: status,
    scoringPhase: scoringPhase,
    initialEastSeatIndex: 0,
    currentDealerSeatIndex: 0,
    dealerPassCount: 0,
    completedGamesCount: 0,
    handCount: 0,
    startedAt: DateTime.parse('2026-04-24T19:00:00-07:00'),
    startedByUserId: 'usr_01',
  );
}

TagScanResult _tableScanResult([String uid = 'TABLE-001']) {
  return TagScanResult(
    rawUid: uid,
    normalizedUid: uid,
    isManualEntry: true,
  );
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required EventRecord event,
  MosaicAccessRole callerRole = MosaicAccessRole.owner,
  LeaderboardRepository? leaderboardRepository,
  PrizeRepository? prizeRepository,
  TableRepository? tableRepository,
  SessionRepository? sessionRepository,
  SeatingRepository? seatingRepository,
  NfcService? nfcService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EventDashboardScreen(
        args: EventDashboardArgs(
          eventId: event.id,
          callerRole: callerRole,
        ),
        eventRepository: _EventRepository(event),
        guestRepository: _GuestRepository(),
        leaderboardRepository:
            leaderboardRepository ?? _LeaderboardRepository(),
        prizeRepository: prizeRepository,
        tableRepository: tableRepository,
        sessionRepository: sessionRepository,
        seatingRepository: seatingRepository,
        nfcService: nfcService,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TournamentRoundSummary _roundSummary({
  int roundNumber = 1,
  int assignedTableCount = 1,
  int completeTableCount = 0,
  int activeTableCount = 0,
  int pausedTableCount = 0,
  int notStartedTableCount = 0,
}) {
  return TournamentRoundSummary(
    round: TournamentRoundRecord(
      id: 'round_01',
      eventId: 'evt_01',
      roundNumber: roundNumber,
      scoringPhase: EventScoringPhase.tournament,
      status: TournamentRoundStatus.active,
      assignmentRound: roundNumber,
      startedAt: DateTime.utc(2026, 5, 24, 19),
    ),
    assignedTableCount: assignedTableCount,
    completeTableCount: completeTableCount,
    activeTableCount: activeTableCount,
    pausedTableCount: pausedTableCount,
    notStartedTableCount: notStartedTableCount,
    currentRoundTables: const [],
    otherTables: const [],
  );
}

SeatingAssignmentRecord _assignment({
  String id = 'asg_01',
  String eventId = 'evt_01',
  String tableId = 'tbl_01',
  String tableLabel = 'Table 1',
  String guestId = 'gst_01',
  String displayName = 'Ava East',
  int seatIndex = 0,
}) {
  return SeatingAssignmentRecord(
    id: id,
    eventId: eventId,
    eventTableId: tableId,
    tableLabel: tableLabel,
    eventGuestId: guestId,
    displayName: displayName,
    seatIndex: seatIndex,
    assignmentRound: 1,
    status: 'active',
  );
}

SeatingAssignmentRecord _bonusAssignment({
  String id = 'bonus_asg_01',
  String eventId = 'evt_01',
  String tableId = 'tbl_01',
  String tableLabel = 'Table 1',
  String guestId = 'gst_01',
  String displayName = 'Ava East',
  int seatIndex = 0,
  int assignmentRound = 1,
  BonusTableRole bonusTableRole = BonusTableRole.tableOfChampions,
}) {
  return SeatingAssignmentRecord(
    id: id,
    eventId: eventId,
    eventTableId: tableId,
    tableLabel: tableLabel,
    eventGuestId: guestId,
    displayName: displayName,
    seatIndex: seatIndex,
    assignmentRound: assignmentRound,
    status: 'active',
    assignmentType: SeatingAssignmentType.bonus,
    bonusRoundId: 'bonus_01',
    bonusTableRole: bonusTableRole,
  );
}

void main() {
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
  final completedEvent = EventRecord.fromJson(const {
    'id': 'evt_02',
    'owner_user_id': 'usr_01',
    'title': 'Completed Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'completed',
    'checkin_open': true,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
  });
  final finalizedEvent = EventRecord.fromJson(const {
    'id': 'evt_03',
    'owner_user_id': 'usr_01',
    'title': 'Finalized Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'finalized',
    'checkin_open': false,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
  });
  final cancelledEvent = EventRecord.fromJson(const {
    'id': 'evt_05',
    'owner_user_id': 'usr_01',
    'title': 'Cancelled Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'cancelled',
    'checkin_open': false,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
  });

  final activeCheckinOnlyEvent = EventRecord.fromJson(const {
    'id': 'evt_04',
    'owner_user_id': 'usr_01',
    'title': 'Live Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'active',
    'checkin_open': true,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
  });

  testWidgets('dashboard exposes a prize pool action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prize Pool'), findsOneWidget);
  });

  testWidgets('dashboard exposes an activity action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
  });

  testWidgets('dashboard does not link to qualification standings',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'current_scoring_phase': 'qualification',
    });

    await _pumpDashboard(tester, event: event);

    expect(find.text('Tournament Live'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Scoring Phase'), findsNothing);
    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Tournament'), findsNothing);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('View Qualification Standings'), findsNothing);
    expect(find.text('Qualification Leaderboard'), findsNothing);
    expect(find.text('Alice Wong'), findsNothing);
    expect(find.text('72 pts'), findsNothing);
  });

  testWidgets('dashboard summarizes configured prize pool', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          prizeRepository: _PrizeRepository(
            loadedPlan: _fixedPrizePlan([15000, 10000, 0]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prize Pool'), findsOneWidget);
    expect(find.text('\$250.00'), findsOneWidget);
  });

  testWidgets('prizes action refreshes the dashboard prize pool on return', (
    tester,
  ) async {
    final prizeRepository = _PrizeRepository(
      loadedPlan: _fixedPrizePlan([10000]),
      loadedPlans: [
        _fixedPrizePlan([10000]),
        _fixedPrizePlan([15000, 10000]),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          prizeRepository: prizeRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.prizePlanRoute) {
            return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done editing prizes'),
                ),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$100.00'), findsOneWidget);

    await tester.ensureVisible(find.text('Prize Pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prize Pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done editing prizes'));
    await tester.pumpAndSettle();

    expect(find.text('\$250.00'), findsOneWidget);
  });

  testWidgets('prizes action routes into the prize plan screen', (
    tester,
  ) async {
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: const _NfcService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Prize Pool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prize Pool'));
    await tester.pumpAndSettle();

    expect(find.byType(PrizePlanScreen), findsOneWidget);
    expect(find.text('Total Prizes'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
  });

  testWidgets('guests summary card routes into guest roster', (tester) async {
    GuestRosterArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.guestRosterRoute) {
            openedArgs = settings.arguments! as GuestRosterArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Guests'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guests'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.eventTitle, activeEvent.title);
    expect(openedArgs?.eventCoverChargeCents, activeEvent.coverChargeCents);
    expect(find.text('Opened Guests'), findsOneWidget);
  });

  testWidgets('tables summary card routes into tables overview',
      (tester) async {
    TablesOverviewArgs? openedArgs;
    final tableRepository = _TableRepository(tables: [_table()]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: tableRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    tableRepository.tables.add(_table(id: 'tbl_02'));
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close Tables'),
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.eventTitle, activeEvent.title);
    expect(openedArgs?.scoringOpen, activeEvent.scoringOpen);
    expect(openedArgs?.readOnly, isFalse);
    expect(find.text('Close Tables'), findsOneWidget);

    await tester.tap(find.text('Close Tables'));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('finalized event opens tables read-only', (tester) async {
    TablesOverviewArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_03'),
          eventRepository: _EventRepository(finalizedEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(tables: [_table()]),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Tables'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_03');
    expect(openedArgs?.readOnly, isTrue);
  });

  testWidgets('leader summary card routes into leaderboard', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(
            entries: [_leaderboardEntry(displayName: 'Brian Le')],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.leaderboardRoute) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Leaderboard'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leader'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);

    await tester.tap(find.text('Leader'));
    await tester.pumpAndSettle();

    expect(find.text('Opened Leaderboard'), findsOneWidget);
  });

  testWidgets('leader summary card shows the top qualified player',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: activeEvent,
      leaderboardRepository: _LeaderboardRepository(
        entries: [
          _leaderboardEntry(
            eventGuestId: 'gst_giang',
            displayName: 'Giang Pham',
            totalPoints: 50,
            handsPlayed: 1,
            rank: 1,
          ),
          _leaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            totalPoints: 40,
            handsPlayed: 8,
            rank: 2,
          ),
          _leaderboardEntry(
            eventGuestId: 'gst_grinder',
            displayName: 'Late Grinder',
            totalPoints: 10,
            handsPlayed: 30,
            rank: 3,
          ),
        ],
      ),
    );

    expect(find.text('Leader'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);
    expect(find.text('Giang Pham'), findsNothing);
  });

  testWidgets('dashboard surfaces bonus round winners after finals',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: completedEvent,
      leaderboardRepository: _LeaderboardRepository(
        entries: [
          _leaderboardEntry(
            eventGuestId: 'gst_alice',
            displayName: 'Alice Wong',
            totalPoints: 121,
            handsPlayed: 6,
            rank: 1,
          ),
        ],
      ),
      sessionRepository: _SessionRepository(
        ledgerRows: [
          _championAwardEntry(),
          _redemptionHandEntry(),
        ],
      ),
    );

    expect(find.text('Bonus Round Results'), findsOneWidget);
    expect(find.text('Final champion'), findsOneWidget);
    expect(find.text('Alice Wong'), findsWidgets);
    expect(find.text('121 pts total'), findsOneWidget);
    expect(find.text('Redemption winner'), findsOneWidget);
    expect(find.text('Brian Lee'), findsOneWidget);
    expect(find.text('Score +18'), findsOneWidget);
  });

  testWidgets('activity action routes into the activity screen',
      (tester) async {
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: const _NfcService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityScreen), findsOneWidget);
  });

  testWidgets(
      'hand ledger action routes active and completed events with correctable hands enabled',
      (tester) async {
    await _expectHandLedgerCorrectionFlag(
      tester,
      event: activeEvent,
      expectedCanCorrectHands: true,
    );
    await _expectHandLedgerCorrectionFlag(
      tester,
      event: completedEvent,
      expectedCanCorrectHands: true,
    );
  });

  testWidgets(
      'hand ledger action routes finalized, cancelled, and draft events read-only',
      (tester) async {
    await _expectHandLedgerCorrectionFlag(
      tester,
      event: finalizedEvent,
      expectedCanCorrectHands: false,
    );
    await _expectHandLedgerCorrectionFlag(
      tester,
      event: cancelledEvent,
      expectedCanCorrectHands: false,
    );
    await _expectHandLedgerCorrectionFlag(
      tester,
      event: draftEvent,
      expectedCanCorrectHands: false,
    );
  });

  testWidgets('completed event routes to hand evidence review', (tester) async {
    final router = AppRouter(
      eventRepository: _EventRepository(completedEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: const _NfcService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: completedEvent.id),
          eventRepository: _EventRepository(completedEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hand Evidence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hand Evidence'));
    await tester.pumpAndSettle();

    expect(find.byType(HandEvidenceReviewScreen), findsOneWidget);
    expect(find.text('Hand Review'), findsOneWidget);
  });

  testWidgets('hand evidence review action follows event access rules',
      (tester) async {
    Future<void> expectHandEvidenceAction(
      EventRecord event,
      Matcher matcher, {
      MosaicAccessRole callerRole = MosaicAccessRole.owner,
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await _pumpDashboard(
        tester,
        event: event,
        callerRole: callerRole,
      );
      await tester.ensureVisible(find.text('Event options'));
      await tester.pumpAndSettle();

      expect(find.text('Hand Evidence'), matcher);
    }

    await expectHandEvidenceAction(completedEvent, findsOneWidget);
    await expectHandEvidenceAction(finalizedEvent, findsOneWidget);
    await expectHandEvidenceAction(draftEvent, findsNothing);
    await expectHandEvidenceAction(cancelledEvent, findsNothing);
    await expectHandEvidenceAction(
      completedEvent,
      findsNothing,
      callerRole: MosaicAccessRole.eventScorer,
    );
  });

  testWidgets('active event exposes seating action', (tester) async {
    await _pumpDashboard(tester, event: activeEvent);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsOneWidget);
  });

  testWidgets(
      'active event options do not show finals before a completed round',
      (tester) async {
    await _pumpDashboard(tester, event: activeEvent);

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Begin Finals'), findsNothing);
  });

  testWidgets(
      'completed tournament round offers finals below next round action',
      (tester) async {
    RouteSettings? openedSettings;
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(event),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          seatingRepository: _SeatingRepository(
            roundSummary: _roundSummary(
              roundNumber: 2,
              assignedTableCount: 3,
              completeTableCount: 3,
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.bonusRoundRoute) {
            openedSettings = settings;
            final args = settings.arguments! as BonusRoundArgs;
            return MaterialPageRoute<void>(
              builder: (_) => BonusRoundScreen(
                eventId: args.eventId,
                leaderboardRepository: _LeaderboardRepository(),
                tableRepository: _TableRepository(),
                sessionRepository: const _SessionRepository(),
                seatingRepository: const _SeatingRepository(),
                nfcService: const _NfcService(),
              ),
              settings: settings,
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Next Round'), findsOneWidget);
    await tester.ensureVisible(find.text('Begin Finals'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Begin Finals'));
    await tester.pumpAndSettle();

    expect(openedSettings?.name, AppRouter.bonusRoundRoute);
    expect((openedSettings?.arguments as BonusRoundArgs?)?.eventId, 'evt_01');
    expect(find.byType(BonusRoundScreen), findsOneWidget);
  });

  testWidgets('draft event exposes seating prep action', (tester) async {
    await _pumpDashboard(tester, event: draftEvent);

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsOneWidget);
  });

  testWidgets('draft event opens metadata editor from event options',
      (tester) async {
    RouteSettings? openedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: draftEvent.id),
          eventRepository: _EventRepository(draftEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: (settings) {
          openedSettings = settings;
          return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Edit event form')),
            settings: settings,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Event'));
    await tester.pumpAndSettle();

    expect(openedSettings?.name, AppRouter.createEventRoute);
    final args = openedSettings?.arguments as CreateEventArgs?;
    expect(args?.initialEvent?.id, draftEvent.id);
    expect(find.text('Edit event form'), findsOneWidget);
  });

  testWidgets('completed event exposes seating prep action', (tester) async {
    await _pumpDashboard(tester, event: completedEvent);

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsOneWidget);
  });

  testWidgets('finalized event hides seating prep action', (tester) async {
    await _pumpDashboard(tester, event: finalizedEvent);

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsNothing);
  });

  testWidgets('cancelled event does not expose prep actions', (tester) async {
    await _pumpDashboard(tester, event: cancelledEvent);

    await tester.ensureVisible(find.text('Event options'));
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsNothing);
  });

  testWidgets('scan table routes to active table session', (tester) async {
    final table = _table();
    final activeSession = _session(id: 'sess_active');
    final sessionRepository = _SessionRepository(sessions: [activeSession]);
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(resolvedTable: table),
      sessionRepository: sessionRepository,
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: table),
          sessionRepository: sessionRepository,
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
  });

  testWidgets('table scan surfaces native NFC errors inline', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: _table()),
          sessionRepository: const _SessionRepository(),
          nfcService: const _NfcService(
            tableScanError: NfcScanException(
              'NFC is not available on this device.',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pump();

    expect(find.text('NFC is not available on this device.'), findsOneWidget);
  });

  testWidgets('prevents overlapping table scans on dashboard', (tester) async {
    final tableScanCompleter = Completer<TagScanResult?>();
    final nfcService = _CompletingTableScanNfcService(tableScanCompleter);

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: _table()),
          sessionRepository: const _SessionRepository(),
          nfcService: nfcService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.tap(find.text('Scan Table'));

    expect(nfcService.tableScanCallCount, 1);

    tableScanCompleter.complete(null);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'scan table opens active sessions read-only when scoring is paused',
      (tester) async {
    final table = _table();
    final activeSession = _session(id: 'sess_active');
    final sessionRepository = _SessionRepository(sessions: [activeSession]);
    final router = AppRouter(
      eventRepository: _EventRepository(activeCheckinOnlyEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(resolvedTable: table),
      sessionRepository: sessionRepository,
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(activeCheckinOnlyEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: table),
          sessionRepository: sessionRepository,
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(
      find.text('Hand entry is unavailable while scoring is paused.'),
      findsOneWidget,
    );
    expect(find.text('Record Hand'), findsNothing);
  });

  testWidgets('scan table routes to paused table session', (tester) async {
    final table = _table();
    final pausedSession = _session(
      id: 'sess_paused',
      status: SessionStatus.paused,
    );
    final sessionRepository = _SessionRepository(sessions: [pausedSession]);
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(resolvedTable: table),
      sessionRepository: sessionRepository,
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: const _SeatingRepository(),
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: table),
          sessionRepository: sessionRepository,
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(find.byType(SessionDetailScreen), findsOneWidget);
    expect(find.text('Resume Timer'), findsOneWidget);
  });

  testWidgets('scan table opens assigned table review without player prompts',
      (tester) async {
    final table = _table();
    final seatingRepository = _SeatingRepository(
      assignments: [
        _assignment(displayName: 'Ava East'),
        _assignment(
          id: 'asg_02',
          guestId: 'gst_02',
          displayName: 'Ben South',
          seatIndex: 1,
        ),
      ],
    );
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(resolvedTable: table),
      sessionRepository: const _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      seatingRepository: seatingRepository,
      mosaicProfileRepository: const _MosaicProfileRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: table),
          sessionRepository: const _SessionRepository(),
          seatingRepository: seatingRepository,
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(find.text('Start Session'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Scan Table Tag'), findsNothing);
    expect(find.text('Review assigned seating'), findsOneWidget);
    expect(find.text('Ava East'), findsOneWidget);
    expect(find.text('Ben South'), findsOneWidget);
    expect(find.textContaining('Player Tag'), findsNothing);
  });

  testWidgets('scan table shows message when scoring is closed',
      (tester) async {
    final table = _table(eventId: 'evt_04');

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(activeCheckinOnlyEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: table),
          sessionRepository: const _SessionRepository(),
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(
      find.text('Open scoring before starting a table session.'),
      findsOneWidget,
    );
    expect(find.text('Live Friday Night Mahjong'), findsWidgets);
  });

  testWidgets('scan table resolution error renders on dashboard',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(
            resolveError: TableTagResolutionException(
              TableTagResolutionFailure.unknownTag,
            ),
          ),
          sessionRepository: const _SessionRepository(),
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan Table'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unknown table tag. Bind this tag to a table first.'),
      findsOneWidget,
    );
    expect(find.text('Friday Night Mahjong'), findsWidgets);
  });

  testWidgets('scoring-open event uses live host console hierarchy',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: activeEvent,
      leaderboardRepository: _LeaderboardRepository(
        entries: [_leaderboardEntry(displayName: 'Brian Le')],
      ),
      prizeRepository: _PrizeRepository(
        loadedPlan: _fixedPrizePlan([17500]),
      ),
      tableRepository: _TableRepository(
        tables: [_table(), _table(id: 'tbl_02', label: 'Table 2')],
        resolvedTable: _table(),
      ),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text(activeEvent.title), findsOneWidget);
    expect(find.text('Event Phase'), findsNothing);
    expect(
      find.text(
        'Use the live operations controls to open or close check-in and scoring during the event.',
      ),
      findsNothing,
    );
    expect(find.text('Scoring Open'), findsNothing);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Prize Pool'), findsOneWidget);
    expect(find.text('Leader'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);
    expect(find.text('Prizes'), findsNothing);
    expect(find.text('Scan Table'), findsOneWidget);
    expect(find.text('Leaderboard'), findsNothing);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Live Operations'), findsNothing);
    expect(find.text('Pause Scoring'), findsNothing);
    expect(find.text('Close Hand Entry'), findsNothing);
    expect(find.text('Event options'), findsOneWidget);

    final tablesTop = tester.getTopLeft(find.text('Tables')).dy;
    final scanTop = tester.getTopLeft(find.text('Scan Table')).dy;
    final optionsTop = tester.getTopLeft(find.text('Event options')).dy;

    expect(tablesTop, lessThan(scanTop));
    expect(scanTop, lessThan(optionsTop));
  });

  testWidgets('event scorers open guests without check-in permission',
      (tester) async {
    GuestRosterArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(
            eventId: activeEvent.id,
            callerRole: MosaicAccessRole.eventScorer,
          ),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.guestRosterRoute) {
            openedArgs = settings.arguments! as GuestRosterArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Guests opened')),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guests').first);
    await tester.pumpAndSettle();

    expect(openedArgs?.canCheckIn, isFalse);
    expect(openedArgs?.canManageGuests, isFalse);
    expect(openedArgs?.canManageCover, isFalse);
    expect(openedArgs?.canManageTournamentStatus, isFalse);
  });

  testWidgets('owners open guests with management and check-in permission',
      (tester) async {
    GuestRosterArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(
            eventId: activeEvent.id,
            callerRole: MosaicAccessRole.owner,
          ),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.guestRosterRoute) {
            openedArgs = settings.arguments! as GuestRosterArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Guests opened')),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guests').first);
    await tester.pumpAndSettle();

    expect(openedArgs?.canCheckIn, isTrue);
    expect(openedArgs?.canManageGuests, isTrue);
    expect(openedArgs?.canManageCover, isTrue);
    expect(openedArgs?.canManageTournamentStatus, isTrue);
  });

  testWidgets('live console renders event title once', (tester) async {
    await _pumpDashboard(
      tester,
      event: activeEvent,
      tableRepository: _TableRepository(resolvedTable: _table()),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text(activeEvent.title), findsOneWidget);
  });

  testWidgets('polished dashboard back button is square', (tester) async {
    await _pumpDashboard(
      tester,
      event: activeEvent,
      tableRepository: _TableRepository(resolvedTable: _table()),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    final backButton = find.byKey(const ValueKey('eventDashboardBackButton'));
    final size = tester.getSize(backButton);

    expect(size.width, size.height);
  });

  testWidgets('draft event uses polished event dashboard shell',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: draftEvent,
      tableRepository: _TableRepository(resolvedTable: _table()),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text(draftEvent.title), findsOneWidget);
    expect(find.text('Event Phase'), findsNothing);
    expect(find.text('Check-In Not Open'), findsNothing);
    expect(find.text('Scoring Not Open'), findsNothing);
    expect(find.text('Open Check-In'), findsOneWidget);
    expect(find.text('Scan Table'), findsNothing);
    expect(find.text('Event options'), findsOneWidget);
  });

  testWidgets('completed event uses polished event dashboard shell',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: completedEvent,
      prizeRepository: _PrizeRepository(
        loadedPlan: _fixedPrizePlan([17500]),
      ),
    );

    expect(find.text(completedEvent.title), findsOneWidget);
    expect(find.text('Event Phase'), findsNothing);
    expect(find.text('Check-In Open'), findsNothing);
    expect(find.text('Scoring Not Open'), findsNothing);
    expect(find.text('Finalize Event'), findsOneWidget);
    expect(find.text('Event options'), findsOneWidget);
  });

  testWidgets('completed event separates primary action from info panel',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: completedEvent,
      prizeRepository: _PrizeRepository(
        loadedPlan: _fixedPrizePlan([17500]),
      ),
    );

    final actionBottom = tester.getBottomLeft(find.byType(HeroActionButton)).dy;
    final panelTop = tester.getTopLeft(find.byType(InfoPanel)).dy;

    expect(panelTop - actionBottom, greaterThanOrEqualTo(12));
  });

  testWidgets('check-in open tournament with no tables prompts table setup',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: activeCheckinOnlyEvent,
      tableRepository:
          _TableRepository(resolvedTable: _table(eventId: 'evt_04')),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text('Add Tables'), findsOneWidget);
    expect(find.text('Open Scoring'), findsNothing);
    expect(find.text('Close Hand Entry'), findsNothing);
    expect(find.text('Reopen Hand Entry'), findsNothing);
    expect(find.text('Start Qualification'), findsNothing);
    expect(find.text('Scan Table'), findsOneWidget);

    final addTablesTop = tester.getTopLeft(find.text('Add Tables')).dy;
    final scanTableTop = tester.getTopLeft(find.text('Scan Table')).dy;

    expect(addTablesTop, lessThan(scanTableTop));
  });

  testWidgets('active check-in dashboard opens tournament seating setup',
      (tester) async {
    _SeatingRepository.generatedTournamentRoundCount = 0;
    final eventRepository = _EventRepository(
      activeCheckinOnlyEvent,
      onUpdateScoringPhase: (eventId, phase) async => EventRecord.fromJson({
        ...activeCheckinOnlyEvent.toJson(),
        'current_scoring_phase': eventScoringPhaseToJson(phase),
      }),
    );
    final seatingRepository = _SeatingRepository(
      generatedAssignments: [_assignment(eventId: activeCheckinOnlyEvent.id)],
    );
    final guests = [
      _dashboardGuest(
        id: 'gst_an',
        name: 'An Le',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.openPlayOnly,
      ),
      _dashboardGuest(
        id: 'gst_amy',
        name: 'Amy Wong',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _dashboardGuest(
        id: 'gst_brian',
        name: 'Brian Le',
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _dashboardGuest(
        id: 'gst_pending',
        name: 'Pending Guest',
        attendanceStatus: AttendanceStatus.expected,
        tournamentStatus: EventTournamentStatus.openPlayOnly,
      ),
    ];

    TablesOverviewArgs? openedTablesArgs;
    RouteSettings? openedSeatingSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: eventRepository,
          guestRepository: _GuestRepository(guests: guests),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(
            tables: [
              _table(eventId: 'evt_04'),
              _table(id: 'tbl_02', eventId: 'evt_04', label: 'Table 2'),
            ],
            resolvedTable: _table(eventId: 'evt_04'),
          ),
          sessionRepository: const _SessionRepository(),
          seatingRepository: seatingRepository,
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedTablesArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Tables'),
              ),
            );
          }
          if (settings.name == AppRouter.seatingAssignmentsRoute) {
            openedSeatingSettings = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Seating'),
              ),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Tournament'), findsOneWidget);
    expect(find.text('Open Scoring'), findsNothing);
    expect(find.text('Close Hand Entry'), findsNothing);
    expect(find.text('Reopen Hand Entry'), findsNothing);
    expect(find.text('Start Qualification'), findsNothing);
    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Checked In'), findsNothing);
    expect(find.text('Qualifying'), findsNothing);
    expect(find.text('Qualified'), findsNothing);
    expect(find.text('Live Operations'), findsNothing);
    expect(find.text('Prize Pool'), findsOneWidget);
    expect(find.text('Leader'), findsOneWidget);

    await tester.tap(find.text('Tables'));
    await tester.pumpAndSettle();

    expect(openedTablesArgs?.eventId, 'evt_04');
    expect(openedTablesArgs?.eventTitle, activeCheckinOnlyEvent.title);
    expect(openedTablesArgs?.scoringOpen, isFalse);
    expect(find.text('Opened Tables'), findsOneWidget);

    Navigator.of(tester.element(find.text('Opened Tables'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Tournament'));
    await tester.pumpAndSettle();

    expect(eventRepository.event.scoringOpen, isFalse);
    expect(_SeatingRepository.generatedTournamentRoundCount, 1);
    expect(openedSeatingSettings?.name, AppRouter.seatingAssignmentsRoute);
    expect(
      (openedSeatingSettings?.arguments as SeatingAssignmentsArgs?)
          ?.initialAssignments,
      seatingRepository.generatedAssignments,
    );
  });

  testWidgets('active event shows Complete Event action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete Event'), findsOneWidget);
    expect(find.text('Finalize Event'), findsNothing);
  });

  testWidgets('draft event shows setup state and open check-in action',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(
            draftEvent,
            onStart: (_) async => activeCheckinOnlyEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open Check-In'), findsOneWidget);
    expect(find.text('Start Event'), findsNothing);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Event Phase'), findsNothing);
    expect(find.text('Setup'), findsOneWidget);
    expect(
      find.text(
          'Finish setup, then open check-in when hosts are ready to receive guests.'),
      findsOneWidget,
    );
  });

  testWidgets('draft event hides scan table action even with scan dependencies',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(draftEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(resolvedTable: _table()),
          sessionRepository: const _SessionRepository(),
          nfcService: _NfcService(tableScanResult: _tableScanResult()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Scan Table'), findsNothing);
  });

  testWidgets('draft event can be deleted after confirmation', (tester) async {
    var deletedEventId = '';
    final navigatorObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [navigatorObserver],
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(
            draftEvent,
            onDelete: (eventId) async {
              deletedEventId = eventId;
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete Event'), findsOneWidget);

    await tester.ensureVisible(find.text('Delete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Event'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this event?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(deletedEventId, 'evt_00');
    expect(navigatorObserver.didPopRoute, isTrue);
  });

  testWidgets('active event can be cancelled after confirmation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(
            activeEvent,
            onCancel: (_) async {
              return EventRecord.fromJson({
                ...activeEvent.toJson(),
                'lifecycle_status': 'cancelled',
                'checkin_open': false,
                'scoring_open': false,
              });
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel Event'), findsOneWidget);

    await tester.ensureVisible(find.text('Cancel Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Event'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this event?'), findsOneWidget);

    await tester.tap(find.text('Cancel Event').last);
    await tester.pumpAndSettle();

    expect(find.text('Cancelled'), findsOneWidget);
    expect(
      find.text('This event was cancelled and is no longer live.'),
      findsOneWidget,
    );
    expect(find.text('Complete Event'), findsNothing);
  });

  testWidgets('active event can revert to draft after confirmation',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(
            activeEvent,
            onRevertToDraft: (_) async {
              return EventRecord.fromJson({
                ...activeEvent.toJson(),
                'lifecycle_status': 'draft',
                'checkin_open': false,
                'scoring_open': false,
              });
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revert to Draft'), findsOneWidget);

    await tester.ensureVisible(find.text('Revert to Draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revert to Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Revert to draft?'), findsOneWidget);
    expect(
      find.text(
        'Only events with no checked-in guests, sessions, or scores can go back to draft.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Revert'));
    await tester.pumpAndSettle();

    expect(find.text('Setup'), findsOneWidget);
    expect(find.text('Open Check-In'), findsOneWidget);
    expect(find.text('Start Event'), findsNothing);
    expect(find.text('Delete Event'), findsOneWidget);
    expect(find.text('Complete Event'), findsNothing);
  });

  testWidgets('event can be copied for testing after confirmation',
      (tester) async {
    var copiedEventId = '';
    RouteSettings? openedSettings;
    final copiedEvent = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'id': 'evt_copy',
      'title': 'Friday Night Mahjong Copy',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'current_scoring_phase': 'qualification',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(
            activeEvent,
            onCopyForTesting: (eventId) async {
              copiedEventId = eventId;
              return copiedEvent;
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.eventDashboardRoute) {
            openedSettings = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Copied event dashboard'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Copy Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy Event'));
    await tester.pumpAndSettle();

    expect(find.text('Copy this event?'), findsOneWidget);
    expect(
      find.text(
        'This creates a draft testing copy with guests, tables, and prize setup, but no check-ins, live activity, sessions, scores, standings, or awards.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copiedEventId, 'evt_01');
    expect(openedSettings?.name, AppRouter.eventDashboardRoute);
    expect((openedSettings?.arguments as EventDashboardArgs?)?.eventId,
        'evt_copy');
    expect(find.text('Copied event dashboard'), findsOneWidget);
  });

  testWidgets('starting a draft event prompts tournament setup',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(
            draftEvent,
            onStart: (_) async => activeCheckinOnlyEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Check-In'));
    await tester.pumpAndSettle();

    expect(find.text('Event Phase'), findsNothing);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Not Open'), findsNothing);
    expect(find.text('Close Check-In'), findsNothing);
    expect(find.text('Add Tables'), findsOneWidget);
    expect(find.text('Open Scoring'), findsNothing);
    expect(find.text('Start Qualification'), findsNothing);
  });

  testWidgets('active event hides hand entry operational flag actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(activeCheckinOnlyEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Not Open'), findsNothing);
    expect(find.text('Close Check-In'), findsNothing);
    expect(find.text('Open Scoring'), findsNothing);
    expect(find.text('Start Qualification'), findsNothing);
    expect(find.text('Pause Scoring'), findsNothing);
    expect(find.text('Close Hand Entry'), findsNothing);
    expect(find.text('Reopen Hand Entry'), findsNothing);
  });

  testWidgets(
      'legacy qualification scoring phase does not expose game tracking action',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'qualification',
    });

    await _pumpDashboard(tester, event: event);

    expect(find.text('Start Tournament'), findsNothing);
    expect(find.text('Pause Scoring'), findsNothing);
    expect(find.text('Close Hand Entry'), findsNothing);
    expect(
        find.text('Hand entry and check-in are open for hosts.'), findsNothing);
    expect(find.text('Tournament Live'), findsOneWidget);
    expect(find.text('Scoring Phase'), findsNothing);
  });

  testWidgets(
      'tournament scoring shows phase status without manual phase control',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });

    await _pumpDashboard(tester, event: event);

    expect(find.text('Tournament Live'), findsOneWidget);
    expect(find.text('Scoring Phase'), findsNothing);
    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Tournament'), findsNothing);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('View Qualification Standings'), findsNothing);
  });

  testWidgets('tournament dashboard shows round command center while active',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });

    await _pumpDashboard(
      tester,
      event: event,
      tableRepository: _TableRepository(tables: [_table(eventId: event.id)]),
      sessionRepository: const _SessionRepository(),
      seatingRepository: _SeatingRepository(
        roundSummary: _roundSummary(
          roundNumber: 2,
          assignedTableCount: 3,
          completeTableCount: 1,
          activeTableCount: 2,
        ),
      ),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text('Tournament Live'), findsOneWidget);
    expect(find.text('Round 2'), findsOneWidget);
    expect(find.text('1 of 3 tables complete'), findsOneWidget);
    expect(find.text('2 tables still in progress'), findsOneWidget);
    expect(find.text('Open Tables'), findsOneWidget);
    expect(find.text('Scan Table'), findsOneWidget);
  });

  testWidgets('tournament dashboard can recover with no generated round',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });

    await _pumpDashboard(
      tester,
      event: event,
      seatingRepository: _SeatingRepository(
        roundSummary: TournamentRoundSummary.empty(),
      ),
    );

    expect(find.text('Tournament Round'), findsNothing);
    expect(find.text('No tournament round generated'), findsNothing);
    expect(find.text('Generate Tournament Round'), findsNothing);
    expect(find.text('Scan Table'), findsOneWidget);
  });

  testWidgets('finals live dashboard ignores stale tournament round summary',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'bonus',
    });
    TablesOverviewArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(event),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository:
              _TableRepository(tables: [_table(eventId: event.id)]),
          sessionRepository: const _SessionRepository(),
          seatingRepository: _SeatingRepository(
            roundSummary: _roundSummary(
              roundNumber: 2,
              assignedTableCount: 3,
              completeTableCount: 3,
            ),
            assignments: [
              _bonusAssignment(eventId: event.id),
              _bonusAssignment(
                id: 'bonus_asg_02',
                eventId: event.id,
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Finals Tables'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finals Live'), findsOneWidget);
    expect(find.text('Finals'), findsOneWidget);
    expect(find.text('0 of 1 finals tables complete'), findsOneWidget);
    expect(find.text('1 finals table not started'), findsOneWidget);
    expect(find.text('Open Finals Tables'), findsOneWidget);
    expect(find.text('Scan Table'), findsNothing);
    expect(find.text('Tournament Live'), findsNothing);
    expect(find.text('Round 2'), findsNothing);
    expect(find.text('Start Next Round'), findsNothing);

    await tester.tap(find.text('Open Finals Tables'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, event.id);
    expect(openedArgs?.scoringPhase, EventScoringPhase.bonus);
  });

  testWidgets('completed finals with required sudden death opens tables',
      (tester) async {
    tester.view.physicalSize = const Size(800, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _SeatingRepository.generatedTournamentRoundCount = 0;
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'bonus',
    });
    TablesOverviewArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(event),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository:
              _TableRepository(tables: [_table(eventId: event.id)]),
          sessionRepository: _SessionRepository(
            sessions: [
              _session(
                id: 'ses_final',
                eventId: event.id,
                tableId: 'tbl_01',
                status: SessionStatus.completed,
              ),
            ],
          ),
          seatingRepository: _SeatingRepository(
            bonusRoundState: const BonusRoundState(
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
            ),
            assignments: [
              _bonusAssignment(eventId: event.id),
              _bonusAssignment(
                id: 'bonus_asg_02',
                eventId: event.id,
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Finals Tables'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death Required'), findsOneWidget);
    expect(find.textContaining('Alice Wong'), findsWidgets);
    expect(find.textContaining('Bob Lee'), findsWidgets);
    expect(find.text('Ready to complete event'), findsNothing);
    expect(find.text('Open Finals Tables'), findsOneWidget);

    final openFinalsTablesButton =
        find.widgetWithText(FilledButton, 'Open Finals Tables');
    await tester.tap(openFinalsTablesButton);
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, event.id);
    expect(openedArgs?.scoringPhase, EventScoringPhase.bonus);
    expect(_SeatingRepository.generatedTournamentRoundCount, 0);
  });

  testWidgets('dashboard opens finals tables when event phase is stale',
      (tester) async {
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });
    TablesOverviewArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(event),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository:
              _TableRepository(tables: [_table(eventId: event.id)]),
          sessionRepository: const _SessionRepository(),
          seatingRepository: _SeatingRepository(
            roundSummary: _roundSummary(
              roundNumber: 2,
              assignedTableCount: 0,
            ),
            assignments: [
              _bonusAssignment(eventId: event.id),
              _bonusAssignment(
                id: 'bonus_asg_02',
                eventId: event.id,
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.tablesOverviewRoute) {
            openedArgs = settings.arguments! as TablesOverviewArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Text('Opened Finals Tables'),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finals Live'), findsOneWidget);
    expect(find.text('Finals'), findsOneWidget);
    expect(find.text('0 of 1 finals tables complete'), findsOneWidget);
    expect(find.text('Open Finals Tables'), findsOneWidget);
    expect(find.text('Round 2'), findsNothing);

    await tester.tap(find.text('Open Finals Tables'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, event.id);
    expect(openedArgs?.scoringPhase, EventScoringPhase.bonus);
  });

  testWidgets('tournament dashboard starts next round when complete',
      (tester) async {
    _SeatingRepository.generatedTournamentRoundCount = 0;
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'tournament',
    });
    final seatingRepository = _SeatingRepository(
      roundSummary: _roundSummary(
        roundNumber: 2,
        assignedTableCount: 3,
        completeTableCount: 3,
      ),
      generatedAssignments: [_assignment(eventId: event.id)],
    );
    RouteSettings? openedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(event),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          seatingRepository: seatingRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.seatingAssignmentsRoute) {
            openedSettings = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Opened Seating')),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready to start next round'), findsOneWidget);
    await tester.tap(find.text('Start Next Round'));
    await tester.pumpAndSettle();

    expect(_SeatingRepository.generatedTournamentRoundCount, 1);
    expect(openedSettings?.name, AppRouter.seatingAssignmentsRoute);
    expect(
      (openedSettings?.arguments as SeatingAssignmentsArgs?)
          ?.initialAssignments,
      seatingRepository.generatedAssignments,
    );
  });

  testWidgets(
      'legacy qualification phase does not expose start tournament flow',
      (tester) async {
    _SeatingRepository.generatedRandomAssignmentCount = 0;
    _SeatingRepository.generatedTournamentRoundCount = 0;
    final event = EventRecord.fromJson({
      ...activeEvent.toJson(),
      'scoring_open': true,
      'current_scoring_phase': 'qualification',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: EventDashboardArgs(eventId: event.id),
          eventRepository: _EventRepository(
            event,
            onUpdateScoringPhase: (eventId, phase) async {
              return EventRecord.fromJson({
                ...event.toJson(),
                'current_scoring_phase': eventScoringPhaseToJson(phase),
              });
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          seatingRepository: const _SeatingRepository(),
          sessionRepository: const _SessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Tournament'), findsNothing);
    expect(find.byType(SeatingAssignmentScreen), findsNothing);
    expect(_SeatingRepository.generatedTournamentRoundCount, 0);
    expect(_SeatingRepository.generatedRandomAssignmentCount, 0);
  });

  testWidgets('completed event shows Finalize Event action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_02'),
          eventRepository: _EventRepository(
            completedEvent,
            onFinalize: (_) async => finalizedEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finalize Event'), findsOneWidget);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Review Before Finalizing'), findsOneWidget);
    expect(
      find.text('Review standings and locked prizes before finalizing.'),
      findsOneWidget,
    );
  });

  testWidgets('finalized event hides live operation actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_03'),
          eventRepository: _EventRepository(finalizedEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Results Locked'), findsOneWidget);
    expect(
      find.text('Standings and awards are locked for this event.'),
      findsOneWidget,
    );
    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Add Guest'), findsNothing);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Finalize Event'), findsNothing);
  });

  testWidgets('finalized event hides live scoring controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_03'),
          eventRepository: _EventRepository(finalizedEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Results Locked'), findsOneWidget);
    expect(find.text('Scoring Not Open'), findsNothing);
    expect(find.text('Check-In Not Open'), findsNothing);
    expect(find.text('Scoring Phase'), findsNothing);
    expect(find.text('Qualification'), findsNothing);
    expect(find.text('Tournament'), findsNothing);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('View Qualification Standings'), findsNothing);
  });

  testWidgets('blocked lifecycle error renders when completion fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(
            activeEvent,
            onComplete: (_) async {
              throw StateError(
                '1 active or paused session(s) must be ended before changing the event lifecycle.',
              );
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Complete Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete Event'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'End all active or paused sessions before changing the event phase.'),
      findsOneWidget,
    );
  });

  testWidgets('blocked tournament start error renders when setup is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(activeCheckinOnlyEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
          tableRepository: _TableRepository(
            tables: [_table(eventId: 'evt_04')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Tournament'));
    await tester.pumpAndSettle();

    expect(
      find.text('Seating setup is required to start tournament play.'),
      findsOneWidget,
    );
  });
}
