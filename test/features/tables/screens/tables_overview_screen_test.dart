import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/tables_overview_screen.dart';

class _FakeTableRepository implements TableRepository {
  _FakeTableRepository(this.tables);

  final List<EventTableRecord> tables;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    required this.sessions,
    this.details = const {},
  });

  final List<TableSessionRecord> sessions;
  final Map<String, SessionDetailRecord> details;

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
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      details[sessionId]!;

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
      details[sessionId];

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      sessions;

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

class _FakeGuestRepository implements GuestRepository {
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
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders an intentional empty state when no tables exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          tableRepository: _FakeTableRepository(const []),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tables yet'), findsOneWidget);
    expect(
      find.text('Add a table before starting live seating.'),
      findsOneWidget,
    );
    expect(find.text('Add Table'), findsOneWidget);
  });

  testWidgets('ready tagged tables explain scan-only session start',
      (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_01',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          tableRepository: tableRepository,
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Scan this table from the event dashboard to start seating.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Start Session'), findsNothing);
  });

  testWidgets('renders table cards and statuses', (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_points',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
      EventTableRecord.fromJson(const {
        'id': 'tbl_casual',
        'event_id': 'evt_01',
        'label': 'Table 2',
        'display_order': 2,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);
    final session = _session(id: 'ses_01', tableId: 'tbl_points');
    final sessionRepository = _FakeSessionRepository(
      sessions: [session],
      details: {
        'ses_01': _detail(session),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: tableRepository,
          sessionRepository: sessionRepository,
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Table 2'), findsOneWidget);
    expect(find.text('Points Table'), findsNothing);
    expect(find.text('Casual Table'), findsNothing);
    expect(find.text('Inactive Table'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Needs Tag'), findsOneWidget);
    expect(find.text('Casual play only'), findsNothing);
    expect(
        find.text('Bind this table tag before live seating.'), findsOneWidget);
    expect(find.text('Start Session'), findsNothing);
    expect(find.text('View Session'), findsOneWidget);
  });

  testWidgets('active table renders birdseye session summary', (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD_V1',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_points',
      currentDealerSeatIndex: 0,
      handCount: 3,
    );
    final detail = _detail(
      session,
      hands: [
        _hand(
          id: 'hand_01',
          handNumber: 1,
          winnerSeatIndex: 0,
          winType: 'discard',
          fanCount: 1,
          eastSeatIndex: 0,
        ),
        _hand(
          id: 'hand_02',
          handNumber: 2,
          winnerSeatIndex: 3,
          winType: 'self_draw',
          fanCount: 2,
          eastSeatIndex: 0,
        ),
        _hand(
          id: 'hand_03',
          handNumber: 3,
          winnerSeatIndex: 1,
          winType: 'self_draw',
          fanCount: 3,
          eastSeatIndex: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {'ses_01': detail},
          ),
          guestRepository: _FakeGuestRepository([
            _guest('guest_east', 'Alice Chen'),
            _guest('guest_south', 'Ben Wong'),
            _guest('guest_west', 'Chris Lee'),
            _guest('guest_north', 'Dana Park'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('East · Dealer'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    expect(find.text('Ben Wong'), findsOneWidget);
    expect(find.text('West'), findsOneWidget);
    expect(find.text('Chris Lee'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('Dana Park'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Hand 3'), findsOneWidget);
    expect(find.text('Last Result'), findsOneWidget);
    expect(find.text('Ben Wong self-draw'), findsOneWidget);
    expect(
        find.text('3 fan recorded. Ready for the next hand.'), findsOneWidget);
    expect(find.text('Tag Bound'), findsNothing);
    expect(find.text('Live Session'), findsNothing);
    expect(find.text('Start Session'), findsNothing);
    expect(find.text('View Session'), findsOneWidget);
  });

  testWidgets('paused table keeps birdseye summary and view action',
      (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD_V1',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(
      id: 'ses_01',
      tableId: 'tbl_points',
      status: 'paused',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {'ses_01': _detail(session)},
          ),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('View Session'), findsOneWidget);
    expect(find.text('Start Session'), findsNothing);
  });

  testWidgets('live table overflow surfaces missing tag warning',
      (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_points');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {'ses_01': _detail(session)},
          ),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tag Bound'), findsNothing);
    await tester.tap(find.byTooltip('Table options'));
    await tester.pumpAndSettle();

    expect(find.text('Tag missing'), findsOneWidget);
    expect(find.text('Bind table tag'), findsOneWidget);
  });

  testWidgets('long guest names do not overflow live cards', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD_V1',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_points');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {'ses_01': _detail(session)},
          ),
          guestRepository: _FakeGuestRepository([
            _guest('guest_east', 'Alexandria Very Long Mahjong Name'),
            _guest('guest_south', 'Ben Wong'),
            _guest('guest_west', 'Chris Lee'),
            _guest('guest_north', 'Dana Park'),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('active table session can be opened from tables view',
      (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_points',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);
    final session = _session(id: 'ses_01', tableId: 'tbl_points');
    final sessionRepository = _FakeSessionRepository(
      sessions: [session],
      details: {
        'ses_01': _detail(session),
      },
    );

    SessionDetailArgs? openedArgs;
    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: tableRepository,
          sessionRepository: sessionRepository,
          guestRepository: _FakeGuestRepository(const []),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.sessionDetailRoute) {
            openedArgs = settings.arguments! as SessionDetailArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Session Detail'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Session'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.sessionId, 'ses_01');
    expect(find.text('Opened Session Detail'), findsOneWidget);
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
  int currentDealerSeatIndex = 0,
  int handCount = 0,
}) {
  return TableSessionRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'event_table_id': tableId,
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD_V1',
    'ruleset_version': 1,
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': const {},
    'status': status,
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': currentDealerSeatIndex,
    'dealer_pass_count': 0,
    'completed_games_count': 0,
    'hand_count': handCount,
    'started_at': '2026-04-24T19:00:00-07:00',
    'started_by_user_id': 'usr_01',
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

TableSessionSeatRecord _seat(int index, String guestId) {
  return TableSessionSeatRecord.fromJson({
    'id': 'seat_$index',
    'table_session_id': 'ses_01',
    'seat_index': index,
    'initial_wind': ['east', 'south', 'west', 'north'][index],
    'event_guest_id': guestId,
  });
}

HandResultRecord _hand({
  required String id,
  required int handNumber,
  required int winnerSeatIndex,
  required String winType,
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
    'status': 'recorded',
    'entered_by_user_id': 'usr_01',
    'entered_at': '2026-04-24T19:30:00-07:00',
  });
}
