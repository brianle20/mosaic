import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defines the versioned Finals state machine schema', () {
    final sql = File(
      'supabase/migrations/20260711120000_finals_orchestration_schema.sql',
    ).readAsStringSync();

    expect(sql, contains('alter column redemption_table_id drop not null'));
    expect(sql, contains('add column if not exists flow_version text'));
    expect(sql, contains('add column if not exists state_version bigint'));
    expect(sql,
        contains('add column if not exists eligible_player_count integer'));
    expect(sql, contains('add column if not exists format text'));
    expect(
      sql,
      contains(
        'add column if not exists redemption_winner_event_guest_id uuid',
      ),
    );
    expect(
      sql,
      contains('add column if not exists redemption_resolution_method text'),
    );

    expect(sql, contains('create table public.event_finals_contests'));
    expect(
      sql,
      contains('create table public.event_finals_contest_participants'),
    );
    expect(
      sql,
      contains('create table public.event_finals_champions_slots'),
    );
    expect(sql, contains("'available_table_ids'"));
    expect(sql, contains("tag.default_tag_type = 'table'"));
    expect(sql, contains("tag.status = 'active'"));
    expect(sql, contains("session.status in ('active', 'paused')"));
    expect(
      sql,
      contains('create table public.event_finals_eligible_snapshot'),
    );
    for (final column in <String>[
      'bonus_round_id uuid not null',
      'event_id uuid not null',
      'event_guest_id uuid not null',
      'display_name text not null',
      'total_points integer not null',
      'hands_played integer not null',
      'standing_rank integer not null',
      'seed_rank integer not null',
      'primary key (bonus_round_id, event_guest_id)',
      'unique (bonus_round_id, seed_rank)',
    ]) {
      expect(sql, contains(column));
    }
    expect(sql, contains('event_finals_eligible_snapshot_root_event_fk'));
    expect(sql, contains('event_finals_eligible_snapshot_guest_event_fk'));
    expect(sql, contains('event_finals_eligible_snapshot_event_seed_idx'));
    expect(
      sql,
      contains(
          'alter table public.event_finals_eligible_snapshot enable row level security'),
    );
    expect(sql, contains('event_finals_eligible_snapshot_owner_or_staff_read'));
    expect(
      sql,
      isNot(contains('event_finals_eligible_snapshot_owner_manage')),
      reason: 'the frozen snapshot must not accept authenticated writes',
    );
    expect(
      sql,
      contains(
        'revoke insert, update, delete, truncate, references, trigger\n'
        'on public.event_finals_eligible_snapshot from anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on public.event_finals_eligible_snapshot to authenticated;',
      ),
    );
    expect(sql, contains('add column if not exists finals_contest_id uuid'));
    expect(
      sql,
      contains(
        'create or replace function app_private.finals_session_matches_assignments(',
      ),
      reason: 'contest start needs the exact-seat helper before progression',
    );
    expect(
      sql,
      contains('and app_private.can_manage_event(target_event_id)'),
      reason: 'view access must not expose mutation actions to scorers',
    );

    for (final column in <String>[
      'id uuid primary key default gen_random_uuid()',
      'bonus_round_id uuid not null references public.event_bonus_rounds(id) on delete cascade',
      'event_id uuid not null references public.events(id) on delete cascade',
      'contest_type text not null',
      "status text not null default 'pending'",
      'parent_contest_id uuid references public.event_finals_contests(id) on delete restrict',
      'event_table_id uuid references public.event_tables(id) on delete restrict',
      'table_session_id uuid references public.table_sessions(id) on delete set null',
      'slots_to_fill integer not null default 0',
      'slot_start_index integer',
      'sequence_number integer not null',
      'created_by_user_id uuid references public.users(id) on delete set null',
      'created_at timestamptz not null default now()',
      'updated_at timestamptz not null default now()',
      'started_at timestamptz',
      'completed_at timestamptz',
    ]) {
      expect(sql, contains(column));
    }
    for (final column in <String>[
      'contest_id uuid not null references public.event_finals_contests(id) on delete cascade',
      'event_guest_id uuid not null references public.event_guests(id) on delete restrict',
      'entry_seed integer not null',
      'seat_index integer',
      "outcome text not null default 'pending'",
      'advanced_champions_slot integer',
      'outcome_order integer',
      'created_at timestamptz not null default now()',
      'primary key (contest_id, event_guest_id)',
      'unique (contest_id, seat_index)',
    ]) {
      expect(sql, contains(column));
    }
    for (final column in <String>[
      'bonus_round_id uuid not null references public.event_bonus_rounds(id) on delete cascade',
      'slot_index integer not null',
      'event_guest_id uuid references public.event_guests(id) on delete restrict',
      'qualification_method text',
      'source_contest_id uuid references public.event_finals_contests(id) on delete restrict',
      'source_finish_order integer',
      'created_at timestamptz not null default now()',
      'primary key (bonus_round_id, slot_index)',
      'unique (bonus_round_id, event_guest_id)',
    ]) {
      expect(sql, contains(column));
    }

    expect(sql, contains('event_bonus_rounds_flow_version_check'));
    expect(sql, contains("flow_version in ('legacy', 'orchestrated')"));
    expect(sql, contains('event_bonus_rounds_state_version_check'));
    expect(sql, contains('check (state_version >= 0)'));
    expect(sql, contains('event_bonus_rounds_eligible_player_count_check'));
    expect(
      sql,
      contains(
        'check (eligible_player_count is null or eligible_player_count >= 2)',
      ),
    );
    expect(sql, contains('event_bonus_rounds_format_check'));
    expect(
      sql,
      contains(
        "format in ('champions_only', 'automatic_redemption', 'redemption_advancement', 'parallel_finals')",
      ),
    );
    expect(sql, contains('event_bonus_rounds_status_check'));
    expect(sql, contains("status in ('active', 'completed', 'cancelled')"));
    expect(sql, contains('event_bonus_rounds_redemption_resolution_check'));
    expect(
      sql,
      contains(
        "redemption_resolution_method in ('standing_fifth', 'table_score', 'sudden_death')",
      ),
    );
    expect(
      sql,
      contains('event_bonus_rounds_redemption_winner_same_event_fk'),
    );
    expect(
      sql,
      contains(
        'foreign key (redemption_winner_event_guest_id, event_id)',
      ),
    );
    expect(sql, contains('event_finals_contests_bonus_round_same_event_fk'));
    expect(
      sql,
      contains(
        'foreign key (bonus_round_id, event_id)\n'
        '    references public.event_bonus_rounds(id, event_id)',
      ),
    );
    expect(sql, contains('event_finals_contests_table_same_event_fk'));
    expect(
      sql,
      contains(
        'foreign key (event_table_id, event_id)\n'
        '    references public.event_tables(id, event_id)',
      ),
    );
    expect(sql, contains('event_finals_contests_parent_same_event_fk'));
    expect(
      sql,
      contains(
        'foreign key (parent_contest_id, event_id)\n'
        '    references public.event_finals_contests(id, event_id)',
      ),
    );
    expect(
      sql,
      contains('event_seating_assignments_finals_contest_event_fk'),
    );
    expect(
      sql,
      contains(
        'foreign key (finals_contest_id, event_id)\n'
        'references public.event_finals_contests(id, event_id)\n'
        'on delete set null (finals_contest_id);',
      ),
    );
    expect(sql, contains('table_sessions_finals_contest_event_fk'));

    for (final scopeContract in <String>[
      'app_private.event_finals_contests_enforce_scope',
      'event_finals_contests_enforce_scope',
      'before insert or update of bonus_round_id, event_id, parent_contest_id, table_session_id',
      'app_private.event_finals_contest_participants_enforce_scope',
      'event_finals_contest_participants_enforce_scope',
      'app_private.event_finals_champions_slots_enforce_scope',
      'event_finals_champions_slots_enforce_scope',
      'Finals parent contest must belong to the same event.',
      'Finals parent contest must belong to the same Finals root.',
      'Finals contest session must belong to the same event.',
      'Finals contest participant must belong to the same event.',
      'Finals Champions slot guest must belong to the same event.',
      'Finals Champions slot source contest must belong to the same Finals root.',
    ]) {
      expect(sql, contains(scopeContract));
    }

    expect(sql, contains('event_finals_contests_contest_type_check'));
    for (final value in <String>[
      'direct_qualification_tiebreak',
      'table_of_redemption',
      'redemption_advancement_tiebreak',
      'redemption_winner_tiebreak',
      'table_of_champions',
      'champions_sudden_death',
    ]) {
      expect(sql, contains("'$value'"));
    }
    expect(sql, contains('event_finals_contests_status_check'));
    expect(
      sql,
      contains(
          "status in ('pending', 'ready', 'active', 'complete', 'cancelled')"),
    );
    expect(sql, contains('event_finals_contests_slots_to_fill_check'));
    expect(sql, contains('check (slots_to_fill >= 0)'));
    expect(sql, contains('event_finals_contests_slot_start_index_check'));
    expect(
      sql,
      contains(
        'check (slot_start_index is null or slot_start_index between 1 and 4)',
      ),
    );
    expect(sql, contains('event_finals_contests_sequence_number_check'));
    expect(sql, contains('check (sequence_number > 0)'));
    expect(sql, contains('event_finals_contests_id_event_unique'));
    expect(sql, contains('unique (id, event_id)'));
    expect(sql, contains('unique (bonus_round_id, sequence_number)'));
    expect(sql, contains('unique (table_session_id)'));
    expect(
      sql,
      contains('event_finals_contest_participants_entry_seed_check'),
    );
    expect(sql, contains('check (entry_seed > 0)'));
    expect(
      sql,
      contains('event_finals_contest_participants_seat_index_check'),
    );
    expect(
      sql,
      contains('check (seat_index is null or seat_index between 0 and 3)'),
    );
    expect(
      sql,
      contains('event_finals_contest_participants_outcome_check'),
    );
    expect(
      sql,
      contains(
        "outcome in ('pending', 'advanced', 'winner', 'runner_up', 'eliminated')",
      ),
    );
    expect(
      sql,
      contains('event_finals_contest_participants_advanced_slot_check'),
    );
    expect(
      sql,
      contains(
        'check (advanced_champions_slot is null or advanced_champions_slot between 1 and 4)',
      ),
    );
    expect(
      sql,
      contains('event_finals_contest_participants_outcome_order_check'),
    );
    expect(
      sql,
      contains('check (outcome_order is null or outcome_order > 0)'),
    );
    expect(sql, contains('event_finals_champions_slots_slot_index_check'));
    expect(sql, contains('check (slot_index between 1 and 4)'));
    expect(
      sql,
      contains('event_finals_champions_slots_qualification_method_check'),
    );
    expect(
      sql,
      contains(
        "qualification_method in ('direct_seed', 'redemption_finish', 'tiebreak_win')",
      ),
    );
    expect(
      sql,
      contains('event_finals_champions_slots_source_finish_order_check'),
    );
    expect(
      sql,
      contains(
          'check (source_finish_order is null or source_finish_order > 0)'),
    );

    expect(
      sql,
      contains(
        'create unique index event_finals_contests_current_step_idx\n'
        '  on public.event_finals_contests (\n'
        '    bonus_round_id,\n'
        '    contest_type,\n'
        '    coalesce(slot_start_index, 0)\n'
        '  )\n'
        "  where status in ('ready', 'active')",
      ),
    );
    expect(sql, contains("where status in ('ready', 'active')"));
    expect(
      sql,
      contains(
        'event_finals_contests_event_status_idx\n'
        '  on public.event_finals_contests (event_id, status, sequence_number)',
      ),
    );
    expect(
      sql,
      contains(
        'event_finals_contests_bonus_status_idx\n'
        '  on public.event_finals_contests (bonus_round_id, status, sequence_number)',
      ),
    );
    expect(
      sql,
      contains(
        'event_finals_contest_participants_guest_idx\n'
        '  on public.event_finals_contest_participants (event_guest_id, contest_id)',
      ),
    );
    expect(sql, contains('event_finals_champions_slots_guest_idx'));
    expect(
      sql,
      contains(
        'event_seating_assignments_finals_contest_idx\n'
        '  on public.event_seating_assignments (finals_contest_id, event_table_id, status)',
      ),
    );
    expect(
      sql,
      contains(
        'table_sessions_finals_contest_idx\n'
        '  on public.table_sessions (finals_contest_id, status)',
      ),
    );

    expect(sql, contains('event_finals_contests_touch_updated_at'));
    expect(sql, contains('execute function app_private.touch_updated_at();'));
    expect(
      sql,
      contains(
        'alter table public.event_finals_contests enable row level security;',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.event_finals_contest_participants enable row level security;',
      ),
    );
    expect(
      sql,
      contains(
        'alter table public.event_finals_champions_slots enable row level security;',
      ),
    );
    for (final policy in <String>[
      'create policy event_finals_contests_owner_or_staff_read',
      'create policy event_finals_contest_participants_owner_or_staff_read',
      'create policy event_finals_champions_slots_owner_or_staff_read',
    ]) {
      expect(sql, contains(policy));
    }
    for (final policy in <String>[
      'event_finals_contests_owner_manage',
      'event_finals_contest_participants_owner_manage',
      'event_finals_champions_slots_owner_manage',
    ]) {
      expect(
        sql,
        isNot(contains(policy)),
        reason: 'Finals state writes must be confined to server commands',
      );
    }
    expect(sql, contains('using (app_private.can_view_event(event_id))'));
    expect(
      sql,
      contains(
        'where contest.id = event_finals_contest_participants.contest_id\n'
        '      and app_private.can_view_event(contest.event_id)',
      ),
    );
    expect(
      sql,
      contains(
        'where bonus_round.id = event_finals_champions_slots.bonus_round_id\n'
        '      and app_private.can_view_event(bonus_round.event_id)',
      ),
    );
    expect(
      sql,
      contains(
        'revoke insert, update, delete, truncate, references, trigger\n'
        'on public.event_finals_contests,\n'
        '  public.event_finals_contest_participants,\n'
        '  public.event_finals_champions_slots\n'
        'from anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on public.event_finals_contests,\n'
        '  public.event_finals_contest_participants,\n'
        '  public.event_finals_champions_slots\n'
        'to authenticated;',
      ),
    );

    expect(
      sql,
      contains(
        'create or replace function app_private.finals_format_for_count(\n'
        '  eligible_count integer\n'
        ')\n'
        'returns text',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function app_private.finals_direct_slot_count(\n'
        '  eligible_count integer\n'
        ')\n'
        'returns integer',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function app_private.finals_standings_snapshot(\n'
        '  target_event_id uuid\n'
        ')\n'
        'returns table (',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function public.preview_event_finals(\n'
        '  target_event_id uuid\n'
        ')\n'
        'returns jsonb\n'
        'language plpgsql\n'
        'stable\n'
        'security definer\n'
        'set search_path = public',
      ),
    );
    expect(
      sql,
      contains(
        'create or replace function public.get_event_finals_state(\n'
        '  target_event_id uuid\n'
        ')\n'
        'returns jsonb\n'
        'language plpgsql\n'
        'stable\n'
        'security definer\n'
        'set search_path = public',
      ),
    );
    expect(sql,
        contains('app_private.finals_standings_snapshot(target_event_id)'));

    for (final key in <String>[
      'eligible_player_count',
      'preview_token',
      'format',
      'direct_slots',
      'redemption_players',
      'cutoff_tie_players',
      'requires_champions_table',
      'requires_redemption_table',
      'order_copy',
      'available_table_ids',
      'flow_version',
      'state_version',
      'overall_status',
      'champions_slots',
      'contests',
      'allowed_actions',
      'blocking_reason',
      'champion',
      'redemption_winner',
    ]) {
      expect(sql, contains("'$key'"));
    }
    expect(sql, contains("tag.default_tag_type = 'table'"));
    expect(sql, contains("tag.status = 'active'"));
    expect(sql, contains("session.status in ('active', 'paused')"));

    expect(
      sql,
      contains(
        'grant execute on function public.preview_event_finals(uuid) to authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.get_event_finals_state(uuid) to authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function app_private.finals_standings_snapshot(uuid) from public;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function app_private.finals_format_for_count(integer) from public;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function app_private.finals_direct_slot_count(integer) from public;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.preview_event_finals(uuid) from public;',
      ),
    );
    expect(
      sql,
      contains(
        'revoke all on function public.get_event_finals_state(uuid) from public;',
      ),
    );
    for (final triggerFunction in <String>[
      'event_finals_contests_enforce_scope()',
      'event_finals_contest_participants_enforce_scope()',
      'event_finals_champions_slots_enforce_scope()',
    ]) {
      expect(
        sql,
        contains(
          'revoke all on function app_private.$triggerFunction from public;',
        ),
      );
    }
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
