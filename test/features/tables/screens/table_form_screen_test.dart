import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/screens/table_form_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _RecordingTableRepository implements TableRepository {
  CreateEventTableInput? created;
  EventTableRecord? boundTable;

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    boundTable = EventTableRecord.fromJson({
      'id': tableId,
      'event_id': 'evt_01',
      'label': 'Table 1',
      'mode': 'points',
      'display_order': 1,
      'nfc_tag_id': 'tag_01',
      'default_ruleset_id': 'HK_STANDARD_V1',
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
      'mode': input.mode.name,
      'display_order': input.displayOrder,
      'default_ruleset_id': input.defaultRulesetId,
      'default_rotation_policy_type': 'dealer_cycle_return_to_initial_east',
      'default_rotation_policy_config_json': const {},
      'status': 'active',
    });
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async => const [];

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      const [];

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _FakeNfcService implements NfcService {
  const _FakeNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(BuildContext context) async =>
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
  testWidgets('shows validation and submits a new table', (tester) async {
    final repository = _RecordingTableRepository();
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

    await tester.tap(find.text('Save Table'));
    await tester.pump();
    expect(find.text('Table label is required.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Table 1');
    await tester.ensureVisible(find.text('Save Table'));
    await tester.tap(find.text('Save Table'));
    await tester.pumpAndSettle();

    expect(repository.created, isNotNull);
    expect(repository.created!.mode, EventTableMode.points);
    expect(savedTable, isNotNull);
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
            'mode': 'points',
            'display_order': 1,
            'default_ruleset_id': 'HK_STANDARD_V1',
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
