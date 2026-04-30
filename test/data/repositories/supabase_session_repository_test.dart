import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
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
            'ruleset_id': 'HK_STANDARD',
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

    test('reads cached event hand ledger rows', () async {
      final cache = await LocalCache.create();
      final row = EventHandLedgerEntry.fromJson({
        'event_id': 'evt_01',
        'table_id': 'tbl_03',
        'table_label': 'Table 3',
        'session_id': 'ses_03',
        'session_number_for_table': 2,
        'hand_id': 'hand_12',
        'hand_number': 12,
        'entered_at': '2026-04-24T20:15:00-07:00',
        'result_type': 'win',
        'status': 'recorded',
        'win_type': 'discard',
        'fan_count': 7,
        'has_settlements': true,
        'cells': [
          {
            'wind': 'east',
            'seat_index': 0,
            'event_guest_id': 'gst_east',
            'display_name': 'Estevon Jackson',
            'points_delta': -96,
          },
          {
            'wind': 'south',
            'seat_index': 1,
            'event_guest_id': 'gst_south',
            'display_name': 'Giang Pham',
            'points_delta': 0,
          },
          {
            'wind': 'west',
            'seat_index': 2,
            'event_guest_id': 'gst_west',
            'display_name': 'Justin Park',
            'points_delta': 0,
          },
          {
            'wind': 'north',
            'seat_index': 3,
            'event_guest_id': 'gst_north',
            'display_name': 'Wen Lee',
            'points_delta': 96,
          },
        ],
      });

      await cache.saveEventHandLedger('evt_01', [row]);

      final cached = cache.readEventHandLedger('evt_01');

      expect(cached, hasLength(1));
      expect(cached.single.tableLabel, 'Table 3');
      expect(cached.single.sessionNumberForTable, 2);
      expect(cached.single.cells.map((cell) => cell.wind), [
        SeatWind.east,
        SeatWind.south,
        SeatWind.west,
        SeatWind.north,
      ]);
      expect(cached.single.cells.last.pointsDelta, 96);
    });

    test('loads event hand ledger from injected loader and caches newest first',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        eventHandLedgerLoader: (eventId) async {
          expect(eventId, 'evt_01');
          return [
            _eventHandLedgerJson(
              handId: 'hand_12',
              handNumber: 12,
              enteredAt: '2026-04-24T20:15:00-07:00',
              eastDelta: -96,
              northDelta: 96,
            ),
            _eventHandLedgerJson(
              handId: 'hand_08',
              handNumber: 8,
              enteredAt: '2026-04-24T20:00:00-07:00',
              eastDelta: -16,
              southDelta: 40,
              westDelta: -8,
              northDelta: -16,
              winType: 'self_draw',
              fanCount: 3,
            ),
          ];
        },
      );

      final rows = await repository.loadEventHandLedger('evt_01');
      final cached = await repository.readCachedEventHandLedger('evt_01');

      expect(rows.map((row) => row.handId), ['hand_12', 'hand_08']);
      expect(cached.map((row) => row.handId), ['hand_12', 'hand_08']);
      expect(rows.first.cells.first.pointsDelta, -96);
      expect(rows.first.cells.last.pointsDelta, 96);
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
            'ruleset_id': 'HK_STANDARD',
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

    test('loads and caches table label with session detail', () async {
      final cache = await LocalCache.create();
      final loadedTableIds = <String>[];
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        sessionDetailLoader: (_) async => {
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
            'completed_games_count': 0,
            'hand_count': 0,
            'started_at': '2026-04-24T19:00:00-07:00',
            'started_by_user_id': 'usr_01',
          },
          'seats': const [],
          'hands': const [],
          'settlements': const [],
        },
        sessionTableLabelLoader: (tableId) async {
          loadedTableIds.add(tableId);
          return 'Table 1';
        },
      );

      final detail = await repository.loadSessionDetail('ses_01');
      final cached = await repository.readCachedSessionDetail('ses_01');

      expect(loadedTableIds, ['tbl_01']);
      expect(detail.tableLabel, 'Table 1');
      expect(cached?.tableLabel, 'Table 1');
    });

    test('does not query table label for injected session detail', () async {
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
            'ruleset_id': 'HK_STANDARD',
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
          'seats': const [],
          'hands': const [],
          'settlements': const [],
        },
      );

      final detail = await repository.loadSessionDetail('ses_01');

      expect(detail.tableLabel, isNull);
    });
  });
}

Map<String, Object?> _eventHandLedgerJson({
  required String handId,
  required int handNumber,
  required String enteredAt,
  int eastDelta = 0,
  int southDelta = 0,
  int westDelta = 0,
  int northDelta = 0,
  String resultType = 'win',
  String status = 'recorded',
  String? winType = 'discard',
  int? fanCount = 7,
}) {
  return {
    'event_id': 'evt_01',
    'table_id': 'tbl_03',
    'table_label': 'Table 3',
    'session_id': 'ses_03',
    'session_number_for_table': 2,
    'hand_id': handId,
    'hand_number': handNumber,
    'entered_at': enteredAt,
    'result_type': resultType,
    'status': status,
    'win_type': winType,
    'fan_count': fanCount,
    'has_settlements': resultType == 'win',
    'cells': [
      _eventHandLedgerCellJson(
        'east',
        0,
        'gst_east',
        'Estevon Jackson',
        eastDelta,
      ),
      _eventHandLedgerCellJson(
        'south',
        1,
        'gst_south',
        'Giang Pham',
        southDelta,
      ),
      _eventHandLedgerCellJson(
        'west',
        2,
        'gst_west',
        'Justin Park',
        westDelta,
      ),
      _eventHandLedgerCellJson(
        'north',
        3,
        'gst_north',
        'Wen Lee',
        northDelta,
      ),
    ],
  };
}

Map<String, Object?> _eventHandLedgerCellJson(
  String wind,
  int seatIndex,
  String guestId,
  String displayName,
  int pointsDelta,
) {
  return {
    'wind': wind,
    'seat_index': seatIndex,
    'event_guest_id': guestId,
    'display_name': displayName,
    'points_delta': pointsDelta,
  };
}
