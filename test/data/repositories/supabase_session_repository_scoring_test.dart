import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSessionRepository scoring', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads session detail with ordered hands and settlements', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        sessionDetailLoader: (_) async => {
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
          ],
          'hands': [
            {
              'id': 'hand_01',
              'table_session_id': 'ses_01',
              'hand_number': 1,
              'result_type': 'win',
              'winner_seat_index': 2,
              'win_type': 'discard',
              'discarder_seat_index': 0,
              'fan_count': 2,
              'base_points': 4,
              'east_seat_index_before_hand': 0,
              'east_seat_index_after_hand': 1,
              'dealer_rotated': true,
              'session_completed_after_hand': false,
              'status': 'recorded',
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-04-24T19:10:00-07:00',
            }
          ],
          'settlements': [
            {
              'id': 'set_01',
              'hand_result_id': 'hand_01',
              'payer_event_guest_id': 'gst_east',
              'payee_event_guest_id': 'gst_west',
              'amount_points': 16,
              'multiplier_flags_json': ['discard', 'east_loses'],
            }
          ],
        },
      );

      final detail = await repository.loadSessionDetail('ses_01');

      expect(detail.session.id, 'ses_01');
      expect(detail.seats.first.initialWind, SeatWind.east);
      expect(detail.hands.single.basePoints, 4);
      expect(detail.settlements.single.amountPoints, 16);
    });

    test('records a hand and refreshes cached session detail', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'record_hand_result');
          expect(params['target_table_session_id'], 'ses_01');
          expect(params['target_result_type'], 'washout');
          return {
            'id': 'hand_02',
            'table_session_id': 'ses_01',
            'hand_number': 2,
            'result_type': 'washout',
            'winner_seat_index': null,
            'win_type': null,
            'discarder_seat_index': null,
            'fan_count': null,
            'base_points': null,
            'east_seat_index_before_hand': 1,
            'east_seat_index_after_hand': 1,
            'dealer_rotated': false,
            'session_completed_after_hand': false,
            'status': 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:20:00-07:00',
          };
        },
        sessionDetailLoader: (_) async => {
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
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          },
          'seats': const [],
          'hands': [
            {
              'id': 'hand_02',
              'table_session_id': 'ses_01',
              'hand_number': 2,
              'result_type': 'washout',
              'winner_seat_index': null,
              'win_type': null,
              'discarder_seat_index': null,
              'fan_count': null,
              'base_points': null,
              'east_seat_index_before_hand': 1,
              'east_seat_index_after_hand': 1,
              'dealer_rotated': false,
              'session_completed_after_hand': false,
              'status': 'recorded',
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-04-24T19:20:00-07:00',
            }
          ],
          'settlements': const [],
        },
      );

      final detail = await repository.recordHand(
        const RecordHandResultInput(
          tableSessionId: 'ses_01',
          resultType: HandResultType.washout,
        ),
      );

      expect(detail.hands.single.handNumber, 2);

      final cachedDetail = await repository.readCachedSessionDetail('ses_01');
      expect(cachedDetail?.hands.single.resultType, HandResultType.washout);
    });

    test('edits and voids a hand through scoring RPCs', () async {
      final rpcCalls = <String>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          rpcCalls.add(functionName);
          return {
            'id': 'hand_01',
            'table_session_id': 'ses_01',
            'hand_number': 1,
            'result_type': params['target_result_type'] ?? 'win',
            'winner_seat_index': params['target_winner_seat_index'],
            'win_type': params['target_win_type'],
            'discarder_seat_index': params['target_discarder_seat_index'],
            'fan_count': params['target_fan_count'],
            'base_points': params['target_fan_count'] == null ? null : 8,
            'east_seat_index_before_hand': 0,
            'east_seat_index_after_hand': 0,
            'dealer_rotated': false,
            'session_completed_after_hand': false,
            'status':
                functionName == 'void_hand_result' ? 'voided' : 'recorded',
            'entered_by_user_id': 'usr_01',
            'entered_at': '2026-04-24T19:05:00-07:00',
            'correction_note': params['target_correction_note'],
          };
        },
        sessionDetailLoader: (_) async => {
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
          'seats': const [],
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
              'status':
                  rpcCalls.isNotEmpty && rpcCalls.last == 'void_hand_result'
                      ? 'voided'
                      : 'recorded',
              'entered_by_user_id': 'usr_01',
              'entered_at': '2026-04-24T19:05:00-07:00',
              'correction_note': 'fixed host entry',
            }
          ],
          'settlements': const [],
        },
      );

      final edited = await repository.editHand(
        const EditHandResultInput(
          handResultId: 'hand_01',
          resultType: HandResultType.win,
          winnerSeatIndex: 0,
          winType: HandWinType.selfDraw,
          fanCount: 3,
          correctionNote: 'fixed host entry',
        ),
      );
      final voided = await repository.voidHand(
        const VoidHandResultInput(
          handResultId: 'hand_01',
          correctionNote: 'voiding bad hand',
        ),
      );

      expect(rpcCalls, ['edit_hand_result', 'void_hand_result']);
      expect(edited.hands.single.status, HandResultStatus.recorded);
      expect(voided.hands.single.status, HandResultStatus.voided);
    });
  });
}
