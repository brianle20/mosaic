import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk saved guest migration adds one-shot insert RPC', () {
    final migration = File(
      'supabase/migrations/20260627210000_bulk_saved_guest_insert.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.add_saved_guests_to_event'),
    );
    expect(sql, contains('target_guest_profile_ids uuid[]'));
    expect(sql, contains('insert into public.event_guests'));
    expect(
      sql,
      contains("set_config('app.bulk_saved_guest_insert', 'on', true)"),
    );
    expect(
      sql,
      contains('app_private.refresh_public_event_standings_snapshot'),
    );
  });

  test('event guest snapshot trigger skips per-row bulk refreshes', () {
    final migration = File(
      'supabase/migrations/20260627210000_bulk_saved_guest_insert.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        "current_setting('app.bulk_saved_guest_insert', true) = 'on'",
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function app_private.refresh_public_standings_snapshot_for_event_guest_change',
      ),
    );
  });
}
