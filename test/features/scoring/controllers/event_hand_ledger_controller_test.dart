import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/controllers/event_hand_ledger_controller.dart';

void main() {
  group('EventHandLedgerController', () {
    test('loads cached rows before refreshed rows', () async {
      final controller = EventHandLedgerController(
        sessionRepository: _FakeSessionRepository(
          cachedRows: [_entry('cached_hand', handNumber: 1)],
          loadedRows: [_entry('live_hand', handNumber: 2)],
        ),
      );

      final seen = <List<String>>[];
      controller.addListener(() {
        seen.add(controller.rows.map((row) => row.handId).toList());
      });

      await controller.load('evt_01');

      expect(seen, contains(equals(['cached_hand'])));
      expect(controller.rows.map((row) => row.handId), ['live_hand']);
      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
    });

    test('shows error only when no cached rows exist', () async {
      final controller = EventHandLedgerController(
        sessionRepository: _FakeSessionRepository(
          loadError: StateError('ledger unavailable'),
        ),
      );

      await controller.load('evt_01');

      expect(controller.rows, isEmpty);
      expect(controller.error, contains('ledger unavailable'));
    });
  });
}

class _FakeSessionRepository implements SessionRepository {
  const _FakeSessionRepository({
    this.cachedRows = const [],
    this.loadedRows = const [],
    this.loadError,
  });

  final List<EventHandLedgerEntry> cachedRows;
  final List<EventHandLedgerEntry> loadedRows;
  final Object? loadError;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      cachedRows;

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId) async {
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return loadedRows;
  }

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
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
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

EventHandLedgerEntry _entry(String id, {required int handNumber}) {
  return EventHandLedgerEntry(
    eventId: 'evt_01',
    tableId: 'tbl_01',
    tableLabel: 'Table 1',
    sessionId: 'ses_01',
    sessionNumberForTable: 1,
    handId: id,
    handNumber: handNumber,
    enteredAt: DateTime.parse('2026-04-24T20:15:00-07:00'),
    resultType: HandResultType.washout,
    status: HandResultStatus.recorded,
    hasSettlements: false,
    cells: const [
      EventHandLedgerCell(
        wind: SeatWind.east,
        seatIndex: 0,
        eventGuestId: 'gst_east',
        displayName: 'East Player',
        pointsDelta: 0,
      ),
      EventHandLedgerCell(
        wind: SeatWind.south,
        seatIndex: 1,
        eventGuestId: 'gst_south',
        displayName: 'South Player',
        pointsDelta: 0,
      ),
      EventHandLedgerCell(
        wind: SeatWind.west,
        seatIndex: 2,
        eventGuestId: 'gst_west',
        displayName: 'West Player',
        pointsDelta: 0,
      ),
      EventHandLedgerCell(
        wind: SeatWind.north,
        seatIndex: 3,
        eventGuestId: 'gst_north',
        displayName: 'North Player',
        pointsDelta: 0,
      ),
    ],
  );
}
