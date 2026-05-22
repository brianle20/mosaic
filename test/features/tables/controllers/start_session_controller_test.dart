import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/start_session_controller.dart';
import 'package:mosaic/features/tables/models/start_session_scan_state.dart';

class _FakeGuestRepository implements GuestRepository {
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

class _FakeSeatingRepository implements SeatingRepository {
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
    required String redemptionTableId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(String eventId) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements SessionRepository {
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

  test('manual mode without assignment rows preserves generic scan behavior',
      () async {
    final controller = _buildController();

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
}) {
  return StartSessionController(
    table: _table(),
    guestRepository: _FakeGuestRepository(
      guests: _guests(),
      tagAssignments: _tagAssignments(),
    ),
    seatingRepository: _FakeSeatingRepository(seatingAssignments),
    sessionRepository: _FakeSessionRepository(),
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
