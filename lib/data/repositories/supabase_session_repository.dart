import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SessionListLoader = Future<List<Map<String, dynamic>>> Function(
  String eventId,
);
typedef SessionSeatsLoader = Future<List<Map<String, dynamic>>> Function(
  String sessionId,
);
typedef SessionRpcSingleRunner = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> params,
);

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository({
    required this.client,
    required this.cache,
    SessionListLoader? sessionListLoader,
    SessionSeatsLoader? sessionSeatsLoader,
    SessionRpcSingleRunner? rpcSingleRunner,
  })  : _sessionListLoader = sessionListLoader,
        _sessionSeatsLoader = sessionSeatsLoader,
        _rpcSingleRunner = rpcSingleRunner;

  final SupabaseClient client;
  final LocalCache cache;
  final SessionListLoader? _sessionListLoader;
  final SessionSeatsLoader? _sessionSeatsLoader;
  final SessionRpcSingleRunner? _rpcSingleRunner;

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    final loader = _sessionListLoader;
    final rows = loader != null
        ? await loader(eventId)
        : await client
            .from('table_sessions')
            .select()
            .eq('event_id', eventId)
            .order('started_at', ascending: false);

    final sessions = rows
        .map((row) => TableSessionRecord.fromJson(row))
        .toList(growable: false);
    await cache.saveSessions(eventId, sessions);
    return sessions;
  }

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async {
    return cache.readSessions(eventId);
  }

  @override
  Future<StartedTableSessionRecord> startSession(
    StartTableSessionInput input,
  ) async {
    final sessionRow = await _runRpcSingle(
      'start_table_session',
      input.toRpcParams(),
    );
    final sessionId = sessionRow['id'] as String;
    final seatsRows = await _loadSessionSeats(sessionId);
    final startedSession = StartedTableSessionRecord.fromJson(
      sessionJson: sessionRow,
      seatsJson: seatsRows,
    );

    final currentSessions = await readCachedSessions(startedSession.session.eventId);
    final mergedSessions = [
      ...currentSessions.where(
        (session) => session.id != startedSession.session.id,
      ),
      startedSession.session,
    ]..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    await cache.saveSessions(startedSession.session.eventId, mergedSessions);

    return startedSession;
  }

  Future<List<Map<String, dynamic>>> _loadSessionSeats(String sessionId) async {
    final loader = _sessionSeatsLoader;
    if (loader != null) {
      return loader(sessionId);
    }

    final rows = await client
        .from('table_session_seats')
        .select()
        .eq('table_session_id', sessionId)
        .order('seat_index', ascending: true);
    return rows
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _runRpcSingle(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _rpcSingleRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return response.cast<String, dynamic>();
    }

    throw StateError(
      'Expected a single row map from $functionName but received ${response.runtimeType}.',
    );
  }
}
