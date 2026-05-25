import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/controllers/seating_assignment_controller.dart';

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  _FakeSeatingRepository({
    this.cachedAssignments = const [],
    this.loadedAssignments = const [],
    this.generatedAssignments = const [],
    this.clearedAssignments = const [],
  });

  final List<SeatingAssignmentRecord> cachedAssignments;
  final List<SeatingAssignmentRecord> loadedAssignments;
  final List<SeatingAssignmentRecord> generatedAssignments;
  final List<SeatingAssignmentRecord> clearedAssignments;
  final calls = <String>[];

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) async {
    calls.add('clear:$eventId');
    return clearedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async {
    calls.add('generate:$eventId');
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
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async {
    calls.add('load:$eventId');
    return loadedAssignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async {
    calls.add('cache:$eventId');
    return cachedAssignments;
  }
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
  _FakeSessionRepository({this.sessions = const []});

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
  test('load publishes cached assignments before remote assignments', () async {
    final repository = _FakeSeatingRepository(
      cachedAssignments: [_assignment(displayName: 'Cached East')],
      loadedAssignments: [_assignment(displayName: 'Remote East')],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
    );
    final snapshots = <List<String>>[];
    controller.addListener(() {
      snapshots.add([
        for (final assignment in controller.assignments) assignment.displayName,
      ]);
    });

    await controller.load('evt_01');

    expect(repository.calls, ['cache:evt_01', 'load:evt_01']);
    expect(
      snapshots.any(
        (snapshot) => snapshot.length == 1 && snapshot.single == 'Cached East',
      ),
      isTrue,
    );
    expect(controller.assignments.single.displayName, 'Remote East');
    expect(controller.isLoading, isFalse);
    expect(controller.error, isNull);
  });

  test('generate updates assignments and groups seats by table order',
      () async {
    final repository = _FakeSeatingRepository(
      generatedAssignments: [
        _assignment(
          id: 'a2',
          tableId: 'tbl_01',
          tableLabel: 'Table 1',
          displayName: 'South Player',
          seatIndex: 1,
        ),
        _assignment(
          id: 'a1',
          tableId: 'tbl_01',
          tableLabel: 'Table 1',
          displayName: 'East Player',
          seatIndex: 0,
        ),
        _assignment(
          id: 'a6',
          tableId: 'tbl_02',
          tableLabel: 'Table 2',
          displayName: 'West Player',
          seatIndex: 2,
        ),
      ],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.generate('evt_01');

    expect(repository.calls, ['generate:evt_01']);
    expect(controller.assignments, repository.generatedAssignments);
    expect(controller.tableGroups.map((group) => group.tableLabel), [
      'Table 1',
      'Table 2',
    ]);
    expect(controller.tableGroups.first.seats.map((seat) => seat.seatIndex), [
      0,
      1,
    ]);
    expect(
      controller.tableGroups.first.seats.map((seat) => seat.displayName),
      ['East Player', 'South Player'],
    );
  });

  test('clear removes assignments', () async {
    final repository = _FakeSeatingRepository(
      clearedAssignments: const [],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.clear('evt_01');

    expect(repository.calls, ['clear:evt_01']);
    expect(controller.assignments, isEmpty);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
  });

  test('generate identifies eligible guests left unassigned', () async {
    final guests = [
      _guest(
        id: 'gst_01',
        displayName: 'Alice',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_02',
        displayName: 'Billy',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_03',
        displayName: 'Carmen',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_04',
        displayName: 'Dev',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_05',
        displayName: 'Ellen',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_06',
        displayName: 'Not Checked In',
        attendanceStatus: 'expected',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
    ];
    final repository = _FakeSeatingRepository(
      generatedAssignments: [
        _assignment(guestId: 'gst_01', displayName: 'Alice', seatIndex: 0),
        _assignment(guestId: 'gst_02', displayName: 'Billy', seatIndex: 1),
        _assignment(guestId: 'gst_03', displayName: 'Carmen', seatIndex: 2),
        _assignment(guestId: 'gst_04', displayName: 'Dev', seatIndex: 3),
      ],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(
        guests: guests,
        assignments: {
          for (final guest in guests)
            guest.id: _tagAssignment(guestId: guest.id),
        },
      ),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.generate('evt_01');

    expect(
      controller.unassignedGuests.map((guest) => guest.displayName),
      ['Ellen'],
    );
  });

  test(
      'eligible tournament players must be qualified checked-in tagged players',
      () async {
    final guests = [
      _guest(
        id: 'gst_qualified',
        displayName: 'Qualified Player',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_qualifying',
        displayName: 'Qualifying Player',
        tournamentStatus: EventTournamentStatus.qualifying,
      ),
      _guest(
        id: 'gst_open',
        displayName: 'Open Play Player',
        tournamentStatus: EventTournamentStatus.openPlayOnly,
      ),
      _guest(
        id: 'gst_withdrawn',
        displayName: 'Withdrawn Player',
        tournamentStatus: EventTournamentStatus.withdrawn,
      ),
      _guest(
        id: 'gst_expected',
        displayName: 'Not Checked In',
        attendanceStatus: 'expected',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_untagged',
        displayName: 'No Active Tag',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
    ];
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(
        guests: guests,
        assignments: {
          for (final guest in guests)
            if (guest.id != 'gst_untagged')
              guest.id: _tagAssignment(guestId: guest.id),
        },
      ),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.load('evt_01');

    expect(
      controller.eligibleGuests.map((guest) => guest.displayName),
      ['Qualified Player'],
    );
  });

  test('generate and clear are blocked while a session is live', () async {
    final repository = _FakeSeatingRepository(
      generatedAssignments: [_assignment()],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(
        sessions: [_session(SessionStatus.active)],
      ),
    );

    await controller.generate('evt_01');
    await controller.clear('evt_01');

    expect(repository.calls, isEmpty);
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.error, seatingChangeBlockedMessage);
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
  String attendanceStatus = 'checked_in',
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': displayName,
    'normalized_name': displayName.toLowerCase(),
    'attendance_status': attendanceStatus,
    'cover_status': 'paid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
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
