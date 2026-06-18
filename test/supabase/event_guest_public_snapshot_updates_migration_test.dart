import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event guest changes refresh public standings snapshots', () {
    final migrationFile = File(
      'supabase/migrations/20260618120000_refresh_public_snapshots_on_guest_changes.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains('drop trigger if exists public_event_updates_event_guests'),
    );
    expect(
      migration,
      contains('create trigger public_event_updates_event_guests'),
    );
    expect(
      migration,
      contains(
        'after insert or update or delete on public.event_guests',
      ),
    );
    expect(
      migration,
      contains(
        'for each row execute function app_private.insert_public_event_update()',
      ),
    );
    expect(
      migration,
      contains('app_private.refresh_public_event_standings_snapshot'),
    );
  });
}
