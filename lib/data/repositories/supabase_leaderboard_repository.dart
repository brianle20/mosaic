import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef LeaderboardLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
);

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository({
    required this.client,
    required this.cache,
    LeaderboardLoader? leaderboardLoader,
  }) : _leaderboardLoader = leaderboardLoader;

  final SupabaseClient client;
  final LocalCache cache;
  final LeaderboardLoader? _leaderboardLoader;

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async {
    return cache.readLeaderboard(eventId);
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async {
    final loader = _leaderboardLoader;
    final rows = loader != null
        ? await loader(eventId)
        : (await client.rpc(
            'get_event_leaderboard',
            params: {'target_event_id': eventId},
          ) as List)
            .map((row) => (row as Map).cast<String, dynamic>())
            .toList(growable: false);

    final entries = rows
        .map((row) => LeaderboardEntry.fromJson(row))
        .toList(growable: false);
    await cache.saveLeaderboard(eventId, entries);
    return entries;
  }
}
