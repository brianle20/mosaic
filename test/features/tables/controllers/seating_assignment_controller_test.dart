import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
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

void main() {
  test('load publishes cached assignments before remote assignments', () async {
    final repository = _FakeSeatingRepository(
      cachedAssignments: [_assignment(displayName: 'Cached East')],
      loadedAssignments: [_assignment(displayName: 'Remote East')],
    );
    final controller = SeatingAssignmentController(repository);
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
    final controller = SeatingAssignmentController(repository);

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
    final controller = SeatingAssignmentController(repository);

    await controller.clear('evt_01');

    expect(repository.calls, ['clear:evt_01']);
    expect(controller.assignments, isEmpty);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
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
