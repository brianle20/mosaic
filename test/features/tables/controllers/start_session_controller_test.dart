import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/tables/controllers/start_session_controller.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

class _FakeGuestRepository extends ThrowingGuestRepository {
  const _FakeGuestRepository({
    required this.guests,
    required this.tagAssignments,
  });

  final List<EventGuestRecord> guests;
  final Map<String, GuestTagAssignmentSummary> tagAssignments;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      tagAssignments;

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

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  const _FakeSeatingRepository(this.assignments);

  final List<SeatingAssignmentRecord> assignments;

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      assignments;

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) {
    throw UnimplementedError();
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
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(String eventId) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository extends ThrowingSessionRepository {
  StartAssignedTableSessionInput? startedAssignedInput;

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) async {
    startedAssignedInput = input;
    return _startedSession();
  }

  @override
  Future<StartedTableSessionRecord> startSession(
    StartTableSessionInput input,
  ) {
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
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

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

void main() {
  test('assigned table can start from generated seats without player scans',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = _buildController(
      seatingAssignments: _tableAssignments(),
      sessionRepository: sessionRepository,
      preverifiedTableTagUid: 'TABLE-001',
    );

    await controller.load('evt_01');

    expect(controller.hasAssignedTableSeating, isTrue);
    expect(controller.currentPrompt, 'Review assigned seating');
    expect(controller.resolvedSeats.map((seat) => seat.guestName), [
      'Alice',
      'Billy',
      'Carol',
      'Dee',
    ]);

    final started = await controller.confirmStart();

    expect(started?.session.id, 'ses_01');
    expect(sessionRepository.startedAssignedInput?.eventTableId, 'tbl_01');
    expect(
        sessionRepository.startedAssignedInput?.scannedTableUid, 'TABLE-001');
  });

  test('assigned table can be entered without scanning the table tag',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = _buildController(
      seatingAssignments: _tableAssignments(),
      sessionRepository: sessionRepository,
      allowAssignedTableEntry: true,
    );

    await controller.load('evt_01');

    expect(controller.hasAssignedTableSeating, isTrue);
    expect(controller.currentPrompt, 'Review assigned seating');

    final started = await controller.confirmStart();

    expect(started?.session.id, 'ses_01');
    expect(sessionRepository.startedAssignedInput?.eventTableId, 'tbl_01');
    expect(sessionRepository.startedAssignedInput?.scannedTableUid, isNull);
  });

  for (final playerCount in [2, 3]) {
    test(
        'assigned tournament table with $playerCount players can start '
        'without a fourth player', () async {
      final sessionRepository = _FakeSessionRepository();
      final controller = _buildController(
        seatingAssignments: _tableAssignments().take(playerCount).toList(),
        sessionRepository: sessionRepository,
        allowAssignedTableEntry: true,
      );

      await controller.load('evt_01');

      expect(controller.hasAssignedTableSeating, isTrue);
      expect(controller.currentPrompt, 'Review assigned seating');
      expect(controller.resolvedSeats.map((seat) => seat.guestName), [
        'Alice',
        'Billy',
        if (playerCount == 3) 'Carol',
      ]);

      final started = await controller.confirmStart();

      expect(started?.session.id, 'ses_01');
      expect(sessionRepository.startedAssignedInput?.eventTableId, 'tbl_01');
      expect(sessionRepository.startedAssignedInput?.scannedTableUid, isNull);
    });
  }

  test('blocks tournament start when assigned seats are not contiguous',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = _buildController(
      seatingAssignments: [
        _assignment(guestId: 'gst_south', name: 'Billy', seatIndex: 1),
        _assignment(guestId: 'gst_west', name: 'Carol', seatIndex: 2),
      ],
      sessionRepository: sessionRepository,
      allowAssignedTableEntry: true,
    );

    await controller.load('evt_01');

    expect(controller.hasAssignedTableSeating, isFalse);
    expect(controller.currentPrompt, 'Assigned seating required');

    final started = await controller.confirmStart();

    expect(started, isNull);
    expect(sessionRepository.startedAssignedInput, isNull);
  });

  test('tournament table without assigned seats does not scan player tags',
      () async {
    final sessionRepository = _FakeSessionRepository();
    final controller = _buildController(
      sessionRepository: sessionRepository,
      preverifiedTableTagUid: 'TABLE-001',
    );

    await controller.load('evt_01');
    controller.recordPlayerScan('PLAYER-EAST');

    expect(controller.hasAssignedTableSeating, isFalse);
    expect(controller.canConfirmStart, isFalse);
    expect(controller.currentPrompt, 'Assigned seating required');
    expect(
      controller.actionError,
      'Generate seating assignments before entering this table.',
    );
    expect(controller.state.scannedPlayerUids, isEmpty);

    final started = await controller.confirmStart();

    expect(started, isNull);
    expect(sessionRepository.startedAssignedInput, isNull);
  });

  test('rejects a player scanned for the wrong assigned seat', () async {
    final controller = _buildController(
      seatingAssignments: _tableAssignments(),
    );

    await controller.load('evt_01');
    controller.recordTableScan('TABLE-001');
    controller.recordPlayerScan('PLAYER-SOUTH');

    expect(controller.state.currentStep, StartSessionScanStep.scanEast);
    expect(controller.state.scannedPlayerUids, isEmpty);
    expect(
      controller.actionError,
      'Expected Alice for East. Scan the assigned player tag.',
    );
  });

  test('accepts assigned player for expected seat', () async {
    final controller = _buildController(
      seatingAssignments: _tableAssignments(),
    );

    await controller.load('evt_01');
    controller.recordTableScan('TABLE-001');
    controller.recordPlayerScan('PLAYER-EAST');

    expect(controller.actionError, isNull);
    expect(controller.state.currentStep, StartSessionScanStep.scanSouth);
    expect(controller.state.scannedPlayerUids, ['PLAYER-EAST']);
  });

  test(
      'legacy qualification mode without assignment rows preserves scan behavior',
      () async {
    final controller = _buildController(
      scoringPhase: EventScoringPhase.qualification,
    );

    await controller.load('evt_01');
    controller.recordTableScan('TABLE-001');
    controller.recordPlayerScan('PLAYER-SOUTH');

    expect(controller.currentPrompt, 'Scan South Player Tag');
    expect(controller.actionError, isNull);
    expect(controller.state.scannedPlayerUids, ['PLAYER-SOUTH']);
  });
}

StartSessionController _buildController({
  List<SeatingAssignmentRecord> seatingAssignments = const [],
  SessionRepository? sessionRepository,
  String? preverifiedTableTagUid,
  bool allowAssignedTableEntry = false,
  EventScoringPhase scoringPhase = EventScoringPhase.tournament,
}) {
  return StartSessionController(
    table: _table(),
    scoringPhase: scoringPhase,
    guestRepository: _FakeGuestRepository(
      guests: _guests(),
      tagAssignments: _tagAssignments(),
    ),
    seatingRepository: _FakeSeatingRepository(seatingAssignments),
    sessionRepository: sessionRepository ?? _FakeSessionRepository(),
    preverifiedTableTagUid: preverifiedTableTagUid,
    allowAssignedTableEntry: allowAssignedTableEntry,
  );
}

EventTableRecord _table() {
  return EventTableRecord.fromJson(const {
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
}

List<EventGuestRecord> _guests() {
  return const [
    {
      'id': 'gst_east',
      'event_id': 'evt_01',
      'display_name': 'Alice',
      'normalized_name': 'alice',
      'attendance_status': 'checked_in',
      'cover_status': 'paid',
      'cover_amount_cents': 2000,
      'is_comped': false,
      'has_scored_play': false,
    },
    {
      'id': 'gst_south',
      'event_id': 'evt_01',
      'display_name': 'Billy',
      'normalized_name': 'billy',
      'attendance_status': 'checked_in',
      'cover_status': 'paid',
      'cover_amount_cents': 2000,
      'is_comped': false,
      'has_scored_play': false,
    },
  ].map(EventGuestRecord.fromJson).toList(growable: false);
}

Map<String, GuestTagAssignmentSummary> _tagAssignments() {
  return const {
    'gst_east': {
      'assignment_id': 'tag_asg_east',
      'event_id': 'evt_01',
      'event_guest_id': 'gst_east',
      'status': 'assigned',
      'assigned_at': '2026-04-24T18:00:00-07:00',
      'nfc_tag': {
        'id': 'tag_east',
        'uid_hex': 'PLAYER-EAST',
        'uid_fingerprint': 'PLAYER-EAST',
        'default_tag_type': 'player',
        'status': 'active',
      },
    },
    'gst_south': {
      'assignment_id': 'tag_asg_south',
      'event_id': 'evt_01',
      'event_guest_id': 'gst_south',
      'status': 'assigned',
      'assigned_at': '2026-04-24T18:01:00-07:00',
      'nfc_tag': {
        'id': 'tag_south',
        'uid_hex': 'PLAYER-SOUTH',
        'uid_fingerprint': 'PLAYER-SOUTH',
        'default_tag_type': 'player',
        'status': 'active',
      },
    },
  }.map(
    (guestId, json) => MapEntry(
      guestId,
      GuestTagAssignmentSummary.fromJson(json),
    ),
  );
}

List<SeatingAssignmentRecord> _tableAssignments() {
  return [
    _assignment(guestId: 'gst_east', name: 'Alice', seatIndex: 0),
    _assignment(guestId: 'gst_south', name: 'Billy', seatIndex: 1),
    _assignment(guestId: 'gst_west', name: 'Carol', seatIndex: 2),
    _assignment(guestId: 'gst_north', name: 'Dee', seatIndex: 3),
  ];
}

SeatingAssignmentRecord _assignment({
  required String guestId,
  required String name,
  required int seatIndex,
}) {
  return SeatingAssignmentRecord(
    id: 'seat_asg_$seatIndex',
    eventId: 'evt_01',
    eventTableId: 'tbl_01',
    tableLabel: 'Table 1',
    eventGuestId: guestId,
    displayName: name,
    seatIndex: seatIndex,
    assignmentRound: 1,
    status: 'active',
  );
}

StartedTableSessionRecord _startedSession() {
  return StartedTableSessionRecord.fromJson(
    sessionJson: const {
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
    },
    seatsJson: const [
      {
        'id': 'seat_01',
        'table_session_id': 'ses_01',
        'seat_index': 0,
        'initial_wind': 'east',
        'event_guest_id': 'gst_east',
      },
      {
        'id': 'seat_02',
        'table_session_id': 'ses_01',
        'seat_index': 1,
        'initial_wind': 'south',
        'event_guest_id': 'gst_south',
      },
      {
        'id': 'seat_03',
        'table_session_id': 'ses_01',
        'seat_index': 2,
        'initial_wind': 'west',
        'event_guest_id': 'gst_west',
      },
      {
        'id': 'seat_04',
        'table_session_id': 'ses_01',
        'seat_index': 3,
        'initial_wind': 'north',
        'event_guest_id': 'gst_north',
      },
    ],
  );
}
