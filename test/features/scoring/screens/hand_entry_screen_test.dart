import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/hand_win_bonus.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';
import 'package:mosaic/services/media/hand_photo_service.dart';
import 'package:mosaic/services/media/hand_photo_storage.dart';

CapturedHandPhoto _photo(String clientPhotoId, String localPath) {
  return CapturedHandPhoto(
    clientPhotoId: clientPhotoId,
    localPath: localPath,
    capturedAt: DateTime.utc(2026, 6, 25, 18),
  );
}

class _SequencedHandPhotoService implements HandPhotoService {
  _SequencedHandPhotoService(this.photos);

  final List<CapturedHandPhoto?> photos;
  int _nextPhoto = 0;

  @override
  Future<CapturedHandPhoto?> captureWinningHandPhoto() async {
    return photos[_nextPhoto++];
  }
}

class _DelayedHandPhotoService implements HandPhotoService {
  final Completer<CapturedHandPhoto?> completer =
      Completer<CapturedHandPhoto?>();
  int captureCount = 0;

  @override
  Future<CapturedHandPhoto?> captureWinningHandPhoto() {
    captureCount += 1;
    return completer.future;
  }
}

class _FakeHandPhotoStorage implements HandPhotoStorage {
  _FakeHandPhotoStorage({Set<String>? existing})
      : existingPaths = {...?existing};

  final Set<String> existingPaths;
  final List<String> deletedPaths = [];

  @override
  Future<void> delete(String path) async {
    deletedPaths.add(path);
    existingPaths.remove(path);
  }

  @override
  Future<bool> exists(String path) async => existingPaths.contains(path);

  @override
  Future<String> persist({
    required String sourcePath,
    required String photoId,
  }) async {
    existingPaths.add(sourcePath);
    return sourcePath;
  }
}

class _FakeHandPhotoService implements HandPhotoService {
  _FakeHandPhotoService({CapturedHandPhoto? photo})
      : photo = photo ??
            CapturedHandPhoto(
              clientPhotoId: 'photo_client_01',
              localPath: '/local/hand.jpg',
              capturedAt: DateTime.utc(2026, 6, 25, 18),
            );

  final CapturedHandPhoto? photo;
  int captureCount = 0;

  @override
  Future<CapturedHandPhoto?> captureWinningHandPhoto() async {
    captureCount += 1;
    return photo;
  }
}

class _RecordingSessionRepository
    implements SessionRepository, FalseWinPenaltyCorrectionRepository {
  RecordHandResultInput? recordedInput;
  EditHandResultInput? editedInput;
  VoidHandResultInput? voidedInput;
  VoidFalseWinPenaltyInput? voidedFalseWinPenalty;
  RecordFalseWinPenaltyInput? recordedFalseWinPenalty;
  int recordFalseWinPenaltyCallCount = 0;
  Completer<SessionDetailRecord>? recordHandCompleter;
  Completer<SessionDetailRecord>? recordFalseWinPenaltyCompleter;
  SessionDetailRecord Function(RecordFalseWinPenaltyInput input)?
      falseWinPenaltyResponseBuilder;
  SessionDetailRecord Function(VoidFalseWinPenaltyInput input)?
      voidFalseWinPenaltyResponseBuilder;
  SessionStatus recordHandSessionStatus = SessionStatus.active;

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
        'status': switch (recordHandSessionStatus) {
          SessionStatus.active => 'active',
          SessionStatus.paused => 'paused',
          SessionStatus.completed => 'completed',
          SessionStatus.endedEarly => 'ended_early',
          SessionStatus.aborted => 'aborted',
        },
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
          'session_completed_after_hand':
              recordHandSessionStatus == SessionStatus.completed,
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
    final pendingResponse = recordHandCompleter;
    if (pendingResponse != null) {
      return pendingResponse.future;
    }
    return _detailFromStatus(HandResultStatus.recorded);
  }

  @override
  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  ) async {
    recordedFalseWinPenalty = input;
    recordFalseWinPenaltyCallCount += 1;
    final pendingResponse = recordFalseWinPenaltyCompleter;
    if (pendingResponse != null) {
      return pendingResponse.future;
    }
    return falseWinPenaltyResponseBuilder?.call(input) ??
        _detailFromStatus(HandResultStatus.recorded);
  }

  @override
  Future<SessionDetailRecord> voidFalseWinPenalty(
    VoidFalseWinPenaltyInput input,
  ) async {
    voidedFalseWinPenalty = input;
    return voidFalseWinPenaltyResponseBuilder?.call(input) ??
        _detailFromStatus(HandResultStatus.recorded);
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
  Future<List<TableSessionRecord>> startBonusAssignedTableSessions({
    required String eventId,
    required BonusTableRole? bonusTableRole,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async {
    voidedInput = input;
    return _detailFromStatus(HandResultStatus.voided);
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
    List<Map<String, Object?>> falseWinPenalties = const [],
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
      'false_win_penalties': falseWinPenalties,
    });
  }

  Map<String, Object?> falseWinPenaltyJson({
    int penaltySeatIndex = 2,
    String status = 'pending',
    String? handResultId,
  }) {
    return {
      'id': 'penalty-$penaltySeatIndex',
      'table_session_id': 'session-1',
      'hand_result_id': handResultId,
      'penalty_seat_index': penaltySeatIndex,
      'fan_count': 6,
      'entered_by_user_id': 'host-1',
      'entered_at': '2026-06-24T12:00:00Z',
      'status': status,
      'correction_note': null,
    };
  }

  Map<String, String> seatNames = const {
    'gst_east': 'Alice Wong',
    'gst_south': 'Bob Lee',
    'gst_west': 'Carol Ng',
    'gst_north': 'Dee Wu',
  };

  Future<void> pumpHandEntry(
    WidgetTester tester, {
    required _RecordingSessionRepository repository,
    required HandPhotoService handPhotoService,
    required HandPhotoStorage handPhotoStorage,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HandEntryScreen(
                    sessionDetail: buildDetail(),
                    guestNamesById: seatNames,
                    sessionRepository: repository,
                    handPhotoService: handPhotoService,
                    handPhotoStorage: handPhotoStorage,
                  ),
                ),
              );
            },
            child: const Text('Open hand entry'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open hand entry'));
    await tester.pumpAndSettle();
  }

  Future<void> completeValidWinAndSave(WidgetTester tester) async {
    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'East\nAlice Wong'),
    );
    await tapVisible(tester, find.text('Save Hand'));
  }

  Map<String, dynamic> existingWinHandJson() {
    return {
      'id': 'hand_01',
      'table_session_id': 'ses_01',
      'hand_number': 1,
      'result_type': 'win',
      'winner_seat_index': 0,
      'win_type': 'self_draw',
      'discarder_seat_index': null,
      'penalty_seat_index': null,
      'fan_count': 3,
      'base_points': 8,
      'dealer_was_waiting_at_draw': null,
      'east_seat_index_before_hand': 0,
      'east_seat_index_after_hand': 0,
      'dealer_rotated': false,
      'session_completed_after_hand': false,
      'status': 'recorded',
      'entered_by_user_id': 'usr_01',
      'entered_at': '2026-04-24T19:05:00-07:00',
      'correction_note': null,
      'row_version': 1,
      'client_mutation_id': null,
      'photo_id': null,
      'photo_client_id': null,
      'photo_captured_at': null,
      'photo_upload_status': null,
      'photo_storage_bucket': null,
      'photo_storage_path': null,
    };
  }

  testWidgets('seat buttons select a self-draw winner', (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(currentDealerSeatIndex: 1),
          guestNamesById: seatNames,
          sessionRepository: repository,
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'East\nBob Lee'));
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
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Discard'));
    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'East\nBob Lee').first);
    await tester.pumpAndSettle();
    await tapVisible(
        tester, find.widgetWithText(OutlinedButton, 'South\nCarol Ng').last);
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '5F'));
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
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Self-draw'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
    expect(find.text('Choose discarder'), findsNothing);

    await tapVisible(tester, find.text('Discard'));
    expect(find.text('Choose discarder'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'East\nAlice Wong').first,
    );

    await tapVisible(tester, find.text('Choose discarder'));
    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'South\nBob Lee').last,
    );

    expect(find.text('Scoring Preview'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNotNull);
    expect(repository.recordedInput!.winType, HandWinType.discard);
  });

  testWidgets('uses guided sections and quick fan picks on one screen',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1. Result'), findsOneWidget);
    expect(find.text('2. Winner'), findsOneWidget);
    expect(find.text('3. Score'), findsOneWidget);
    expect(find.text('Declared fan'), findsOneWidget);

    final quickFanLabels = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .map((chip) => (chip.label as Text).data)
        .where((label) => label?.endsWith('F') ?? false)
        .toList();
    expect(quickFanLabels, ['3F', '4F', '5F', '6F', '7F']);
    expect(find.widgetWithText(ChoiceChip, '8F'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, '13F'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'East\nAlice Wong'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '7F'));

    expect(find.widgetWithText(TextFormField, 'Fan Count'), findsNothing);
    expect(find.byKey(const ValueKey('fanCountSlider')), findsOneWidget);
    expect(find.byKey(const ValueKey('fanCountDecrement')), findsOneWidget);
    expect(find.byKey(const ValueKey('fanCountIncrement')), findsOneWidget);
    expect(find.text('7F'), findsWidgets);
    expect(find.text('Alice Wong (East) wins by self-draw for 7 fan.'),
        findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.fanCount, 7);
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'East\nAlice Wong'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Discard'));
    await tapVisible(tester, find.text('Choose discarder'));

    expect(
        find.widgetWithText(OutlinedButton, 'East\nAlice Wong'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'South\nBob Lee'), findsWidgets);
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

    await tapVisible(tester, find.text('Discard'));

    final discarderTop = tester.getTopLeft(find.text('Choose discarder')).dy;
    final fanCountTop =
        tester.getTopLeft(find.byKey(const ValueKey('fanCountPicker'))).dy;

    expect(discarderTop, lessThan(fanCountTop));
  });

  testWidgets('records selected win bonuses with a win', (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Win bonuses'), findsOneWidget);
    expect(find.text('None selected'), findsOneWidget);
    expect(find.text('Concealed Hand'), findsNothing);
    expect(find.text('Concealed Hand +1F'), findsNothing);

    await tapVisible(tester, find.text('Win bonuses'));

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'East\nAlice Wong'),
    );
    await tapVisible(
      tester,
      find.text('Concealed Hand'),
    );
    await tapVisible(
      tester,
      find.text('Moon Under the Sea'),
    );
    await tapVisible(tester, find.widgetWithText(ChoiceChip, '5F'));

    expect(
      find.textContaining('Bonuses: Concealed Hand, Moon Under the Sea'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.winBonuses, [
      HandWinBonus.concealedHand,
      HandWinBonus.moonUnderTheSea,
    ]);
  });

  testWidgets('hides win bonuses for draws', (tester) async {
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

    expect(find.text('Win bonuses'), findsOneWidget);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    expect(find.text('Win bonuses'), findsNothing);
  });

  testWidgets('editing historical hand preserves unknown win bonuses',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: HandResultRecord.fromJson({
            ...existingWinHandJson(),
            'win_bonuses': null,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not recorded'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.editedInput?.winBonuses, isNull);
  });

  testWidgets(
      'editing historical hand preserves unknown bonuses after draw toggle',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: HandResultRecord.fromJson({
            ...existingWinHandJson(),
            'win_bonuses': null,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Win'));
    await tester.pumpAndSettle();

    expect(find.text('Not recorded'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.editedInput?.winBonuses, isNull);
  });

  testWidgets('editing historical hand can record selected win bonuses',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: HandResultRecord.fromJson({
            ...existingWinHandJson(),
            'win_bonuses': null,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Win bonuses'));
    await tapVisible(
      tester,
      find.text('Concealed Hand'),
    );

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.editedInput?.winBonuses, [HandWinBonus.concealedHand]);
  });

  testWidgets('editing hand preselects existing win bonuses', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: _RecordingSessionRepository(),
          initialHand: HandResultRecord.fromJson({
            ...existingWinHandJson(),
            'win_bonuses': ['robbing_the_kong'],
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Robbing the Kong'), findsOneWidget);
    await tapVisible(tester, find.text('Win bonuses'));

    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(
          const ValueKey('winBonusOption-robbing_the_kong'),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.value, isTrue);
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

    expect(
        find.widgetWithText(OutlinedButton, 'East\nBob Lee'), findsOneWidget);
    expect(
        find.widgetWithText(OutlinedButton, 'South\nCarol Ng'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'West\nDee Wu'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'North\nAlice Wong'),
        findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'South\nBob Lee'), findsNothing);
  });

  testWidgets('fan picker clamps manual adjustments between three and thirteen',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'East\nAlice Wong'));
    await tester.pumpAndSettle();

    expect(find.text('3F'), findsWidgets);

    await tapVisible(tester, find.byKey(const ValueKey('fanCountDecrement')));

    expect(find.text('2F'), findsNothing);
    expect(find.text('3F'), findsWidgets);

    for (var i = 0; i < 11; i += 1) {
      await tapVisible(tester, find.byKey(const ValueKey('fanCountIncrement')));
    }

    expect(find.text('14F'), findsNothing);
    expect(find.text('13F'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.fanCount, 13);
  });

  testWidgets('save hand shows validation blocker near the save button',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: repository,
          handPhotoService: _FakeHandPhotoService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Capture winning hand photo'));
    expect(find.text('Photo captured'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    final summary = tester.widget<Text>(
      find.byKey(const ValueKey('saveHandValidationSummary')),
    );
    expect(summary.data, 'Select a winner.');
    expect(repository.recordedInput, isNull);
  });

  testWidgets('retake deletes superseded photo and submit transfers ownership',
      (tester) async {
    final service = _SequencedHandPhotoService([
      _photo('photo_01', '/local/one.jpg'),
      _photo('photo_02', '/local/two.jpg'),
    ]);
    final storage = _FakeHandPhotoStorage(existing: {
      '/local/one.jpg',
      '/local/two.jpg',
    });
    final repository = _RecordingSessionRepository();
    await pumpHandEntry(
      tester,
      repository: repository,
      handPhotoService: service,
      handPhotoStorage: storage,
    );

    await tapVisible(tester, find.text('Capture winning hand photo'));
    await tapVisible(tester, find.text('Retake winning hand photo'));
    expect(storage.deletedPaths, ['/local/one.jpg']);

    await completeValidWinAndSave(tester);
    expect(repository.recordedInput!.photoLocalPath, '/local/two.jpg');
    expect(storage.deletedPaths, ['/local/one.jpg']);
  });

  testWidgets('submitting win keeps queued photo when draw is tapped',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..recordHandCompleter = Completer<SessionDetailRecord>();
    final storage = _FakeHandPhotoStorage(existing: {'/local/one.jpg'});
    await pumpHandEntry(
      tester,
      repository: repository,
      handPhotoService: _SequencedHandPhotoService([
        _photo('photo_01', '/local/one.jpg'),
      ]),
      handPhotoStorage: storage,
    );

    await tapVisible(tester, find.text('Capture winning hand photo'));
    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'East\nAlice Wong'),
    );
    await tester.tap(find.text('Save Hand'));
    await tester.pump();
    expect(repository.recordedInput?.photoLocalPath, '/local/one.jpg');
    expect(find.text('Saving...'), findsOneWidget);

    await tapVisible(tester, find.text('Draw'));
    repository.recordHandCompleter!.complete(buildDetail());
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.photoLocalPath, '/local/one.jpg');
    expect(storage.deletedPaths, isEmpty);
    expect(storage.existingPaths, contains('/local/one.jpg'));
    expect(find.text('Open hand entry'), findsOneWidget);
  });

  testWidgets('leaving an unsubmitted draft deletes its captured photo',
      (tester) async {
    final storage = _FakeHandPhotoStorage(existing: {'/local/one.jpg'});
    await pumpHandEntry(
      tester,
      repository: _RecordingSessionRepository(),
      handPhotoService: _SequencedHandPhotoService([
        _photo('photo_01', '/local/one.jpg'),
      ]),
      handPhotoStorage: storage,
    );
    await tapVisible(tester, find.text('Capture winning hand photo'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(storage.deletedPaths, ['/local/one.jpg']);
  });

  testWidgets('switching a captured win to a draw deletes the photo once',
      (tester) async {
    final storage = _FakeHandPhotoStorage(existing: {'/local/one.jpg'});
    final repository = _RecordingSessionRepository();
    await pumpHandEntry(
      tester,
      repository: repository,
      handPhotoService: _SequencedHandPhotoService([
        _photo('photo_01', '/local/one.jpg'),
      ]),
      handPhotoStorage: storage,
    );

    await tapVisible(tester, find.text('Capture winning hand photo'));
    await tapVisible(tester, find.text('Draw'));
    expect(storage.deletedPaths, ['/local/one.jpg']);

    await tapVisible(tester, find.text('Save Hand'));
    expect(repository.recordedInput?.resultType, HandResultType.washout);
    expect(repository.recordedInput?.photoLocalPath, isNull);
    expect(storage.deletedPaths, ['/local/one.jpg']);
  });

  testWidgets('capture completing after route disposal deletes returned photo',
      (tester) async {
    final service = _DelayedHandPhotoService();
    final storage = _FakeHandPhotoStorage(existing: {'/local/one.jpg'});
    await pumpHandEntry(
      tester,
      repository: _RecordingSessionRepository(),
      handPhotoService: service,
      handPhotoStorage: storage,
    );

    final captureButton = find.text('Capture winning hand photo');
    await tester.ensureVisible(captureButton);
    await tester.pumpAndSettle();
    await tester.tap(captureButton);
    await tester.pump();
    expect(service.captureCount, 1);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    service.completer.complete(_photo('photo_01', '/local/one.jpg'));
    await tester.pumpAndSettle();

    expect(storage.deletedPaths, ['/local/one.jpg']);
  });

  testWidgets(
      'capture completing after switching to draw is deleted and not queued',
      (tester) async {
    final service = _DelayedHandPhotoService();
    final storage = _FakeHandPhotoStorage(existing: {'/local/one.jpg'});
    final repository = _RecordingSessionRepository();
    await pumpHandEntry(
      tester,
      repository: repository,
      handPhotoService: service,
      handPhotoStorage: storage,
    );

    final captureButton = find.text('Capture winning hand photo');
    await tester.ensureVisible(captureButton);
    await tester.pumpAndSettle();
    await tester.tap(captureButton);
    await tester.pump();
    expect(service.captureCount, 1);

    await tapVisible(tester, find.text('Draw'));
    service.completer.complete(_photo('photo_01', '/local/one.jpg'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save Hand'));

    expect(repository.recordedInput?.resultType, HandResultType.washout);
    expect(repository.recordedInput?.photoLocalPath, isNull);
    expect(repository.recordedInput?.photoClientId, isNull);
    expect(storage.deletedPaths, ['/local/one.jpg']);
  });

  testWidgets(
      'expired round can save the final hand and returns completed detail',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..recordHandSessionStatus = SessionStatus.completed;
    SessionDetailRecord? routeResult;
    final sessionDetail = buildDetail(
      scoringPhase: EventScoringPhase.tournament,
      startedAt: DateTime.now()
          .subtract(const Duration(minutes: 61))
          .toIso8601String(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              routeResult =
                  await Navigator.of(context).push<SessionDetailRecord>(
                MaterialPageRoute(
                  builder: (_) => HandEntryScreen(
                    sessionDetail: sessionDetail,
                    guestNamesById: seatNames,
                    sessionRepository: repository,
                    handPhotoService: _FakeHandPhotoService(),
                  ),
                ),
              );
            },
            child: const Text('Open hand entry'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open hand entry'));
    await tester.pumpAndSettle();

    expect(find.text('Round time has expired.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'East\nAlice Wong'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNotNull);
    expect(routeResult?.session.status, SessionStatus.completed);
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

  testWidgets('draw saves without dealer waiting state', (tester) async {
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
    expect(find.text('Waiting'), findsNothing);
    expect(find.text('Not waiting'), findsNothing);
    expect(find.text('Draw. Dealer rotates.'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput?.resultType, HandResultType.washout);
    expect(repository.recordedInput?.dealerWasWaitingAtDraw, isNull);
  });

  testWidgets('false win is recorded as pending penalty without saving hand',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..falseWinPenaltyResponseBuilder = (_) => buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: [
              falseWinPenaltyJson(
                penaltySeatIndex: 2,
                status: 'pending',
              ),
            ],
          );
    SessionDetailRecord? routeResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              routeResult =
                  await Navigator.of(context).push<SessionDetailRecord>(
                MaterialPageRoute(
                  builder: (_) => HandEntryScreen(
                    sessionDetail: buildDetail(currentDealerSeatIndex: 1),
                    guestNamesById: seatNames,
                    sessionRepository: repository,
                  ),
                ),
              );
            },
            child: const Text('Open hand entry'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open hand entry'));
    await tester.pumpAndSettle();

    expect(find.text('False Win'), findsNothing);
    expect(find.text('Record False Win'), findsOneWidget);

    await tapVisible(tester, find.text('Record False Win'));
    await tester.pumpAndSettle();

    expect(find.text('Choose false win caller'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'South\nCarol Ng'));
    await tester.pumpAndSettle();

    expect(repository.recordedFalseWinPenalty?.penaltySeatIndex, 2);
    expect(repository.recordedInput, isNull);
    expect(routeResult, isNull);
    expect(find.text('Record Hand'), findsOneWidget);
    expect(find.text('False wins'), findsOneWidget);
    expect(find.text('Carol Ng'), findsOneWidget);
    expect(find.text('South - 6 fan penalty'), findsOneWidget);

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'South\nCarol Ng'),
    );

    expect(
        find.text('False win callers cannot win this hand.'), findsOneWidget);
  });

  testWidgets('pending false win row can be removed before saving hand',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..voidFalseWinPenaltyResponseBuilder = (_) => buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: const [],
          );

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: [
              falseWinPenaltyJson(
                penaltySeatIndex: 2,
                status: 'pending',
              ),
            ],
          ),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('False wins'), findsOneWidget);
    expect(find.text('Carol Ng'), findsOneWidget);
    expect(find.text('South - 6 fan penalty'), findsOneWidget);

    await tapVisible(tester, find.text('Remove'));

    expect(
      repository.voidedFalseWinPenalty?.handFalseWinPenaltyId,
      'penalty-2',
    );
    expect(find.text('Carol Ng'), findsNothing);
  });

  testWidgets('save hand is disabled while choosing a false win caller',
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

    await tapVisible(tester, find.text('Record False Win'));
    await tester.pumpAndSettle();

    expect(find.text('Choose false win caller'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save Hand'),
    );
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNull);
  });

  testWidgets('record false win is hidden while editing a hand',
      (tester) async {
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
          sessionRepository: _RecordingSessionRepository(),
          initialHand: existingHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record False Win'), findsNothing);
  });

  testWidgets('editing a legacy false win penalty preserves caller',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final existingHand = HandResultRecord.fromJson(const {
      'id': 'hand_legacy_false_win',
      'table_session_id': 'ses_01',
      'hand_number': 1,
      'result_type': 'false_win_penalty',
      'winner_seat_index': null,
      'win_type': null,
      'discarder_seat_index': null,
      'penalty_seat_index': 2,
      'fan_count': 6,
      'base_points': 32,
      'east_seat_index_before_hand': 1,
      'east_seat_index_after_hand': 1,
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

    expect(find.text('Record False Win'), findsNothing);
    expect(find.text('Legacy false win penalty'), findsOneWidget);
    expect(find.text('False win caller: Carol Ng (South)'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNull);
    expect(repository.recordedFalseWinPenalty, isNull);
    expect(repository.editedInput?.handResultId, 'hand_legacy_false_win');
    expect(repository.editedInput?.resultType, HandResultType.falseWinPenalty);
    expect(repository.editedInput?.penaltySeatIndex, 2);
  });

  testWidgets('attached false win row can be removed while editing saved hand',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..voidFalseWinPenaltyResponseBuilder = (_) => buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: const [],
          );
    final initialHand = HandResultRecord.fromJson(existingWinHandJson());

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: [
              falseWinPenaltyJson(
                penaltySeatIndex: 3,
                status: 'attached',
                handResultId: 'hand_01',
              ),
            ],
          ),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: initialHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('False wins attached to this hand'), findsOneWidget);
    expect(find.text('Dee Wu'), findsOneWidget);
    expect(find.text('North - 6 fan penalty'), findsOneWidget);

    await tapVisible(tester, find.text('Remove'));

    expect(
      repository.voidedFalseWinPenalty?.handFalseWinPenaltyId,
      'penalty-3',
    );
    expect(find.text('Dee Wu'), findsNothing);
  });

  testWidgets('editing existing winner ignores pending false win blockers',
      (tester) async {
    final repository = _RecordingSessionRepository();
    final existingHand = HandResultRecord.fromJson(const {
      'id': 'hand_01',
      'table_session_id': 'ses_01',
      'hand_number': 1,
      'result_type': 'win',
      'winner_seat_index': 2,
      'win_type': 'self_draw',
      'discarder_seat_index': null,
      'fan_count': 3,
      'base_points': 8,
      'east_seat_index_before_hand': 1,
      'east_seat_index_after_hand': 1,
      'dealer_rotated': false,
      'session_completed_after_hand': false,
      'status': 'recorded',
      'entered_by_user_id': 'usr_01',
      'entered_at': '2026-04-24T19:05:00-07:00',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: [
              falseWinPenaltyJson(
                penaltySeatIndex: 2,
                status: 'pending',
              ),
            ],
          ),
          guestNamesById: seatNames,
          sessionRepository: repository,
          initialHand: existingHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(find.text('False win callers cannot win this hand.'), findsNothing);
    expect(repository.editedInput?.handResultId, 'hand_01');
    expect(repository.editedInput?.winnerSeatIndex, 2);
  });

  testWidgets('pending false win caller cannot be selected as winner',
      (tester) async {
    final repository = _RecordingSessionRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(
            currentDealerSeatIndex: 1,
            falseWinPenalties: [
              falseWinPenaltyJson(
                penaltySeatIndex: 2,
                status: 'pending',
              ),
            ],
          ),
          guestNamesById: seatNames,
          sessionRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'South\nCarol Ng'),
    );

    expect(
        find.text('False win callers cannot win this hand.'), findsOneWidget);
    expect(repository.recordedInput, isNull);
  });

  testWidgets('false win caller buttons are disabled while submitting',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..recordFalseWinPenaltyCompleter = Completer<SessionDetailRecord>();

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

    await tester.tap(find.text('Record False Win'));
    await tester.pumpAndSettle();

    final carolButton = find.widgetWithText(OutlinedButton, 'South\nCarol Ng');
    await tester.ensureVisible(carolButton);
    await tester.pumpAndSettle();
    await tester.tap(carolButton);
    await tester.pump();
    await tester.tap(carolButton, warnIfMissed: false);
    await tester.pump();

    expect(repository.recordFalseWinPenaltyCallCount, 1);

    repository.recordFalseWinPenaltyCompleter!.complete(
      buildDetail(
        currentDealerSeatIndex: 1,
        falseWinPenalties: [
          falseWinPenaltyJson(
            penaltySeatIndex: 2,
            status: 'pending',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('shows saving status and cannot leave on iOS while saving',
      (tester) async {
    final repository = _RecordingSessionRepository()
      ..recordFalseWinPenaltyCompleter = Completer<SessionDetailRecord>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HandEntryScreen(
                    sessionDetail: buildDetail(currentDealerSeatIndex: 1),
                    guestNamesById: seatNames,
                    sessionRepository: repository,
                  ),
                ),
              );
            },
            child: const Text('Open hand entry'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open hand entry'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Record False Win'));
    await tester.pumpAndSettle();
    final carolButton = find.widgetWithText(
      OutlinedButton,
      'South\nCarol Ng',
    );
    await tester.ensureVisible(carolButton);
    await tester.tap(carolButton);
    await tester.pump();

    expect(find.text('Saving in progress. Please wait.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Record Hand'), findsOneWidget);
    expect(find.text('Saving in progress. Please wait.'), findsOneWidget);

    repository.recordFalseWinPenaltyCompleter!.complete(
      buildDetail(
        currentDealerSeatIndex: 1,
        falseWinPenalties: [
          falseWinPenaltyJson(
            penaltySeatIndex: 2,
            status: 'pending',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carol Ng'), findsOneWidget);
    expect(find.text('False win saved.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Open hand entry'), findsOneWidget);
  });

  testWidgets('editing a legacy draw preserves its dealer waiting state',
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

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.editedInput?.resultType, HandResultType.washout);
    expect(repository.editedInput?.dealerWasWaitingAtDraw, isTrue);
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

  testWidgets('editing existing win shows saved photo status', (tester) async {
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
      'photo_id': 'photo_01',
      'photo_client_id': 'photo_client_01',
      'photo_captured_at': '2026-04-24T19:05:05-07:00',
      'photo_upload_status': 'uploaded',
      'photo_storage_bucket': 'hand-photos',
      'photo_storage_path': 'events/evt_01/hands/hand_01/photo_client_01.jpg',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: HandEntryScreen(
          sessionDetail: buildDetail(),
          guestNamesById: seatNames,
          sessionRepository: _RecordingSessionRepository(),
          initialHand: existingHand,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Winning hand photo uploaded'), findsOneWidget);
    expect(find.text('photo_client_01'), findsNothing);
  });
}
