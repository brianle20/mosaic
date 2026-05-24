import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
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
    this.clearedAssignments = const [],
  });

  final List<SeatingAssignmentRecord> loadedAssignments;
  final List<SeatingAssignmentRecord> generatedAssignments;
  final List<SeatingAssignmentRecord> clearedAssignments;
  int generateCallCount = 0;
  int clearCallCount = 0;

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) async {
    clearCallCount += 1;
    return clearedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async {
    generateCallCount += 1;
    return generatedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    required String redemptionTableId,
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
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      assignments;

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

class _FakeSessionRepository extends ThrowingSessionRepository {
  const _FakeSessionRepository({this.sessions = const []});

  final List<TableSessionRecord> sessions;

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
      sessions;

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
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('shows empty state and generate action', (tester) async {
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
      find.text('Generate random seating for checked-in players.'),
      findsOneWidget,
    );
    expect(find.text('Generate Seating'), findsOneWidget);
    expect(find.text('Clear Assignments'), findsNothing);
  });

  testWidgets('generates and displays seating by table and wind',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            generatedAssignments: [
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

    await tester.tap(find.text('Generate Seating'));
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
    expect(find.text('Clear Assignments'), findsOneWidget);
  });

  testWidgets('regenerate confirms before replacing displayed assignments',
      (tester) async {
    final repository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Original East'),
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
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generate Seating'));
    await tester.pumpAndSettle();

    expect(repository.generateCallCount, 0);
    expect(find.text('Regenerate Seating'), findsOneWidget);
    expect(
      find.text('This will replace the current seating assignments.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Regenerate'));
    await tester.pumpAndSettle();

    expect(repository.generateCallCount, 1);
    expect(find.text('Original East'), findsNothing);
    expect(find.text('New East'), findsOneWidget);
  });

  testWidgets('clear confirms before removing displayed assignments',
      (tester) async {
    final repository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
      clearedAssignments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: repository,
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ava East'), findsOneWidget);

    await tester.tap(find.text('Clear Assignments'));
    await tester.pumpAndSettle();

    expect(repository.clearCallCount, 0);
    expect(find.text('Clear Seating'), findsOneWidget);
    expect(
      find.text('This will remove the current seating assignments.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(repository.clearCallCount, 1);
    expect(find.text('Ava East'), findsNothing);
    expect(
      find.text('Generate random seating for checked-in players.'),
      findsOneWidget,
    );
  });

  testWidgets('shows eligible guests left unassigned after generation',
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
            generatedAssignments: [
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

    await tester.tap(find.text('Generate Seating'));
    await tester.pumpAndSettle();

    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('Eli Waiting'), findsOneWidget);
  });

  testWidgets('blocks seating changes while a session is live', (tester) async {
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

    expect(find.text(seatingChangeBlockedMessage), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
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
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': displayName,
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
