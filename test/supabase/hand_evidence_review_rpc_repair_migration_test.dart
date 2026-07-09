import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260709193000_repair_hand_evidence_review_rpc.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync();
  });

  test('repairs hand tile review status constraint', () {
    expect(
      migration,
      contains('drop constraint if exists hand_tile_entries_review_check'),
    );
    expect(
      migration,
      contains("'under_declared'"),
    );
  });

  test('review list rpc returns tile entry data', () {
    expect(
        migration,
        contains(
            'drop function if exists public.list_hand_evidence_review(uuid)'));
    expect(migration, contains('returns table ('));
    expect(migration, contains('tile_entry_id uuid'));
    expect(migration, contains('tiles_json jsonb'));
    expect(migration,
        contains('left join public.hand_tile_entries as tile_entry'));
    expect(migration, contains('tile_entry.review_status'));
  });

  test('tile upsert rpc can classify under declared hands', () {
    expect(migration, contains('public.upsert_hand_tile_entry'));
    expect(
      migration,
      contains(
        "when target_calculated_fan_count > hand_row.fan_count then 'under_declared'",
      ),
    );
    expect(
      migration,
      contains(
        "when target_calculated_fan_count < hand_row.fan_count then 'flagged'",
      ),
    );
  });
}
