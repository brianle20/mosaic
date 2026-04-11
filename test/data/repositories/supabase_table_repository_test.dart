import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/local/local_cache.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/supabase_table_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseTableRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('creates a table from the create_event_table RPC and refreshes cache',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseTableRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'create_event_table');
          expect(params['target_event_id'], 'evt_01');
          expect(params['table_label'], 'Table 1');
          expect(params['table_mode'], 'points');
          return {
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
          };
        },
      );

      final created = await repository.createTable(
        const CreateEventTableInput(
          eventId: 'evt_01',
          label: 'Table 1',
          mode: EventTableMode.points,
          displayOrder: 1,
        ),
      );

      expect(created.label, 'Table 1');
      expect(created.mode, EventTableMode.points);

      final cachedTables = await repository.readCachedTables('evt_01');
      expect(cachedTables, hasLength(1));
      expect(cachedTables.single.id, 'tbl_01');
    });

    test('updates a table from the update_event_table RPC', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseTableRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'update_event_table');
          expect(params['target_event_table_id'], 'tbl_01');
          expect(params['table_label'], 'Table A');
          expect(params['table_mode'], 'casual');
          return {
            'id': 'tbl_01',
            'event_id': 'evt_01',
            'label': 'Table A',
            'mode': 'casual',
            'display_order': 2,
            'default_ruleset_id': 'HK_STANDARD_V1',
            'default_rotation_policy_type':
                'dealer_cycle_return_to_initial_east',
            'default_rotation_policy_config_json': {},
            'status': 'active',
          };
        },
      );

      final updated = await repository.updateTable(
        const UpdateEventTableInput(
          id: 'tbl_01',
          eventId: 'evt_01',
          label: 'Table A',
          mode: EventTableMode.casual,
          displayOrder: 2,
        ),
      );

      expect(updated.label, 'Table A');
      expect(updated.mode, EventTableMode.casual);
    });

    test('binds a table tag from the bind_table_tag RPC', () async {
      final cache = await LocalCache.create();
      final repository = SupabaseTableRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcSingleRunner: (functionName, params) async {
          expect(functionName, 'bind_table_tag');
          expect(params['target_event_table_id'], 'tbl_01');
          expect(params['scanned_uid'], 'table-001');
          return {
            'id': 'tbl_01',
            'event_id': 'evt_01',
            'label': 'Table 1',
            'mode': 'points',
            'display_order': 1,
            'nfc_tag_id': 'tag_table_01',
            'default_ruleset_id': 'HK_STANDARD_V1',
            'default_rotation_policy_type':
                'dealer_cycle_return_to_initial_east',
            'default_rotation_policy_config_json': {},
            'status': 'active',
          };
        },
      );

      final updated = await repository.bindTableTag(
        tableId: 'tbl_01',
        scannedUid: 'table-001',
      );

      expect(updated.nfcTagId, 'tag_table_01');
      expect(updated.defaultRotationPolicyType,
          RotationPolicyType.dealerCycleReturnToInitialEast);
    });
  });
}
