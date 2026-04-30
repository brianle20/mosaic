import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
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
typedef SessionDetailLoader = Future<Map<String, dynamic>> Function(
  String sessionId,
);
typedef SessionTableLabelLoader = Future<String?> Function(String tableId);
typedef SessionEventHandLedgerLoader = Future<List<Map<String, dynamic>>>
    Function(String eventId);

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository({
    required this.client,
    required this.cache,
    SessionListLoader? sessionListLoader,
    SessionSeatsLoader? sessionSeatsLoader,
    SessionRpcSingleRunner? rpcSingleRunner,
    SessionDetailLoader? sessionDetailLoader,
    SessionTableLabelLoader? sessionTableLabelLoader,
    SessionEventHandLedgerLoader? eventHandLedgerLoader,
  })  : _sessionListLoader = sessionListLoader,
        _sessionSeatsLoader = sessionSeatsLoader,
        _rpcSingleRunner = rpcSingleRunner,
        _sessionDetailLoader = sessionDetailLoader,
        _sessionTableLabelLoader = sessionTableLabelLoader,
        _eventHandLedgerLoader = eventHandLedgerLoader;

  final SupabaseClient client;
  final LocalCache cache;
  final SessionListLoader? _sessionListLoader;
  final SessionSeatsLoader? _sessionSeatsLoader;
  final SessionRpcSingleRunner? _rpcSingleRunner;
  final SessionDetailLoader? _sessionDetailLoader;
  final SessionTableLabelLoader? _sessionTableLabelLoader;
  final SessionEventHandLedgerLoader? _eventHandLedgerLoader;

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
  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId) async {
    return cache.readSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) async {
    final detail = await _loadSessionDetail(sessionId);
    await cache.saveSessionDetail(detail);
    await _mergeSessionIntoCache(detail.session);
    return detail;
  }

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) async {
    return cache.readEventHandLedger(eventId);
  }

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId) async {
    final loader = _eventHandLedgerLoader;
    final rows = loader != null
        ? await loader(eventId)
        : await _loadEventHandLedgerRows(eventId);

    final entries = rows
        .map((row) => EventHandLedgerEntry.fromJson(row))
        .toList(growable: false);
    await cache.saveEventHandLedger(eventId, entries);
    return entries;
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

    final currentSessions =
        await readCachedSessions(startedSession.session.eventId);
    final mergedSessions = [
      ...currentSessions.where(
        (session) => session.id != startedSession.session.id,
      ),
      startedSession.session,
    ]..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    await cache.saveSessions(startedSession.session.eventId, mergedSessions);

    return startedSession;
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) async {
    await _runRpcSingle(
      'pause_table_session',
      {'target_table_session_id': sessionId},
    );
    return loadSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) async {
    await _runRpcSingle(
      'resume_table_session',
      {'target_table_session_id': sessionId},
    );
    return loadSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) async {
    await _runRpcSingle(
      'end_table_session',
      {
        'target_table_session_id': sessionId,
        'target_end_reason': reason,
      },
    );
    return loadSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) async {
    final handRow =
        await _runRpcSingle('record_hand_result', input.toRpcParams());
    final sessionId = handRow['table_session_id'] as String;
    return loadSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) async {
    final handRow =
        await _runRpcSingle('edit_hand_result', input.toRpcParams());
    final sessionId = handRow['table_session_id'] as String;
    return loadSessionDetail(sessionId);
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) async {
    final handRow =
        await _runRpcSingle('void_hand_result', input.toRpcParams());
    final sessionId = handRow['table_session_id'] as String;
    return loadSessionDetail(sessionId);
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

  Future<SessionDetailRecord> _loadSessionDetail(String sessionId) async {
    final loader = _sessionDetailLoader;
    if (loader != null) {
      final detailJson = await loader(sessionId);
      final sessionJson =
          (detailJson['session'] as Map).cast<String, dynamic>();
      final session = TableSessionRecord.fromJson(sessionJson);
      final tableLabel = _normalizeTableLabel(detailJson['table_label']) ??
          (_sessionTableLabelLoader == null
              ? null
              : await _loadTableLabel(session.eventTableId));

      return SessionDetailRecord.fromJson({
        ...detailJson,
        'table_label': tableLabel,
      });
    }

    final sessionRow = await client
        .from('table_sessions')
        .select()
        .eq('id', sessionId)
        .single();
    final sessionJson = sessionRow.cast<String, dynamic>();
    final session = TableSessionRecord.fromJson(sessionJson);
    final tableLabel = await _loadTableLabel(session.eventTableId);
    final seatsRows = await _loadSessionSeats(sessionId);
    final handsRows = await client
        .from('hand_results')
        .select()
        .eq('table_session_id', sessionId)
        .order('hand_number', ascending: true);

    final handIds = handsRows
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
    final settlementsRows = handIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : (await client
                .from('hand_settlements')
                .select()
                .inFilter('hand_result_id', handIds))
            .map((row) => row.cast<String, dynamic>())
            .toList(growable: false);

    return SessionDetailRecord.fromJson({
      'table_label': tableLabel,
      'session': sessionJson,
      'seats': seatsRows,
      'hands': handsRows,
      'settlements': settlementsRows,
    });
  }

  Future<String?> _loadTableLabel(String tableId) async {
    final loader = _sessionTableLabelLoader;
    if (loader != null) {
      return loader(tableId);
    }

    final row = await client
        .from('event_tables')
        .select('label')
        .eq('id', tableId)
        .maybeSingle();
    return _normalizeTableLabel(row?['label']);
  }

  Future<List<Map<String, dynamic>>> _loadEventHandLedgerRows(
    String eventId,
  ) async {
    final response = await client.rpc(
      'list_event_hand_ledger',
      params: {'target_event_id': eventId},
    );
    if (response is List) {
      return response
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from list_event_hand_ledger but received ${response.runtimeType}.',
    );
  }

  String? _normalizeTableLabel(Object? value) {
    if (value is! String) {
      return null;
    }

    final label = value.trim();
    return label.isEmpty ? null : label;
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

  Future<void> _mergeSessionIntoCache(TableSessionRecord session) async {
    final currentSessions = await readCachedSessions(session.eventId);
    final mergedSessions = [
      ...currentSessions.where((existing) => existing.id != session.id),
      session,
    ]..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    await cache.saveSessions(session.eventId, mergedSessions);
  }
}
