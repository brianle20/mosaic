-- Bonus round finals database foundation.

create table if not exists public.event_bonus_rounds (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  champions_table_id uuid not null references public.event_tables(id) on delete restrict,
  redemption_table_id uuid not null references public.event_tables(id) on delete restrict,
  assignment_round integer not null check (assignment_round > 0),
  status text not null default 'active'
    check (status in ('active', 'completed')),
  champion_event_guest_id uuid references public.event_guests(id) on delete set null,
  champion_bonus_score_points integer,
  champion_top_up_points integer,
  champion_award_points integer,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint event_bonus_rounds_tables_different_check
    check (champions_table_id <> redemption_table_id),
  constraint event_bonus_rounds_champions_table_same_event_fk
    foreign key (champions_table_id, event_id)
    references public.event_tables (id, event_id)
    on delete restrict,
  constraint event_bonus_rounds_redemption_table_same_event_fk
    foreign key (redemption_table_id, event_id)
    references public.event_tables (id, event_id)
    on delete restrict,
  constraint event_bonus_rounds_champion_guest_same_event_fk
    foreign key (champion_event_guest_id, event_id)
    references public.event_guests (id, event_id)
    on delete restrict
);

create index if not exists event_bonus_rounds_event_status_idx
  on public.event_bonus_rounds (event_id, status, assignment_round);

drop trigger if exists event_bonus_rounds_touch_updated_at
  on public.event_bonus_rounds;
create trigger event_bonus_rounds_touch_updated_at
before update on public.event_bonus_rounds
for each row
execute function app_private.touch_updated_at();

alter table public.event_bonus_rounds enable row level security;

drop policy if exists event_bonus_rounds_owner_all
  on public.event_bonus_rounds;
create policy event_bonus_rounds_owner_all
on public.event_bonus_rounds
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

create table if not exists public.event_score_adjustments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  adjustment_type text not null
    check (adjustment_type in ('finals_champion_award')),
  amount_points integer not null check (amount_points <> 0),
  label text not null,
  source_table_session_id uuid references public.table_sessions(id) on delete cascade,
  context_json jsonb not null default '{}'::jsonb,
  created_by_user_id uuid references public.users(id),
  created_at timestamptz not null default now(),
  constraint event_score_adjustments_guest_same_event_fk
    foreign key (event_guest_id, event_id)
    references public.event_guests (id, event_id)
    on delete cascade
);

create index if not exists event_score_adjustments_event_guest_idx
  on public.event_score_adjustments (event_id, event_guest_id);

create unique index if not exists event_score_adjustments_finals_champion_award_source_idx
  on public.event_score_adjustments (source_table_session_id)
  where adjustment_type = 'finals_champion_award'
    and source_table_session_id is not null;

alter table public.event_score_adjustments enable row level security;

drop policy if exists event_score_adjustments_owner_all
  on public.event_score_adjustments;
create policy event_score_adjustments_owner_all
on public.event_score_adjustments
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

alter table public.event_seating_assignments
add column if not exists assignment_type text;

update public.event_seating_assignments
set assignment_type = 'random'
where assignment_type is null;

alter table public.event_seating_assignments
alter column assignment_type set default 'random';

alter table public.event_seating_assignments
alter column assignment_type set not null;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_assignment_type_check;

alter table public.event_seating_assignments
add constraint event_seating_assignments_assignment_type_check
check (assignment_type in ('random', 'bonus'));

alter table public.event_seating_assignments
add column if not exists bonus_table_role text;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_bonus_table_role_check;

alter table public.event_seating_assignments
add constraint event_seating_assignments_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in ('table_of_champions', 'table_of_redemption')
);

alter table public.event_seating_assignments
add column if not exists seed_rank integer;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_seed_rank_check;

alter table public.event_seating_assignments
add constraint event_seating_assignments_seed_rank_check
check (seed_rank is null or seed_rank > 0);

alter table public.event_seating_assignments
add column if not exists bonus_round_id uuid references public.event_bonus_rounds(id) on delete set null;

create index if not exists event_seating_assignments_bonus_round_idx
  on public.event_seating_assignments (bonus_round_id, bonus_table_role, seed_rank);

alter table public.table_sessions
add column if not exists bonus_round_id uuid references public.event_bonus_rounds(id) on delete set null;

alter table public.table_sessions
add column if not exists bonus_table_role text;

alter table public.table_sessions
drop constraint if exists table_sessions_bonus_table_role_check;

alter table public.table_sessions
add constraint table_sessions_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in ('table_of_champions', 'table_of_redemption')
);

create index if not exists table_sessions_bonus_round_idx
  on public.table_sessions (bonus_round_id, bonus_table_role);

drop function if exists public.clear_event_seating_assignments(uuid);
drop function if exists public.generate_random_seating_assignments(uuid);
drop function if exists public.get_event_seating_assignments(uuid);

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
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
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
    assignment.assignment_type,
    assignment.bonus_round_id,
    assignment.bonus_table_role,
    assignment.seed_rank,
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
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
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
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
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
    assignment_type,
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
    'random',
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

create or replace function public.generate_bonus_round_seating_assignments(
  target_event_id uuid,
  champions_table_id uuid,
  redemption_table_id uuid
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
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  ranked_player_count integer;
  next_assignment_round integer;
  bonus_round_row public.event_bonus_rounds%rowtype;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if champions_table_id = redemption_table_id then
    raise exception 'Bonus round tables must be different.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End active or paused sessions before generating bonus round seating assignments.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
  ) then
    raise exception 'An active bonus round already exists for this event.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = champions_table_id
      and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Champions must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = redemption_table_id
      and event_table.event_id = target_event_id
  ) then
    raise exception 'Table of Redemption must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  perform app_private.refresh_event_score_totals(target_event_id);

  select count(*)
  into ranked_player_count
  from public.get_event_leaderboard(target_event_id) as leaderboard
  join public.event_guests as guest
    on guest.id = leaderboard.event_guest_id
    and guest.event_id = target_event_id
    and guest.attendance_status = 'checked_in'
  join public.event_guest_tag_assignments as tag_assignment
    on tag_assignment.event_guest_id = guest.id
    and tag_assignment.event_id = guest.event_id
    and tag_assignment.status = 'assigned'
  join public.nfc_tags as tag
    on tag.id = tag_assignment.nfc_tag_id
    and tag.default_tag_type = 'player'
    and tag.status = 'active';

  if ranked_player_count < 8 then
    raise exception 'At least eight ranked players are required to generate bonus round seating assignments.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = target_event_id
    and assignment.status = 'active';

  insert into public.event_bonus_rounds (
    event_id,
    champions_table_id,
    redemption_table_id,
    assignment_round,
    status
  )
  values (
    target_event_id,
    champions_table_id,
    redemption_table_id,
    next_assignment_round,
    'active'
  )
  returning *
  into bonus_round_row;

  -- Table of Champions seats East: #4, South: #3, West: #2, North: #1.
  -- Table of Redemption seats East: 4th last, South: 3rd last, West: 2nd last, North: last.
  with ranked_players as (
    select
      leaderboard.event_guest_id,
      (row_number() over (
        order by leaderboard.rank asc, leaderboard.total_points desc,
          leaderboard.display_name asc, leaderboard.event_guest_id asc
      ))::integer as seed_rank,
      (count(*) over ())::integer as player_count
    from public.get_event_leaderboard(target_event_id) as leaderboard
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
      and guest.event_id = target_event_id
      and guest.attendance_status = 'checked_in'
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
  ),
  champions as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      case ranked_players.seed_rank
        when 4 then 0
        when 3 then 1
        when 2 then 2
        when 1 then 3
      end as seat_index
    from ranked_players
    where ranked_players.seed_rank between 1 and 4
  ),
  redemption as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      (ranked_players.seed_rank - (ranked_players.player_count - 4) - 1)::integer
        as seat_index
    from ranked_players
    where ranked_players.seed_rank > ranked_players.player_count - 4
  ),
  selected_bonus_players as (
    select
      champions_table_id as event_table_id,
      champions.event_guest_id,
      champions.seat_index,
      'table_of_champions'::text as bonus_table_role,
      champions.seed_rank
    from champions
    union all
    select
      redemption_table_id as event_table_id,
      redemption.event_guest_id,
      redemption.seat_index,
      'table_of_redemption'::text as bonus_table_role,
      redemption.seed_rank
    from redemption
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    assignment_type,
    bonus_round_id,
    bonus_table_role,
    seed_rank,
    status,
    assigned_at,
    assigned_by_user_id
  )
  select
    target_event_id,
    selected_bonus_players.event_table_id,
    selected_bonus_players.event_guest_id,
    selected_bonus_players.seat_index,
    next_assignment_round,
    'bonus',
    bonus_round_row.id,
    selected_bonus_players.bonus_table_role,
    selected_bonus_players.seed_rank,
    'active',
    now(),
    auth.uid()
  from selected_bonus_players;

  return query
  select *
  from public.get_event_seating_assignments(target_event_id);
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
  bonus_assignment_row public.event_seating_assignments%rowtype;
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

  select assignment.*
  into bonus_assignment_row
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.assignment_type = 'bonus'
    and assignment.status = 'active'
  order by assignment.seat_index asc
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
    case when bonus_assignment_row.id is null then null else bonus_assignment_row.bonus_round_id end,
    case when bonus_assignment_row.id is null then null else bonus_assignment_row.bonus_table_role end,
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
    -- exclude bonus sessions from event score totals
    where settlement.id is null
      or (
        session.event_id = target_event_id
        and session.bonus_round_id is null
      )
    group by guest_base.event_guest_id
  ),
  adjustment_totals as (
    select
      adjustment.event_guest_id,
      sum(adjustment.amount_points)::integer as total_points
    from public.event_score_adjustments as adjustment
    where adjustment.event_id = target_event_id
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
      and session.bonus_round_id is null
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  ),
  hand_win_totals as (
    select
      seat.event_guest_id,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index) as hands_won,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw') as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard') as discard_wins
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.bonus_round_id is null
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
      and session.bonus_round_id is null
    group by seat.event_guest_id
  )
  select
    target_event_id,
    guest_base.event_guest_id,
    coalesce(points_totals.total_points, 0)
      + coalesce(adjustment_totals.total_points, 0),
    coalesce(hand_play_totals.hands_played, 0),
    coalesce(hand_win_totals.hands_won, 0),
    coalesce(hand_win_totals.self_draw_wins, 0),
    coalesce(hand_win_totals.discard_wins, 0),
    coalesce(session_counts.sessions_started, 0),
    coalesce(session_counts.sessions_completed, 0)
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join adjustment_totals
    on adjustment_totals.event_guest_id = guest_base.event_guest_id
  left join hand_play_totals
    on hand_play_totals.event_guest_id = guest_base.event_guest_id
  left join hand_win_totals
    on hand_win_totals.event_guest_id = guest_base.event_guest_id
  left join session_counts
    on session_counts.event_guest_id = guest_base.event_guest_id;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'event_guests'
      and column_name = 'score_total_points'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'event_guests'
      and column_name = 'score_rank'
  ) then
    update public.event_guests as guest
    set
      score_total_points = totals.total_points,
      score_rank = ranked.rank
    from public.event_score_totals as totals
    join (
      select
        event_guest_id,
        dense_rank() over (order by total_points desc) as rank
      from public.event_score_totals
      where event_id = target_event_id
    ) as ranked
      on ranked.event_guest_id = totals.event_guest_id
    where guest.id = totals.event_guest_id
      and totals.event_id = target_event_id;
  end if;
end;
$$;

create or replace function app_private.apply_bonus_round_champion_award(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  champion_event_guest_id_value uuid;
  champion_bonus_score_points_value integer;
  champion_base_total_value integer;
  top_non_champion_total_value integer;
  champion_top_up_points_value integer;
  champion_award_points_value integer;
begin
  select *
  into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;

  if not found
    or session_row.bonus_table_role is distinct from 'table_of_champions'
    or session_row.bonus_round_id is null then
    return;
  end if;

  delete from public.event_score_adjustments as adjustment
  where adjustment.adjustment_type = 'finals_champion_award'
    and adjustment.source_table_session_id = session_row.id;

  if session_row.status <> 'completed' then
    update public.event_bonus_rounds
    set
      status = 'active',
      champion_event_guest_id = null,
      champion_bonus_score_points = null,
      champion_top_up_points = null,
      champion_award_points = null,
      completed_at = null
    where id = session_row.bonus_round_id;

    perform app_private.refresh_event_score_totals(session_row.event_id);
    return;
  end if;

  perform app_private.refresh_event_score_totals(session_row.event_id);

  with session_bonus_scores as (
    select
      seat.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = seat.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = seat.event_guest_id then settlement.amount_points else 0 end), 0) as bonus_score_points,
      min(assignment.seed_rank) as seed_rank
    from public.table_session_seats as seat
    left join public.hand_results as hand_result
      on hand_result.table_session_id = seat.table_session_id
      and hand_result.status = 'recorded'
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and (
        settlement.payee_event_guest_id = seat.event_guest_id
        or settlement.payer_event_guest_id = seat.event_guest_id
      )
    left join public.event_seating_assignments as assignment
      on assignment.bonus_round_id = session_row.bonus_round_id
      and assignment.event_guest_id = seat.event_guest_id
      and assignment.bonus_table_role = 'table_of_champions'
    where seat.table_session_id = session_row.id
    group by seat.event_guest_id
  )
  select
    session_bonus_scores.event_guest_id,
    session_bonus_scores.bonus_score_points::integer
  into champion_event_guest_id_value,
    champion_bonus_score_points_value
  from session_bonus_scores
  order by session_bonus_scores.bonus_score_points desc,
    session_bonus_scores.seed_rank asc nulls last,
    session_bonus_scores.event_guest_id asc
  limit 1;

  if champion_event_guest_id_value is null then
    return;
  end if;

  select coalesce(total.total_points, 0)
  into champion_base_total_value
  from public.event_score_totals as total
  where total.event_id = session_row.event_id
    and total.event_guest_id = champion_event_guest_id_value;

  champion_base_total_value := coalesce(champion_base_total_value, 0);

  select coalesce(max(total.total_points), 0)
  into top_non_champion_total_value
  from public.event_score_totals as total
  where total.event_id = session_row.event_id
    and total.event_guest_id <> champion_event_guest_id_value;

  top_non_champion_total_value := coalesce(top_non_champion_total_value, 0);
  champion_top_up_points_value := greatest(
    0,
    top_non_champion_total_value + 1
      - (champion_base_total_value + champion_bonus_score_points_value)
  );
  champion_award_points_value :=
    champion_bonus_score_points_value + champion_top_up_points_value;

  update public.event_bonus_rounds
  set
    status = 'completed',
    champion_event_guest_id = champion_event_guest_id_value,
    champion_bonus_score_points = champion_bonus_score_points_value,
    champion_top_up_points = champion_top_up_points_value,
    champion_award_points = champion_award_points_value,
    completed_at = now()
  where id = session_row.bonus_round_id;

  if champion_award_points_value > 0 then
    insert into public.event_score_adjustments (
      event_id,
      event_guest_id,
      adjustment_type,
      amount_points,
      label,
      source_table_session_id,
      context_json,
      created_by_user_id
    )
    values (
      session_row.event_id,
      champion_event_guest_id_value,
      'finals_champion_award',
      champion_award_points_value,
      'Finals champion award',
      session_row.id,
      jsonb_build_object(
        'formula',
        'award_points = Bonus round score + max(0, top non-champion event score before champion award + 1 - (champion normal-round score + Bonus round score))',
        'champion_bonus_score_points', champion_bonus_score_points_value,
        'champion_base_total', champion_base_total_value,
        'top_non_champion_event_total_before_champion_award',
          top_non_champion_total_value,
        'champion_top_up_points', champion_top_up_points_value,
        'award_points', champion_award_points_value
      ),
      auth.uid()
    );
  end if;

  perform app_private.refresh_event_score_totals(session_row.event_id);
end;
$$;

create or replace function app_private.recalculate_session_unowned(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  updated_session public.table_sessions%rowtype;
  hand_row public.hand_results%rowtype;
  seat_guest_ids uuid[];
  initial_east integer;
  current_east integer;
  east_after integer;
  next_pass_count integer;
  dealer_rotated_flag boolean;
  completion_flag boolean;
  base_points_value integer;
  seat_index integer;
  amount_points_value integer;
  payer_guest_id uuid;
  payee_guest_id uuid;
  multiplier_flags text[];
  dealer_multiplier_1_5_effective_at constant timestamptz :=
    '2026-05-17T18:23:17Z'::timestamptz;
  dealer_compound_cap_effective_at constant timestamptz :=
    '2026-05-19T14:00:00Z'::timestamptz;
  round_time_limit_effective_at constant timestamptz :=
    '2026-05-21T12:00:00Z'::timestamptz;
  round_time_limit_duration constant interval := interval '1 hour';
  recorded_hand_count integer := 0;
  dealer_win_count integer := 0;
  round_time_completed boolean := false;
begin
  select *
  into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;

  if not found then
    raise exception 'Session not found: %', target_table_session_id
      using errcode = 'P0001';
  end if;

  select array_agg(seat.event_guest_id order by seat.seat_index)
  into seat_guest_ids
  from public.table_session_seats as seat
  where seat.table_session_id = session_row.id;

  if seat_guest_ids is null or array_length(seat_guest_ids, 1) <> 4 then
    raise exception 'Session is missing seat assignments.'
      using errcode = 'P0001';
  end if;

  delete from public.hand_settlements as settlement
  using public.hand_results as hand_result
  where settlement.hand_result_id = hand_result.id
    and hand_result.table_session_id = session_row.id;

  initial_east := session_row.initial_east_seat_index;
  current_east := initial_east;
  next_pass_count := 0;

  for hand_row in
    select *
    from public.hand_results
    where table_session_id = session_row.id
      and status = 'recorded'
    order by hand_number asc
  loop
    recorded_hand_count := recorded_hand_count + 1;
    dealer_rotated_flag := false;
    completion_flag := false;
    base_points_value := null;
    east_after := current_east;

    if hand_row.result_type = 'win' then
      base_points_value := app_private.ruleset_base_points(
        session_row.ruleset_id,
        hand_row.fan_count
      );

      if hand_row.winner_seat_index = current_east then
        if hand_row.entered_at >= dealer_compound_cap_effective_at then
          dealer_win_count := dealer_win_count + 1;

          if dealer_win_count >= 2 then
            east_after := (current_east + 1) % 4;
            dealer_rotated_flag := true;
            next_pass_count := next_pass_count + 1;
            dealer_win_count := 0;
          end if;
        end if;
      else
        east_after := (current_east + 1) % 4;
        dealer_rotated_flag := true;
        next_pass_count := next_pass_count + 1;
        dealer_win_count := 0;
      end if;

      payee_guest_id := seat_guest_ids[hand_row.winner_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = hand_row.winner_seat_index then
          continue;
        end if;

        if hand_row.win_type = 'discard'
          and seat_index <> hand_row.discarder_seat_index then
          continue;
        end if;

        multiplier_flags := array[]::text[];
        amount_points_value := base_points_value;

        if hand_row.win_type = 'discard' then
          amount_points_value := amount_points_value * 2;
          multiplier_flags := array_append(multiplier_flags, 'discard');
        end if;

        if hand_row.winner_seat_index = current_east then
          if hand_row.entered_at >= dealer_multiplier_1_5_effective_at then
            amount_points_value := (amount_points_value * 3) / 2;
          else
            amount_points_value := amount_points_value * 2;
          end if;
          multiplier_flags := array_append(multiplier_flags, 'east_wins');
        end if;

        if seat_index = current_east
          and hand_row.winner_seat_index <> current_east then
          if hand_row.entered_at >= dealer_multiplier_1_5_effective_at then
            amount_points_value := (amount_points_value * 3) / 2;
          else
            amount_points_value := amount_points_value * 2;
          end if;
          multiplier_flags := array_append(multiplier_flags, 'east_loses');
        end if;

        payer_guest_id := seat_guest_ids[seat_index + 1];

        insert into public.hand_settlements (
          hand_result_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          payer_guest_id,
          payee_guest_id,
          amount_points_value,
          to_jsonb(multiplier_flags)
        );
      end loop;
    elsif hand_row.result_type = 'false_win_penalty' then
      base_points_value := app_private.ruleset_base_points(session_row.ruleset_id, 6);
      payer_guest_id := seat_guest_ids[hand_row.penalty_seat_index + 1];

      for seat_index in 0..3 loop
        if seat_index = hand_row.penalty_seat_index then
          continue;
        end if;

        payee_guest_id := seat_guest_ids[seat_index + 1];

        insert into public.hand_settlements (
          hand_result_id,
          payer_event_guest_id,
          payee_event_guest_id,
          amount_points,
          multiplier_flags_json
        )
        values (
          hand_row.id,
          payer_guest_id,
          payee_guest_id,
          base_points_value,
          to_jsonb(array['false_win_penalty']::text[])
        );
      end loop;
    elsif hand_row.result_type = 'washout'
      and hand_row.dealer_was_waiting_at_draw is false then
      east_after := (current_east + 1) % 4;
      dealer_rotated_flag := true;
      next_pass_count := next_pass_count + 1;
      dealer_win_count := 0;
    end if;

    if east_after = initial_east and next_pass_count >= 4 then
      completion_flag := true;
    end if;

    if not round_time_completed
      and hand_row.entered_at >= round_time_limit_effective_at
      and hand_row.entered_at >= session_row.started_at + round_time_limit_duration then
      completion_flag := true;
      round_time_completed := true;
    end if;

    update public.hand_results
    set
      base_points = base_points_value,
      east_seat_index_before_hand = current_east,
      east_seat_index_after_hand = east_after,
      dealer_rotated = dealer_rotated_flag,
      session_completed_after_hand = completion_flag
    where id = hand_row.id;

    current_east := east_after;
  end loop;

  update public.table_sessions
  set
    current_dealer_seat_index = current_east,
    dealer_pass_count = next_pass_count,
    completed_games_count = recorded_hand_count,
    hand_count = recorded_hand_count,
    status = case
      when session_row.status in ('ended_early', 'aborted') then session_row.status
      when round_time_completed then 'completed'
      when current_east = initial_east and next_pass_count >= 4 then 'completed'
      else 'active'
    end,
    ended_at = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_at
      when round_time_completed then coalesce(session_row.ended_at, now())
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_at, now())
      else null
    end,
    ended_by_user_id = case
      when session_row.status in ('ended_early', 'aborted') then session_row.ended_by_user_id
      when round_time_completed then coalesce(session_row.ended_by_user_id, auth.uid())
      when current_east = initial_east and next_pass_count >= 4 then coalesce(session_row.ended_by_user_id, auth.uid())
      else null
    end,
    end_reason = case
      when session_row.status in ('ended_early', 'aborted') then session_row.end_reason
      when round_time_completed then null
      when current_east = initial_east and next_pass_count >= 4 then null
      else null
    end
  where id = session_row.id
  returning *
  into updated_session;

  perform app_private.refresh_event_score_totals(updated_session.event_id);
  perform app_private.apply_bonus_round_champion_award(updated_session.id);

  return updated_session;
end;
$$;

drop function if exists public.list_event_hand_ledger(uuid);

create or replace function public.list_event_hand_ledger(target_event_id uuid)
returns table (
  event_id uuid,
  table_id uuid,
  table_label text,
  session_id uuid,
  session_number_for_table integer,
  hand_id uuid,
  hand_number integer,
  entered_at timestamptz,
  result_type text,
  status text,
  win_type text,
  fan_count integer,
  penalty_seat_index integer,
  bonus_round_id uuid,
  bonus_table_role text,
  has_settlements boolean,
  cells jsonb,
  ledger_row_type text,
  adjustment_id uuid,
  adjustment_type text,
  adjustment_amount_points integer,
  adjustment_event_guest_id uuid,
  adjustment_display_name text,
  adjustment_context_json jsonb
)
language sql
security definer
set search_path = public, app_private
as $$
  with authorized_event as (
    select event.id
    from public.events as event
    where event.id = target_event_id
      and app_private.is_event_owner(target_event_id)
  ),
  hand_rows as (
    select
      session.event_id,
      event_table.id as table_id,
      event_table.label as table_label,
      session.id as session_id,
      session.session_number_for_table,
      hand_result.id as hand_id,
      hand_result.hand_number,
      hand_result.entered_at,
      hand_result.result_type,
      hand_result.status,
      hand_result.win_type,
      hand_result.fan_count,
      hand_result.penalty_seat_index,
      session.bonus_round_id,
      session.bonus_table_role,
      hand_result.east_seat_index_before_hand,
      exists (
        select 1
        from public.hand_settlements as settlement
        where settlement.hand_result_id = hand_result.id
      ) as has_settlements
    from authorized_event
    join public.table_sessions as session
      on session.event_id = authorized_event.id
    join public.event_tables as event_table
      on event_table.id = session.event_table_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
  ),
  ledger_hand_rows as (
    select
      hand_row.event_id,
      hand_row.table_id,
      hand_row.table_label,
      hand_row.session_id,
      hand_row.session_number_for_table,
      hand_row.hand_id,
      hand_row.hand_number,
      hand_row.entered_at,
      hand_row.result_type,
      hand_row.status,
      hand_row.win_type,
      hand_row.fan_count,
      hand_row.penalty_seat_index,
      hand_row.bonus_round_id,
      hand_row.bonus_table_role,
      hand_row.has_settlements,
      jsonb_agg(
        jsonb_build_object(
          'wind', wind_position.wind,
          'seat_index', seat.seat_index,
          'event_guest_id', seat.event_guest_id,
          'display_name', guest.display_name,
          'points_delta', coalesce(delta.points_delta, 0)
        )
        order by wind_position.sort_order
      ) as cells,
      'hand'::text as ledger_row_type,
      null::uuid as adjustment_id,
      null::text as adjustment_type,
      null::integer as adjustment_amount_points,
      null::uuid as adjustment_event_guest_id,
      null::text as adjustment_display_name,
      null::jsonb as adjustment_context_json
    from hand_rows as hand_row
    cross join lateral (
      values
        (0, 'east', hand_row.east_seat_index_before_hand),
        (1, 'south', (hand_row.east_seat_index_before_hand + 1) % 4),
        (2, 'west', (hand_row.east_seat_index_before_hand + 2) % 4),
        (3, 'north', (hand_row.east_seat_index_before_hand + 3) % 4)
    ) as wind_position(sort_order, wind, seat_index)
    join public.table_session_seats as seat
      on seat.table_session_id = hand_row.session_id
     and seat.seat_index = wind_position.seat_index
    join public.event_guests as guest
      on guest.id = seat.event_guest_id
    left join lateral (
      select
        sum(
          case
            when settlement.payee_event_guest_id = seat.event_guest_id
              then settlement.amount_points
            when settlement.payer_event_guest_id = seat.event_guest_id
              then -settlement.amount_points
            else 0
          end
        )::integer as points_delta
      from public.hand_settlements as settlement
      where settlement.hand_result_id = hand_row.hand_id
        and (
          settlement.payee_event_guest_id = seat.event_guest_id
          or settlement.payer_event_guest_id = seat.event_guest_id
        )
    ) as delta on true
    group by
      hand_row.event_id,
      hand_row.table_id,
      hand_row.table_label,
      hand_row.session_id,
      hand_row.session_number_for_table,
      hand_row.hand_id,
      hand_row.hand_number,
      hand_row.entered_at,
      hand_row.result_type,
      hand_row.status,
      hand_row.win_type,
      hand_row.fan_count,
      hand_row.penalty_seat_index,
      hand_row.bonus_round_id,
      hand_row.bonus_table_role,
      hand_row.has_settlements
  ),
  ledger_adjustment_rows as (
    select
      adjustment.event_id,
      null::uuid as table_id,
      null::text as table_label,
      adjustment.source_table_session_id as session_id,
      null::integer as session_number_for_table,
      null::uuid as hand_id,
      null::integer as hand_number,
      adjustment.created_at as entered_at,
      null::text as result_type,
      'recorded'::text as status,
      null::text as win_type,
      null::integer as fan_count,
      null::integer as penalty_seat_index,
      source_session.bonus_round_id,
      source_session.bonus_table_role,
      false as has_settlements,
      '[]'::jsonb as cells,
      'adjustment'::text as ledger_row_type,
      adjustment.id as adjustment_id,
      adjustment.adjustment_type,
      adjustment.amount_points as adjustment_amount_points,
      adjustment.event_guest_id as adjustment_event_guest_id,
      guest.display_name as adjustment_display_name,
      adjustment.context_json as adjustment_context_json
    from authorized_event
    join public.event_score_adjustments as adjustment
      on adjustment.event_id = authorized_event.id
    join public.event_guests as guest
      on guest.id = adjustment.event_guest_id
    left join public.table_sessions as source_session
      on source_session.id = adjustment.source_table_session_id
    where adjustment.adjustment_type = 'finals_champion_award'
  )
  select *
  from ledger_hand_rows
  union all
  select *
  from ledger_adjustment_rows
  order by entered_at desc, session_id desc, hand_number desc nulls last;
$$;

grant execute on function public.get_event_seating_assignments(uuid)
  to authenticated;
grant execute on function public.clear_event_seating_assignments(uuid)
  to authenticated;
grant execute on function public.generate_random_seating_assignments(uuid)
  to authenticated;
grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.list_event_hand_ledger(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
