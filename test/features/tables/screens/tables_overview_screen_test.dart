import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/screens/tables_overview_screen.dart';

class _FakeTableRepository extends ThrowingTableRepository {
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

class _FakeSessionRepository extends ThrowingSessionRepository {
  _FakeSessionRepository({
    required this.sessions,
    this.details = const {},
    this.sessionsAfterBulkStart = const [],
  });

  List<TableSessionRecord> sessions;
  final Map<String, SessionDetailRecord> details;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  final pausedSessionIds = <String>[];
  final resumedSessionIds = <String>[];
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
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      sessions;

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async =>
      details[sessionId]!;

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async {
    pausedSessionIds.add(sessionId);
    final detail = _updatedDetail(sessionId, SessionStatus.paused);
    details[sessionId] = detail;
    _replaceSession(detail.session);
    return detail;
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
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      sessions;

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    bulkStartCallCount += 1;
    sessions = sessionsAfterBulkStart;
    return sessionsAfterBulkStart;
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async {
    resumedSessionIds.add(sessionId);
    final detail = _updatedDetail(sessionId, SessionStatus.active);
    details[sessionId] = detail;
    _replaceSession(detail.session);
    return detail;
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }

  SessionDetailRecord _updatedDetail(
    String sessionId,
    SessionStatus status,
  ) {
    final existing = details[sessionId]!;
    return SessionDetailRecord.fromJson({
      ...existing.toJson(),
      'session': {
        ...existing.session.toJson(),
        'status': _sessionStatusJson(status),
      },
    });
  }

  void _replaceSession(TableSessionRecord updatedSession) {
    final index = sessions.indexWhere(
      (session) => session.id == updatedSession.id,
    );
    if (index >= 0) {
      sessions[index] = updatedSession;
    }
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

String _sessionStatusJson(SessionStatus status) {
  return switch (status) {
    SessionStatus.active => 'active',
    SessionStatus.paused => 'paused',
    SessionStatus.completed => 'completed',
    SessionStatus.endedEarly => 'ended_early',
    SessionStatus.aborted => 'aborted',
  };
}

Future<void> _scrollTablesOverviewUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Offset moveStep = const Offset(0, -300),
}) async {
  await tester.dragUntilVisible(
    finder,
    find.byKey(const ValueKey('tables-overview-list')),
    moveStep,
  );
  await tester.pumpAndSettle();
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    required this.summary,
    this.assignments = const [],
    this.bonusRoundState,
    this.suddenDeathAssignments = const [],
  });

  TournamentRoundSummary summary;
  List<SeatingAssignmentRecord> assignments;
  BonusRoundState? bonusRoundState;
  List<SeatingAssignmentRecord> suddenDeathAssignments;
  int generateCount = 0;
  int loadCount = 0;
  final startedSuddenDeathTables = <String>[];

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      assignments;

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      assignments;

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async =>
      summary;

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async {
    loadCount += 1;
    return summary;
  }

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async =>
      bonusRoundState;

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    generateCount += 1;
    return const [];
  }

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

  testWidgets('legacy qualification table entry opens directly',
      (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_01',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);
    StartSessionArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.qualification,
          tableRepository: tableRepository,
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.startSessionRoute) {
            openedArgs = settings.arguments! as StartSessionArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Legacy Qualification Table'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('table-card-tbl_01')), findsOneWidget);
    expect(
      find.text(
        'Ready for assigned tournament seating. Enter the table to start assigned play.',
      ),
      findsOneWidget,
    );
    expect(find.text('Ready'), findsOneWidget);
    expect(
      find.text('Scan this table from the event dashboard to start seating.'),
      findsNothing,
    );

    await tester.tap(find.text('Enter Table'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.table.id, 'tbl_01');
    expect(openedArgs?.scoringPhase, EventScoringPhase.qualification);
    expect(openedArgs?.allowAssignedTableEntry, isFalse);
    expect(find.text('Opened Legacy Qualification Table'), findsOneWidget);
  });

  testWidgets('read-only table overview hides table mutation actions',
      (tester) async {
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
      status: 'completed',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          readOnly: true,
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

    expect(find.text('Add Table'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Bind Tag'), findsNothing);
    expect(find.text('History'), findsOneWidget);
    expect(
      find.text(
        'This event is locked. Tables and tag bindings can no longer be changed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders table cards and statuses', (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_points',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
      EventTableRecord.fromJson(const {
        'id': 'tbl_casual',
        'event_id': 'evt_01',
        'label': 'Table 2',
        'display_order': 2,
        'default_ruleset_id': 'HK_STANDARD',
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
    await _scrollTablesOverviewUntilVisible(tester, find.text('Table 2'));
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
      'default_ruleset_id': 'HK_STANDARD',
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
          fanCount: 3,
          eastSeatIndex: 0,
        ),
        _hand(
          id: 'hand_02',
          handNumber: 2,
          winnerSeatIndex: 3,
          winType: 'self_draw',
          fanCount: 4,
          eastSeatIndex: 0,
        ),
        _hand(
          id: 'hand_03',
          handNumber: 3,
          winnerSeatIndex: 1,
          winType: 'self_draw',
          fanCount: 5,
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

    expect(find.byKey(const ValueKey('table-card-tbl_points')), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('East · Dealer'), findsNothing);
    expect(find.text('East'), findsOneWidget);
    expect(find.text('Dealer'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    expect(find.text('Ben Wong'), findsOneWidget);
    expect(find.text('West'), findsOneWidget);
    expect(find.text('Chris Lee'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('Dana Park'), findsOneWidget);
    expect(find.text('Progress'), findsNothing);
    expect(find.text('Hand 3'), findsOneWidget);
    expect(find.text('Last Result'), findsOneWidget);
    expect(find.text('Ben Wong self-draw'), findsOneWidget);
    expect(
        find.text('5 fan recorded. Ready for the next hand.'), findsOneWidget);
    expect(find.text('Tag Bound'), findsNothing);
    expect(find.text('Live Session'), findsNothing);
    expect(find.text('Start Session'), findsNothing);
    expect(find.text('View Session'), findsOneWidget);
  });

  testWidgets('live table seats render counter-clockwise around the table',
      (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
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
      tableId: 'tbl_points',
      currentDealerSeatIndex: 0,
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

    final alice = tester.getCenter(find.text('Alice Chen'));
    final ben = tester.getCenter(find.text('Ben Wong'));
    final chris = tester.getCenter(find.text('Chris Lee'));
    final dana = tester.getCenter(find.text('Dana Park'));

    expect(alice.dx, lessThan(dana.dx));
    expect(alice.dy, lessThan(ben.dy));
    expect(ben.dx, lessThan(chris.dx));
    expect(dana.dy, lessThan(chris.dy));
  });

  testWidgets('live table shows expired round timer', (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
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
      tableId: 'tbl_points',
      scoringPhase: EventScoringPhase.tournament,
      startedAt: DateTime.now()
          .subtract(const Duration(minutes: 61))
          .toIso8601String(),
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

    expect(find.text('Time expired'), findsOneWidget);
  });

  testWidgets('live table can pause and resume its timer', (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
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
      tableId: 'tbl_points',
      scoringPhase: EventScoringPhase.tournament,
      startedAt: DateTime.now()
          .subtract(const Duration(minutes: 30))
          .toIso8601String(),
    );
    final sessionRepository = _FakeSessionRepository(
      sessions: [session],
      details: {'ses_01': _detail(session)},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: sessionRepository,
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pause Timer'));
    await tester.pumpAndSettle();

    expect(sessionRepository.pausedSessionIds, ['ses_01']);
    expect(find.text('Resume Timer'), findsOneWidget);

    await tester.tap(find.text('Resume Timer'));
    await tester.pumpAndSettle();

    expect(sessionRepository.resumedSessionIds, ['ses_01']);
    expect(find.text('Pause Timer'), findsOneWidget);
  });

  testWidgets('legacy qualification table hides round timer', (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
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
      tableId: 'tbl_points',
      scoringPhase: EventScoringPhase.qualification,
      startedAt: DateTime.now()
          .subtract(const Duration(minutes: 61))
          .toIso8601String(),
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

    expect(find.text('Time expired'), findsNothing);
    expect(find.text('59:00'), findsNothing);
  });

  testWidgets('paused table keeps birdseye summary and view action',
      (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
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
      'default_ruleset_id': 'HK_STANDARD',
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
      'default_ruleset_id': 'HK_STANDARD',
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

  testWidgets('last result spans the live card width and can wrap',
      (tester) async {
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
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final session = _session(id: 'ses_01', tableId: 'tbl_points');
    final lastResultTitle = 'Alexandria Very Long Mahjong Name discard';

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {
              'ses_01': _detail(
                session,
                hands: [
                  _hand(
                    id: 'hand_01',
                    handNumber: 1,
                    winnerSeatIndex: 0,
                    winType: 'discard',
                  ),
                ],
              ),
            },
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

    final titleWidget = tester.widget<Text>(find.text(lastResultTitle));
    expect(titleWidget.maxLines, 2);
    expect(titleWidget.overflow, TextOverflow.ellipsis);
    expect(find.text('Progress'), findsNothing);
    expect(
      (tester.getTopLeft(find.text('Hand 1')).dx -
              tester.getTopLeft(find.text('Table 1')).dx)
          .abs(),
      lessThan(2),
    );
    expect(
      tester.getTopLeft(find.text('Hand 1')).dy,
      greaterThan(tester.getBottomLeft(find.text('Table 1')).dy),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('live-last-result-summary')))
          .width,
      greaterThan(320),
    );
    expect(tester.getSize(find.text(lastResultTitle)).width, greaterThan(280));
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
        'default_ruleset_id': 'HK_STANDARD',
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

  testWidgets('shows tournament round board and groups current round tables',
      (tester) async {
    final currentActive = _table('tbl_active', 'Table 1', order: 1);
    final currentReady = _table('tbl_ready', 'Table 2', order: 2);
    final currentComplete = _table('tbl_done', 'Table 3', order: 3);
    final openPlay = _table('tbl_open', 'Open Play', order: 4);
    final activeSession = _session(
      id: 'ses_active',
      tableId: currentActive.id,
      handCount: 2,
      currentDealerSeatIndex: 0,
      scoringPhase: EventScoringPhase.tournament,
      startedAt: '2026-04-24T19:00:00-07:00',
    );
    final completeSession = _session(
      id: 'ses_done',
      tableId: currentComplete.id,
      status: 'completed',
      handCount: 4,
      scoringPhase: EventScoringPhase.tournament,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([
            currentActive,
            currentReady,
            currentComplete,
            openPlay,
          ]),
          sessionRepository: _FakeSessionRepository(
            sessions: [activeSession, completeSession],
            details: {'ses_active': _detail(activeSession)},
          ),
          guestRepository: _FakeGuestRepository([
            _guest('guest_east', 'Alice Chen'),
            _guest('guest_south', 'Ben Wong'),
            _guest('guest_west', 'Chris Lee'),
            _guest('guest_north', 'Dana Park'),
          ]),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              status: TournamentRoundStatus.active,
              complete: 1,
              active: 1,
              notStarted: 1,
              currentTables: [
                _roundTable(
                  table: currentActive,
                  status: TournamentRoundTableStatus.active,
                  activeSessionId: 'ses_active',
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
                _roundTable(
                  table: currentReady,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Chris Lee', 'Dana Park'],
                ),
                _roundTable(
                  table: currentComplete,
                  status: TournamentRoundTableStatus.complete,
                  latestEndedSessionId: 'ses_done',
                  names: const ['Eli Ho', 'Fran Ng'],
                ),
              ],
            ),
          ),
          now: () => DateTime.parse('2026-04-24T19:01:00-07:00'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round 2'), findsOneWidget);
    expect(find.text('1 Complete'), findsOneWidget);
    expect(find.text('1 In Progress'), findsOneWidget);
    expect(find.text('1 Not Started'), findsOneWidget);
    expect(find.text('1 / 3 tables complete'), findsOneWidget);
    expect(find.text('Current Round'), findsOneWidget);
    expect(find.text('East seat'), findsOneWidget);
    expect(find.text('South seat'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('Ben Wong'), findsOneWidget);
    expect(find.text('Alice Chen, Ben Wong'), findsNothing);
    expect(find.text('Hand 2'), findsOneWidget);
    expect(find.text('59:00'), findsOneWidget);
    expect(find.text('Round Wind: East'), findsOneWidget);
    expect(find.text('Dealer: Alice Chen'), findsOneWidget);
    expect(find.text('Open Session'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(tester, find.text('Chris Lee'));

    expect(find.text('Chris Lee'), findsOneWidget);
    expect(find.text('Dana Park'), findsOneWidget);
    expect(find.text('Chris Lee, Dana Park'), findsNothing);
    expect(find.text('Enter Table'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(tester, find.text('Eli Ho'));

    expect(find.text('Eli Ho'), findsOneWidget);
    expect(find.text('Fran Ng'), findsOneWidget);
    expect(find.text('Eli Ho, Fran Ng'), findsNothing);
    expect(find.text('Hand 4'), findsOneWidget);
    expect(find.text('View Session'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(tester, find.text('Other Tables'));

    expect(find.text('Other Tables'), findsOneWidget);
    expect(find.text('Open Play'), findsOneWidget);
    expect(find.text('Start Next Round'), findsNothing);
  });

  testWidgets('seated tournament round starts all tables from tables view',
      (tester) async {
    final table = _table('tbl_ready', 'Table 2', order: 2);
    final startedSession = _session(
      id: 'ses_round_02',
      tableId: table.id,
      scoringPhase: EventScoringPhase.tournament,
      assignmentRound: 2,
    );
    final sessionRepository = _FakeSessionRepository(
      sessions: const [],
      sessionsAfterBulkStart: [startedSession],
      details: {'ses_round_02': _detail(startedSession)},
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: sessionRepository,
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              status: TournamentRoundStatus.seating,
              assigned: 1,
              notStarted: 1,
              currentTables: [
                _roundTable(
                  table: table,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Chris Lee', 'Dana Park'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start All Tables'), findsOneWidget);
    expect(find.text('Start Next Round'), findsNothing);

    await tester.tap(find.text('Start All Tables'));
    await tester.pumpAndSettle();

    expect(sessionRepository.bulkStartCallCount, 1);
    expect(find.text('Start All Tables'), findsNothing);
  });

  testWidgets('paused current-round card shows open action, timer, and dealer',
      (tester) async {
    final table = _table('tbl_paused', 'Table 4');
    final session = _session(
      id: 'ses_paused',
      tableId: table.id,
      status: 'paused',
      currentDealerSeatIndex: 1,
      scoringPhase: EventScoringPhase.tournament,
      startedAt: '2026-04-24T19:00:00-07:00',
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
            details: {'ses_paused': _detail(session)},
          ),
          guestRepository: _FakeGuestRepository([
            _guest('guest_east', 'Alice Chen'),
            _guest('guest_south', 'Ben Wong'),
            _guest('guest_west', 'Chris Lee'),
            _guest('guest_north', 'Dana Park'),
          ]),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              paused: 1,
              currentTables: [
                _roundTable(
                  table: table,
                  status: TournamentRoundTableStatus.paused,
                  activeSessionId: 'ses_paused',
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
              ],
            ),
          ),
          now: () => DateTime.parse('2026-04-24T19:01:00-07:00'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Open Session'), findsOneWidget);
    expect(find.text('View Session'), findsNothing);
    expect(find.text('59:00'), findsOneWidget);
    expect(find.text('Round Wind: East'), findsOneWidget);
    expect(find.text('Dealer: Ben Wong'), findsOneWidget);
  });

  testWidgets('current round board can pause and resume all table timers',
      (tester) async {
    final activeTable = _table('tbl_active', 'Table 1');
    final pausedTable = _table('tbl_paused', 'Table 2', order: 2);
    final activeSession = _session(
      id: 'ses_active',
      tableId: activeTable.id,
      scoringPhase: EventScoringPhase.tournament,
    );
    final pausedSession = _session(
      id: 'ses_paused',
      tableId: pausedTable.id,
      status: 'paused',
      scoringPhase: EventScoringPhase.tournament,
    );
    final sessionRepository = _FakeSessionRepository(
      sessions: [activeSession, pausedSession],
      details: {
        'ses_active': _detail(activeSession),
        'ses_paused': _detail(pausedSession),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([activeTable, pausedTable]),
          sessionRepository: sessionRepository,
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              active: 1,
              paused: 1,
              currentTables: [
                _roundTable(
                  table: activeTable,
                  status: TournamentRoundTableStatus.active,
                  activeSessionId: 'ses_active',
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
                _roundTable(
                  table: pausedTable,
                  status: TournamentRoundTableStatus.paused,
                  activeSessionId: 'ses_paused',
                  names: const ['Chris Lee', 'Dana Park'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pause All Timers'), findsOneWidget);
    expect(find.text('Resume All Timers'), findsOneWidget);

    await tester.tap(find.text('Pause All Timers'));
    await tester.pumpAndSettle();

    expect(sessionRepository.pausedSessionIds, ['ses_active']);

    await tester.tap(find.text('Resume All Timers'));
    await tester.pumpAndSettle();

    expect(sessionRepository.resumedSessionIds, ['ses_active', 'ses_paused']);
  });

  testWidgets('enter table fallback opens assigned tournament start flow',
      (tester) async {
    final table = _table('tbl_ready', 'Table 2');
    StartSessionArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              notStarted: 1,
              currentTables: [
                _roundTable(
                  table: table,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Chris Lee', 'Dana Park'],
                ),
              ],
            ),
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.startSessionRoute) {
            openedArgs = settings.arguments! as StartSessionArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Start Session'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTablesOverviewUntilVisible(tester, find.text('Enter Table'));
    await tester.tap(find.text('Enter Table'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.table.id, 'tbl_ready');
    expect(openedArgs?.scoringPhase, EventScoringPhase.tournament);
    expect(openedArgs?.allowAssignedTableEntry, isTrue);
    expect(find.text('Opened Start Session'), findsOneWidget);
  });

  testWidgets('completed round offers next round and finals actions',
      (tester) async {
    final table = _table('tbl_done', 'Table 1');
    final session = _session(
      id: 'ses_done',
      tableId: table.id,
      status: 'completed',
      handCount: 4,
      scoringPhase: EventScoringPhase.tournament,
    );
    final seatingRepository = _FakeSeatingRepository(
      summary: _roundSummary(
        status: TournamentRoundStatus.complete,
        assigned: 1,
        complete: 1,
        currentTables: [
          _roundTable(
            table: table,
            status: TournamentRoundTableStatus.complete,
            latestEndedSessionId: 'ses_done',
            names: const ['Alice Chen', 'Ben Wong'],
          ),
        ],
      ),
    );
    RouteSettings? openedSettings;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: [session]),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: seatingRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.bonusRoundRoute) {
            openedSettings = settings;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Opened Finals')),
              settings: settings,
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Next Round'), findsOneWidget);
    expect(find.text('Begin Finals'), findsOneWidget);

    await tester.tap(find.text('Begin Finals'));
    await tester.pumpAndSettle();

    expect(openedSettings?.name, AppRouter.bonusRoundRoute);
    expect((openedSettings?.arguments as BonusRoundArgs?)?.eventId, 'evt_01');
    expect(find.text('Opened Finals'), findsOneWidget);

    Navigator.of(tester.element(find.text('Opened Finals'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Next Round'));
    await tester.pumpAndSettle();

    expect(seatingRepository.generateCount, 1);
    expect(seatingRepository.loadCount, greaterThanOrEqualTo(2));
  });

  testWidgets('completed current-round board hides bulk timer actions',
      (tester) async {
    final tableOne = _table('tbl_done_1', 'Table 1');
    final tableTwo = _table('tbl_done_2', 'Table 2', order: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([tableOne, tableTwo]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              status: TournamentRoundStatus.complete,
              assigned: 2,
              complete: 2,
              active: 0,
              paused: 0,
              notStarted: 0,
              currentTables: [
                _roundTable(
                  table: tableOne,
                  status: TournamentRoundTableStatus.complete,
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
                _roundTable(
                  table: tableTwo,
                  status: TournamentRoundTableStatus.complete,
                  names: const ['Chris Lee', 'Dana Park'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round 2'), findsOneWidget);
    expect(find.text('Complete'), findsAtLeastNWidgets(1));
    expect(find.text('2 / 2 tables complete'), findsOneWidget);
    expect(find.text('Start Next Round'), findsOneWidget);
    expect(find.text('Begin Finals'), findsOneWidget);
    expect(find.text('Pause All Timers'), findsNothing);
    expect(find.text('Resume All Timers'), findsNothing);
    expect(find.text('Table 1'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(tester, find.text('Table 2'));
    expect(find.text('Table 2'), findsOneWidget);
  });

  testWidgets('finals mode renders finals assignments instead of stale round',
      (tester) async {
    final table = _table('tbl_champions', 'Table 1');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              status: TournamentRoundStatus.complete,
              assigned: 1,
              complete: 1,
            ),
            assignments: [
              _bonusAssignment(
                table: table,
                seatIndex: 0,
                displayName: 'Seed Four',
                seedRank: 4,
              ),
              _bonusAssignment(
                table: table,
                seatIndex: 1,
                displayName: 'Seed Three',
                seedRank: 3,
              ),
              _bonusAssignment(
                table: table,
                seatIndex: 2,
                displayName: 'Seed Two',
                seedRank: 2,
              ),
              _bonusAssignment(
                table: table,
                seatIndex: 3,
                displayName: 'Seed One',
                seedRank: 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finals'), findsOneWidget);
    expect(find.text('Round 2'), findsNothing);
    expect(find.text('Start Next Round'), findsNothing);
    expect(find.text('Finals Tables'), findsOneWidget);
    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Seed Four'), findsOneWidget);
    expect(find.text('Seed One'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.text('Enter Table'), findsOneWidget);
  });

  testWidgets('active finals assignments override stale tournament phase',
      (tester) async {
    final table = _table('tbl_champions', 'Table 1');
    final session = _session(
      id: 'ses_bonus',
      tableId: table.id,
      scoringPhase: EventScoringPhase.bonus,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.tournament,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: [session]),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(),
            assignments: [
              _bonusAssignment(
                table: table,
                seatIndex: 0,
                displayName: 'Seed Four',
                seedRank: 4,
              ),
              _bonusAssignment(
                table: table,
                seatIndex: 1,
                displayName: 'Seed Three',
                seedRank: 3,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finals'), findsOneWidget);
    expect(find.text('Round 2'), findsNothing);
    expect(find.text('Finals Tables'), findsOneWidget);
    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('In Progress'), findsWidgets);
    expect(find.text('Ready'), findsNothing);
    expect(
        find.text('Scan this table from the event dashboard to start seating.'),
        findsNothing);
  });

  testWidgets('finals enter table opens assigned bonus start flow',
      (tester) async {
    final table = _table('tbl_champions', 'Table 1');
    StartSessionArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: TournamentRoundSummary.empty(),
            assignments: [
              _bonusAssignment(
                table: table,
                seatIndex: 0,
                displayName: 'Seed Four',
                seedRank: 4,
              ),
              _bonusAssignment(
                table: table,
                seatIndex: 1,
                displayName: 'Seed Three',
                seedRank: 3,
              ),
            ],
          ),
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.startSessionRoute) {
            openedArgs = settings.arguments! as StartSessionArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Start Session'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTablesOverviewUntilVisible(tester, find.text('Enter Table'));
    await tester.tap(find.text('Enter Table'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.table.id, 'tbl_champions');
    expect(openedArgs?.scoringPhase, EventScoringPhase.bonus);
    expect(openedArgs?.allowAssignedTableEntry, isTrue);
  });

  testWidgets('required sudden death starts from current finals table',
      (tester) async {
    final table = _table('tbl_sudden', 'Table 9');
    final returnedAssignments = [
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
    ];
    final seatingRepository = _FakeSeatingRepository(
      summary: TournamentRoundSummary.empty(),
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
      suddenDeathAssignments: returnedAssignments,
    );
    SeatingAssignmentsArgs? openedAssignmentsArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: seatingRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.seatingAssignmentsRoute) {
            openedAssignmentsArgs =
                settings.arguments! as SeatingAssignmentsArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Seating Assignments'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death Required'), findsOneWidget);
    expect(find.text('Start Next Round'), findsNothing);
    expect(find.text('Finals Tables'), findsOneWidget);
    expect(find.text('Table of Champions Sudden Death'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('Ben Wong'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(
      tester,
      find.text('Start Sudden Death'),
    );
    await tester.tap(find.text('Start Sudden Death'));
    await tester.pumpAndSettle();

    expect(seatingRepository.startedSuddenDeathTables, ['tbl_sudden']);
    expect(openedAssignmentsArgs?.eventId, 'evt_01');
    expect(openedAssignmentsArgs?.initialAssignments, returnedAssignments);
    expect(find.text('Opened Seating Assignments'), findsOneWidget);
  });

  testWidgets('required sudden death can reuse completed champions table',
      (tester) async {
    final table = _table('tbl_champions', 'Table 1');
    final completedChampionsSession = _session(
      id: 'ses_champions',
      tableId: table.id,
      status: 'completed',
      scoringPhase: EventScoringPhase.bonus,
      handCount: 4,
    );
    final returnedAssignments = [
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
    ];
    final seatingRepository = _FakeSeatingRepository(
      summary: TournamentRoundSummary.empty(),
      assignments: [
        _bonusAssignment(
          table: table,
          seatIndex: 0,
          displayName: 'Alice Chen',
          seedRank: 1,
        ),
        _bonusAssignment(
          table: table,
          seatIndex: 1,
          displayName: 'Ben Wong',
          seedRank: 2,
        ),
      ],
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        suddenDeathStatus: 'required',
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
      suddenDeathAssignments: returnedAssignments,
    );
    SeatingAssignmentsArgs? openedAssignmentsArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [completedChampionsSession],
          ),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: seatingRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.seatingAssignmentsRoute) {
            openedAssignmentsArgs =
                settings.arguments! as SeatingAssignmentsArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Seating Assignments'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death Required'), findsOneWidget);
    expect(find.text('Table of Champions'), findsOneWidget);
    expect(find.text('Not Started'), findsWidgets);
    expect(find.text('View Session'), findsNothing);
    expect(find.text('Start Sudden Death'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(
      tester,
      find.text('Start Sudden Death'),
    );
    await tester.tap(find.text('Start Sudden Death'));
    await tester.pumpAndSettle();

    expect(seatingRepository.startedSuddenDeathTables, ['tbl_champions']);
    expect(openedAssignmentsArgs?.initialAssignments, returnedAssignments);
    expect(find.text('Opened Seating Assignments'), findsOneWidget);
  });

  testWidgets('required sudden death can start from a ready table',
      (tester) async {
    final table = _table('tbl_sudden', 'Table 9');
    final returnedAssignments = [
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
    ];
    final seatingRepository = _FakeSeatingRepository(
      summary: TournamentRoundSummary.empty(),
      bonusRoundState: const BonusRoundState(
        bonusRoundId: 'bonus_01',
        eventId: 'evt_01',
        status: 'active',
        suddenDeathStatus: 'required',
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
      suddenDeathAssignments: returnedAssignments,
    );
    SeatingAssignmentsArgs? openedAssignmentsArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: seatingRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.seatingAssignmentsRoute) {
            openedAssignmentsArgs =
                settings.arguments! as SeatingAssignmentsArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Seating Assignments'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start sudden death at this table.'), findsOneWidget);
    expect(find.text('Start Sudden Death'), findsOneWidget);

    await tester.tap(find.text('Start Sudden Death'));
    await tester.pumpAndSettle();

    expect(seatingRepository.startedSuddenDeathTables, ['tbl_sudden']);
    expect(openedAssignmentsArgs?.initialAssignments, returnedAssignments);
    expect(find.text('Opened Seating Assignments'), findsOneWidget);
  });

  testWidgets('active sudden death lists only the sudden death finals table',
      (tester) async {
    final championsTable = _table('tbl_champions', 'Table 1');
    final suddenDeathTable = _table('tbl_sudden', 'Table 9', order: 9);
    final session = _session(
      id: 'ses_sudden',
      tableId: suddenDeathTable.id,
      scoringPhase: EventScoringPhase.bonus,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          scoringPhase: EventScoringPhase.bonus,
          tableRepository: _FakeTableRepository([
            championsTable,
            suddenDeathTable,
          ]),
          sessionRepository: _FakeSessionRepository(
            sessions: [session],
            details: {'ses_sudden': _detail(session)},
          ),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: TournamentRoundSummary.empty(),
            bonusRoundState: const BonusRoundState(
              bonusRoundId: 'bonus_01',
              eventId: 'evt_01',
              status: 'active',
              suddenDeathStatus: 'active',
              suddenDeathTableId: 'tbl_sudden',
              suddenDeathSessionId: 'ses_sudden',
            ),
            assignments: [
              _bonusAssignment(
                table: championsTable,
                seatIndex: 0,
                displayName: 'Seed One',
                seedRank: 1,
              ),
              _bonusAssignment(
                table: suddenDeathTable,
                seatIndex: 0,
                displayName: 'Alice Chen',
                seedRank: 1,
                role: BonusTableRole.tableOfChampionsSuddenDeath,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sudden Death in progress'), findsOneWidget);
    expect(find.text('Table of Champions Sudden Death'), findsOneWidget);
    expect(find.text('Alice Chen'), findsOneWidget);
    expect(find.text('Seed One'), findsNothing);
  });

  testWidgets('searches tables by table label and preserves sections',
      (tester) async {
    final currentTable = _table('tbl_dragon', 'Dragon Table');
    final otherTable = _table('tbl_bamboo', 'Bamboo Table', order: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([currentTable, otherTable]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              notStarted: 1,
              currentTables: [
                _roundTable(
                  table: currentTable,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bodySearchField = find.descendant(
      of: find.byKey(const ValueKey('tables-overview-list')),
      matching: find.widgetWithText(TextField, 'Search tables'),
    );
    expect(bodySearchField, findsOneWidget);
    expect(
      tester.getTopLeft(bodySearchField).dy,
      greaterThan(tester.getTopLeft(find.text('Friday Night Mahjong')).dy),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'table',
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Round'), findsOneWidget);
    expect(find.text('Dragon Table'), findsOneWidget);
    await _scrollTablesOverviewUntilVisible(tester, find.text('Other Tables'));

    expect(find.text('Other Tables'), findsOneWidget);
    expect(find.text('Bamboo Table'), findsOneWidget);

    await _scrollTablesOverviewUntilVisible(
      tester,
      find.widgetWithText(TextField, 'Search tables'),
      moveStep: const Offset(0, 300),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'dragon',
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Round'), findsOneWidget);
    expect(find.text('Other Tables'), findsNothing);
    expect(find.text('Dragon Table'), findsOneWidget);
    expect(find.text('Bamboo Table'), findsNothing);
  });

  testWidgets('searches current round tables by assigned player',
      (tester) async {
    final aliceTable = _table('tbl_alice', 'Table 1');
    final danaTable = _table('tbl_dana', 'Table 2', order: 2);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([aliceTable, danaTable]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              notStarted: 2,
              currentTables: [
                _roundTable(
                  table: aliceTable,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
                _roundTable(
                  table: danaTable,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Chris Lee', 'Dana Park'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'dana',
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Round'), findsOneWidget);
    expect(find.text('Table 1'), findsNothing);
    expect(find.text('Alice Chen'), findsNothing);
    expect(find.text('Table 2'), findsOneWidget);
    expect(find.text('Dana Park'), findsOneWidget);
  });

  testWidgets('search shows no-match empty state', (tester) async {
    final table = _table('tbl_dragon', 'Dragon Table');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'missing',
    );
    await tester.pumpAndSettle();

    expect(find.text('No matching tables'), findsOneWidget);
    expect(
      find.text('Try a different table or player search.'),
      findsOneWidget,
    );
    expect(find.text('Dragon Table'), findsNothing);
  });

  testWidgets('current round search shows no-match empty state',
      (tester) async {
    final table = _table('tbl_alice', 'Table 1');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
          seatingRepository: _FakeSeatingRepository(
            summary: _roundSummary(
              notStarted: 1,
              currentTables: [
                _roundTable(
                  table: table,
                  status: TournamentRoundTableStatus.notStarted,
                  names: const ['Alice Chen', 'Ben Wong'],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Round'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Search tables'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'missing',
    );
    await tester.pumpAndSettle();

    expect(find.text('Current Round'), findsNothing);
    expect(find.text('No matching tables'), findsOneWidget);
    expect(
      find.text('Try a different table or player search.'),
      findsOneWidget,
    );
    expect(find.text('Table 1'), findsNothing);
    expect(find.text('Alice Chen'), findsNothing);
  });

  testWidgets('search clear and keyboard dismiss suffix controls work',
      (tester) async {
    final table = _table('tbl_dragon', 'Dragon Table');

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(sessions: const []),
          guestRepository: _FakeGuestRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    EditableText editableText() => tester.widget<EditableText>(
          find.descendant(
            of: find.widgetWithText(TextField, 'Search tables'),
            matching: find.byType(EditableText),
          ),
        );

    await tester.tap(find.widgetWithText(TextField, 'Search tables'));
    await tester.pump();

    expect(editableText().focusNode.hasFocus, isTrue);
    expect(find.byTooltip('Dismiss keyboard'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search tables'),
      'missing',
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(find.text('Dragon Table'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(find.text('Dragon Table'), findsOneWidget);
    expect(find.text('No matching tables'), findsNothing);

    await tester.tap(find.byTooltip('Dismiss keyboard'));
    await tester.pump();

    expect(editableText().focusNode.hasFocus, isFalse);
  });

  testWidgets('table options can open previous session history',
      (tester) async {
    final table = EventTableRecord.fromJson(const {
      'id': 'tbl_points',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
    });
    final currentSession = _session(
      id: 'ses_02',
      tableId: 'tbl_points',
      sessionNumberForTable: 2,
      handCount: 1,
      startedAt: '2026-04-24T20:00:00-07:00',
    );
    final previousSession = _session(
      id: 'ses_01',
      tableId: 'tbl_points',
      status: 'completed',
      sessionNumberForTable: 1,
      handCount: 4,
      startedAt: '2026-04-24T19:00:00-07:00',
    );
    SessionDetailArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: _FakeTableRepository([table]),
          sessionRepository: _FakeSessionRepository(
            sessions: [previousSession, currentSession],
            details: {'ses_02': _detail(currentSession)},
          ),
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

    await tester.tap(find.byTooltip('Table options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session history'));
    await tester.pumpAndSettle();

    expect(find.text('Session History'), findsOneWidget);
    expect(find.text('Table 1'), findsWidgets);
    expect(find.text('Session 2'), findsOneWidget);
    expect(find.text('Active · Hand 1'), findsOneWidget);
    expect(find.text('Session 1'), findsOneWidget);
    expect(find.text('Completed · Hand 4'), findsOneWidget);

    await tester.tap(find.text('Session 1'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.sessionId, 'ses_01');
    expect(find.text('Opened Session Detail'), findsOneWidget);
  });
}

EventTableRecord _table(String id, String label, {int order = 1}) {
  return EventTableRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'label': label,
    'display_order': order,
    'nfc_tag_id': 'tag_$id',
    'default_ruleset_id': 'HK_STANDARD',
    'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'default_rotation_policy_config_json': const {},
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

TournamentRoundTableSummary _roundTable({
  required EventTableRecord table,
  required TournamentRoundTableStatus status,
  List<String> names = const [],
  String? activeSessionId,
  String? latestEndedSessionId,
}) {
  return TournamentRoundTableSummary(
    eventTableId: table.id,
    tableLabel: table.label,
    tableDisplayOrder: table.displayOrder,
    status: status,
    activeSessionId: activeSessionId,
    latestEndedSessionId: latestEndedSessionId,
    assignedPlayers: [
      for (var index = 0; index < names.length; index += 1)
        TournamentRoundAssignedPlayer(
          eventGuestId: 'guest_$index',
          displayName: names[index],
          seatIndex: index,
        ),
    ],
  );
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
    assignmentRound: 3,
    status: 'active',
    assignmentType: SeatingAssignmentType.bonus,
    bonusRoundId: 'bonus_01',
    bonusTableRole: role,
    seedRank: seedRank,
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
