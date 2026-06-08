import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final db hygiene migration stubs deprecated tag RPC and cleans bulk start',
      () {
    final migrationFile = File(
      'supabase/migrations/20260607150000_final_db_hygiene.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.replace_guest_tag'),
    );
    expect(sql, contains('scanned_display_label text default null'));
    expect(sql, contains('Player tag replacement is deprecated.'));
    expect(sql, contains('returns table ('));
    expect(sql, contains('assignment_id uuid'));
    expect(sql, contains('nfc_tag jsonb'));
    expect(sql, contains('revoke all on function public.replace_guest_tag'));
    expect(sql, contains('grant execute on function public.replace_guest_tag'));
    expect(sql, contains('to service_role;'));

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, isNot(contains('subscript_index integer;')));
    expect(sql, isNot(contains('ruleset_row public.rulesets%rowtype;')));
    expect(sql, contains('for seat_assignment_index in 1..array_length'));
    expect(
      sql,
      contains(
        'assignment_rows[seat_assignment_index].event_guest_id',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
