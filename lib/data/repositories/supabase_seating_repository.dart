import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SeatingRpcListRunner = Future<List<Map<String, dynamic>>> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseSeatingRepository implements SeatingRepository {
  SupabaseSeatingRepository({
    required this.client,
    required this.cache,
    SeatingRpcListRunner? rpcListRunner,
  }) : _rpcListRunner = rpcListRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final SeatingRpcListRunner? _rpcListRunner;

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(
    String eventId,
  ) async {
    return cache.readSeatingAssignments(eventId);
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
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    required String redemptionTableId,
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
}
