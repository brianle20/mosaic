import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/supabase_seating_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseSeatingRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads assignments through RPC and refreshes cache', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {
              'id': 'asg_01',
              'event_id': 'evt_01',
              'event_table_id': 'tbl_01',
              'table_label': 'Table 1',
              'event_guest_id': 'gst_01',
              'guest_display_name': 'Alice Wong',
              'seat_index': 0,
              'assignment_round': 1,
              'status': 'active',
            },
          ];
        },
      );

      final assignments = await repository.loadAssignments('evt_01');

      expect(calls.single.functionName, 'get_event_seating_assignments');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(assignments, hasLength(1));
      expect(assignments.single.displayName, 'Alice Wong');

      final cached = await repository.readCachedAssignments('evt_01');
      expect(cached, hasLength(1));
      expect(cached.single.tableLabel, 'Table 1');
    });

    test('generates assignments through RPC and refreshes cache', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {
              'id': 'asg_02',
              'event_id': 'evt_01',
              'event_table_id': 'tbl_02',
              'table_label': 'Table 2',
              'event_guest_id': 'gst_02',
              'guest_display_name': 'Bob Lee',
              'seat_index': 1,
              'assignment_round': 2,
              'status': 'active',
            },
          ];
        },
      );

      final assignments = await repository.generateRandomAssignments('evt_01');

      expect(calls.single.functionName, 'generate_random_seating_assignments');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(assignments.single.assignmentRound, 2);

      final cached = await repository.readCachedAssignments('evt_01');
      expect(cached.single.displayName, 'Bob Lee');
    });

    test('clears assignments through RPC and clears cache on empty result',
        () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      await cache.saveSeatingAssignments('evt_01', [
        SeatingAssignmentRecordFixture.active(),
      ]);
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return const [];
        },
      );

      final assignments = await repository.clearAssignments('evt_01');

      expect(calls.single.functionName, 'clear_event_seating_assignments');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(assignments, isEmpty);
      expect(await repository.readCachedAssignments('evt_01'), isEmpty);
    });
  });
}

class SeatingAssignmentRecordFixture {
  static SeatingAssignmentRecord active() {
    return const SeatingAssignmentRecord(
      id: 'asg_cached',
      eventId: 'evt_01',
      eventTableId: 'tbl_01',
      tableLabel: 'Table 1',
      eventGuestId: 'gst_01',
      displayName: 'Cached Guest',
      seatIndex: 0,
      assignmentRound: 1,
      status: 'active',
    );
  }
}
