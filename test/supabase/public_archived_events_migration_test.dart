import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('archived events are hidden from public standings access', () {
    final migrationFile = File(
      'supabase/migrations/20260530233000_hide_archived_public_events.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('public_event_standings_snapshots_public_read'));
    expect(migration, contains('event.archived_at is null'));
    expect(migration, contains('public.resolve_public_event_id'));
    expect(migration, contains('public.get_public_event_summary'));
    expect(migration,
        contains('delete from public.public_event_standings_snapshots'));
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
