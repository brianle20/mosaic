-- Random tournament seating assignments
-- Checklist:
--   [x] add event seating mode
--   [x] add event seating assignment table
--   [x] add random assignment management RPCs
--   [x] enforce random seating during session start

alter table public.events
add column if not exists seating_mode text;

update public.events
set seating_mode = 'manual'
where seating_mode is null;

alter table public.events
alter column seating_mode set default 'random';

alter table public.events
alter column seating_mode set not null;

alter table public.events
drop constraint if exists events_seating_mode_check;

alter table public.events
add constraint events_seating_mode_check
check (seating_mode in ('random', 'manual'));

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.event_tables'::regclass
      and conname = 'event_tables_id_event_id_unique'
  ) then
    alter table public.event_tables
    add constraint event_tables_id_event_id_unique
    unique (id, event_id);
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.event_guests'::regclass
      and conname = 'event_guests_id_event_id_unique'
  ) then
    alter table public.event_guests
    add constraint event_guests_id_event_id_unique
    unique (id, event_id);
  end if;
end;
$$;

create table public.event_seating_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_table_id uuid not null references public.event_tables(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  seat_index integer not null check (seat_index between 0 and 3),
  assignment_round integer not null default 1 check (assignment_round > 0),
  status text not null default 'active'
    check (status in ('active', 'cleared', 'seated')),
  assigned_at timestamptz not null default now(),
  assigned_by_user_id uuid references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (event_id, assignment_round, event_guest_id),
  unique (event_id, assignment_round, event_table_id, seat_index),
  constraint event_seating_assignments_table_same_event_fk
    foreign key (event_table_id, event_id)
    references public.event_tables (id, event_id)
    on delete cascade,
  constraint event_seating_assignments_guest_same_event_fk
    foreign key (event_guest_id, event_id)
    references public.event_guests (id, event_id)
    on delete cascade
);

create index event_seating_assignments_event_status_idx
  on public.event_seating_assignments (event_id, status, assignment_round);

create unique index event_seating_assignments_active_guest_idx
  on public.event_seating_assignments (event_id, event_guest_id)
  where status = 'active';

create unique index event_seating_assignments_active_table_seat_idx
  on public.event_seating_assignments (event_id, event_table_id, seat_index)
  where status = 'active';

create or replace function app_private.event_seating_assignments_enforce_same_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  table_event_id uuid;
  guest_event_id uuid;
begin
  select event_table.event_id
  into table_event_id
  from public.event_tables as event_table
  where event_table.id = new.event_table_id;

  if table_event_id is distinct from new.event_id then
    raise exception 'Seating assignment table must belong to the same event.'
      using errcode = 'P0001';
  end if;

  select guest.event_id
  into guest_event_id
  from public.event_guests as guest
  where guest.id = new.event_guest_id;

  if guest_event_id is distinct from new.event_id then
    raise exception 'Seating assignment guest must belong to the same event.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger trigger_event_seating_assignments_enforce_same_event
before insert or update of event_id, event_table_id, event_guest_id
on public.event_seating_assignments
for each row
execute function app_private.event_seating_assignments_enforce_same_event();

create trigger event_seating_assignments_touch_updated_at
before update on public.event_seating_assignments
for each row
execute function app_private.touch_updated_at();

alter table public.event_seating_assignments enable row level security;

drop policy if exists event_seating_assignments_owner_all
  on public.event_seating_assignments;
create policy event_seating_assignments_owner_all
on public.event_seating_assignments
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

create or replace function public.get_event_seating_assignments(
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
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
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
    assignment.status,
    assignment.assigned_at,
    assignment.assigned_by_user_id,
    assignment.created_at,
    assignment.updated_at
  from public.event_seating_assignments as assignment
  join public.event_tables as event_table
    on event_table.id = assignment.event_table_id
  join public.event_guests as guest
    on guest.id = assignment.event_guest_id
  where assignment.event_id = target_event_id
    and assignment.status = 'active'
    and app_private.is_event_owner(assignment.event_id)
  order by event_table.display_order asc, assignment.seat_index asc;
$$;

create or replace function public.clear_event_seating_assignments(
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
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active';

  return query
  select *
  from public.get_event_seating_assignments(target_event_id);
end;
$$;

create or replace function public.generate_random_seating_assignments(
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
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  eligible_player_count integer;
  ready_table_count integer;
  table_count_to_fill integer;
  next_assignment_round integer;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select count(*)
  into eligible_player_count
  from public.event_guests as guest
  join public.event_guest_tag_assignments as tag_assignment
    on tag_assignment.event_guest_id = guest.id
    and tag_assignment.event_id = guest.event_id
    and tag_assignment.status = 'assigned'
  join public.nfc_tags as tag
    on tag.id = tag_assignment.nfc_tag_id
    and tag.default_tag_type = 'player'
    and tag.status = 'active'
  where guest.event_id = target_event_id
    and guest.attendance_status = 'checked_in';

  if eligible_player_count < 4 then
    raise exception 'At least four checked-in players with active player tags are required to generate seating assignments.'
      using errcode = 'P0001';
  end if;

  select count(*)
  into ready_table_count
  from public.event_tables as event_table
  join public.nfc_tags as tag
    on tag.id = event_table.nfc_tag_id
    and tag.default_tag_type = 'table'
    and tag.status = 'active'
  where event_table.event_id = target_event_id;

  if ready_table_count = 0 then
    raise exception 'At least one ready table with a bound NFC tag is required to generate seating assignments.'
      using errcode = 'P0001';
  end if;

  table_count_to_fill := least(eligible_player_count / 4, ready_table_count);

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active';

  with selected_tables as (
    select
      event_table.id as event_table_id,
      row_number() over (order by event_table.display_order, event_table.id) - 1
        as table_offset
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.event_id = target_event_id
    order by event_table.display_order, event_table.id
    limit table_count_to_fill
  ),
  randomized_players as (
    select
      guest.id as event_guest_id,
      random() as random_sort
    from public.event_guests as guest
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
    where guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    order by random_sort
    limit table_count_to_fill * 4
  ),
  selected_players as (
    select
      randomized_players.event_guest_id,
      row_number() over (order by randomized_players.random_sort) - 1
        as player_offset
    from randomized_players
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    status,
    assigned_at,
    assigned_by_user_id
  )
  select
    target_event_id,
    selected_tables.event_table_id,
    selected_players.event_guest_id,
    (selected_players.player_offset % 4)::integer,
    next_assignment_round,
    'active',
    now(),
    auth.uid()
  from selected_players
  join selected_tables
    on selected_tables.table_offset = selected_players.player_offset / 4;

  return query
  select *
  from public.get_event_seating_assignments(target_event_id);
end;
$$;

create or replace function app_private.validate_random_seating_assignment(
  target_event_table_id uuid,
  target_seat_index integer,
  target_event_guest_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  select event.*
  into event_row
  from public.events as event
  join public.event_tables as event_table
    on event_table.event_id = event.id
  where event_table.id = target_event_table_id;

  if not found or event_row.seating_mode = 'manual' then
    return;
  end if;

  if not exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_id = event_row.id
      and assignment.event_table_id = target_event_table_id
      and assignment.seat_index = target_seat_index
      and assignment.event_guest_id = target_event_guest_id
      and assignment.status = 'active'
  ) then
    raise exception 'The scanned player does not match the random seating assignment.'
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function public.start_table_session(
  target_event_table_id uuid,
  scanned_table_uid text,
  east_player_uid text,
  south_player_uid text,
  west_player_uid text,
  north_player_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  normalized_table_uid text;
  bound_tag_uid text;
  next_session_number integer;
  seat_guest_ids uuid[];
  seat_index integer;
  scanned_uid text;
  resolved_tag_row public.nfc_tags%rowtype;
  resolved_assignment_row public.event_guest_tag_assignments%rowtype;
  resolved_guest_row public.event_guests%rowtype;
  scanned_player_uids text[] := array[
    east_player_uid,
    south_player_uid,
    west_player_uid,
    north_player_uid
  ];
  initial_winds text[] := array['east', 'south', 'west', 'north'];
begin
  table_row := app_private.require_owned_table(target_event_table_id);
  perform app_private.require_event_for_scoring(table_row.event_id);

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

  seat_guest_ids := array[]::uuid[];

  for seat_index in 1..array_length(scanned_player_uids, 1) loop
    scanned_uid := app_private.normalize_tag_uid(scanned_player_uids[seat_index]);

    if scanned_uid = '' then
      raise exception 'Each seat requires a player tag.'
        using errcode = 'P0001';
    end if;

    if scanned_uid = any (
      coalesce(scanned_player_uids[1:seat_index - 1], array[]::text[])
    ) then
      raise exception 'Duplicate player tag scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    select *
    into resolved_tag_row
    from public.nfc_tags
    where owner_user_id = auth.uid()
      and uid_hex = scanned_uid
    for update;

    if not found then
      raise exception 'Unknown player tag. Register player tags during check-in first.'
        using errcode = 'P0001';
    end if;

    if resolved_tag_row.default_tag_type <> 'player' then
      raise exception 'Expected a player tag for seat assignment.'
        using errcode = 'P0001';
    end if;

    select assignment.*
    into resolved_assignment_row
    from public.event_guest_tag_assignments as assignment
    where assignment.event_id = table_row.event_id
      and assignment.nfc_tag_id = resolved_tag_row.id
      and assignment.status = 'assigned'
    for update;

    if not found then
      raise exception 'The scanned player tag is not assigned to an eligible guest in this event.'
        using errcode = 'P0001';
    end if;

    select guest.*
    into resolved_guest_row
    from public.event_guests as guest
    where guest.id = resolved_assignment_row.event_guest_id
    for update;

    if resolved_guest_row.attendance_status <> 'checked_in' then
      raise exception 'All session players must be checked in.'
        using errcode = 'P0001';
    end if;

    if resolved_guest_row.id = any (seat_guest_ids) then
      raise exception 'Duplicate guest scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.table_session_seats as seat
      join public.table_sessions as existing_session
        on existing_session.id = seat.table_session_id
      where seat.event_guest_id = resolved_guest_row.id
        and existing_session.event_id = table_row.event_id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'A scanned guest is already seated in another active session.'
        using errcode = 'P0001';
    end if;

    perform app_private.validate_random_seating_assignment(
      table_row.id,
      seat_index - 1,
      resolved_guest_row.id
    );

    seat_guest_ids := array_append(seat_guest_ids, resolved_guest_row.id);
  end loop;

  select *
  into ruleset_row
  from public.rulesets
  where id = table_row.default_ruleset_id;

  if not found then
    raise exception 'Default ruleset not found for the selected table.'
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
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  for seat_index in 1..array_length(seat_guest_ids, 1) loop
    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values (
      session_row.id,
      seat_index - 1,
      initial_winds[seat_index],
      seat_guest_ids[seat_index]
    );
  end loop;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'table_session',
    session_row.id::text,
    'start',
    null,
    to_jsonb(session_row),
    jsonb_build_object(
      'event_table_id', table_row.id,
      'seat_guest_ids', seat_guest_ids,
      'scanned_table_uid', normalized_table_uid
    )
  );

  return session_row;
end;
$$;

select pg_notify('pgrst', 'reload schema');
