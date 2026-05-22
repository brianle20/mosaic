import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/seating_assignment_screen.dart';

class _FakeSeatingRepository implements SeatingRepository {
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
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      loadedAssignments;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async =>
      const [];
}

void main() {
  testWidgets('shows empty state and generate action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
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
