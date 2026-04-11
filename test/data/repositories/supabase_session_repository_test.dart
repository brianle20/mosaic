import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/supabase_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSessionRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('lists sessions for an event', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        sessionListLoader: (_) async => [
          {
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
          }
        ],
      );

      final sessions = await repository.listSessions('evt_01');

      expect(sessions, hasLength(1));
      expect(sessions.single.eventTableId, 'tbl_01');
      expect(sessions.single.status, SessionStatus.active);
    });

    test('maps a started session and ordered seats from RPC plus seat lookup',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'start_table_session');
          expect(params['target_event_table_id'], 'tbl_01');
          expect(params['scanned_table_uid'], 'table-001');
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
            'current_dealer_seat_index': 0,
            'dealer_pass_count': 0,
            'completed_games_count': 0,
            'hand_count': 0,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          };
        },
        sessionSeatsLoader: (_) async => [
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
      );

      final startedSession = await repository.startSession(
        const StartTableSessionInput(
          eventTableId: 'tbl_01',
          scannedTableUid: 'table-001',
          eastPlayerUid: 'p-east',
          southPlayerUid: 'p-south',
          westPlayerUid: 'p-west',
          northPlayerUid: 'p-north',
        ),
      );

      expect(startedSession.session.id, 'ses_01');
      expect(startedSession.seats, hasLength(4));
      expect(startedSession.seats.first.initialWind, SeatWind.east);
      expect(startedSession.seats.last.eventGuestId, 'gst_north');
    });
  });
}
