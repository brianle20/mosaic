import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tournament round orchestration migration adds round schema and RPCs',
      () {
    final migration = File(
      'supabase/migrations/20260524190000_tournament_round_orchestration.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(sql,
        contains('create table if not exists public.event_tournament_rounds'));
    expect(sql, contains('id uuid primary key default gen_random_uuid()'));
    expect(
      sql,
      contains(
        'event_id uuid not null references public.events(id) on delete cascade',
      ),
    );
    expect(
      sql,
      contains('round_number integer not null check (round_number > 0)'),
    );
    expect(
      sql,
      contains(
        "scoring_phase text not null check (scoring_phase in ('tournament', 'bonus'))",
      ),
    );
    expect(
      sql,
      contains(
        "status text not null default 'active'\n"
        "    check (status in ('seating', 'active', 'complete', 'cancelled'))",
      ),
    );
    expect(sql, contains('started_at timestamptz'));
    expect(sql, contains('completed_at timestamptz'));
    expect(sql, contains('created_at timestamptz not null default now()'));
    expect(sql, contains('updated_at timestamptz not null default now()'));
    expect(
      sql,
      contains(
        'created_by_user_id uuid references public.users(id) on delete set null',
      ),
    );
    expect(
      sql,
      contains(
        'constraint event_tournament_rounds_id_event_unique\n'
        '    unique (id, event_id)',
      ),
    );
    expect(sql, contains('event_tournament_rounds_one_current_idx'));
    expect(sql, contains('event_seating_assignments_tournament_round_idx'));
    expect(sql, contains('table_sessions_tournament_round_idx'));
    expect(
      sql,
      contains(
        'drop trigger if exists event_tournament_rounds_touch_updated_at\n'
        '  on public.event_tournament_rounds;\n'
        'create trigger event_tournament_rounds_touch_updated_at',
      ),
    );
    expect(sql, contains('execute function app_private.touch_updated_at();'));
    expect(
      sql,
      contains(
        'alter table public.event_tournament_rounds enable row level security;',
      ),
    );
    expect(sql, contains('create policy event_tournament_rounds_owner_all'));
    expect(
      sql,
      contains(
        'alter table public.event_seating_assignments\n'
        'add column if not exists tournament_round_id uuid;',
      ),
    );
    expect(
      sql,
      contains(
        'drop constraint if exists event_seating_assignments_tournament_round_event_fk',
      ),
    );
    expect(
      sql,
      contains(
        'add constraint event_seating_assignments_tournament_round_event_fk\n'
        'foreign key (tournament_round_id, event_id)\n'
        'references public.event_tournament_rounds(id, event_id)\n'
        'on delete set null (tournament_round_id);',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.table_sessions\n'
        'add column if not exists tournament_round_id uuid;',
      ),
    );
    expect(
      sql,
      contains(
        'drop constraint if exists table_sessions_tournament_round_event_fk',
      ),
    );
    expect(
      sql,
      contains(
        'add constraint table_sessions_tournament_round_event_fk\n'
        'foreign key (tournament_round_id, event_id)\n'
        'references public.event_tournament_rounds(id, event_id)\n'
        'on delete set null (tournament_round_id);',
      ),
    );
    expect(sql, contains('tournament_round_id uuid'));
    expect(sql, contains('assignment_round integer'));
    expect(sql, contains('get_tournament_round_summary'));
    expect(sql, contains("'complete_table_count'"));
    expect(sql, contains("'active_table_count'"));
    expect(sql, contains("'paused_table_count'"));
    expect(sql, contains("'not_started_table_count'"));
    expect(sql, contains("'current_round_tables'"));
    expect(sql, contains("'other_tables'"));
    expect(sql, contains("'assigned_players'"));
    expect(sql, contains("'latest_ended_session_id'"));
    expect(sql, contains("'active_session_id'"));
    expect(sql, contains("then 'active'"));
    expect(sql, contains("then 'paused'"));
    expect(sql, contains("then 'complete'"));
    expect(sql, contains("else 'not_started'"));
    expect(
      sql,
      contains(
        'return jsonb_build_object(\n'
        "      'round', null,\n"
        "      'assigned_table_count', 0,\n"
        "      'complete_table_count', 0,\n"
        "      'active_table_count', 0,\n"
        "      'paused_table_count', 0,\n"
        "      'not_started_table_count', 0,\n"
        "      'current_round_tables', jsonb_build_array(),\n"
        "      'other_tables', other_tables",
      ),
    );
    expect(sql, contains('into other_tables'));
    expect(sql, contains('from public.event_tables as event_table'));
    expect(
      sql,
      contains(
        "'round', jsonb_build_object(\n"
        "      'id', round_row.id,\n"
        "      'event_id', round_row.event_id,\n"
        "      'round_number', round_row.round_number,\n"
        "      'scoring_phase', round_row.scoring_phase,\n"
        "      'status', round_row.status,\n"
        "      'assignment_round', round_row.assignment_round",
      ),
    );
    expect(
      sql,
      contains(
        "'event_guest_id', assignment.event_guest_id,\n"
        "            'display_name', guest.display_name,\n"
        "            'seat_index', assignment.seat_index",
      ),
    );
    expect(sql, contains('session.tournament_round_id = round_row.id'));
    expect(sql, contains("session.scoring_phase = 'tournament'"));
    expect(
      sql,
      contains("'active_session_id', table_row.active_session_id"),
    );
    expect(
      sql,
      contains(
        "'latest_ended_session_id', table_row.latest_ended_session_id",
      ),
    );
    expect(sql, contains('generate_tournament_round'));
    expect(sql, contains('balanced_table_sizes'));
    expect(sql, contains('eligible_players as'));
    expect(sql, contains('ready_tables as'));
    expect(sql, contains('player_count < 2'));
    expect(sql, contains('array_length(table_sizes, 1)'));
    expect(sql, contains('cardinality(table_sizes)'));
    expect(sql, contains('guest.tournament_status = \'qualified\''));
    expect(sql, contains('guest.attendance_status = \'checked_in\''));
    expect(sql, contains('tag.default_tag_type = \'player\''));
    expect(sql, contains('tag.default_tag_type = \'table\''));
    expect(sql, contains('assignment.tournament_round_id'));
    expect(sql, contains('previous_round.status in (\'seating\', \'active\')'));
    expect(sql, contains('session.status in (\'active\', \'paused\')'));
    expect(sql, contains('not_started'));
    expect(
      sql,
      contains(
          'create or replace function public.start_assigned_table_session'),
    );
    expect(
      sql,
      contains('array_length(assignment_rows, 1) between 2 and 4'),
    );
    expect(
      sql,
      contains(
        'assignment_rows[assignment_index].seat_index <> assignment_index - 1',
      ),
    );
    expect(
      sql,
      contains(
        'Assigned seating must fill seats contiguously from East.',
      ),
    );
    expect(
      sql,
      contains(
        'assignment.assignment_round is distinct from assignment_rows[1].assignment_round',
      ),
    );
    expect(
      sql,
      contains(
        'All active seating assignments must use the same assignment round.',
      ),
    );
    expect(
      sql,
      contains(
        'assignment_rows[1].tournament_round_id is null',
      ),
    );
    expect(
      sql,
      contains(
        'assignment.tournament_round_id is distinct from assignment_rows[1].tournament_round_id',
      ),
    );
    expect(
      sql,
      contains(
        'All active tournament assignments must belong to the same tournament round.',
      ),
    );
    expect(
      sql,
      contains(
        'assignment.bonus_round_id is distinct from assignment_rows[1].bonus_round_id',
      ),
    );
    expect(
      sql,
      contains(
        'assignment.bonus_table_role is distinct from assignment_rows[1].bonus_table_role',
      ),
    );
    expect(
      sql,
      contains(
        'All active bonus assignments must use the same bonus metadata.',
      ),
    );
    expect(sql, contains('assignment_rows[1].tournament_round_id'));
    expect(sql, contains('assignment_rows[1].assignment_round'));
    expect(
      sql,
      contains(
          'for seat_assignment_count in 1..array_length(assignment_rows, 1) loop'),
    );
    expect(
      sql,
      contains(
        'app_private.tournament_round_orchestration_finals_policy_placeholder',
      ),
    );
    expect(sql, contains('Event not found for current host.'));
    expect(
        sql,
        contains(
            'At least 2 qualified, checked-in, tagged players are required.'));
    expect(sql, contains('Add or tag more tables before starting this round.'));
    expect(
        sql, contains('No prize-eligible players are available for finals.'));
    expect(sql, contains('minimum_hands_played'));
    expect(sql, contains('percentile_cont(0.5)'));
    expect(sql, contains('ranked_player_count = 0'));
    expect(sql, contains('ranked_player_count = 1'));
    expect(
      sql,
      contains('At least 2 prize-eligible players are required for finals.'),
    );
    expect(sql, contains('ranked_player_count between 2 and 5'));
    expect(sql, contains('redemption_table_id uuid default null'));
    expect(sql, contains('redemption_table_id is null'));
    expect(sql, contains('current_round.scoring_phase = \'tournament\''));
    expect(sql, contains('session.tournament_round_id = current_round.id'));
    expect(sql, contains('session.scoring_phase = \'tournament\''));
    expect(sql, contains('when ranked_players.seed_rank = 4 then 0'));
    expect(sql, contains('when ranked_players.seed_rank = 3 then 1'));
    expect(sql, contains('when ranked_players.seed_rank = 2 then 2'));
    expect(sql, contains('when ranked_player_count >= 4'));
    expect(sql, contains('else ranked_players.seed_rank - 1'));
    expect(sql, contains('ranked_players.seed_rank > 4'));
    expect(
      sql,
      contains(
        '(row_number() over (order by ranked_players.seed_rank asc))::integer - 1',
      ),
    );
    expect(
      sql,
      contains('A second ready table is required for Table of Redemption.'),
    );
    expect(sql, contains('table_of_champions'));
    expect(sql, contains('table_of_redemption'));
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });

  test('grants execute access for tournament round RPCs', () {
    final migration = File(
      'supabase/migrations/20260524190000_tournament_round_orchestration.sql',
    );
    final grantMigration = File(
      'supabase/migrations/20260524200000_grant_tournament_round_rpcs.sql',
    );

    expect(migration.existsSync(), isTrue);
    expect(grantMigration.existsSync(), isTrue);
    final sql = '${migration.readAsStringSync()}\n'
        '${grantMigration.readAsStringSync()}';

    expect(
      sql,
      contains(
        'grant execute on function public.get_tournament_round_summary(uuid)\n'
        '  to authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.generate_tournament_round(uuid)\n'
        '  to authenticated;',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });

  test('avoids repeating the exact previous tournament seating map', () {
    final migration = File(
      'supabase/migrations/20260524190000_tournament_round_orchestration.sql',
    );
    final repeatGuardMigration = File(
      'supabase/migrations/20260524201000_avoid_identical_tournament_round_seating.sql',
    );

    expect(migration.existsSync(), isTrue);
    expect(repeatGuardMigration.existsSync(), isTrue);
    final sql = '${migration.readAsStringSync()}\n'
        '${repeatGuardMigration.readAsStringSync()}';

    expect(
      sql,
      contains(
        'create or replace function '
        'app_private.avoid_identical_tournament_round_seating()',
      ),
    );
    expect(sql, contains('referencing new table as new_assignments'));
    expect(sql, contains('target_assignment_round - 1'));
    expect(sql, contains('if new_order = previous_order then'));
    expect(
      sql,
      contains(
        'delete from public.event_seating_assignments as assignment\n'
        '    using new_assignments as new_assignment',
      ),
    );
    expect(sql, contains('new_order[assignment_count]'));
    expect(sql, contains('new_order[ordered_new.slot_number - 1]'));
    expect(sql, isNot(contains('min(new_assignment.event_id)')));
    expect(sql, isNot(contains('min(new_assignment.tournament_round_id)')));
  });
}
