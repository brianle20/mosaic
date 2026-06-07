import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/features/tables/screens/start_session_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

import '../../../helpers/repository_fakes.dart';

void main() {
  testWidgets('starts assigned table after scanning table tag', (tester) async {
    final sessionRepository = _FakeSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.sessionDetailRoute) {
            return MaterialPageRoute<void>(
              builder: (_) => const SizedBox(key: Key('session-detail')),
              settings: settings,
            );
          }
          return null;
        },
        home: StartSessionScreen(
          eventId: 'evt_01',
          table: _table(),
          guestRepository: const _FakeGuestRepository(),
          seatingRepository: _FakeSeatingRepository(_tableAssignments()),
          sessionRepository: sessionRepository,
          nfcService: _QueuedTableNfcService([
            const TagScanResult(
              rawUid: 'table-001',
              normalizedUid: 'TABLE-001',
              isManualEntry: false,
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan Table Tag'), findsOneWidget);
    await tester.tap(find.text('Scan Next Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Review assigned seating'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Billy'), findsOneWidget);

    await tester.tap(find.text('Start Assigned Table'));
    await tester.pumpAndSettle();

    expect(sessionRepository.startedAssignedInput?.eventTableId, 'tbl_01');
    expect(sessionRepository.startedAssignedInput?.scannedTableUid, 'TABLE-001');
    expect(find.byKey(const Key('session-detail')), findsOneWidget);
  });

  testWidgets('requires assigned seating and does not show player tag prompts',
      (tester) async {
    final sessionRepository = _FakeSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: StartSessionScreen(
          eventId: 'evt_01',
          table: _table(),
          guestRepository: const _FakeGuestRepository(),
          seatingRepository: const _FakeSeatingRepository([]),
          sessionRepository: sessionRepository,
          nfcService: const _EmptyTableNfcService(),
          preverifiedTableTagUid: 'TABLE-001',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assigned seating required'), findsOneWidget);
    expect(find.textContaining('Player Tag'), findsNothing);
    expect(find.text('Start Assigned Table'), findsNothing);

    expect(sessionRepository.startedAssignedInput, isNull);
  });
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  const _FakeGuestRepository();

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];
}

class _FakeSeatingRepository extends ThrowingSeatingRepository {
  const _FakeSeatingRepository(this.assignments);

  final List<SeatingAssignmentRecord> assignments;

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async =>
      assignments;
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
}

class _QueuedTableNfcService implements NfcService {
  _QueuedTableNfcService(this.results);

  final List<TagScanResult?> results;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return results.removeAt(0);
  }
}

class _EmptyTableNfcService implements NfcService {
  const _EmptyTableNfcService();

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async => null;
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
  return SeatingAssignmentRecord.fromJson({
    'id': 'seat_$seatIndex',
    'event_id': 'evt_01',
    'event_table_id': 'tbl_01',
    'table_label': 'Table 1',
    'event_guest_id': guestId,
    'display_name': name,
    'assignment_round': 1,
    'seat_index': seatIndex,
    'status': 'active',
    'created_at': '2026-04-24T18:00:00-07:00',
  });
}

StartedTableSessionRecord _startedSession() {
  return StartedTableSessionRecord(
    session: TableSessionRecord.fromJson(const {
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
      'scoring_phase': 'tournament',
    }),
    seats: const [],
  );
}
