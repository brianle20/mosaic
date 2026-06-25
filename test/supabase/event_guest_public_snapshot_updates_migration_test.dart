import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event guest changes refresh public standings snapshots directly', () {
    final migrationFile = File(
      'supabase/migrations/20260625180000_retire_public_event_updates.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains('drop trigger if exists public_event_updates_event_guests'),
    );
    expect(
      migration,
      contains(
        'create or replace function '
        'app_private.refresh_public_standings_snapshot_for_event_guest_change()',
      ),
    );
    expect(
      migration,
      contains('create trigger public_standings_snapshots_event_guests'),
    );
    expect(
      migration,
      contains('after insert or update or delete on public.event_guests'),
    );
    expect(
      migration,
      contains(
        'for each row execute function '
        'app_private.refresh_public_standings_snapshot_for_event_guest_change()',
      ),
    );
    expect(
      migration,
      contains('app_private.refresh_public_event_standings_snapshot'),
    );
    expect(
      migration,
      isNot(
        contains(
          'for each row execute function app_private.insert_public_event_update()',
        ),
      ),
    );
  });
}
