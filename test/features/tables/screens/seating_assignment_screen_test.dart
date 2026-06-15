import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/controllers/seating_assignment_controller.dart';
import 'package:mosaic/features/tables/screens/seating_assignment_screen.dart';

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.loadedAssignments = const [],
    this.generatedAssignments = const [],
  });

  final List<SeatingAssignmentRecord> loadedAssignments;
  final List<SeatingAssignmentRecord> generatedAssignments;
  int generateCallCount = 0;
  int clearCallCount = 0;

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) async {
    clearCallCount += 1;
    return const [];
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async {
    generateCallCount += 1;
    return generatedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    generateCallCount += 1;
    return generatedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      loadedAssignments;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository({
    this.guests = const [],
    this.assignments = const {},
  });

  final List<EventGuestRecord> guests;
  final Map<String, GuestTagAssignmentSummary> assignments;

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
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

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

class _FakeSessionRepository extends ThrowingSessionRepository {
  const _FakeSessionRepository({
    this.sessions = const [],
    this.sessionsAfterBulkStart = const [],
  });

  final List<TableSessionRecord> sessions;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  static int bulkStartCallCount = 0;

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
          String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      bulkStartCallCount > 0 ? sessionsAfterBulkStart : sessions;

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      sessions;

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    bulkStartCallCount += 1;
    return sessionsAfterBulkStart;
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    _FakeSessionRepository.bulkStartCallCount = 0;
  });

  testWidgets('shows empty state without seating mutation actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Seating'), findsOneWidget);
    expect(
      find.text('Round seating appears after starting a tournament round.'),
      findsOneWidget,
    );
    expect(find.text('Generate Seating'), findsNothing);
    expect(find.text('Clear Assignments'), findsNothing);
    expect(find.text('Copy Seating'), findsNothing);
  });

  testWidgets('displays seating by table and wind', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(
                id: 'a1',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                displayName: 'Ava East',
                seatIndex: 0,
              ),
              _assignment(
                id: 'a2',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
              _assignment(
                id: 'a3',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                displayName: 'Cam West',
                seatIndex: 2,
              ),
              _assignment(
                id: 'a4',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                displayName: 'Dia North',
                seatIndex: 3,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('East'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    expect(find.text('West'), findsOneWidget);
    expect(find.text('North'), findsOneWidget);
    expect(find.text('Ava East'), findsOneWidget);
    expect(find.text('Ben South'), findsOneWidget);
    expect(find.text('Cam West'), findsOneWidget);
    expect(find.text('Dia North'), findsOneWidget);
    expect(find.text('Generate Seating'), findsNothing);
    expect(find.text('Clear Assignments'), findsNothing);
  });

  testWidgets('copies seating assignments as plain text', (tester) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(
                id: 'a2',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                guestId: 'gst_02',
                displayName: 'Benjamin Southworth',
                seatIndex: 1,
              ),
              _assignment(
                id: 'a1',
                tableId: 'tbl_01',
                tableLabel: 'Table 1',
                guestId: 'gst_01',
                displayName: 'Ava East',
                seatIndex: 0,
              ),
              _assignment(
                id: 'a3',
                tableId: 'tbl_02',
                tableLabel: 'Table 2',
                guestId: 'gst_03',
                displayName: 'Cameron Eastman',
                seatIndex: 0,
              ),
              _assignment(
                id: 'a4',
                tableId: 'tbl_02',
                tableLabel: 'Table 2',
                guestId: 'gst_04',
                displayName: 'Dia South',
                seatIndex: 1,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(
            guests: [
              _guest(
                id: 'gst_01',
                displayName: 'Ava East',
                publicDisplayName: 'Ava E.',
              ),
              _guest(
                id: 'gst_02',
                displayName: 'Benjamin Southworth',
                publicDisplayName: 'Ben S.',
              ),
              _guest(
                id: 'gst_03',
                displayName: 'Cameron Eastman',
                publicDisplayName: 'Cam E.',
              ),
              _guest(id: 'gst_04', displayName: 'Dia South'),
            ],
          ),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy Seating'));
    await tester.pump();

    expect(
      copiedText,
      'Table 1\n'
      'East: Ava E.\n'
      'South: Ben S.\n'
      '\n'
      'Table 2\n'
      'East: Cam E.\n'
      'South: Dia South',
    );
    expect(find.text('Seating copied.'), findsOneWidget);
  });

  testWidgets('seating review does not start all tables', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(displayName: 'Ava East', seatIndex: 0),
              _assignment(
                id: 'a2',
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            sessionsAfterBulkStart: [_session(SessionStatus.active)],
          ),
          minimumTableSize: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start All Tables'), findsNothing);
    expect(find.text('Copy Seating'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(_FakeSessionRepository.bulkStartCallCount, 0);
  });

  testWidgets('start all tables stays hidden without seating', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start All Tables'), findsNothing);
  });

  testWidgets('renders initial assignments before loading remote seating',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
          initialAssignments: [
            _assignment(
              id: 'a1',
              tableId: 'tbl_01',
              tableLabel: 'Table 1',
              displayName: 'Ava East',
              seatIndex: 0,
            ),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Ava East'), findsOneWidget);
    expect(
        find.text('Round seating appears after starting a tournament round.'),
        findsNothing);
  });

  testWidgets('enter table opens assigned start session fallback',
      (tester) async {
    StartSessionArgs? openedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
          initialAssignments: [
            _assignment(
              id: 'a1',
              tableId: 'tbl_01',
              tableLabel: 'Table 1',
              displayName: 'Ava East',
              seatIndex: 0,
            ),
            _assignment(
              id: 'a2',
              tableId: 'tbl_01',
              tableLabel: 'Table 1',
              displayName: 'Ben South',
              seatIndex: 1,
            ),
            _assignment(
              id: 'a3',
              tableId: 'tbl_01',
              tableLabel: 'Table 1',
              displayName: 'Cam West',
              seatIndex: 2,
            ),
            _assignment(
              id: 'a4',
              tableId: 'tbl_01',
              tableLabel: 'Table 1',
              displayName: 'Dia North',
              seatIndex: 3,
            ),
          ],
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.startSessionRoute) {
            openedArgs = settings.arguments! as StartSessionArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Start Session')),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );

    await tester.pump();
    await tester.tap(find.text('Enter Table'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.table.id, 'tbl_01');
    expect(openedArgs?.table.label, 'Table 1');
    expect(openedArgs?.scoringPhase, EventScoringPhase.tournament);
    expect(openedArgs?.allowAssignedTableEntry, isTrue);
  });

  testWidgets('shows eligible guests left unassigned after loading seating',
      (tester) async {
    final guests = [
      _guest(id: 'gst_01', displayName: 'Ava East'),
      _guest(id: 'gst_02', displayName: 'Ben South'),
      _guest(id: 'gst_03', displayName: 'Cam West'),
      _guest(id: 'gst_04', displayName: 'Dia North'),
      _guest(id: 'gst_05', displayName: 'Eli Waiting'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(
                id: 'a1',
                guestId: 'gst_01',
                displayName: 'Ava East',
                seatIndex: 0,
              ),
              _assignment(
                id: 'a2',
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
              _assignment(
                id: 'a3',
                guestId: 'gst_03',
                displayName: 'Cam West',
                seatIndex: 2,
              ),
              _assignment(
                id: 'a4',
                guestId: 'gst_04',
                displayName: 'Dia North',
                seatIndex: 3,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(
            guests: guests,
            assignments: {
              for (final guest in guests)
                guest.id: _tagAssignment(guestId: guest.id),
            },
          ),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('Eli Waiting'), findsOneWidget);
  });

  testWidgets('sudden death seating hides non-champions and unassigned guests',
      (tester) async {
    final guests = [
      _guest(id: 'gst_01', displayName: 'Champion One'),
      _guest(id: 'gst_02', displayName: 'Champion Two'),
      _guest(id: 'gst_03', displayName: 'Redemption Player'),
      _guest(id: 'gst_04', displayName: 'Waiting Player'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(
                id: 'sd_01',
                tableId: 'tbl_sd',
                tableLabel: 'Table 1A',
                guestId: 'gst_01',
                displayName: 'Champion One',
                assignmentType: SeatingAssignmentType.bonus,
                bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
              ),
              _assignment(
                id: 'sd_02',
                tableId: 'tbl_sd',
                tableLabel: 'Table 1A',
                guestId: 'gst_02',
                displayName: 'Champion Two',
                seatIndex: 1,
                assignmentType: SeatingAssignmentType.bonus,
                bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
              ),
              _assignment(
                id: 'redemption_01',
                tableId: 'tbl_redemption',
                tableLabel: 'Table 1B',
                guestId: 'gst_03',
                displayName: 'Redemption Player',
                assignmentType: SeatingAssignmentType.bonus,
                bonusTableRole: BonusTableRole.tableOfRedemption,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(
            guests: guests,
            assignments: {
              for (final guest in guests)
                guest.id: _tagAssignment(guestId: guest.id),
            },
          ),
          sessionRepository: const _FakeSessionRepository(),
          bonusTableRoleFilter: BonusTableRole.tableOfChampionsSuddenDeath,
          showUnassignedGuests: false,
          enterTableScoringPhase: EventScoringPhase.bonus,
          minimumTableSize: 2,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.startSessionRoute) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Start Session')),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table 1A'), findsOneWidget);
    expect(find.text('Champion One'), findsOneWidget);
    expect(find.text('Champion Two'), findsOneWidget);
    expect(find.text('Table 1B'), findsNothing);
    expect(find.text('Redemption Player'), findsNothing);
    expect(find.text('Unassigned'), findsNothing);
    expect(find.text('Waiting Player'), findsNothing);
    expect(find.text('Start All Tables'), findsNothing);

    await tester.tap(find.text('Enter Table'));
    await tester.pumpAndSettle();
    expect(find.text('Start Session'), findsOneWidget);
  });

  testWidgets('live sessions do not expose seating mutation actions',
      (tester) async {
    final repository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
      generatedAssignments: [
        _assignment(displayName: 'New East'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: repository,
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            sessions: [_session(SessionStatus.paused)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(seatingChangeBlockedMessage), findsNothing);
    expect(find.text('Generate Seating'), findsNothing);
    expect(find.text('Clear Assignments'), findsNothing);
    expect(find.text('Start All Tables'), findsNothing);
    expect(repository.generateCallCount, 0);
    expect(repository.clearCallCount, 0);
  });
}

SeatingAssignmentRecord _assignment({
  String id = 'asg_01',
  String eventId = 'evt_01',
  String tableId = 'tbl_01',
  String tableLabel = 'Table 1',
  String guestId = 'gst_01',
  String displayName = 'Player',
  int seatIndex = 0,
  SeatingAssignmentType assignmentType = SeatingAssignmentType.random,
  BonusTableRole? bonusTableRole,
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
    assignmentType: assignmentType,
    bonusTableRole: bonusTableRole,
  );
}

TableSessionRecord _session(SessionStatus status) {
  return TableSessionRecord(
    id: 'ses_${status.name}',
    eventId: 'evt_01',
    eventTableId: 'tbl_01',
    sessionNumberForTable: 1,
    rulesetId: 'HK_STANDARD',
    rotationPolicyType: RotationPolicyType.dealerCycleReturnToInitialEast,
    rotationPolicyConfig: const {},
    status: status,
    initialEastSeatIndex: 0,
    currentDealerSeatIndex: 0,
    dealerPassCount: 0,
    completedGamesCount: 0,
    handCount: 0,
    startedAt: DateTime.parse('2026-05-22T12:00:00Z'),
    startedByUserId: 'usr_01',
  );
}

EventGuestRecord _guest({
  required String id,
  required String displayName,
  String? publicDisplayName,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': displayName,
    'public_display_name': publicDisplayName,
    'normalized_name': displayName.toLowerCase(),
    'attendance_status': 'checked_in',
    'tournament_status': 'qualified',
    'cover_status': 'paid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
  });
}

GuestTagAssignmentSummary _tagAssignment({required String guestId}) {
  return GuestTagAssignmentSummary(
    assignmentId: 'asg_$guestId',
    eventId: 'evt_01',
    eventGuestId: guestId,
    status: GuestTagAssignmentStatus.assigned,
    assignedAt: DateTime.parse('2026-05-22T12:00:00Z'),
    tag: NfcTagRecord(
      id: 'tag_$guestId',
      uidHex: 'UID_$guestId',
      uidFingerprint: 'fingerprint_$guestId',
      defaultTagType: NfcTagType.player,
      status: NfcTagStatus.active,
    ),
  );
}
