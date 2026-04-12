import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/repositories/supabase_leaderboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseLeaderboardRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads ordered leaderboard entries from the RPC', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseLeaderboardRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        leaderboardLoader: (_) async => [
          {
            'event_guest_id': 'gst_west',
            'display_name': 'West Guest',
            'total_points': 16,
            'hands_won': 1,
            'self_draw_wins': 0,
            'discard_wins': 1,
            'rank': 1,
          },
          {
            'event_guest_id': 'gst_east',
            'display_name': 'East Guest',
            'total_points': 8,
            'hands_won': 1,
            'self_draw_wins': 1,
            'discard_wins': 0,
            'rank': 2,
          },
        ],
      );

      final entries = await repository.loadLeaderboard('evt_01');

      expect(entries, hasLength(2));
      expect(entries.first.displayName, 'West Guest');
      expect(entries.first.totalPoints, 16);
      expect(entries.last.rank, 2);
    });

    test('refreshes cached leaderboard after fetch', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseLeaderboardRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        leaderboardLoader: (_) async => [
          {
            'event_guest_id': 'gst_west',
            'display_name': 'West Guest',
            'total_points': 16,
            'hands_won': 1,
            'self_draw_wins': 0,
            'discard_wins': 1,
            'rank': 1,
          },
        ],
      );

      await repository.loadLeaderboard('evt_01');
      final cachedEntries = await repository.readCachedLeaderboard('evt_01');

      expect(cachedEntries, hasLength(1));
      expect(cachedEntries.single.displayName, 'West Guest');
    });
  });
}
