import 'dart:async';

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

    test('loads correction target from ledger row session and hand id', () async {
      final detail = _sessionDetailWithHand('hand_01');
      final repository = _FakeSessionRepository(
        loadedRows: [_entry('hand_01', handNumber: 1)],
        sessionDetail: detail,
      );
      final controller = EventHandLedgerController(sessionRepository: repository);
      await controller.load('evt_01');

      final target = await controller.loadCorrectionTarget(controller.rows.single);

      expect(repository.loadedSessionIds, ['ses_01']);
      expect(target, isNotNull);
      expect(target!.detail.session.id, 'ses_01');
      expect(target.hand.id, 'hand_01');
      expect(target.guestNamesById['gst_east'], 'East Player');
      expect(controller.correctionError, isNull);
      expect(controller.isLoadingCorrection, isFalse);
    });

    test('reports a correction error when the hand is missing from session detail',
        () async {
      final repository = _FakeSessionRepository(
        loadedRows: [_entry('hand_01', handNumber: 1)],
        sessionDetail: _sessionDetailWithHand('other_hand'),
      );
      final controller = EventHandLedgerController(sessionRepository: repository);
      await controller.load('evt_01');

      final target = await controller.loadCorrectionTarget(controller.rows.single);

      expect(target, isNull);
      expect(
        controller.correctionError,
        'Hand is no longer available. Refresh the ledger and try again.',
      );
      expect(controller.isLoadingCorrection, isFalse);
    });

    test('does not load correction target for adjustment rows', () async {
      final repository = _FakeSessionRepository(
        loadedRows: [_adjustmentEntry()],
        sessionDetail: _sessionDetailWithHand('hand_01'),
      );
      final controller = EventHandLedgerController(
        sessionRepository: repository,
      );
      await controller.load('evt_01');

      final target = await controller.loadCorrectionTarget(controller.rows.single);

      expect(target, isNull);
      expect(controller.correctionError, isNull);
      expect(repository.loadedSessionIds, isEmpty);
    });

    test(
        'notifies loading state and clears stale correction error before loading detail',
        () async {
      final completer = Completer<SessionDetailRecord>();
      var loadCount = 0;
      final repository = _FakeSessionRepository(
        loadedRows: [_entry('hand_01', handNumber: 1)],
        detailLoader: (sessionId) {
          loadCount += 1;
          if (loadCount == 1) {
            return Future.value(_sessionDetailWithHand('other_hand'));
          }
          return completer.future;
        },
      );
      final controller = EventHandLedgerController(sessionRepository: repository);
      await controller.load('evt_01');

      await controller.loadCorrectionTarget(controller.rows.single);
      expect(controller.correctionError, isNotNull);

      final snapshots = <({bool isLoadingCorrection, String? correctionError})>[];
      controller.addListener(() {
        snapshots.add((
          isLoadingCorrection: controller.isLoadingCorrection,
          correctionError: controller.correctionError,
        ));
      });

      final targetFuture = controller.loadCorrectionTarget(controller.rows.single);
      await Future<void>.delayed(Duration.zero);

      expect(
        snapshots,
        contains(
          predicate<({bool isLoadingCorrection, String? correctionError})>(
            (snapshot) =>
                snapshot.isLoadingCorrection == true &&
                snapshot.correctionError == null,
          ),
        ),
      );

      completer.complete(_sessionDetailWithHand('hand_01'));
      final target = await targetFuture;

      expect(target, isNotNull);
      expect(controller.correctionError, isNull);
      expect(controller.isLoadingCorrection, isFalse);
    });
  });
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    this.cachedRows = const [],
    this.loadedRows = const [],
    this.loadError,
    this.sessionDetail,
    this.detailLoader,
  });

  final List<EventHandLedgerEntry> cachedRows;
  final List<EventHandLedgerEntry> loadedRows;
  final Object? loadError;
  final SessionDetailRecord? sessionDetail;
  final Future<SessionDetailRecord> Function(String sessionId)? detailLoader;
  final loadedSessionIds = <String>[];

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
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    loadedSessionIds.add(sessionId);
    final loader = detailLoader;
    if (loader != null) {
      return loader(sessionId);
    }
    final detail = sessionDetail;
    if (detail == null) {
      throw StateError('missing session detail');
    }
    return detail;
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
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

SessionDetailRecord _sessionDetailWithHand(String handId) {
  return SessionDetailRecord.fromJson({
    'table_label': 'Table 1',
    'session': {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD',
      'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'rotation_policy_config_json': {},
      'status': 'completed',
      'scoring_phase': 'tournament',
      'initial_east_seat_index': 0,
      'current_dealer_seat_index': 1,
      'dealer_pass_count': 1,
      'completed_games_count': 1,
      'hand_count': 1,
      'started_at': '2026-04-24T19:00:00-07:00',
      'started_by_user_id': 'usr_01',
    },
    'seats': [
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
    'hands': [
      {
        'id': handId,
        'table_session_id': 'ses_01',
        'hand_number': 1,
        'result_type': 'win',
        'winner_seat_index': 0,
        'win_type': 'self_draw',
        'discarder_seat_index': null,
        'fan_count': 3,
        'base_points': 8,
        'east_seat_index_before_hand': 0,
        'east_seat_index_after_hand': 0,
        'dealer_rotated': false,
        'session_completed_after_hand': true,
        'status': 'recorded',
        'entered_by_user_id': 'usr_01',
        'entered_at': '2026-04-24T19:05:00-07:00',
      },
    ],
    'settlements': const [],
  });
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
