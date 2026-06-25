import 'dart:async';

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
          sessionRepository: _FakeSessionRepository(rows: []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hands recorded yet.'), findsOneWidget);
  });

  testWidgets('renders bonus tint marker without crowding hand label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: _FakeSessionRepository(
            rows: [_entry(bonusRoundId: 'bonus_01')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Table 1 · Session 2 · Hand 4'), findsOneWidget);
    expect(find.text('Bonus round'), findsOneWidget);
    expect(find.text('4 fan discard'), findsOneWidget);
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('Bonus round only'), findsNothing);
  });

  testWidgets('keeps shortened finals champion award summary inside ledger row',
      (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: _FakeSessionRepository(
            rows: [_adjustmentEntry()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Champion award'), findsOneWidget);
    expect(find.text('Bonus +24 · Top +13'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'tapping a correctable hand row opens edit flow and refreshes ledger after saving',
      (tester) async {
    final repository = _FakeSessionRepository(
      rows: [_entry()],
      sessionDetail: _sessionDetailWithHand(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: repository,
          canCorrectHands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Table 1 · Session 2 · Hand 4'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Hand'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Fan Count'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Fan Count'),
      ).controller?.text,
      '4',
    );
    expect(repository.loadedSessionIds, ['ses_02']);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.editedInput, isNotNull);
    expect(repository.loadLedgerCount, 2);
  });

  testWidgets(
      'rapid repeated taps while correction lookup is in flight only open one editor',
      (tester) async {
    final loadSessionDetailCompleter = Completer<SessionDetailRecord>();
    final repository = _FakeSessionRepository(
      rows: [_entry()],
      sessionDetail: _sessionDetailWithHand(),
      loadSessionDetailCompleter: loadSessionDetailCompleter,
    );
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: repository,
          canCorrectHands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialPushCount = observer.pushCount;

    await tester.tap(find.text('Table 1 · Session 2 · Hand 4'));
    await tester.tap(find.text('Table 1 · Session 2 · Hand 4'));

    expect(repository.loadedSessionIds, ['ses_02']);
    expect(observer.pushCount, initialPushCount);

    loadSessionDetailCompleter.complete(_sessionDetailWithHand());
    await tester.pumpAndSettle();

    expect(repository.loadedSessionIds, ['ses_02']);
    expect(observer.pushCount, initialPushCount + 1);
    expect(find.text('Edit Hand'), findsOneWidget);
  });

  testWidgets('hand row is read-only when corrections are disabled',
      (tester) async {
    final repository = _FakeSessionRepository(
      rows: [_entry()],
      sessionDetail: _sessionDetailWithHand(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Table 1 · Session 2 · Hand 4'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Hand'), findsNothing);
    expect(repository.loadedSessionIds, isEmpty);
    expect(repository.editedInput, isNull);
  });

  testWidgets('adjustment row does not open correction flow', (tester) async {
    final repository = _FakeSessionRepository(
      rows: [_adjustmentEntry()],
      sessionDetail: _sessionDetailWithHand(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventHandLedgerScreen(
          eventId: 'evt_01',
          sessionRepository: repository,
          canCorrectHands: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Champion award'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Hand'), findsNothing);
    expect(repository.loadedSessionIds, isEmpty);
    expect(repository.editedInput, isNull);
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    required this.rows,
    this.sessionDetail,
    this.loadSessionDetailCompleter,
  });

  final List<EventHandLedgerEntry> rows;
  final SessionDetailRecord? sessionDetail;
  final Completer<SessionDetailRecord>? loadSessionDetailCompleter;
  int loadLedgerCount = 0;
  final loadedSessionIds = <String>[];
  EditHandResultInput? editedInput;

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async {
    loadLedgerCount += 1;
    return rows;
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
    loadedSessionIds.add(sessionId);
    final completer = loadSessionDetailCompleter;
    if (completer != null) {
      return completer.future;
    }
    final detail = sessionDetail;
    if (detail == null) {
      throw UnimplementedError();
    }
    return Future.value(detail);
  }

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) {
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
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async {
    editedInput = input;
    final detail = sessionDetail;
    if (detail == null) {
      throw UnimplementedError();
    }
    return detail;
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount += 1;
    super.didPush(route, previousRoute);
  }
}

EventHandLedgerEntry _entry({String? bonusRoundId}) {
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
    bonusRoundId: bonusRoundId,
    bonusTableRole: bonusRoundId == null ? null : 'table_of_champions',
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

EventHandLedgerEntry _adjustmentEntry() {
  return EventHandLedgerEntry.fromJson({
    'event_id': 'evt_01',
    'entered_at': '2026-04-24T22:15:00-07:00',
    'ledger_row_type': 'adjustment',
    'adjustment_id': 'adj_01',
    'adjustment_type': 'finals_champion_award',
    'adjustment_amount_points': 37,
    'adjustment_event_guest_id': 'gst_01',
    'adjustment_display_name': 'Alice Wong',
    'adjustment_context_json': {
      'champion_bonus_score_points': 24,
      'champion_top_up_points': 13,
    },
    'cells': const [],
  });
}

SessionDetailRecord _sessionDetailWithHand() {
  return SessionDetailRecord.fromJson({
    'table_label': 'Table 1',
    'session': {
      'id': 'ses_02',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 2,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': 'completed',
      'scoring_phase': 'tournament',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 0,
      'dealer_pass_count': 1,
      'completed_games_count': 1,
      'hand_count': 1,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': [
      {
        'id': 'seat_01',
        'table_session_id': 'ses_02',
        'seat_index': 0,
        'initial_wind': 'east',
        'event_guest_id': 'gst_east',
      },
      {
        'id': 'seat_02',
        'table_session_id': 'ses_02',
        'seat_index': 1,
        'initial_wind': 'south',
        'event_guest_id': 'gst_south',
      },
      {
        'id': 'seat_03',
        'table_session_id': 'ses_02',
        'seat_index': 2,
        'initial_wind': 'west',
        'event_guest_id': 'gst_west',
      },
      {
        'id': 'seat_04',
        'table_session_id': 'ses_02',
        'seat_index': 3,
        'initial_wind': 'north',
        'event_guest_id': 'gst_north',
      },
    ],
    'hands': [
      {
        'id': 'hand_03',
        'table_session_id': 'ses_02',
        'hand_number': 3,
        'result_type': 'win',
        'winner_seat_index': 2,
        'win_type': 'self_draw',
        'discarder_seat_index': null,
        'fan_count': 8,
        'base_points': 16,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': false,
        'status': 'recorded',
        'entered_by_user_id': 'usr_02',
        'entered_at': '2026-04-24T13:14:00-07:00',
      },
      {
        'id': 'hand_04',
        'table_session_id': 'ses_02',
        'hand_number': 4,
        'result_type': 'win',
        'winner_seat_index': 0,
        'win_type': 'discard',
        'discarder_seat_index': 1,
        'fan_count': 4,
        'base_points': 8,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': true,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T13:26:00-07:00',
      },
    ],
    'settlements': const [],
  });
}
