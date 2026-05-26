import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
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

    test('generates bonus round assignments through RPC and refreshes cache',
        () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {
              'id': 'asg_bonus_01',
              'event_id': 'evt_01',
              'event_table_id': 'tbl_champions',
              'table_label': 'Table 1',
              'event_guest_id': 'gst_04',
              'guest_display_name': 'Seed Four',
              'seat_index': 0,
              'assignment_round': 3,
              'status': 'active',
              'assignment_type': 'bonus',
              'bonus_round_id': 'bonus_01',
              'bonus_table_role': 'table_of_champions',
              'seed_rank': 4,
            },
          ];
        },
      );

      final assignments = await repository.generateBonusRoundAssignments(
        eventId: 'evt_01',
        championsTableId: 'tbl_champions',
        redemptionTableId: 'tbl_redemption',
      );

      expect(calls.single.functionName,
          'generate_bonus_round_seating_assignments');
      expect(calls.single.params, {
        'target_event_id': 'evt_01',
        'champions_table_id': 'tbl_champions',
        'redemption_table_id': 'tbl_redemption',
      });
      expect(assignments.single.assignmentType, SeatingAssignmentType.bonus);
      expect(
        assignments.single.bonusTableRole,
        BonusTableRole.tableOfChampions,
      );
      expect(assignments.single.bonusRoundId, 'bonus_01');
      expect(assignments.single.seedRank, 4);

      final cached = await repository.readCachedAssignments('evt_01');
      expect(cached.single.assignmentType, SeatingAssignmentType.bonus);
      expect(cached.single.bonusTableRole, BonusTableRole.tableOfChampions);
    });

    test('allows bonus round assignments without a redemption table', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return const [];
        },
      );

      await repository.generateBonusRoundAssignments(
        eventId: 'evt_01',
        championsTableId: 'tbl_champions',
      );

      expect(calls.single.functionName,
          'generate_bonus_round_seating_assignments');
      expect(calls.single.params, {
        'target_event_id': 'evt_01',
        'champions_table_id': 'tbl_champions',
        'redemption_table_id': null,
      });
    });

    test('loads bonus round state through nullable RPC JSON', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcJsonRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return {
            'bonus_round_id': 'bonus_01',
            'event_id': 'evt_01',
            'status': 'active',
            'champions_table_id': 'tbl_champions',
            'redemption_table_id': 'tbl_redemption',
            'sudden_death_status': 'required',
            'champion_resolution_method': 'sudden_death',
            'sudden_death_table_id': 'tbl_sudden_death',
            'sudden_death_session_id': null,
            'tied_top_players': const [
              {
                'event_guest_id': 'gst_01',
                'display_name': 'Alice Wong',
                'bonus_score_points': 120,
                'seed_rank': 1,
              },
            ],
            'champion_event_guest_id': null,
            'champion_bonus_score_points': null,
            'champion_award_points': null,
            'champion_top_up_points': null,
          };
        },
      );

      final state = await repository.loadBonusRoundState('evt_01');

      expect(calls.single.functionName, 'get_bonus_round_state');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(state, isNotNull);
      expect(state!.bonusRoundId, 'bonus_01');
      expect(state.tiedTopPlayers.single.eventGuestId, 'gst_01');
      expect(state.tiedTopPlayers.single.bonusScorePoints, 120);
    });

    test('returns null when bonus round state RPC returns no state', () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcJsonRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return null;
        },
      );

      final state = await repository.loadBonusRoundState('evt_01');

      expect(calls.single.functionName, 'get_bonus_round_state');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(state, isNull);
    });

    test('starts bonus round sudden death through RPC and refreshes cache',
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
          if (functionName == 'get_event_seating_assignments') {
            return [
              SeatingAssignmentRecordFixture.active().toJson(),
              {
                'id': 'asg_sudden_01',
                'event_id': 'evt_01',
                'event_table_id': 'tbl_sudden_death',
                'table_label': 'Sudden Death',
                'event_guest_id': 'gst_01',
                'guest_display_name': 'Alice Wong',
                'seat_index': 0,
                'assignment_round': 4,
                'status': 'active',
                'assignment_type': 'bonus',
                'bonus_round_id': 'bonus_01',
                'bonus_table_role': 'table_of_champions_sudden_death',
                'seed_rank': 1,
              },
            ];
          }
          return [
            {
              'id': 'asg_sudden_01',
              'event_id': 'evt_01',
              'event_table_id': 'tbl_sudden_death',
              'table_label': 'Sudden Death',
              'event_guest_id': 'gst_01',
              'guest_display_name': 'Alice Wong',
              'seat_index': 0,
              'assignment_round': 4,
              'status': 'active',
              'assignment_type': 'bonus',
              'bonus_round_id': 'bonus_01',
              'bonus_table_role': 'table_of_champions_sudden_death',
              'seed_rank': 1,
            },
          ];
        },
      );

      final assignments = await repository.startBonusRoundSuddenDeath(
        eventId: 'evt_01',
        tableId: 'tbl_sudden_death',
      );

      expect(calls.first.functionName, 'start_bonus_round_sudden_death');
      expect(calls.first.params, {
        'target_event_id': 'evt_01',
        'sudden_death_table_id': 'tbl_sudden_death',
      });
      expect(calls.last.functionName, 'get_event_seating_assignments');
      expect(calls.last.params, {'target_event_id': 'evt_01'});
      expect(
        assignments.single.bonusTableRole,
        BonusTableRole.tableOfChampionsSuddenDeath,
      );

      final cached = await repository.readCachedAssignments('evt_01');
      expect(cached, hasLength(2));
      expect(cached.last.eventTableId, 'tbl_sudden_death');
      expect(
        cached.last.bonusTableRole,
        BonusTableRole.tableOfChampionsSuddenDeath,
      );
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

    test('loads tournament round summary through RPC and refreshes cache',
        () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcJsonRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return {
            'round': {
              'id': 'rnd_01',
              'event_id': 'evt_01',
              'round_number': 1,
              'scoring_phase': 'tournament',
              'status': 'seating',
              'assignment_round': 3,
              'started_at': '2026-05-24T19:00:00-07:00',
              'completed_at': null,
            },
            'assigned_table_count': 1,
            'complete_table_count': 0,
            'active_table_count': 0,
            'paused_table_count': 0,
            'not_started_table_count': 1,
            'current_round_tables': const [],
            'other_tables': const [],
          };
        },
      );

      final summary = await repository.loadTournamentRoundSummary('evt_01');

      expect(calls.single.functionName, 'get_tournament_round_summary');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(summary.round!.id, 'rnd_01');
      expect(summary.round!.status, TournamentRoundStatus.seating);

      final cached =
          await repository.readCachedTournamentRoundSummary('evt_01');
      expect(cached!.round!.assignmentRound, 3);
    });

    test(
        'generates tournament round through RPC and refreshes assignments cache',
        () async {
      final calls = <({String functionName, Map<String, dynamic> params})>[];
      final cache = await LocalCache.create();
      final repository = SupabaseSeatingRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          calls.add((functionName: functionName, params: params));
          return [
            {
              'id': 'asg_round_01',
              'event_id': 'evt_01',
              'event_table_id': 'tbl_01',
              'table_label': 'Table 1',
              'event_guest_id': 'gst_01',
              'guest_display_name': 'Alice Wong',
              'seat_index': 0,
              'assignment_round': 3,
              'status': 'active',
              'tournament_round_id': 'rnd_01',
            },
          ];
        },
      );

      final assignments = await repository.generateTournamentRound('evt_01');

      expect(calls.single.functionName, 'start_tournament_round');
      expect(calls.single.params, {'target_event_id': 'evt_01'});
      expect(assignments.single.tournamentRoundId, 'rnd_01');

      final cached = await repository.readCachedAssignments('evt_01');
      expect(cached.single.tournamentRoundId, 'rnd_01');
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
