import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public events directory exposes the configured event schedule', () {
    final migrationFile = File(
      'supabase/migrations/20260723124000_show_public_event_datetime.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(
      migration,
      contains('drop function if exists public.get_public_events();'),
    );
    expect(migration, contains('event_starts_at timestamptz'));
    expect(migration, contains('event_timezone text'));
    expect(migration, contains('event.starts_at as event_starts_at'));
    expect(migration, contains('event.timezone as event_timezone'));
    expect(
      migration,
      contains(
        'create or replace function '
        'app_private.public_event_last_recorded_hand_at',
      ),
    );
    expect(migration, contains('max(hand_result.entered_at)'));
    expect(migration, contains("hand_result.status = 'recorded'"));
    expect(
      migration,
      contains(
        'app_private.public_event_last_recorded_hand_at(event.id)\n'
        '      as standings_updated_at',
      ),
    );
    expect(
      migration,
      contains(
        'app_private.public_event_last_recorded_hand_at(target_event_id)',
      ),
    );
    expect(migration, contains("'{updatedAt}'"));
    expect(migration, contains("'null'::jsonb"));
    expect(
      migration,
      contains(
        'perform app_private.refresh_public_event_standings_snapshot('
        'event_row.id',
      ),
    );
    expect(migration, contains('event.archived_at is null'));
    expect(migration, contains("event.lifecycle_status <> 'cancelled'"));
    expect(
      migration,
      contains(
        'order by\n'
        '    event.starts_at desc,\n'
        '    event.title asc;',
      ),
    );
    expect(
      migration,
      contains('grant execute on function public.get_public_events()'),
    );
    expect(migration, contains('to anon, authenticated'));
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
