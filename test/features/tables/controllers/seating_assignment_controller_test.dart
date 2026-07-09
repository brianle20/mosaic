import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
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
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    calls.add('generate-tournament:$eventId');
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
  });

  final List<EventGuestRecord> guests;

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
  _FakeSessionRepository({
    this.sessions = const [],
    this.sessionsAfterBulkStart = const [],
    this.bulkStartError,
    this.sessionsBecomeLiveBeforeBulkStartError = false,
    this.listSessionsDelay,
  });

  final List<TableSessionRecord> sessions;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  final Object? bulkStartError;
  final bool sessionsBecomeLiveBeforeBulkStartError;
  final Future<void>? listSessionsDelay;
  final calls = <String>[];
  var _bulkStartSucceeded = false;

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
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    calls.add('list:$eventId');
    final result = _bulkStartSucceeded ? sessionsAfterBulkStart : sessions;
    await listSessionsDelay;
    return result;
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
    calls.add('bulkStart:$eventId');
    final error = bulkStartError;
    if (error != null) {
      if (sessionsBecomeLiveBeforeBulkStartError) {
        _bulkStartSucceeded = true;
      }
      throw error;
    }
    _bulkStartSucceeded = true;
    return sessionsAfterBulkStart;
  }

  @override
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) async {
    calls.add('bonusBulkStart:$eventId:${bonusTableRole?.name}');
    final error = bulkStartError;
    if (error != null) {
      if (sessionsBecomeLiveBeforeBulkStartError) {
        _bulkStartSucceeded = true;
      }
      throw error;
    }
    _bulkStartSucceeded = true;
    return sessionsAfterBulkStart;
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
      ),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.generate('evt_01');

    expect(
      controller.unassignedGuests.map((guest) => guest.displayName),
      ['Ellen'],
    );
  });

  test('sudden death scope keeps only champions sudden death seating',
      () async {
    final guests = [
      _guest(
        id: 'gst_01',
        displayName: 'Champion One',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_02',
        displayName: 'Champion Two',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
      _guest(
        id: 'gst_03',
        displayName: 'Redemption Player',
        tournamentStatus: EventTournamentStatus.qualified,
      ),
    ];
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [
          _assignment(
            id: 'sd_01',
            guestId: 'gst_01',
            displayName: 'Champion One',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
          _assignment(
            id: 'sd_02',
            guestId: 'gst_02',
            displayName: 'Champion Two',
            seatIndex: 1,
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
          _assignment(
            id: 'redemption_01',
            tableId: 'tbl_02',
            tableLabel: 'Table 2',
            guestId: 'gst_03',
            displayName: 'Redemption Player',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfRedemption,
          ),
        ],
      ),
      guestRepository: _FakeGuestRepository(
        guests: guests,
      ),
      sessionRepository: _FakeSessionRepository(),
      bonusTableRoleFilter: BonusTableRole.tableOfChampionsSuddenDeath,
      showUnassignedGuests: false,
    );

    await controller.load('evt_01');

    expect(
      controller.assignments.map((assignment) => assignment.displayName),
      ['Champion One', 'Champion Two'],
    );
    expect(controller.tableGroups, hasLength(1));
    expect(controller.unassignedGuests, isEmpty);
  });

  test('eligible tournament players are qualified checked-in guests', () async {
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
      ),
      sessionRepository: _FakeSessionRepository(),
    );

    await controller.load('evt_01');

    expect(
      controller.eligibleGuests.map((guest) => guest.displayName),
      ['No Active Tag', 'Qualified Player'],
    );
  });

  test('startAllTables generates tournament seating before starting sessions',
      () async {
    final seatingRepository = _FakeSeatingRepository(
      generatedAssignments: [_assignment(displayName: 'Ava East')],
    );
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'list:evt_01',
      'bulkStart:evt_01',
      'list:evt_01',
    ]);
    expect(seatingRepository.calls, [
      'cache:evt_01',
      'load:evt_01',
      'generate-tournament:evt_01',
    ]);
    expect(controller.assignments.single.displayName, 'Ava East');
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
  });

  test('startAllTables reports backend errors and keeps assignments', () async {
    final seatingRepository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(
        bulkStartError: Exception('No current tournament round seating'),
      ),
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(controller.assignments.single.displayName, 'Ava East');
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, contains('No current tournament round seating'));
  });

  test('startAllTables keeps tournament bulk path for random assignments',
      () async {
    final seatingRepository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
    );
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'list:evt_01',
      'bulkStart:evt_01',
      'list:evt_01',
    ]);
    expect(controller.error, isNull);
  });

  test('startAllTables starts bonus sessions for one loaded bonus role',
      () async {
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [
          _assignment(
            displayName: 'Ava East',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
          _assignment(
            id: 'asg_02',
            guestId: 'gst_02',
            displayName: 'Mina South',
            seatIndex: 1,
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
        ],
      ),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'list:evt_01',
      'bonusBulkStart:evt_01:tableOfChampionsSuddenDeath',
      'list:evt_01',
    ]);
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.error, isNull);
  });

  test('startAllTables starts standard finals sessions for mixed bonus roles',
      () async {
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [
          _assignment(
            displayName: 'Champion East',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampions,
          ),
          _assignment(
            id: 'asg_02',
            tableId: 'tbl_02',
            tableLabel: 'Table 2',
            guestId: 'gst_02',
            displayName: 'Redemption East',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfRedemption,
          ),
        ],
      ),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'list:evt_01',
      'bonusBulkStart:evt_01:null',
      'list:evt_01',
    ]);
    expect(controller.error, isNull);
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.isSubmitting, isFalse);
  });

  test('startAllTables rejects mixed sudden death and finals bonus roles',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [
          _assignment(
            displayName: 'Champion East',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          ),
          _assignment(
            id: 'asg_02',
            tableId: 'tbl_02',
            tableLabel: 'Table 2',
            guestId: 'gst_02',
            displayName: 'Redemption East',
            assignmentType: SeatingAssignmentType.bonus,
            bonusTableRole: BonusTableRole.tableOfRedemption,
          ),
        ],
      ),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, ['list:evt_01', 'list:evt_01']);
    expect(controller.error, 'Bonus seating must use one table role.');
    expect(controller.hasLiveSessions, isFalse);
    expect(controller.isSubmitting, isFalse);
  });

  test('startAllTables rejects loaded bonus seating with a missing role',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [
          _assignment(
            displayName: 'Champion East',
            assignmentType: SeatingAssignmentType.bonus,
          ),
        ],
      ),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, ['list:evt_01', 'list:evt_01']);
    expect(controller.error, 'Bonus seating must use one table role.');
  });

  test('startAllTablesLabel describes bonus contexts and tournament default',
      () {
    final tournamentController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [_assignment()],
    );
    final finalsSingleTableController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [
        _assignment(
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfChampions,
        ),
      ],
    );
    final finalsMultiTableController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [
        _assignment(
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfRedemption,
        ),
        _assignment(
          id: 'asg_02',
          tableId: 'tbl_02',
          tableLabel: 'Table 2',
          guestId: 'gst_02',
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfRedemption,
        ),
      ],
    );
    final standardMixedFinalsController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [
        _assignment(
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfChampions,
        ),
        _assignment(
          id: 'asg_03',
          tableId: 'tbl_03',
          tableLabel: 'Table 3',
          guestId: 'gst_03',
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfRedemption,
        ),
      ],
    );
    final suddenDeathController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [
        _assignment(
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
        ),
      ],
    );
    final playInController = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
      initialAssignments: [
        _assignment(
          assignmentType: SeatingAssignmentType.bonus,
          bonusTableRole: BonusTableRole.tableOfChampionsPlayIn,
        ),
      ],
    );

    expect(tournamentController.startAllTablesLabel, 'Start All Tables');
    expect(
        finalsSingleTableController.startAllTablesLabel, 'Start Finals Table');
    expect(
        finalsMultiTableController.startAllTablesLabel, 'Start Finals Tables');
    expect(
      standardMixedFinalsController.startAllTablesLabel,
      'Start Finals Tables',
    );
    expect(suddenDeathController.startAllTablesLabel, 'Start Sudden Death');
    expect(playInController.startAllTablesLabel, 'Start Play-In');
  });

  test('canStartAllTables requires no live sessions', () async {
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
    );

    expect(controller.canStartAllTables, isTrue);

    await controller.load('evt_01');
    expect(controller.canStartAllTables, isTrue);

    controller.hasLiveSessions = true;
    expect(controller.canStartAllTables, isFalse);
  });

  test('startAllTables blocks when preflight finds a live session', () async {
    final seatingRepository = _FakeSeatingRepository();
    final sessionRepository = _FakeSessionRepository(
      sessions: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
      initialAssignments: [_assignment()],
    );

    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, ['list:evt_01']);
    expect(seatingRepository.calls, isEmpty);
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.error, seatingChangeBlockedMessage);
    expect(controller.isSubmitting, isFalse);
  });

  test('startAllTables ignores duplicate starts while preflight is pending',
      () async {
    final preflight = Completer<void>();
    final sessionRepository = _FakeSessionRepository(
      listSessionsDelay: preflight.future,
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
      initialAssignments: [_assignment(displayName: 'Ava East')],
    );

    final firstStart = controller.startAllTables('evt_01');
    final secondStart = controller.startAllTables('evt_01');
    await Future<void>.delayed(Duration.zero);

    preflight.complete();
    await Future.wait([firstStart, secondStart]);

    expect(
      sessionRepository.calls.where((call) => call == 'bulkStart:evt_01'),
      hasLength(1),
    );
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
  });

  test('startAllTables clears client error when sessions started anyway',
      () async {
    final seatingRepository = _FakeSeatingRepository();
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
      bulkStartError: Exception('Client parse failed'),
      sessionsBecomeLiveBeforeBulkStartError: true,
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
      initialAssignments: [_assignment(displayName: 'Ava East')],
    );

    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'bulkStart:evt_01',
      'list:evt_01',
    ]);
    expect(seatingRepository.calls, isEmpty);
    expect(controller.assignments.single.displayName, 'Ava East');
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.canStartAllTables, isFalse);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
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
