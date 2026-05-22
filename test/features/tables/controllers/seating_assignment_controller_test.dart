import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/seating_assignment_controller.dart';

class _FakeSeatingRepository implements SeatingRepository {
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

class _FakeGuestRepository implements GuestRepository {
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

void main() {
  test('load publishes cached assignments before remote assignments', () async {
    final repository = _FakeSeatingRepository(
      cachedAssignments: [_assignment(displayName: 'Cached East')],
      loadedAssignments: [_assignment(displayName: 'Remote East')],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: repository,
      guestRepository: _FakeGuestRepository(),
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
    );

    await controller.clear('evt_01');

    expect(repository.calls, ['clear:evt_01']);
    expect(controller.assignments, isEmpty);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
  });

  test('generate identifies eligible guests left unassigned', () async {
    final guests = [
      _guest(id: 'gst_01', displayName: 'Alice'),
      _guest(id: 'gst_02', displayName: 'Billy'),
      _guest(id: 'gst_03', displayName: 'Carmen'),
      _guest(id: 'gst_04', displayName: 'Dev'),
      _guest(id: 'gst_05', displayName: 'Ellen'),
      _guest(
        id: 'gst_06',
        displayName: 'Not Checked In',
        attendanceStatus: 'expected',
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
    );

    await controller.generate('evt_01');

    expect(
      controller.unassignedGuests.map((guest) => guest.displayName),
      ['Ellen'],
    );
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

EventGuestRecord _guest({
  required String id,
  required String displayName,
  String attendanceStatus = 'checked_in',
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
