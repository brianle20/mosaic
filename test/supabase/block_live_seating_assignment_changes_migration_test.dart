import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live seating assignment changes migration adds trigger guard', () {
    final migrationFile = File(
      'supabase/migrations/20260522120000_block_live_seating_assignment_changes.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains('event_seating_assignments_block_live_changes'),
    );
    expect(
      migration,
      contains("session.status in ('active', 'paused')"),
    );
    expect(
      migration,
      contains(
          'End active or paused sessions before changing seating assignments.'),
    );
    expect(
      migration,
      contains('trigger_event_seating_assignments_block_live_changes'),
    );
    expect(
      migration,
      contains('before insert or update'),
    );
    expect(
      migration,
      contains('on public.event_seating_assignments'),
    );
    expect(
      migration,
      contains("pg_notify('pgrst', 'reload schema')"),
    );
  });
}
