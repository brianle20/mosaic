import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/screens/event_hand_ledger_screen.dart';

void main() {
  testWidgets('renders compact newest-first ledger rows without wind labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: _FakeSessionRepository(rows: [_entry()]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand Ledger'), findsOneWidget);
    expect(find.text('Table 1 · Session 2 · Hand 4'), findsOneWidget);
    expect(find.text('1:26 PM'), findsOneWidget);
    expect(find.text('4 fan discard'), findsOneWidget);
    expect(find.text('-32'), findsOneWidget);
    expect(find.text('+32'), findsOneWidget);
    expect(find.text('Estevon'), findsOneWidget);
    expect(find.text('Brian'), findsOneWidget);
    expect(find.text('Estevon Jackson'), findsNothing);
    expect(find.text('East'), findsNothing);
    expect(find.text('South'), findsNothing);
    expect(find.text('Prize'), findsNothing);
  });

  testWidgets('renders empty state when no hands exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: const _FakeSessionRepository(rows: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hands recorded yet.'), findsOneWidget);
  });
}

class _FakeSessionRepository implements SessionRepository {
  const _FakeSessionRepository({required this.rows});

  final List<EventHandLedgerEntry> rows;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
          String eventId) async =>
      rows;

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

EventHandLedgerEntry _entry() {
  return EventHandLedgerEntry(
    eventId: 'evt_01',
    tableId: 'tbl_01',
    tableLabel: 'Table 1',
    sessionId: 'ses_02',
    sessionNumberForTable: 2,
    handId: 'hand_04',
    handNumber: 4,
    enteredAt: DateTime.parse('2026-04-24T13:26:00-07:00'),
    resultType: HandResultType.win,
    status: HandResultStatus.recorded,
    winType: HandWinType.discard,
    fanCount: 4,
    hasSettlements: true,
    cells: const [
      EventHandLedgerCell(
        wind: SeatWind.east,
        seatIndex: 0,
        eventGuestId: 'gst_east',
        displayName: 'Estevon Jackson',
        pointsDelta: 0,
      ),
      EventHandLedgerCell(
        wind: SeatWind.south,
        seatIndex: 1,
        eventGuestId: 'gst_south',
        displayName: 'Brian Lee',
        pointsDelta: 32,
      ),
      EventHandLedgerCell(
        wind: SeatWind.west,
        seatIndex: 2,
        eventGuestId: 'gst_west',
        displayName: 'Justin Park',
        pointsDelta: -32,
      ),
      EventHandLedgerCell(
        wind: SeatWind.north,
        seatIndex: 3,
        eventGuestId: 'gst_north',
        displayName: 'Giang Pham',
        pointsDelta: 0,
      ),
    ],
  );
}
