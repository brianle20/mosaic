-- Start assigned tournament tables from generated seating without scanning player tags.

create or replace function public.start_assigned_table_session(
  target_event_table_id uuid,
  scanned_table_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  event_row public.events%rowtype;
  bound_tag_uid text;
  normalized_table_uid text;
  next_session_number integer;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  assignment_row public.event_seating_assignments%rowtype;
  effective_scoring_phase text;
  initial_winds text[] := array['east', 'south', 'west', 'north'];
begin
  table_row := app_private.require_owned_table(target_event_table_id);
  perform app_private.require_event_for_scoring(table_row.event_id);

  select *
  into event_row
  from public.events
  where id = table_row.event_id;

  effective_scoring_phase := coalesce(event_row.current_scoring_phase, 'qualification');

  if table_row.nfc_tag_id is null then
    raise exception 'A bound table tag is required before starting a session.'
      using errcode = 'P0001';
  end if;

  normalized_table_uid := app_private.normalize_tag_uid(scanned_table_uid);

  select uid_hex
  into bound_tag_uid
  from public.nfc_tags
  where id = table_row.nfc_tag_id
    and owner_user_id = auth.uid();

  if bound_tag_uid is null or bound_tag_uid <> normalized_table_uid then
    raise exception 'The scanned table tag does not match the selected table.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'This table already has an active session.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_id = table_row.event_id
      and assignment.event_table_id = table_row.id
      and assignment.status = 'active'
    group by assignment.event_table_id
    having count(*) = 4
  ) then
    raise exception 'Four active seating assignments are required to start this assigned table.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_seating_assignments as assignment
    join public.event_guests as guest
      on guest.id = assignment.event_guest_id
    where assignment.event_id = table_row.event_id
      and assignment.event_table_id = table_row.id
      and assignment.status = 'active'
      and guest.attendance_status <> 'checked_in'
  ) then
    raise exception 'All assigned session players must be checked in.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_seating_assignments as assignment
    join public.table_session_seats as seat
      on seat.event_guest_id = assignment.event_guest_id
    join public.table_sessions as existing_session
      on existing_session.id = seat.table_session_id
    where assignment.event_id = table_row.event_id
      and assignment.event_table_id = table_row.id
      and assignment.status = 'active'
      and existing_session.event_id = table_row.event_id
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
    raise exception 'Default ruleset not found for the selected table.'
      using errcode = 'P0001';
  end if;

  select assignment.*
  into assignment_row
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.status = 'active'
  order by assignment.assignment_type = 'bonus' desc, assignment.seat_index asc
  limit 1;

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
    started_at,
    started_by_user_id
  )
  values (
    table_row.event_id,
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
    case when assignment_row.assignment_type = 'bonus' then 'bonus' else effective_scoring_phase end,
    assignment_row.bonus_round_id,
    assignment_row.bonus_table_role,
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  insert into public.table_session_seats (
    table_session_id,
    seat_index,
    initial_wind,
    event_guest_id
  )
  select
    session_row.id,
    assignment.seat_index,
    initial_winds[assignment.seat_index + 1],
    assignment.event_guest_id
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.status = 'active'
  order by assignment.seat_index asc;

  return session_row;
end;
$$;

grant execute on function public.start_assigned_table_session(uuid, text)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
