import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/tables_overview_screen.dart';

class _FakeTableRepository implements TableRepository {
  _FakeTableRepository(this.tables);

  final List<EventTableRecord> tables;

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
  Future<List<EventTableRecord>> listTables(String eventId) async => tables;

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      tables;

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeSessionRepository implements SessionRepository {
  _FakeSessionRepository(this.sessions);

  final List<TableSessionRecord> sessions;

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
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      sessions;

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
      sessions;

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
  testWidgets('renders an intentional empty state when no tables exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          tableRepository: _FakeTableRepository(const []),
          sessionRepository: _FakeSessionRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No tables yet'), findsOneWidget);
    expect(
      find.text('Add a table before starting live seating.'),
      findsOneWidget,
    );
    expect(find.text('Add Table'), findsOneWidget);
  });

  testWidgets('ready tagged tables explain scan-only session start',
      (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_01',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: false,
          tableRepository: tableRepository,
          sessionRepository: _FakeSessionRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Scan this table tag from the event dashboard to start seating.',
      ),
      findsOneWidget,
    );
    expect(find.text('Start Session'), findsNothing);
  });

  testWidgets('renders table cards and statuses', (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_points',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
      EventTableRecord.fromJson(const {
        'id': 'tbl_casual',
        'event_id': 'evt_01',
        'label': 'Table 2',
        'display_order': 2,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);
    final sessionRepository = _FakeSessionRepository([
      TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_points',
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
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: tableRepository,
          sessionRepository: sessionRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tables'), findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
    expect(find.text('Table 2'), findsOneWidget);
    expect(find.text('Points Table'), findsNothing);
    expect(find.text('Casual Table'), findsNothing);
    expect(find.text('Inactive Table'), findsNothing);
    expect(find.text('Tag Bound'), findsOneWidget);
    expect(find.text('Tag Unbound'), findsOneWidget);
    expect(find.text('Live Session'), findsOneWidget);
    expect(find.text('Session Active'), findsOneWidget);
    expect(find.text('Casual play only'), findsNothing);
    expect(find.text('Ready for Seating or Tag Binding'), findsOneWidget);
    expect(find.text('Start Session'), findsNothing);
    expect(find.text('View Session'), findsOneWidget);
  });

  testWidgets('active table session can be opened from tables view',
      (tester) async {
    final tableRepository = _FakeTableRepository([
      EventTableRecord.fromJson(const {
        'id': 'tbl_points',
        'event_id': 'evt_01',
        'label': 'Table 1',
        'display_order': 1,
        'nfc_tag_id': 'tag_01',
        'default_ruleset_id': 'HK_STANDARD_V1',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    ]);
    final sessionRepository = _FakeSessionRepository([
      TableSessionRecord.fromJson(const {
        'id': 'ses_01',
        'event_id': 'evt_01',
        'event_table_id': 'tbl_points',
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
      }),
    ]);

    SessionDetailArgs? openedArgs;
    await tester.pumpWidget(
      MaterialApp(
        home: TablesOverviewScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          scoringOpen: true,
          tableRepository: tableRepository,
          sessionRepository: sessionRepository,
        ),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.sessionDetailRoute) {
            openedArgs = settings.arguments! as SessionDetailArgs;
            return MaterialPageRoute<void>(
              builder: (context) => const Scaffold(
                body: Text('Opened Session Detail'),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Session'));
    await tester.pumpAndSettle();

    expect(openedArgs?.eventId, 'evt_01');
    expect(openedArgs?.sessionId, 'ses_01');
    expect(find.text('Opened Session Detail'), findsOneWidget);
  });
}
