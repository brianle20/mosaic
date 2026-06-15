import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk tournament table start opens scoring as part of starting tables',
      () {
    final migration = File(
      'supabase/migrations/20260613160000_start_all_tables_opens_scoring.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, contains('app_private.can_score_tournament(target_event_id)'));
    expect(sql, isNot(contains('require_event_for_phase_scoring')));
    expect(sql, contains('scoring_open = true'));
    expect(sql, contains("current_scoring_phase = 'tournament'"));
    expect(sql, contains('returning *\n  into event_row;'));
    expect(sql, contains('current_round.status in (\'seating\', \'active\')'));
    expect(
        sql,
        contains(
            'grant execute on function public.start_current_tournament_round_sessions(uuid)'));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
