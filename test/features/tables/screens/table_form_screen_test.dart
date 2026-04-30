import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/table_form_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _RecordingTableRepository implements TableRepository {
  _RecordingTableRepository({
    this.existingTables = const [],
    this.resolvedTable,
    this.resolveException,
  });

  final List<EventTableRecord> existingTables;
  final EventTableRecord? resolvedTable;
  final Object? resolveException;
  CreateEventTableInput? created;
  String? boundScannedUid;
  EventTableRecord? boundTable;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    boundScannedUid = scannedUid;
    boundTable = EventTableRecord.fromJson({
      'id': tableId,
      'event_id': 'evt_01',
      'label': 'Table 1',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD',
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': const {},
      'status': 'active',
    });
    return boundTable!;
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) async {
    created = input;
    return EventTableRecord.fromJson({
      'id': 'tbl_01',
      'event_id': input.eventId,
      'label': input.label,
      'display_order': input.displayOrder,
      'default_ruleset_id': input.defaultRulesetId,
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': const {},
      'status': 'active',
    });
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async =>
      existingTables;

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      const [];

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) {
    final exception = resolveException;
    if (exception != null) {
      throw exception;
    }
    final table = resolvedTable;
    if (table != null) {
      return Future.value(table);
    }
    throw const TableTagResolutionException(
      TableTagResolutionFailure.unknownTag,
    );
  }

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeNfcService implements NfcService {
  const _FakeNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
          BuildContext context) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async =>
      null;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return const TagScanResult(
      rawUid: 'TABLE001',
      normalizedUid: 'TABLE001',
      isManualEntry: true,
    );
  }
}

void main() {
  testWidgets('scans a table tag to create and bind a new table',
      (tester) async {
    final repository = _RecordingTableRepository(
      existingTables: [
        EventTableRecord.fromJson(const {
          'id': 'tbl_existing',
          'event_id': 'evt_01',
          'label': 'Table 1',
          'display_order': 1,
          'default_ruleset_id': 'HK_STANDARD',
          'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
          'default_rotation_policy_config_json': {},
        }),
      ],
    );
    EventTableRecord? savedTable;

    await tester.pumpWidget(
      MaterialApp(
        home: TableFormScreen(
          eventId: 'evt_01',
          tableRepository: repository,
          nfcService: const _FakeNfcService(),
          onSaved: (table) => savedTable = table,
        ),
      ),
    );

    expect(find.text('Label'), findsNothing);
    expect(find.text('Mode'), findsNothing);
    expect(find.text('points'), findsNothing);
    expect(find.text('casual'), findsNothing);
    expect(find.text('inactive'), findsNothing);

    await tester.tap(find.text('Scan Table Tag'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.label, 'Table 2');
    expect(repository.boundScannedUid, 'TABLE001');
    expect(savedTable, isNotNull);
    expect(savedTable!.nfcTagId, 'tag_01');
  });

  testWidgets('rejects a player tag before creating a table', (tester) async {
    final repository = _RecordingTableRepository(
      resolveException: const TableTagResolutionException(
        TableTagResolutionFailure.nonTableTag,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TableFormScreen(
          eventId: 'evt_01',
          tableRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );

    await tester.tap(find.text('Scan Table Tag'));
    await tester.pumpAndSettle();

    expect(repository.created, isNull);
    expect(repository.boundScannedUid, isNull);
    expect(find.text('Expected a table tag.'), findsOneWidget);
  });

  testWidgets('does not create a table for an already bound table tag',
      (tester) async {
    final repository = _RecordingTableRepository(
      resolvedTable: EventTableRecord.fromJson(const {
        'id': 'tbl_existing',
        'event_id': 'evt_01',
        'label': 'Table 4',
        'display_order': 4,
        'nfc_tag_id': 'tag_table_04',
        'default_ruleset_id': 'HK_STANDARD',
        'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
        'default_rotation_policy_config_json': {},
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TableFormScreen(
          eventId: 'evt_01',
          tableRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );

    await tester.tap(find.text('Scan Table Tag'));
    await tester.pumpAndSettle();

    expect(repository.created, isNull);
    expect(repository.boundScannedUid, isNull);
    expect(
      find.text('That table tag is already bound to Table 4.'),
      findsOneWidget,
    );
  });

  testWidgets('shows bind table tag action for an existing table',
      (tester) async {
    final repository = _RecordingTableRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TableFormScreen(
          eventId: 'evt_01',
          tableRepository: repository,
          nfcService: const _FakeNfcService(),
          initialTable: EventTableRecord.fromJson(const {
            'id': 'tbl_01',
            'event_id': 'evt_01',
            'label': 'Table 1',
            'display_order': 1,
            'default_ruleset_id': 'HK_STANDARD',
            'default_rotation_policy_type':
                'dealer_cycle_return_to_initial_east',
            'default_rotation_policy_config_json': {},
            'status': 'active',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bind Table Tag'), findsOneWidget);
  });
}
