import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';

class _FakeTableRepository implements TableRepository {
  _FakeTableRepository({
    required this.cachedTables,
    this.tableLoader,
  });

  final List<EventTableRecord> cachedTables;
  final Future<List<EventTableRecord>> Function(String eventId)? tableLoader;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async {
    final loader = tableLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedTables;
  }

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      cachedTables;

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository({
    required this.cachedSessions,
    this.sessionLoader,
  });

  final List<TableSessionRecord> cachedSessions;
  final Future<List<TableSessionRecord>> Function(String eventId)?
      sessionLoader;

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    final loader = sessionLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedSessions;
  }

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
          String sessionId) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      cachedSessions;

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

void main() {
  test('loads cached tables and active sessions when remote fetches fail',
      () async {
    final cachedTable = EventTableRecord.fromJson(const {
      'id': 'tbl_01',
      'event_id': 'evt_01',
      'label': 'Table 1',
      'mode': 'points',
      'display_order': 1,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': {},
      'status': 'active',
    });
    final cachedSession = TableSessionRecord.fromJson(const {
      'id': 'ses_01',
      'event_id': 'evt_01',
      'event_table_id': 'tbl_01',
      'session_number_for_table': 1,
      'ruleset_id': 'HK_STANDARD_V1',
      'ruleset_version': 1,
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
    });

    final controller = TableListController(
      tableRepository: _FakeTableRepository(
        cachedTables: [cachedTable],
        tableLoader: (_) async => throw Exception('table fetch failed'),
      ),
      sessionRepository: _FakeSessionRepository(
        cachedSessions: [cachedSession],
        sessionLoader: (_) async => throw Exception('session fetch failed'),
      ),
    );

    await controller.load('evt_01');

    expect(controller.tables.map((table) => table.id), ['tbl_01']);
    expect(controller.activeSessionsByTableId.keys, ['tbl_01']);
    expect(controller.error, isNull);
  });
}
