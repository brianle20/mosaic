create or replace function public.start_bonus_assigned_table_sessions(
  target_event_id uuid,
  target_bonus_table_role text
)
returns setof public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  table_row public.event_tables%rowtype;
  next_session_number integer;
  session_row public.table_sessions%rowtype;
  assignment_rows public.event_seating_assignments[];
  initial_winds text[] := array['east', 'south', 'west', 'north'];
  assignment_index integer;
  bulk_started_at timestamptz := now();
begin
  perform app_private.require_event_for_phase_scoring(target_event_id, 'bonus');

  select *
  into event_row
  from public.events as event
  where event.id = target_event_id
    and event.lifecycle_status = 'active'
    and event.current_scoring_phase = 'bonus';

  if event_row.id is null then
    raise exception 'Event must be active and in bonus scoring phase.'
      using errcode = 'P0001';
  end if;

  if target_bonus_table_role is not null
    and target_bonus_table_role not in (
    'table_of_champions',
    'table_of_redemption',
    'table_of_champions_sudden_death',
    'table_of_champions_play_in'
  ) then
    raise exception 'Unsupported bonus table role.'
      using errcode = 'P0001';
  end if;

  if target_bonus_table_role is null
    and exists (
      select 1
      from public.event_seating_assignments as assignment
      where assignment.event_id = target_event_id
        and assignment.status = 'active'
        and assignment.assignment_type = 'bonus'
        and (
          assignment.bonus_table_role is null
          or assignment.bonus_table_role not in (
            'table_of_champions',
            'table_of_redemption'
          )
        )
    )
  then
    raise exception 'Standard finals seating cannot include sudden death or play-in assignments.'
      using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(target_event_id::text || ':bonus-assigned-table-start', 0)
  );

  if not exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.status = 'active'
      and assignment.assignment_type = 'bonus'
      and (
        (
          target_bonus_table_role is null
          and assignment.bonus_table_role in (
            'table_of_champions',
            'table_of_redemption'
          )
        )
        or (
          target_bonus_table_role is not null
          and assignment.bonus_table_role = target_bonus_table_role
        )
      )
  ) then
    raise exception 'No active bonus seating assignments exist for this table role.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_tables as table_candidate
    join public.table_sessions as existing_session
      on existing_session.event_table_id = table_candidate.id
    where existing_session.event_table_id = table_candidate.id
        and existing_session.status in ('active', 'paused')
      and table_candidate.event_id = target_event_id
      and exists (
        select 1
        from public.event_seating_assignments as assignment
        where assignment.event_table_id = table_candidate.id
          and assignment.event_id = table_candidate.event_id
          and assignment.status = 'active'
          and assignment.assignment_type = 'bonus'
          and (
            (
              target_bonus_table_role is null
              and assignment.bonus_table_role in (
                'table_of_champions',
                'table_of_redemption'
              )
            )
            or (
              target_bonus_table_role is not null
              and assignment.bonus_table_role = target_bonus_table_role
            )
          )
      )
  ) then
    raise exception 'A scoped bonus table already has an active session.'
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
          and assignment.assignment_type = 'bonus'
          and (
            (
              target_bonus_table_role is null
              and assignment.bonus_table_role in (
                'table_of_champions',
                'table_of_redemption'
              )
            )
            or (
              target_bonus_table_role is not null
              and assignment.bonus_table_role = target_bonus_table_role
            )
          )
      )
    order by table_candidate.display_order asc,
      table_candidate.label asc,
      table_candidate.id asc
    for update of table_candidate
  loop
    if exists (
      select 1
      from public.table_sessions as existing_session
      where existing_session.event_table_id = table_row.id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'A scoped bonus table already has an active session.'
        using errcode = 'P0001';
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
      raise exception 'Two to four active scoped bonus seating assignments are required to start each table.'
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
      where assignment.assignment_type is distinct from 'bonus'
        or assignment.bonus_round_id is null
        or assignment.bonus_round_id is distinct from assignment_rows[1].bonus_round_id
        or assignment.bonus_table_role is null
        or assignment.bonus_table_role is distinct from assignment_rows[1].bonus_table_role
        or (target_bonus_table_role is null
          and assignment.bonus_table_role not in (
            'table_of_champions',
            'table_of_redemption'
          )
        )
        or (target_bonus_table_role is not null
          and assignment.bonus_table_role is distinct from target_bonus_table_role
        )
        or assignment.tournament_round_id is distinct from assignment_rows[1].tournament_round_id
        or assignment.assignment_round is distinct from assignment_rows[1].assignment_round
    ) then
      raise exception 'All scoped bonus assignments must share metadata.'
        using errcode = 'P0001';
    end if;

    perform 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.id = assignment_rows[1].bonus_round_id
      and bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
    for update;

    if not found then
      raise exception 'Active bonus round not found for this seating.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.table_sessions as existing_session
      where existing_session.event_table_id = table_row.id
        and existing_session.scoring_phase = 'bonus'
        and existing_session.bonus_round_id = assignment_rows[1].bonus_round_id
        and existing_session.bonus_table_role = assignment_rows[1].bonus_table_role
    ) then
      raise exception 'This bonus table has already been started for this seating.'
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

    if not exists (
      select 1
      from public.rulesets
      where id = table_row.default_ruleset_id
    ) then
      raise exception 'Default ruleset not found for a bonus table.'
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
      bonus_round_id,
      bonus_table_role,
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
      'bonus',
      assignment_rows[1].bonus_round_id,
      assignment_rows[1].bonus_table_role,
      assignment_rows[1].tournament_round_id,
      assignment_rows[1].assignment_round,
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

  return;
end;
$$;

revoke all on function public.start_bonus_assigned_table_sessions(uuid, text)
  from public;
revoke all on function public.start_bonus_assigned_table_sessions(uuid, text)
  from anon;
grant execute on function public.start_bonus_assigned_table_sessions(uuid, text) to authenticated;

select pg_notify('pgrst', 'reload schema');
