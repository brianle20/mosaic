import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/services/qr/qr_scanner_service.dart';

class _RecordingSessionRepository implements SessionRepository {
  RecordHandResultInput? recordedInput;
  EditHandResultInput? editedInput;
  VoidHandResultInput? voidedInput;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  SessionDetailRecord _detailFromStatus(HandResultStatus status) {
    return SessionDetailRecord.fromJson({
      'session': {
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
          'id': 'hand_01',
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
          'session_completed_after_hand': false,
          'status': status.name,
          'entered_by_user_id': 'usr_01',
          'entered_at': '2026-04-24T19:05:00-07:00',
        },
      ],
      'settlements': const [],
    });
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async {
    editedInput = input;
    return _detailFromStatus(HandResultStatus.recorded);
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    recordedInput = input;
    return _detailFromStatus(HandResultStatus.recorded);
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async =>
      const [];

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
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
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async {
    voidedInput = input;
    return _detailFromStatus(HandResultStatus.voided);
  }
}

class _PassiveNfcService implements NfcService, PassiveNfcService {
  final controller = StreamController<TagScanResult>.broadcast();

  @override
  Stream<TagScanResult> get playerTagScans => controller.stream;

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(BuildContext context) {
    throw UnimplementedError();
  }

  @override
  Future<TagScanResult?> scanPlayerTagForIdentification(
          BuildContext context) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) {
    throw UnimplementedError();
  }

  Future<void> dispose() => controller.close();
}

class _QueuedPlayerNfcService implements NfcService {
  _QueuedPlayerNfcService(this.results);

  final List<TagScanResult?> results;

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
      BuildContext context) async {
    return results.removeAt(0);
  }

  @override
  Future<TagScanResult?> scanPlayerTagForIdentification(
          BuildContext context) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) {
    throw UnimplementedError();
  }
}

class _QueuedQrScannerService implements QrScannerService {
  _QueuedQrScannerService(this.results);

  final List<Object?> results;

  @override
  Future<QrScanResult?> scanPlayerCode(BuildContext context) async {
    final next = results.removeAt(0);
    if (next is Exception) {
      throw next;
    }
    return next as QrScanResult?;
  }
}

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  SessionDetailRecord buildDetail({
    int currentDealerSeatIndex = 0,
    EventScoringPhase scoringPhase = EventScoringPhase.qualification,
    String? startedAt,
    int roundTimerPausedSeconds = 0,
  }) {
    return SessionDetailRecord.fromJson({
      'session': {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD',
        'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'rotation_policy_config_json': {},
        'status': 'active',
        'scoring_phase': eventScoringPhaseToJson(scoringPhase),
        'initial_east_seat_index': 0,
        'current_dealer_seat_index': currentDealerSeatIndex,
        'dealer_pass_count': 0,
        'completed_games_count': 0,
        'hand_count': 0,
        'started_at': startedAt ?? DateTime.now().toIso8601String(),
        'started_by_user_id': 'usr_01',
        'round_timer_paused_seconds': roundTimerPausedSeconds,
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
      'hands': const [],
      'settlements': const [],
    });
  }

  Map<String, String> seatNames = const {
    'gst_east': 'Alice Wong',
    'gst_south': 'Bob Lee',
    'gst_west': 'Carol Ng',
    'gst_north': 'Dee Wu',
  };

  testWidgets('seat buttons select a self-draw winner', (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'East\nBob Lee'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '3');
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 1);
    expect(repository.recordedInput?.winType, HandWinType.selfDraw);
  });

  testWidgets('seat buttons select winner then discarder in discard mode',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Discard'));
    await tester.tap(find.widgetWithText(FilledButton, 'East\nBob Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'South\nCarol Ng'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '5');
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 1);
    expect(repository.recordedInput?.discarderSeatIndex, 2);
    expect(repository.recordedInput?.winType, HandWinType.discard);
  });

  testWidgets('toggles conditional fields, shows preview, and saves',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Self-draw'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Discarder'), findsNothing);

    await tapVisible(tester, find.text('Discard'));
    expect(find.text('Discarder'), findsOneWidget);

    await tapVisible(tester, find.text('Winner'));
    await tester.tap(find.text('Alice Wong (East)').last);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Discarder'));
    await tester.tap(find.text('Bob Lee (South)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '3');
    await tester.pumpAndSettle();

    expect(find.text('Scoring Preview'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNotNull);
    expect(repository.recordedInput!.winType, HandWinType.discard);
  });

  testWidgets('excludes the selected winner from the discarder menu',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Winner'));
    await tester.tap(find.text('Alice Wong (East)').last);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Discard'));
    await tapVisible(tester, find.text('Discarder'));

    expect(find.text('Alice Wong (East)'), findsOneWidget);
    expect(find.text('Bob Lee (South)'), findsOneWidget);
  });

  testWidgets('discarder selector appears before fan count for discard wins',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: _RecordingSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    final discarderTop = tester.getTopLeft(find.text('Discarder')).dy;
    final fanCountTop =
        tester.getTopLeft(find.widgetWithText(TextFormField, 'Fan Count')).dy;

    expect(discarderTop, lessThan(fanCountTop));
  });

  testWidgets('player labels use current dealer as east', (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Winner'));

    expect(find.text('Bob Lee (East)'), findsOneWidget);
    expect(find.text('Carol Ng (South)'), findsOneWidget);
    expect(find.text('Dee Wu (West)'), findsOneWidget);
    expect(find.text('Alice Wong (North)'), findsOneWidget);
    expect(find.text('Bob Lee (South)'), findsNothing);
  });

  testWidgets('blocks wins below three fan', (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Winner'));
    await tester.tap(find.text('Alice Wong (East)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'),
      '2',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 3 fan.'), findsOneWidget);
    expect(find.text('Scoring Preview'), findsNothing);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNull);
  });

  testWidgets('expired round warns but still allows saving a hand',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            scoringPhase: EventScoringPhase.tournament,
            startedAt: DateTime.now()
                .subtract(const Duration(minutes: 61))
                .toIso8601String(),
          ),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round time has expired.'), findsOneWidget);

    await tapVisible(tester, find.text('Winner'));
    await tester.tap(find.text('Alice Wong (East)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'),
      '3',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNotNull);
  });

  testWidgets('round warning respects paused timer time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            scoringPhase: EventScoringPhase.tournament,
            startedAt: DateTime.now()
                .subtract(const Duration(minutes: 80))
                .toIso8601String(),
            roundTimerPausedSeconds: const Duration(minutes: 30).inSeconds,
          ),
          guestNamesById: seatNames,
          sessionRepository: _RecordingSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round time has expired.'), findsNothing);
  });

  testWidgets('expired qualification session does not show round warning',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            scoringPhase: EventScoringPhase.qualification,
            startedAt: DateTime.now()
                .subtract(const Duration(minutes: 61))
                .toIso8601String(),
          ),
          guestNamesById: seatNames,
          sessionRepository: _RecordingSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Round time has expired.'), findsNothing);
  });

  testWidgets('draw requires dealer waiting state before saving',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    expect(find.text('Dealer: Alice Wong'), findsOneWidget);
    expect(find.text('Waiting'), findsOneWidget);
    expect(find.text('Not waiting'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(find.text('Select whether dealer was waiting.'), findsOneWidget);
    expect(repository.recordedInput, isNull);

    await tester.tap(find.text('Not waiting'));
    await tester.pumpAndSettle();
    expect(find.text('Draw. Dealer rotates.'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.resultType, HandResultType.washout);
    expect(repository.recordedInput?.dealerWasWaitingAtDraw, isFalse);
  });

  testWidgets('false win penalty records caller without win fields',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('False Win'));
    await tester.pumpAndSettle();

    expect(find.text('Caller'), findsOneWidget);
    expect(find.text('6 fan to each player.'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();
    expect(find.text('Select the false win caller.'), findsOneWidget);
    expect(repository.recordedInput, isNull);

    await tester.tap(find.text('Caller'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carol Ng (South)').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Carol Ng (South) false win penalty. East retains.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(
        repository.recordedInput?.resultType, HandResultType.falseWinPenalty);
    expect(repository.recordedInput?.penaltySeatIndex, 2);
    expect(repository.recordedInput?.winnerSeatIndex, isNull);
    expect(repository.recordedInput?.winType, isNull);
    expect(repository.recordedInput?.fanCount, isNull);
  });

  testWidgets('editing a draw labels the dealer from that hand',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final existingHand = HandResultRecord.fromJson(const {
      'id': 'hand_01',
      'table_session_id': 'ses_01',
      'hand_number': 1,
      'result_type': 'washout',
      'winner_seat_index': null,
      'win_type': null,
      'discarder_seat_index': null,
      'fan_count': null,
      'base_points': null,
      'dealer_was_waiting_at_draw': true,
      'east_seat_index_before_hand': 2,
      'east_seat_index_after_hand': 2,
      'dealer_rotated': false,
      'session_completed_after_hand': false,
      'status': 'recorded',
      'entered_by_user_id': 'usr_01',
      'entered_at': '2026-04-24T19:05:00-07:00',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: existingHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dealer: Carol Ng'), findsOneWidget);
    expect(find.text('Dealer: Alice Wong'), findsNothing);
  });

  testWidgets('player tag scan selects the matching seated winner',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final nfcService = _PassiveNfcService();
    addTearDown(nfcService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
          },
          sessionRepository: repository,
          nfcService: nfcService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    nfcService.controller.add(
      const TagScanResult(
        rawUid: 'player-south',
        normalizedUid: 'PLAYER-SOUTH',
        isManualEntry: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bob Lee (East)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'),
      '3',
    );
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 1);
  });

  testWidgets('explicit player scan selects the matching seated winner',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final nfcService = _QueuedPlayerNfcService([
      const TagScanResult(
        rawUid: 'player-south',
        normalizedUid: 'PLAYER-SOUTH',
        isManualEntry: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
          },
          sessionRepository: repository,
          nfcService: nfcService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Scan NFC for winner'));

    expect(find.text('Bob Lee (East)'), findsOneWidget);
    expect(find.text('Scan Target'), findsNothing);
  });

  testWidgets('discard scan buttons fill winner then discarder',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final nfcService = _QueuedPlayerNfcService([
      const TagScanResult(
        rawUid: 'player-south',
        normalizedUid: 'PLAYER-SOUTH',
        isManualEntry: false,
      ),
      const TagScanResult(
        rawUid: 'player-west',
        normalizedUid: 'PLAYER-WEST',
        isManualEntry: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
            'gst_west': _assignment('gst_west', 'PLAYER-WEST'),
          },
          sessionRepository: repository,
          nfcService: nfcService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Scan Target'), findsNothing);
    expect(find.text('Scan NFC for winner'), findsOneWidget);
    expect(find.text('Scan Winner'), findsNothing);
    expect(find.text('Scan Discarder'), findsNothing);

    await tapVisible(tester, find.text('Scan NFC for winner'));

    expect(find.text('Bob Lee (East)'), findsOneWidget);
    expect(find.text('Scan NFC for discarder'), findsOneWidget);

    await tapVisible(tester, find.text('Scan NFC for discarder'));

    expect(find.text('Carol Ng (South)'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'),
      '3',
    );
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 1);
    expect(repository.recordedInput?.discarderSeatIndex, 2);
  });

  testWidgets('QR scan selects the active player target', (tester) async {
    final repository = _RecordingSessionRepository();
    final qrScanner = _QueuedQrScannerService([
      const QrScanResult(
        rawPayload: 'mosaic:tag:player-south',
        normalizedUid: 'PLAYER-SOUTH',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
          },
          sessionRepository: repository,
          qrScannerService: qrScanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Scan QR for winner'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '3');
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 1);
  });

  testWidgets('scanner cannot select winner as discarder', (tester) async {
    final repository = _RecordingSessionRepository();
    final qrScanner = _QueuedQrScannerService([
      const QrScanResult(
        rawPayload: 'mosaic:tag:player-south',
        normalizedUid: 'PLAYER-SOUTH',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
          },
          sessionRepository: repository,
          qrScannerService: qrScanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'East\nBob Lee'));
    await tester.pumpAndSettle();
    final scanQrButton =
        find.widgetWithText(FilledButton, 'Scan QR for discarder');
    await tester.ensureVisible(scanQrButton);
    await tester.pumpAndSettle();
    await tester.tap(scanQrButton);
    await tester.pumpAndSettle();

    expect(find.text('Discarder cannot be the winner.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'East\nBob Lee'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Fan Count'),
      '3',
    );
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNull);
  });

  testWidgets('NFC backup scan still selects the active player target',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final nfcService = _QueuedPlayerNfcService([
      const TagScanResult(
        rawUid: 'player-west',
        normalizedUid: 'PLAYER-WEST',
        isManualEntry: false,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_west': _assignment('gst_west', 'PLAYER-WEST'),
          },
          sessionRepository: repository,
          nfcService: nfcService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Scan NFC for winner'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '4');
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winnerSeatIndex, 2);
  });

  testWidgets('unknown QR scan shows a local error', (tester) async {
    final repository = _RecordingSessionRepository();
    final qrScanner = _QueuedQrScannerService([
      const QrScanResult(
        rawPayload: 'mosaic:tag:missing',
        normalizedUid: 'MISSING',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          guestTagAssignmentsByGuestId: {
            'gst_south': _assignment('gst_south', 'PLAYER-SOUTH'),
          },
          sessionRepository: repository,
          qrScannerService: qrScanner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Scan QR for winner'));

    expect(
      find.text('Scanned code is not assigned to this table.'),
      findsOneWidget,
    );
  });

  testWidgets('shows void action for an existing hand', (tester) async {
    final repository = _RecordingSessionRepository();
    final existingHand = HandResultRecord.fromJson(const {
      'id': 'hand_01',
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
      'session_completed_after_hand': false,
      'status': 'recorded',
      'entered_by_user_id': 'usr_01',
      'entered_at': '2026-04-24T19:05:00-07:00',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: existingHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Void Hand'), findsOneWidget);

    await tapVisible(tester, find.text('Void Hand'));

    expect(repository.voidedInput, isNotNull);
    expect(repository.voidedInput!.handResultId, 'hand_01');
  });
}

GuestTagAssignmentSummary _assignment(String guestId, String uidHex) {
  return GuestTagAssignmentSummary.fromJson({
    'assignment_id': 'assign_$guestId',
    'event_id': 'evt_01',
    'event_guest_id': guestId,
    'status': 'assigned',
    'assigned_at': '2026-04-24T19:00:00-07:00',
    'nfc_tag': {
      'id': 'tag_$guestId',
      'uid_hex': uidHex,
      'uid_fingerprint': uidHex,
      'default_tag_type': 'player',
      'status': 'active',
    },
  });
}
