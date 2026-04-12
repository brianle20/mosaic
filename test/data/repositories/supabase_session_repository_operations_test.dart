import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSessionRepository operations', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('pauseSession returns refreshed paused detail and updates cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'pause_table_session');
          expect(params['target_table_session_id'], 'ses_01');
          return {
            'id': 'ses_01',
            'event_id': 'evt_01',
            'event_table_id': 'tbl_01',
            'session_number_for_table': 1,
            'ruleset_id': 'HK_STANDARD_V1',
            'ruleset_version': 1,
            'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
            'rotation_policy_config_json': {},
            'status': 'paused',
            'initial_east_seat_index': 0,
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
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
            'status': 'paused',
            'initial_east_seat_index': 0,
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          },
          'seats': const [],
          'hands': const [],
          'settlements': const [],
        },
      );

      final detail = await repository.pauseSession('ses_01');

      expect(detail.session.status, SessionStatus.paused);
      final cachedDetail = await repository.readCachedSessionDetail('ses_01');
      expect(cachedDetail?.session.status, SessionStatus.paused);
    });

    test('resumeSession returns refreshed active detail and updates cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'resume_table_session');
          expect(params['target_table_session_id'], 'ses_01');
          return {
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
          'hands': const [],
          'settlements': const [],
        },
      );

      final detail = await repository.resumeSession('ses_01');

      expect(detail.session.status, SessionStatus.active);
      final cachedDetail = await repository.readCachedSessionDetail('ses_01');
      expect(cachedDetail?.session.status, SessionStatus.active);
    });

    test('endSession returns refreshed ended-early detail and updates cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'end_table_session');
          expect(params['target_table_session_id'], 'ses_01');
          expect(params['target_end_reason'], 'Venue closing');
          return {
            'id': 'ses_01',
            'event_id': 'evt_01',
            'event_table_id': 'tbl_01',
            'session_number_for_table': 1,
            'ruleset_id': 'HK_STANDARD_V1',
            'ruleset_version': 1,
            'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
            'rotation_policy_config_json': {},
            'status': 'ended_early',
            'initial_east_seat_index': 0,
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
            'ended_at': '2026-04-24T20:00:00-07:00',
            'ended_by_user_id': 'usr_01',
            'end_reason': 'Venue closing',
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
            'status': 'ended_early',
            'initial_east_seat_index': 0,
            'current_dealer_seat_index': 1,
            'dealer_pass_count': 1,
            'completed_games_count': 2,
            'hand_count': 2,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
            'ended_at': '2026-04-24T20:00:00-07:00',
            'ended_by_user_id': 'usr_01',
            'end_reason': 'Venue closing',
          },
          'seats': const [],
          'hands': const [],
          'settlements': const [],
        },
      );

      final detail = await repository.endSession(
        sessionId: 'ses_01',
        reason: 'Venue closing',
      );

      expect(detail.session.status, SessionStatus.endedEarly);
      expect(detail.session.endReason, 'Venue closing');
      final cachedDetail = await repository.readCachedSessionDetail('ses_01');
      expect(cachedDetail?.session.status, SessionStatus.endedEarly);
    });
  });
}
