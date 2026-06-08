-- Fix live DB lint errors in current scoring and tournament round session RPCs.

create or replace function app_private.validate_hand_result_input(
  target_ruleset_id text,
  target_result_type text,
  target_winner_seat_index integer,
  target_win_type text,
  target_discarder_seat_index integer,
  target_fan_count integer,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns void
language plpgsql
stable
as $$
declare
  minimum_fan integer;
begin
  if target_result_type not in ('win', 'washout', 'false_win_penalty') then
    raise exception 'Hand result type must be win, washout, or false_win_penalty.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'washout' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null
      or target_penalty_seat_index is not null
      or target_fan_count is not null then
      raise exception 'Draw hands cannot include winner, win type, discarder, penalty caller, or fan count.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_dealer_was_waiting_at_draw is not null then
    raise exception 'Only draw hands can include dealer waiting state.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'false_win_penalty' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null then
      raise exception 'False win penalties cannot include winner, win type, or discarder.'
        using errcode = 'P0001';
    end if;

    if target_penalty_seat_index is null
      or target_penalty_seat_index not between 0 and 3 then
      raise exception 'False win penalties require a valid caller seat.'
        using errcode = 'P0001';
    end if;

    if target_fan_count is not null and target_fan_count <> 6 then
      raise exception 'False win penalties are fixed at 6 fan.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_penalty_seat_index is not null then
    raise exception 'Win hands cannot include a false win caller.'
      using errcode = 'P0001';
  end if;

  if target_winner_seat_index is null
    or target_winner_seat_index not between 0 and 3 then
    raise exception 'Win hands require a valid winner seat.'
      using errcode = 'P0001';
  end if;

  if target_win_type not in ('discard', 'self_draw') then
    raise exception 'Win hands require a win type of discard or self_draw.'
      using errcode = 'P0001';
  end if;

  if target_win_type = 'discard' then
    if target_discarder_seat_index is null
      or target_discarder_seat_index not between 0 and 3 then
      raise exception 'Discard wins require a valid discarder seat.'
        using errcode = 'P0001';
    end if;

    if target_discarder_seat_index = target_winner_seat_index then
      raise exception 'Discarder must be different from winner.'
        using errcode = 'P0001';
    end if;
  else
    if target_discarder_seat_index is not null then
      raise exception 'Self-draw wins cannot include a discarder.'
        using errcode = 'P0001';
    end if;
  end if;

  minimum_fan := app_private.ruleset_minimum_winning_fan(target_ruleset_id);
  if target_fan_count is null or target_fan_count < minimum_fan then
    raise exception 'Fan count must be at least %.', minimum_fan
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function app_private.refresh_event_score_totals(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.event_score_totals
  where event_id = target_event_id;

  insert into public.event_score_totals (
    event_id,
    event_guest_id,
    total_points,
    hands_played,
    hands_won,
    self_draw_wins,
    discard_wins,
    discard_losses,
    sessions_started,
    sessions_completed
  )
  with guest_base as (
    select
      guest.id as event_guest_id,
      guest.event_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
  ),
  points_totals as (
    select
      guest_base.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0) as total_points
    from guest_base
    left join public.hand_settlements as settlement
      on settlement.payee_event_guest_id = guest_base.event_guest_id
      or settlement.payer_event_guest_id = guest_base.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.id = settlement.hand_result_id
    left join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where settlement.id is null
      or (
        session.event_id = target_event_id
        and session.scoring_phase = 'tournament'
      )
    group by guest_base.event_guest_id
  ),
  adjustment_totals as (
    select
      adjustment.event_guest_id,
      sum(adjustment.amount_points)::integer as total_points
    from public.event_score_adjustments as adjustment
    where adjustment.event_id = target_event_id
      and adjustment.adjustment_type = 'finals_champion_award'
    group by adjustment.event_guest_id
  ),
  hand_play_totals as (
    select
      seat.event_guest_id,
      count(hand_result.id) as hands_played
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  hand_result_totals as (
    select
      seat.event_guest_id,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index) as hands_won,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw') as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard') as discard_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.win_type = 'discard' and hand_result.discarder_seat_index = seat.seat_index) as discard_losses
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  session_counts as (
    select
      seat.event_guest_id,
      count(distinct session.id) as sessions_started,
      count(distinct session.id) filter (where session.status = 'completed') as sessions_completed
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
    group by seat.event_guest_id
  )
  select
    target_event_id,
    guest_base.event_guest_id,
    coalesce(points_totals.total_points, 0)
      + coalesce(adjustment_totals.total_points, 0),
    coalesce(hand_play_totals.hands_played, 0),
    coalesce(hand_result_totals.hands_won, 0),
    coalesce(hand_result_totals.self_draw_wins, 0),
    coalesce(hand_result_totals.discard_wins, 0),
    coalesce(hand_result_totals.discard_losses, 0),
    coalesce(session_counts.sessions_started, 0),
    coalesce(session_counts.sessions_completed, 0)
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join adjustment_totals
    on adjustment_totals.event_guest_id = guest_base.event_guest_id
  left join hand_play_totals
    on hand_play_totals.event_guest_id = guest_base.event_guest_id
  left join hand_result_totals
    on hand_result_totals.event_guest_id = guest_base.event_guest_id
  left join session_counts
    on session_counts.event_guest_id = guest_base.event_guest_id;

  perform app_private.refresh_public_event_standings_snapshot(target_event_id);
end;
$$;

create or replace function public.start_current_tournament_round_sessions(
  target_event_id uuid
)
returns setof public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  current_round public.event_tournament_rounds%rowtype;
  table_row public.event_tables%rowtype;
  next_session_number integer;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  assignment_rows public.event_seating_assignments[];
  initial_winds text[] := array['east', 'south', 'west', 'north'];
  subscript_index integer;
  bulk_started_at timestamptz := now();
begin
  perform app_private.require_event_for_phase_scoring(target_event_id, 'tournament');

  select *
  into event_row
  from public.events as event
  where event.id = target_event_id
    and event.lifecycle_status = 'active'
    and event.current_scoring_phase = 'tournament';

  if event_row.id is null then
    raise exception 'Event must be active and in tournament scoring phase.'
      using errcode = 'P0001';
  end if;

  select *
  into current_round
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament'
    and tournament_round.status in ('seating', 'active')
  order by tournament_round.round_number desc, tournament_round.created_at desc
  limit 1
  for update;

  if current_round.id is null then
    raise exception 'No current tournament round is ready to start.'
      using errcode = 'P0001';
  end if;

  if not (current_round.status in ('seating', 'active')) then
    raise exception 'Current tournament round is not ready to start.'
      using errcode = 'P0001';
  end if;

  for table_row in
    select table_candidate.*
    from public.event_tables as table_candidate
    where table_candidate.event_id = target_event_id
      and exists (
        select 1
        from public.event_seating_assignments as assignment
        where assignment.event_table_id = table_candidate.id
          and assignment.event_id = table_candidate.event_id
          and assignment.status = 'active'
          and assignment.assignment_type = 'random'
          and assignment.tournament_round_id = current_round.id
          and assignment.assignment_round = current_round.assignment_round
      )
      and not exists (
        select 1
        from public.table_sessions as existing_session
        where existing_session.event_table_id = table_candidate.id
          and existing_session.status in ('active', 'paused')
      )
    order by table_candidate.display_order asc,
      table_candidate.label asc,
      table_candidate.id asc
  loop
    if exists (
      select 1
      from public.table_sessions as existing_session
      where existing_session.event_table_id = table_row.id
        and existing_session.status in ('active', 'paused')
    ) then
      continue;
    end if;

    select array_agg(assignment order by assignment.seat_index asc)
    into assignment_rows
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.event_table_id = table_row.id
      and assignment.status = 'active';

    if assignment_rows is null
      or not (array_length(assignment_rows, 1) between 2 and 4)
    then
      raise exception 'Two to four active current-round seating assignments are required to start each tournament table.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from generate_subscripts(assignment_rows, 1) as generated_index
      where assignment_rows[generated_index].seat_index <> generated_index - 1
    ) then
      raise exception 'Assigned seating must fill seats contiguously from East.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type is distinct from 'random'
        or assignment.tournament_round_id is distinct from current_round.id
        or assignment.assignment_round is distinct from current_round.assignment_round
    ) then
      raise exception 'All active assignments must belong to the current tournament round.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.event_guests as guest
      where guest.id = any (
          select assignment.event_guest_id
          from unnest(assignment_rows) as assignment
        )
        and guest.attendance_status <> 'checked_in'
    ) then
      raise exception 'All assigned session players must be checked in.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      join public.table_session_seats as seat
        on seat.event_guest_id = assignment.event_guest_id
      join public.table_sessions as existing_session
        on existing_session.id = seat.table_session_id
      where existing_session.event_id = target_event_id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'An assigned guest is already seated in another active session.'
        using errcode = 'P0001';
    end if;

    select *
    into ruleset_row
    from public.rulesets
    where id = table_row.default_ruleset_id;

    if not found then
      raise exception 'Default ruleset not found for a tournament table.'
        using errcode = 'P0001';
    end if;

    select coalesce(max(session_number_for_table), 0) + 1
    into next_session_number
    from public.table_sessions
    where event_table_id = table_row.id;

    insert into public.table_sessions (
      event_id,
      event_table_id,
      session_number_for_table,
      ruleset_id,
      rotation_policy_type,
      rotation_policy_config_json,
      status,
      initial_east_seat_index,
      current_dealer_seat_index,
      dealer_pass_count,
      completed_games_count,
      hand_count,
      scoring_phase,
      tournament_round_id,
      assignment_round,
      started_at,
      started_by_user_id
    )
    values (
      target_event_id,
      table_row.id,
      next_session_number,
      table_row.default_ruleset_id,
      table_row.default_rotation_policy_type,
      table_row.default_rotation_policy_config_json,
      'active',
      0,
      0,
      0,
      0,
      0,
      'tournament',
      current_round.id,
      current_round.assignment_round,
      bulk_started_at,
      auth.uid()
    )
    returning *
    into session_row;

    for subscript_index in 1..array_length(assignment_rows, 1) loop
      insert into public.table_session_seats (
        table_session_id,
        seat_index,
        initial_wind,
        event_guest_id
      )
      values (
        session_row.id,
        assignment_rows[subscript_index].seat_index,
        initial_winds[assignment_rows[subscript_index].seat_index + 1],
        assignment_rows[subscript_index].event_guest_id
      );
    end loop;

    return next session_row;
  end loop;

  if exists (
    select 1
    from public.table_sessions as started_session
    where started_session.event_id = target_event_id
      and started_session.tournament_round_id = current_round.id
      and started_session.scoring_phase = 'tournament'
  ) then
    update public.event_tournament_rounds
    set
      status = 'active',
      started_at = coalesce(started_at, bulk_started_at)
    where id = current_round.id;
  end if;

  return;
end;
$$;

grant execute on function public.start_current_tournament_round_sessions(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
