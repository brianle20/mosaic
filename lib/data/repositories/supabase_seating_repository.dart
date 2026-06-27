import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase/supabase.dart';

typedef SeatingRpcListRunner = Future<List<Map<String, dynamic>>> Function(
  String functionName,
  Map<String, dynamic> params,
);

typedef SeatingRpcJsonRunner = Future<Map<String, dynamic>?> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseSeatingRepository implements SeatingRepository {
  SupabaseSeatingRepository({
    required this.client,
    required this.cache,
    SeatingRpcListRunner? rpcListRunner,
    SeatingRpcJsonRunner? rpcJsonRunner,
  })  : _rpcListRunner = rpcListRunner,
        _rpcJsonRunner = rpcJsonRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final SeatingRpcListRunner? _rpcListRunner;
  final SeatingRpcJsonRunner? _rpcJsonRunner;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async {
    return cache.readSeatingAssignments(eventId);
  }

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) async {
    return cache.readTournamentRoundSummary(eventId);
  }

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) async {
    return _loadAndCache(
      eventId,
      'get_event_seating_assignments',
    );
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) async {
    return _loadAndCache(
      eventId,
      'generate_random_seating_assignments',
    );
  }

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(
    String eventId,
  ) async {
    final row = await _runRpcJson(
      'get_tournament_round_summary',
      {'target_event_id': eventId},
    );
    if (row == null) {
      throw StateError('No tournament round summary returned for $eventId.');
    }

    final summary = TournamentRoundSummary.fromJson(row);
    await cache.saveTournamentRoundSummary(eventId, summary);
    return summary;
  }

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) async {
    final row = await _runRpcJson(
      'get_bonus_round_state',
      {'target_event_id': eventId},
    );
    if (row == null) {
      return null;
    }

    return BonusRoundState.fromJson(row);
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) async {
    return _loadAndCache(
      eventId,
      'start_tournament_round',
    );
  }

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) async {
    return _loadAndCache(
      eventId,
      'generate_bonus_round_seating_assignments',
      {
        'target_event_id': eventId,
        'champions_table_id': championsTableId,
        'redemption_table_id': redemptionTableId,
      },
    );
  }

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) async {
    final rows = await _runRpcList(
      'start_bonus_round_sudden_death',
      {
        'target_event_id': eventId,
        'sudden_death_table_id': tableId,
      },
    );
    final assignments = rows
        .map((row) => SeatingAssignmentRecord.fromJson(row))
        .toList(growable: false);
    await loadAssignments(eventId);
    return assignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> startTableOfChampionsPlayIn({
    required String eventId,
    required String tableId,
  }) async {
    final rows = await _runRpcList(
      'start_table_of_champions_play_in',
      {
        'target_event_id': eventId,
        'play_in_table_id': tableId,
      },
    );
    final assignments = rows
        .map((row) => SeatingAssignmentRecord.fromJson(row))
        .toList(growable: false);
    await loadAssignments(eventId);
    return assignments;
  }

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) async {
    return _loadAndCache(
      eventId,
      'clear_event_seating_assignments',
    );
  }

  Future<List<SeatingAssignmentRecord>> _loadAndCache(
    String eventId,
    String functionName, [
    Map<String, dynamic>? params,
  ]) async {
    final rows = await _runRpcList(
      functionName,
      params ?? {'target_event_id': eventId},
    );
    final assignments = rows
        .map((row) => SeatingAssignmentRecord.fromJson(row))
        .toList(growable: false);
    await cache.saveSeatingAssignments(eventId, assignments);
    return assignments;
  }

  Future<List<Map<String, dynamic>>> _runRpcList(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _rpcListRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response is List) {
      return response
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from $functionName but received ${response.runtimeType}.',
    );
  }

  Future<Map<String, dynamic>?> _runRpcJson(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _rpcJsonRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response == null) {
      return null;
    }

    if (response is Map) {
      return response.cast<String, dynamic>();
    }

    if (response is List) {
      if (response.isEmpty) {
        return null;
      }
      if (response.length == 1 && response.single is Map) {
        return (response.single as Map).cast<String, dynamic>();
      }
    }

    throw StateError(
      'Expected a JSON object from $functionName but received ${response.runtimeType}.',
    );
  }
}
