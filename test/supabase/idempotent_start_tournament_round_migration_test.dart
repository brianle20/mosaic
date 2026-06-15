import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('start tournament round reuses an existing seating preview', () {
    final migration = File(
      'supabase/migrations/20260613150000_idempotent_start_tournament_round.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql,
        contains('create or replace function public.start_tournament_round'));
    expect(sql,
        contains('existing_round public.event_tournament_rounds%rowtype;'));
    expect(sql, contains("tournament_round.status = 'seating'"));
    expect(sql, contains('for update'));
    expect(
        sql, contains('from public.event_seating_assignments as assignment'));
    expect(sql, contains('assignment.tournament_round_id = existing_round.id'));
    expect(sql, contains('return query'));
    expect(sql, contains('return;'));
    expect(
      sql,
      isNot(contains("set\n    status = 'cancelled'")),
    );
    expect(sql,
        contains('from public.generate_tournament_round(target_event_id)'));
    expect(
      sql,
      contains(
        'grant execute on function public.start_tournament_round(uuid)\n'
        '  to authenticated;',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
