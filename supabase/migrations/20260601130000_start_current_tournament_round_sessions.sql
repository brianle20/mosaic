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
  assignment_index integer;
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
      from generate_subscripts(assignment_rows, 1) as assignment_index
      where assignment_rows[assignment_index].seat_index <> assignment_index - 1
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

    for assignment_index in 1..array_length(assignment_rows, 1) loop
      insert into public.table_session_seats (
        table_session_id,
        seat_index,
        initial_wind,
        event_guest_id
      )
      values (
        session_row.id,
        assignment_rows[assignment_index].seat_index,
        initial_winds[assignment_rows[assignment_index].seat_index + 1],
        assignment_rows[assignment_index].event_guest_id
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
