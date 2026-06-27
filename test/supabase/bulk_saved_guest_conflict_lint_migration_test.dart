import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;

  setUpAll(() {
    final migrationFile = File(
      'supabase/migrations/20260627233000_bulk_saved_guest_conflict_lint.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    migration = migrationFile.readAsStringSync().toLowerCase();
  });

  test('saved guest bulk insert resolves conflict targets as table columns',
      () {
    expect(
      migration,
      contains('create or replace function public.add_saved_guests_to_event'),
    );
    expect(migration, contains('#variable_conflict use_column'));
    expect(migration, contains('on conflict (event_id, guest_profile_id)'));
    expect(migration, contains('where event_record.id = target_event_id'));
  });

  test('migration reloads the postgrest schema cache', () {
    expect(migration, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
