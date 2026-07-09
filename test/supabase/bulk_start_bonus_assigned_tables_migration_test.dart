import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk bonus table start migration defines scoped assigned-table RPC', () {
    final migration = File(
      'supabase/migrations/20260709200000_bulk_start_bonus_assigned_tables.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();
    final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');

    expect(
      sql,
      contains(
        'create or replace function public.start_bonus_assigned_table_sessions',
      ),
    );
    expect(sql, contains('target_event_id uuid'));
    expect(sql, contains('target_bonus_table_role text'));
    expect(sql, contains('returns setof public.table_sessions'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public'));
    expect(
      sql,
      contains(
        "perform app_private.require_event_for_phase_scoring(target_event_id, 'bonus');",
      ),
    );
    expect(sql, isNot(contains('app_private.can_score_tournament')));
    expect(sql, contains('event_row public.events%rowtype;'));
    expect(sql, contains("event.current_scoring_phase = 'bonus'"));
    expect(
      sql,
      contains('Event must be active and in bonus scoring phase.'),
    );
    expect(sql, contains("'table_of_champions'"));
    expect(sql, contains("'table_of_redemption'"));
    expect(sql, contains("'table_of_champions_sudden_death'"));
    expect(sql, contains("'table_of_champions_play_in'"));
    expect(sql, contains("assignment.assignment_type = 'bonus'"));
    expect(
      sql,
      contains(
        'Standard finals seating cannot include sudden death or play-in assignments.',
      ),
    );
    expect(
      normalizedSql,
      contains(
        "target_bonus_table_role is null and assignment.bonus_table_role in ( 'table_of_champions', 'table_of_redemption' )",
      ),
    );
    expect(
      normalizedSql,
      contains(
        'target_bonus_table_role is not null and assignment.bonus_table_role = target_bonus_table_role',
      ),
    );
    expect(sql, contains('array_length(assignment_rows, 1) between 2 and 4'));
    expect(
      sql,
      contains(
        'where assignment.event_id = target_event_id\n'
        '      and assignment.event_table_id = table_row.id\n'
        "      and assignment.status = 'active';",
      ),
    );
    expect(
      sql,
      contains(
        'assignment_rows[assignment_index].seat_index <> assignment_index - 1',
      ),
    );
    expect(
      sql,
      contains('All scoped bonus assignments must share metadata.'),
    );
    expect(
      sql,
      contains('assignment.assignment_type is distinct from \'bonus\''),
    );
    expect(
      sql,
      contains(
        'assignment.bonus_table_role is distinct from assignment_rows[1].bonus_table_role',
      ),
    );
    expect(
      normalizedSql,
      contains(
        "target_bonus_table_role is null and assignment.bonus_table_role not in ( 'table_of_champions', 'table_of_redemption' )",
      ),
    );
    expect(
      normalizedSql,
      contains(
        '(target_bonus_table_role is not null and assignment.bonus_table_role is distinct from target_bonus_table_role )',
      ),
    );
    expect(sql, contains('All assigned session players must be checked in.'));
    expect(
      sql,
      contains(
        'An assigned guest is already seated in another active session.',
      ),
    );
    expect(
      sql,
      contains('A scoped bonus table already has an active session.'),
    );
    expect(
      sql,
      contains(
        'where existing_session.event_table_id = table_candidate.id\n'
        "        and existing_session.status in ('active', 'paused')",
      ),
    );
    expect(sql, contains('existing_session.event_table_id = table_row.id'));
    expect(sql, contains("existing_session.status in ('active', 'paused')"));
    expect(
      sql,
      contains('This bonus table has already been started for this seating.'),
    );
    expect(
      sql,
      contains(
        'where existing_session.event_table_id = table_row.id\n'
        "        and existing_session.scoring_phase = 'bonus'\n"
        '        and existing_session.bonus_round_id = assignment_rows[1].bonus_round_id\n'
        '        and existing_session.bonus_table_role = assignment_rows[1].bonus_table_role',
      ),
    );
    expect(
      sql,
      contains(
        'or assignment.tournament_round_id is distinct from assignment_rows[1].tournament_round_id',
      ),
    );
    expect(
      sql,
      contains('Active bonus round not found for this seating.'),
    );
    expect(
      sql,
      contains(
        'from public.event_bonus_rounds as bonus_round\n'
        '    where bonus_round.id = assignment_rows[1].bonus_round_id\n'
        '      and bonus_round.event_id = target_event_id\n'
        "      and bonus_round.status = 'active'\n"
        '    for update;',
      ),
    );
    expect(sql, isNot(contains('continue;')));
    expect(sql, contains('return next session_row;'));
    expect(
      sql,
      contains(
        'revoke all on function public.start_bonus_assigned_table_sessions(uuid, text)\n'
        '  from public;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.start_bonus_assigned_table_sessions(uuid, text)\n'
        '  from anon;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.start_bonus_assigned_table_sessions(uuid, text) to authenticated',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
