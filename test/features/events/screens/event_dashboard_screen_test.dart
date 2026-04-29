import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/activity/screens/activity_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:mosaic/features/scoring/screens/session_detail_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _EventRepository implements EventRepository {
  _EventRepository(
    this.event, {
    this.onComplete,
    this.onFinalize,
    this.onStart,
    this.onSetOperationalFlags,
    this.onCancel,
    this.onRevertToDraft,
    this.onDelete,
  });

  EventRecord event;
  final Future<EventRecord> Function(String eventId)? onComplete;
  final Future<EventRecord> Function(String eventId)? onFinalize;
  final Future<EventRecord> Function(String eventId)? onStart;
  final Future<EventRecord> Function(String eventId)? onCancel;
  final Future<EventRecord> Function(String eventId)? onRevertToDraft;
  final Future<void> Function(String eventId)? onDelete;
  final Future<EventRecord> Function(
    String eventId,
    bool checkinOpen,
    bool scoringOpen,
  )? onSetOperationalFlags;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
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
    final handler = onSetOperationalFlags;
    if (handler != null) {
      event = await handler(eventId, checkinOpen, scoringOpen);
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

class _GuestRepository implements GuestRepository {
  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

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
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

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
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

class _LeaderboardRepository implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      const [];

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      const [];
}

class _ActivityRepository implements ActivityRepository {
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

class _PrizeRepository implements PrizeRepository {
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

class _TableRepository implements TableRepository {
  const _TableRepository({
    this.resolvedTable,
    this.resolveError,
  });

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
  Future<List<EventTableRecord>> listTables(String eventId) async => const [];

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      const [];

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

class _SessionRepository implements SessionRepository {
  const _SessionRepository({
    this.sessions = const [],
  });

  final List<TableSessionRecord> sessions;

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
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

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

class _NfcService implements NfcService {
  const _NfcService({
    this.tableScanResult,
  });

  final TagScanResult? tableScanResult;

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
    BuildContext context,
  ) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async =>
      null;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async =>
      tableScanResult;
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  bool didPopRoute = false;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    didPopRoute = true;
    super.didPop(route, previousRoute);
  }
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
    'default_ruleset_id': 'HK_STANDARD_V1',
    'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'default_rotation_policy_config_json': const {},
  });
}

TableSessionRecord _session({
  required String id,
  String eventId = 'evt_01',
  String tableId = 'tbl_01',
  SessionStatus status = SessionStatus.active,
}) {
  return TableSessionRecord(
    id: id,
    eventId: eventId,
    eventTableId: tableId,
    sessionNumberForTable: 1,
    rulesetId: 'HK_STANDARD_V1',
    rulesetVersion: 1,
    rotationPolicyType: RotationPolicyType.dealerCycleReturnToInitialEast,
    rotationPolicyConfig: const {},
    status: status,
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
  PrizeRepository? prizeRepository,
  TableRepository? tableRepository,
  SessionRepository? sessionRepository,
  NfcService? nfcService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EventDashboardScreen(
        args: EventDashboardArgs(eventId: event.id),
        eventRepository: _EventRepository(event),
        guestRepository: _GuestRepository(),
        leaderboardRepository: _LeaderboardRepository(),
        prizeRepository: prizeRepository,
        tableRepository: tableRepository,
        sessionRepository: sessionRepository,
        nfcService: nfcService,
      ),
    ),
  );
  await tester.pumpAndSettle();
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
    'default_ruleset_id': 'HK_STANDARD_V1',
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
    'default_ruleset_id': 'HK_STANDARD_V1',
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
    'default_ruleset_id': 'HK_STANDARD_V1',
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
    'default_ruleset_id': 'HK_STANDARD_V1',
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
    'default_ruleset_id': 'HK_STANDARD_V1',
    'prevailing_wind': 'east',
  });

  testWidgets('dashboard exposes a prizes action', (tester) async {
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

    expect(find.text('Prizes'), findsOneWidget);
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

    await tester.ensureVisible(find.text('Prizes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prizes'));
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

    await tester.ensureVisible(find.text('Prizes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prizes'));
    await tester.pumpAndSettle();

    expect(find.byType(PrizePlanScreen), findsOneWidget);
    expect(find.text('Total Prizes'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
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
    expect(find.text('Session Detail'), findsOneWidget);
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
    expect(find.text('Resume Session'), findsOneWidget);
  });

  testWidgets('scan table starts preverified table flow at east player prompt',
      (tester) async {
    final table = _table();
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(resolvedTable: table),
      sessionRepository: const _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
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
    expect(find.text('Scan East Player Tag'), findsOneWidget);
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
          tableRepository: const _TableRepository(
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
      prizeRepository: _PrizeRepository(
        loadedPlan: _fixedPrizePlan([17500]),
      ),
      tableRepository: _TableRepository(resolvedTable: _table()),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text(activeEvent.title), findsOneWidget);
    expect(find.text('Event Phase'), findsNothing);
    expect(
      find.text(
        'Use the live operations controls to open or close check-in and scoring during the event.',
      ),
      findsOneWidget,
    );
    expect(find.text('Scoring Open'), findsOneWidget);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Guests'), findsWidgets);
    expect(find.text('Prize Pool'), findsOneWidget);
    expect(find.text('Scan Table'), findsOneWidget);
    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Live Operations'), findsOneWidget);
    expect(find.text('Close Scoring'), findsOneWidget);
    expect(find.text('Event options'), findsOneWidget);

    final scanTop = tester.getTopLeft(find.text('Scan Table')).dy;
    final guestsTop = tester.getTopLeft(find.text('Guests').last).dy;
    final optionsTop = tester.getTopLeft(find.text('Event options')).dy;

    expect(scanTop, lessThan(guestsTop));
    expect(guestsTop, lessThan(optionsTop));
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
    expect(find.text('Check-In Closed'), findsOneWidget);
    expect(find.text('Scoring Closed'), findsOneWidget);
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
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Closed'), findsOneWidget);
    expect(find.text('Finalize Event'), findsOneWidget);
    expect(find.text('Event options'), findsOneWidget);
  });

  testWidgets('check-in open scoring closed does not make scan table the hero',
      (tester) async {
    await _pumpDashboard(
      tester,
      event: activeCheckinOnlyEvent,
      tableRepository:
          _TableRepository(resolvedTable: _table(eventId: 'evt_04')),
      sessionRepository: const _SessionRepository(),
      nfcService: _NfcService(tableScanResult: _tableScanResult()),
    );

    expect(find.text('Open Scoring'), findsOneWidget);
    expect(find.text('Scan Table'), findsOneWidget);

    final openScoringTop = tester.getTopLeft(find.text('Open Scoring')).dy;
    final scanTableTop = tester.getTopLeft(find.text('Scan Table')).dy;

    expect(openScoringTop, lessThan(scanTableTop));
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

  testWidgets('starting a draft event enables live controls', (tester) async {
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
    expect(find.text('Scoring Closed'), findsOneWidget);
    expect(find.text('Close Check-In'), findsNothing);
    expect(find.text('Open Scoring'), findsOneWidget);
  });

  testWidgets('active event exposes operational flag actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(
            activeCheckinOnlyEvent,
            onSetOperationalFlags: (_, checkinOpen, scoringOpen) async {
              return EventRecord.fromJson({
                ...activeCheckinOnlyEvent.toJson(),
                'checkin_open': checkinOpen,
                'scoring_open': scoringOpen,
              });
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Operations'), findsOneWidget);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Closed'), findsOneWidget);
    expect(find.text('Close Check-In'), findsNothing);
    expect(find.text('Open Scoring'), findsOneWidget);

    await tester.ensureVisible(find.text('Open Scoring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Scoring'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('Scoring Open'), findsOneWidget);
    expect(find.text('Close Scoring'), findsOneWidget);
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
    expect(find.text('Tables'), findsNothing);
    expect(find.text('Add Guest'), findsNothing);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Finalize Event'), findsNothing);
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

  testWidgets('blocked operational flag error renders when update fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(
            activeCheckinOnlyEvent,
            onSetOperationalFlags: (_, __, ___) async {
              throw StateError(
                  'Scoring can only open while the event is active.');
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Scoring'));
    await tester.pumpAndSettle();

    expect(
      find.text('Scoring can only open while the event is active.'),
      findsOneWidget,
    );
  });
}
