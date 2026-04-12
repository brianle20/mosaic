import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/screens/hand_entry_screen.dart';

class _RecordingSessionRepository implements SessionRepository {
  RecordHandResultInput? recordedInput;
  EditHandResultInput? editedInput;
  VoidHandResultInput? voidedInput;

  SessionDetailRecord _detailFromStatus(HandResultStatus status) {
    return SessionDetailRecord.fromJson({
      'session': {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD_V1',
        'ruleset_version': 1,
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
          'fan_count': 1,
          'base_points': 2,
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
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
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
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async {
    voidedInput = input;
    return _detailFromStatus(HandResultStatus.voided);
  }
}

void main() {
  SessionDetailRecord buildDetail() {
    return SessionDetailRecord.fromJson({
      'session': {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_01',
        'session_number_for_table': 1,
        'ruleset_id': 'HK_STANDARD_V1',
        'ruleset_version': 1,
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

    expect(find.text('Discarder'), findsNothing);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discarder'), findsOneWidget);

    await tester.tap(find.text('Winner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Wong (East)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discarder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bob Lee (South)').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Fan Count'), '2');
    await tester.pumpAndSettle();

    expect(find.text('Scoring Preview'), findsOneWidget);

    await tester.tap(find.text('Save Hand'));
    await tester.pumpAndSettle();

    expect(repository.recordedInput, isNotNull);
    expect(repository.recordedInput!.winType, HandWinType.discard);
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
      'fan_count': 1,
      'base_points': 2,
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

    await tester.tap(find.text('Void Hand'));
    await tester.pumpAndSettle();

    expect(repository.voidedInput, isNotNull);
    expect(repository.voidedInput!.handResultId, 'hand_01');
  });
}
