import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy player tag session start is blocked for unarchived events', () {
    final migrationFile = File(
      'supabase/migrations/20260606150000_deprecate_player_tag_session_start.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(sql, contains('create or replace function public.start_table_session'));
    expect(sql, contains('event_row.archived_at is null'));
    expect(
      sql,
      contains(
        'revoke all on function public.start_table_session_legacy_player_tags',
      ),
    );
    expect(sql, contains(') from public;'));
    expect(sql, contains(') from anon;'));
    expect(
      sql,
      contains(
        'Player tag session start is no longer available. Use assigned seating.',
      ),
    );
    expect(sql, contains('grant execute on function public.start_table_session'));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema')"));
  });
}
