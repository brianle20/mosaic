import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public event updates realtime path is retired', () {
    final migrationFile = File(
      'supabase/migrations/20260625180000_retire_public_event_updates.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    for (final triggerName in [
      'public_event_updates_event_score_totals',
      'public_event_updates_event_score_adjustments',
      'public_event_updates_hand_results',
      'public_event_updates_table_sessions',
      'public_event_updates_event_bonus_rounds',
      'public_event_updates_event_guests',
    ]) {
      expect(migration, contains('drop trigger if exists $triggerName'));
    }

    expect(
      migration,
      contains(
          'drop trigger if exists public_standings_snapshots_event_guests'),
    );
    expect(migration, isNot(contains('create trigger public_event_updates_')));

    expect(
      migration,
      contains(
        'alter publication supabase_realtime '
        'drop table public.public_event_updates',
      ),
    );
    expect(
      migration,
      contains(
          'drop function if exists app_private.insert_public_event_update()'),
    );
    expect(
      migration,
      contains('drop table if exists public.public_event_updates'),
    );
    expect(
      migration,
      contains("select pg_notify('pgrst', 'reload schema');"),
    );

    final dropFunctionIndex = migration.indexOf(
      'drop function if exists app_private.insert_public_event_update()',
    );
    final dropTableIndex = migration.indexOf(
      'drop table if exists public.public_event_updates',
    );
    final dropSnapshotTriggerIndex = migration.indexOf(
      'drop trigger if exists public_standings_snapshots_event_guests',
    );
    final createSnapshotTriggerIndex = migration.indexOf(
      'create trigger public_standings_snapshots_event_guests',
    );

    expect(dropSnapshotTriggerIndex, lessThan(createSnapshotTriggerIndex));

    for (final triggerName in [
      'public_event_updates_event_score_totals',
      'public_event_updates_event_score_adjustments',
      'public_event_updates_hand_results',
      'public_event_updates_table_sessions',
      'public_event_updates_event_bonus_rounds',
      'public_event_updates_event_guests',
    ]) {
      final dropTriggerIndex = migration.indexOf(
        'drop trigger if exists $triggerName',
      );

      expect(dropTriggerIndex, lessThan(dropFunctionIndex));
      expect(dropTriggerIndex, lessThan(dropTableIndex));
    }
  });
}
