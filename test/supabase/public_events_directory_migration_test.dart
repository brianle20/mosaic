import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public events directory exposes only unarchived public event summaries', () {
    final migrationFile = File(
      'supabase/migrations/20260627231000_public_events_directory.sql',
    );

    expect(migrationFile.existsSync(), isTrue);

    final migration = migrationFile.readAsStringSync();

    expect(migration, contains('public.get_public_events'));
    expect(migration, contains('returns table'));
    expect(migration, contains('event_id uuid'));
    expect(migration, contains('public_slug text'));
    expect(migration, contains('title text'));
    expect(migration, contains('standings_updated_at timestamptz'));
    expect(migration, contains('event.archived_at is null'));
    expect(migration, contains('public.public_event_standings_snapshots'));
    expect(migration, contains('grant execute on function public.get_public_events()'));
    expect(migration, contains('to anon, authenticated'));
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));

    expect(migration, isNot(contains('owner_user_id')));
    expect(migration, isNot(contains('created_by')));
    expect(migration, isNot(contains('staff')));
    expect(migration, isNot(contains('guest_profile')));
    expect(migration, isNot(contains('phone')));
    expect(migration, isNot(contains('email')));
  });
}
