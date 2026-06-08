import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live db lint fix migration repairs scoring and bulk start functions',
      () {
    final migrationFile = File(
      'supabase/migrations/20260607140000_fix_live_db_lint_errors.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function app_private.validate_hand_result_input',
      ),
    );
    expect(sql, contains('app_private.ruleset_minimum_winning_fan'));
    expect(sql, isNot(contains('app_private.ruleset_minimum_fan')));

    expect(
      sql,
      contains(
        'create or replace function app_private.refresh_event_score_totals',
      ),
    );
    expect(sql, isNot(contains('score_total_points = totals.total_points')));
    expect(sql, isNot(contains('score_rank = ranked.rank')));
    expect(
      sql,
      contains(
        'perform app_private.refresh_public_event_standings_snapshot(target_event_id);',
      ),
    );

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, contains('subscript_index integer;'));
    expect(
      sql,
      contains(
        'from generate_subscripts(assignment_rows, 1) as generated_index',
      ),
    );
    expect(
      sql,
      contains(
        'assignment_rows[generated_index].seat_index <> generated_index - 1',
      ),
    );
    expect(
      sql,
      contains(
        'for subscript_index in 1..array_length(assignment_rows, 1) loop',
      ),
    );
    expect(
      sql,
      isNot(
        contains(
          'from generate_subscripts(assignment_rows, 1) as assignment_index',
        ),
      ),
    );

    expect(
      sql,
      contains(
        'grant execute on function public.start_current_tournament_round_sessions(uuid)',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
