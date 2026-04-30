import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef LeaderboardLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
);

typedef HandsPlayedLoader = Future<Map<String, int>> Function(String eventId);

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  SupabaseLeaderboardRepository({
    required this.client,
    required this.cache,
    LeaderboardLoader? leaderboardLoader,
    HandsPlayedLoader? handsPlayedLoader,
  })  : _leaderboardLoader = leaderboardLoader,
        _handsPlayedLoader = handsPlayedLoader;

  final SupabaseClient client;
  final LocalCache cache;
  final LeaderboardLoader? _leaderboardLoader;
  final HandsPlayedLoader? _handsPlayedLoader;

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

    final patchedRows = await _withHandsPlayed(eventId, rows);
    final entries = patchedRows
        .map((row) => LeaderboardEntry.fromJson(row))
        .toList(growable: false);
    await cache.saveLeaderboard(eventId, entries);
    return entries;
  }

  Future<List<Map<String, dynamic>>> _withHandsPlayed(
    String eventId,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.every((row) => row['hands_played'] != null)) {
      return rows;
    }

    final loader = _handsPlayedLoader;
    final handsPlayedByGuest = loader != null
        ? await loader(eventId)
        : await _loadHandsPlayedByGuest(eventId);

    return rows
        .map(
          (row) => {
            ...row,
            'hands_played': row['hands_played'] ??
                handsPlayedByGuest[row['event_guest_id']] ??
                0,
          },
        )
        .toList(growable: false);
  }

  Future<Map<String, int>> _loadHandsPlayedByGuest(String eventId) async {
    final sessionRows = (await client
            .from('table_sessions')
            .select('id')
            .eq('event_id', eventId) as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList(growable: false);
    final sessionIds = sessionRows
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
    if (sessionIds.isEmpty) {
      return const {};
    }

    final handRows = (await client
            .from('hand_results')
            .select('table_session_id')
            .inFilter('table_session_id', sessionIds)
            .eq('status', 'recorded') as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList(growable: false);
    final handsPlayedBySession = <String, int>{};
    for (final row in handRows) {
      final sessionId = row['table_session_id'];
      if (sessionId is String) {
        handsPlayedBySession[sessionId] =
            (handsPlayedBySession[sessionId] ?? 0) + 1;
      }
    }

    final seatRows = (await client
            .from('table_session_seats')
            .select('table_session_id, event_guest_id')
            .inFilter('table_session_id', sessionIds) as List)
        .map((row) => (row as Map).cast<String, dynamic>())
        .toList(growable: false);
    final handsPlayedByGuest = <String, int>{};
    for (final row in seatRows) {
      final sessionId = row['table_session_id'];
      final guestId = row['event_guest_id'];
      if (sessionId is! String || guestId is! String) {
        continue;
      }

      handsPlayedByGuest[guestId] = (handsPlayedByGuest[guestId] ?? 0) +
          (handsPlayedBySession[sessionId] ?? 0);
    }

    return handsPlayedByGuest;
  }
}
