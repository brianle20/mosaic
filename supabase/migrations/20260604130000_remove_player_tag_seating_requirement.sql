-- Bias tournament round seating against repeated opponents while preserving random assignment.

create or replace function public.generate_tournament_round(
  target_event_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  event_table_id uuid,
  table_label text,
  table_display_order integer,
  event_guest_id uuid,
  guest_display_name text,
  seat_index integer,
  assignment_round integer,
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz,
  tournament_round_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  player_count integer;
  ready_table_count integer;
  table_sizes integer[];
  required_table_count integer;
  table_size_count integer;
  next_assignment_round integer;
  next_round_number integer;
  tournament_round_row public.event_tournament_rounds%rowtype;
  round_generation_status text := 'not_started';
  candidate_count integer := 500;
  exact_group_repeat_penalty integer := 10000;
  immediate_pair_repeat_penalty integer := 1000;
  older_pair_repeat_penalty integer := 100;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select *
  into event_row
  from public.events as event
  where event.id = target_event_id
    and event.lifecycle_status = 'active'
    and event.current_scoring_phase = 'tournament';

  if event_row.id is null then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_tournament_rounds as previous_round
    join public.event_seating_assignments as assignment
      on assignment.event_id = previous_round.event_id
      and assignment.tournament_round_id = previous_round.id
      and assignment.status = 'active'
    where previous_round.event_id = target_event_id
      and previous_round.scoring_phase = 'tournament'
      and previous_round.status in ('seating', 'active')
      and (
        exists (
          select 1
          from public.table_sessions as session
          where session.event_id = assignment.event_id
            and session.event_table_id = assignment.event_table_id
            and session.tournament_round_id = previous_round.id
            and session.status in ('active', 'paused')
        )
        or not exists (
          select 1
          from public.table_sessions as completed_session
          where completed_session.event_id = assignment.event_id
            and completed_session.event_table_id = assignment.event_table_id
            and completed_session.tournament_round_id = previous_round.id
            and completed_session.status in ('completed', 'ended_early', 'aborted')
        )
      )
  ) then
    raise exception 'Complete active tournament round sessions before starting the next round.'
      using errcode = 'P0001';
  end if;

  with eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  )
  select count(*)::integer
  into player_count
  from eligible_players;

  if player_count < 2 then
    raise exception 'At least 2 qualified, checked-in players are required.'
      using errcode = 'P0001';
  end if;

  table_sizes := app_private.balanced_table_sizes(player_count);
  required_table_count := cardinality(table_sizes);
  table_size_count := array_length(table_sizes, 1);

  if required_table_count <> table_size_count then
    raise exception 'Unable to calculate balanced tournament table sizes.'
      using errcode = 'P0001';
  end if;

  with ready_tables as (
    select event_table.id
    from public.event_tables as event_table
    join public.nfc_tags as table_nfc
      on table_nfc.id = event_table.nfc_tag_id
      and table_nfc.default_tag_type = 'table'
      and table_nfc.status = 'active'
    where event_table.event_id = target_event_id
  )
  select count(*)::integer
  into ready_table_count
  from ready_tables;

  if ready_table_count < required_table_count then
    raise exception 'Add or tag more tables before starting this round.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  select coalesce(max(tournament_round.round_number), 0) + 1
  into next_round_number
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament';

  round_generation_status := 'started';

  update public.event_tournament_rounds as previous_round
  set
    status = 'complete',
    completed_at = coalesce(previous_round.completed_at, now())
  where previous_round.event_id = target_event_id
    and previous_round.scoring_phase = 'tournament'
    and previous_round.status in ('seating', 'active');

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active'
    and assignment.assignment_type = 'random';

  insert into public.event_tournament_rounds (
    event_id,
    round_number,
    scoring_phase,
    status,
    assignment_round,
    started_at,
    created_by_user_id
  )
  values (
    target_event_id,
    next_round_number,
    'tournament',
    'seating',
    next_assignment_round,
    now(),
    auth.uid()
  )
  returning *
  into tournament_round_row;

  with table_plan as (
    select
      table_index as table_number,
      table_sizes[table_index] as table_size
    from generate_subscripts(table_sizes, 1) as table_index
  ),
  table_ranges as (
    select
      table_plan.table_number,
      table_plan.table_size,
      coalesce(
        sum(table_plan.table_size) over (
          order by table_plan.table_number
          rows between unbounded preceding and 1 preceding
        ),
        0
      )::integer as start_offset
    from table_plan
  ),
  ready_tables as (
    select
      event_table.id as event_table_id,
      row_number() over (order by event_table.display_order, event_table.id)::integer
        as table_number
    from public.event_tables as event_table
    join public.nfc_tags as table_nfc
      on table_nfc.id = event_table.nfc_tag_id
      and table_nfc.default_tag_type = 'table'
      and table_nfc.status = 'active'
    where event_table.event_id = target_event_id
    order by event_table.display_order, event_table.id
    limit required_table_count
  ),
  eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  ),
  candidates as (
    select
      candidate_number,
      random() as tie_breaker
    from generate_series(1, candidate_count) as candidate_number
  ),
  candidate_players as (
    select
      candidates.candidate_number,
      eligible_players.event_guest_id,
      row_number() over (
        partition by candidates.candidate_number
        order by random(), eligible_players.event_guest_id
      )::integer - 1 as player_offset
    from candidates
    cross join eligible_players
  ),
  candidate_assignments as (
    select
      candidate_players.candidate_number,
      ready_tables.event_table_id,
      table_ranges.table_number,
      candidate_players.event_guest_id,
      (candidate_players.player_offset - table_ranges.start_offset)::integer
        as seat_index
    from candidate_players
    join table_ranges
      on candidate_players.player_offset >= table_ranges.start_offset
      and candidate_players.player_offset
        < table_ranges.start_offset + table_ranges.table_size
    join ready_tables
      on ready_tables.table_number = table_ranges.table_number
  ),
  historical_assignments as (
    select
      tournament_round.round_number,
      assignment.event_table_id,
      assignment.event_guest_id,
      tournament_round.round_number = next_round_number - 1
        as is_immediate_previous
    from public.event_seating_assignments as assignment
    join public.event_tournament_rounds as tournament_round
      on tournament_round.id = assignment.tournament_round_id
      and tournament_round.event_id = assignment.event_id
    where assignment.event_id = target_event_id
      and assignment.assignment_type = 'random'
      and assignment.tournament_round_id is not null
      and tournament_round.scoring_phase = 'tournament'
      and tournament_round.id <> tournament_round_row.id
  ),
  historical_pairs as (
    select
      least(left_assignment.event_guest_id, right_assignment.event_guest_id)
        as guest_a_id,
      greatest(left_assignment.event_guest_id, right_assignment.event_guest_id)
        as guest_b_id,
      bool_or(left_assignment.is_immediate_previous)
        as has_immediate_previous_repeat,
      count(*) filter (
        where not left_assignment.is_immediate_previous
      )::integer as older_repeat_count
    from historical_assignments as left_assignment
    join historical_assignments as right_assignment
      on right_assignment.round_number = left_assignment.round_number
      and right_assignment.event_table_id = left_assignment.event_table_id
      and right_assignment.event_guest_id > left_assignment.event_guest_id
    group by guest_a_id, guest_b_id
  ),
  candidate_pairs as (
    select
      left_assignment.candidate_number,
      least(left_assignment.event_guest_id, right_assignment.event_guest_id)
        as guest_a_id,
      greatest(left_assignment.event_guest_id, right_assignment.event_guest_id)
        as guest_b_id
    from candidate_assignments as left_assignment
    join candidate_assignments as right_assignment
      on right_assignment.candidate_number = left_assignment.candidate_number
      and right_assignment.table_number = left_assignment.table_number
      and right_assignment.event_guest_id > left_assignment.event_guest_id
  ),
  previous_round_table_groups as (
    select
      array_agg(
        historical_assignments.event_guest_id
        order by historical_assignments.event_guest_id
      ) as player_group
    from historical_assignments
    where historical_assignments.round_number = next_round_number - 1
    group by historical_assignments.event_table_id
  ),
  candidate_table_groups as (
    select
      candidate_assignments.candidate_number,
      candidate_assignments.table_number,
      array_agg(
        candidate_assignments.event_guest_id
        order by candidate_assignments.event_guest_id
      ) as player_group
    from candidate_assignments
    group by
      candidate_assignments.candidate_number,
      candidate_assignments.table_number
  ),
  group_penalties as (
    select
      candidate_table_groups.candidate_number,
      (count(*)::integer * exact_group_repeat_penalty)::integer
        as group_penalty
    from candidate_table_groups
    join previous_round_table_groups
      on previous_round_table_groups.player_group
        = candidate_table_groups.player_group
    group by candidate_table_groups.candidate_number
  ),
  pair_penalties as (
    select
      candidate_pairs.candidate_number,
      sum(
        case
          when historical_pairs.has_immediate_previous_repeat
            then immediate_pair_repeat_penalty
          else 0
        end
        + historical_pairs.older_repeat_count * older_pair_repeat_penalty
      )::integer as pair_penalty
    from candidate_pairs
    join historical_pairs
      on historical_pairs.guest_a_id = candidate_pairs.guest_a_id
      and historical_pairs.guest_b_id = candidate_pairs.guest_b_id
    group by candidate_pairs.candidate_number
  ),
  candidate_score as (
    select
      candidates.candidate_number,
      candidates.tie_breaker,
      (
        coalesce(group_penalties.group_penalty, 0)
        + coalesce(pair_penalties.pair_penalty, 0)
      )::integer as total_penalty
    from candidates
    left join group_penalties
      on group_penalties.candidate_number = candidates.candidate_number
    left join pair_penalties
      on pair_penalties.candidate_number = candidates.candidate_number
  ),
  selected_candidate as (
    select candidate_score.candidate_number
    from candidate_score
    order by candidate_score.total_penalty asc, candidate_score.tie_breaker asc
    limit 1
  ),
  selected_assignments as (
    select candidate_assignments.*
    from candidate_assignments
    join selected_candidate
      on selected_candidate.candidate_number
        = candidate_assignments.candidate_number
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    assignment_type,
    status,
    assigned_at,
    assigned_by_user_id,
    tournament_round_id
  )
  select
    target_event_id,
    selected_assignments.event_table_id,
    selected_assignments.event_guest_id,
    selected_assignments.seat_index,
    next_assignment_round,
    'random',
    'active',
    now(),
    auth.uid(),
    tournament_round_row.id
  from selected_assignments;

  return query
  select
    assignment.id,
    assignment.event_id,
    assignment.event_table_id,
    event_table.label as table_label,
    event_table.display_order as table_display_order,
    assignment.event_guest_id,
    guest.display_name as guest_display_name,
    assignment.seat_index,
    assignment.assignment_round,
    assignment.assignment_type,
    assignment.bonus_round_id,
    assignment.bonus_table_role,
    assignment.seed_rank,
    assignment.status,
    assignment.assigned_at,
    assignment.assigned_by_user_id,
    assignment.created_at,
    assignment.updated_at,
    assignment.tournament_round_id
  from public.event_seating_assignments as assignment
  join public.event_tables as event_table
    on event_table.id = assignment.event_table_id
  join public.event_guests as guest
    on guest.id = assignment.event_guest_id
  where assignment.event_id = target_event_id
    and assignment.status = 'active'
    and assignment.tournament_round_id = tournament_round_row.id
    and app_private.is_event_owner(assignment.event_id)
  order by event_table.display_order asc, assignment.seat_index asc;
end;
$$;

grant execute on function public.generate_tournament_round(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
