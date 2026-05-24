-- Event-ready tournament MVP: qualification statuses, scoring phases, and
-- public-safe leaderboard RPCs.

create or replace function public.default_public_display_name(full_name text)
returns text
language sql
immutable
as $$
  with normalized as (
    select regexp_replace(btrim(coalesce(full_name, '')), '\s+', ' ', 'g') as value
  ),
  parts as (
    select
      value,
      regexp_split_to_array(value, '\s+') as tokens
    from normalized
  )
  select case
    when value = '' then ''
    when array_length(tokens, 1) = 1 then tokens[1]
    else tokens[1] || ' ' || upper(left(tokens[array_length(tokens, 1)], 1)) || '.'
  end
  from parts;
$$;

alter table public.guest_profiles
add column if not exists public_display_name text;

alter table public.event_guests
add column if not exists tournament_status text not null default 'open_play_only',
add column if not exists public_display_name text;

alter table public.events
add column if not exists current_scoring_phase text not null default 'qualification';

alter table public.table_sessions
add column if not exists scoring_phase text not null default 'qualification';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_guests_tournament_status_check'
      and conrelid = 'public.event_guests'::regclass
  ) then
    alter table public.event_guests
    add constraint event_guests_tournament_status_check
    check (tournament_status in ('open_play_only', 'qualifying', 'qualified', 'withdrawn'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'events_current_scoring_phase_check'
      and conrelid = 'public.events'::regclass
  ) then
    alter table public.events
    add constraint events_current_scoring_phase_check
    check (current_scoring_phase in ('qualification', 'tournament', 'bonus'));
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'table_sessions_scoring_phase_check'
      and conrelid = 'public.table_sessions'::regclass
  ) then
    alter table public.table_sessions
    add constraint table_sessions_scoring_phase_check
    check (scoring_phase in ('qualification', 'tournament', 'bonus'));
  end if;
end;
$$;

update public.guest_profiles
set public_display_name = public.default_public_display_name(display_name)
where nullif(btrim(public_display_name), '') is null;

update public.event_guests as guest
set public_display_name = coalesce(
  nullif(btrim(profile.public_display_name), ''),
  public.default_public_display_name(guest.display_name)
)
from public.guest_profiles as profile
where profile.id = guest.guest_profile_id
  and nullif(btrim(guest.public_display_name), '') is null;

update public.event_guests
set public_display_name = public.default_public_display_name(display_name)
where nullif(btrim(public_display_name), '') is null;

create or replace function app_private.set_public_display_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if nullif(btrim(new.public_display_name), '') is null then
    new.public_display_name := public.default_public_display_name(new.display_name);
  end if;

  return new;
end;
$$;

drop trigger if exists guest_profiles_set_public_display_name
on public.guest_profiles;
create trigger guest_profiles_set_public_display_name
before insert or update of display_name, public_display_name
on public.guest_profiles
for each row execute function app_private.set_public_display_name();

drop trigger if exists event_guests_set_public_display_name
on public.event_guests;
create trigger event_guests_set_public_display_name
before insert or update of display_name, public_display_name
on public.event_guests
for each row execute function app_private.set_public_display_name();

create index if not exists event_guests_event_tournament_status_idx
  on public.event_guests (event_id, tournament_status, attendance_status);

create index if not exists table_sessions_event_scoring_phase_idx
  on public.table_sessions (event_id, scoring_phase, status);

create table if not exists public.public_event_updates (
  id bigserial primary key,
  event_id uuid not null references public.events(id) on delete cascade,
  topic text not null,
  updated_at timestamptz not null default now()
);

alter table public.public_event_updates enable row level security;

drop policy if exists public_event_updates_public_read
  on public.public_event_updates;
create policy public_event_updates_public_read
on public.public_event_updates
for select
to anon, authenticated
using (true);

grant select on public.public_event_updates to anon, authenticated;

do $$
begin
  alter publication supabase_realtime
  add table public.public_event_updates;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
$$;

create or replace function app_private.insert_public_event_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  if tg_table_name = 'hand_results' then
    select session.event_id
    into target_event_id
    from public.table_sessions as session
    where session.id = case
      when tg_op = 'DELETE' then old.table_session_id
      else new.table_session_id
    end;
  else
    target_event_id := case
      when tg_op = 'DELETE' then old.event_id
      else new.event_id
    end;
  end if;

  if target_event_id is not null then
    insert into public.public_event_updates (event_id, topic)
    values (target_event_id, tg_table_name);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists public_event_updates_event_score_totals
  on public.event_score_totals;
create trigger public_event_updates_event_score_totals
after insert or update or delete on public.event_score_totals
for each row execute function app_private.insert_public_event_update();

drop trigger if exists public_event_updates_event_score_adjustments
  on public.event_score_adjustments;
create trigger public_event_updates_event_score_adjustments
after insert or update or delete on public.event_score_adjustments
for each row execute function app_private.insert_public_event_update();

drop trigger if exists public_event_updates_hand_results
  on public.hand_results;
create trigger public_event_updates_hand_results
after insert or update or delete on public.hand_results
for each row execute function app_private.insert_public_event_update();

drop trigger if exists public_event_updates_table_sessions
  on public.table_sessions;
create trigger public_event_updates_table_sessions
after insert or update or delete on public.table_sessions
for each row execute function app_private.insert_public_event_update();

drop trigger if exists public_event_updates_event_bonus_rounds
  on public.event_bonus_rounds;
create trigger public_event_updates_event_bonus_rounds
after insert or update or delete on public.event_bonus_rounds
for each row execute function app_private.insert_public_event_update();

create or replace function public.update_event_guest_tournament_status(
  target_event_guest_id uuid,
  target_tournament_status text
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_guest public.event_guests%rowtype;
  updated_guest public.event_guests%rowtype;
begin
  existing_guest := app_private.require_owned_guest(target_event_guest_id);

  update public.event_guests
  set
    tournament_status = target_tournament_status,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_guest.id
  returning *
  into updated_guest;

  perform app_private.insert_audit_log(
    updated_guest.event_id,
    'event_guest',
    updated_guest.id::text,
    'update_tournament_status',
    to_jsonb(existing_guest),
    to_jsonb(updated_guest),
    jsonb_build_object('tournament_status', target_tournament_status)
  );

  return updated_guest;
end;
$$;

create or replace function public.update_event_scoring_phase(
  target_event_id uuid,
  target_scoring_phase text
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_event public.events%rowtype;
  updated_event public.events%rowtype;
begin
  existing_event := app_private.require_owned_event(target_event_id);

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End active or paused sessions before changing scoring phase.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    current_scoring_phase = target_scoring_phase,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'update_scoring_phase',
    to_jsonb(existing_event),
    to_jsonb(updated_event),
    jsonb_build_object('scoring_phase', target_scoring_phase)
  );

  return updated_event;
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
  event_row public.events%rowtype;
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
  effective_scoring_phase text;
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
    case when bonus_assignment_row.id is null then effective_scoring_phase else 'bonus' end,
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
      'scanned_table_uid', normalized_table_uid,
      'scoring_phase', session_row.scoring_phase
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

drop function if exists public.get_event_leaderboard(uuid);

create or replace function public.get_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  total_points integer,
  hands_played integer,
  hands_won integer,
  self_draw_wins integer,
  discard_wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    score.event_guest_id,
    guest.display_name,
    score.total_points,
    score.hands_played,
    score.hands_won,
    score.self_draw_wins,
    score.discard_wins,
    dense_rank() over (order by score.total_points desc) as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
  where score.event_id = target_event_id
    and guest.tournament_status = 'qualified'
    and app_private.is_event_owner(target_event_id)
  order by score.total_points desc, guest.display_name asc;
$$;

create or replace function public.get_event_qualification_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  guest_profile_id uuid,
  full_name text,
  tournament_status text,
  qualification_points integer,
  hands_played integer,
  wins integer,
  self_draw_wins integer,
  discard_wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  with qualified_events as (
    select target_event_id as event_id
    where app_private.is_event_owner(target_event_id)
  ),
  guest_base as (
    select
      guest.id as event_guest_id,
      guest.guest_profile_id,
      guest.display_name as full_name,
      guest.tournament_status
    from public.event_guests as guest
    join qualified_events as owned_event
      on owned_event.event_id = guest.event_id
  ),
  points_totals as (
    select
      guest_base.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = guest_base.event_guest_id then settlement.amount_points else 0 end), 0) as qualification_points
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
        and session.scoring_phase = 'qualification'
      )
    group by guest_base.event_guest_id
  ),
  hand_totals as (
    select
      seat.event_guest_id,
      count(hand_result.id)::integer as hands_played,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index)::integer as wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw')::integer as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard')::integer as discard_wins
    from public.table_session_seats as seat
    join public.table_sessions as session
      on session.id = seat.table_session_id
    join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
    where session.event_id = target_event_id
      and session.scoring_phase = 'qualification'
      and hand_result.status = 'recorded'
    group by seat.event_guest_id
  )
  select
    guest_base.event_guest_id,
    guest_base.guest_profile_id,
    guest_base.full_name,
    guest_base.tournament_status,
    coalesce(points_totals.qualification_points, 0)::integer as qualification_points,
    coalesce(hand_totals.hands_played, 0) as hands_played,
    coalesce(hand_totals.wins, 0) as wins,
    coalesce(hand_totals.self_draw_wins, 0) as self_draw_wins,
    coalesce(hand_totals.discard_wins, 0) as discard_wins,
    dense_rank() over (
      order by coalesce(points_totals.qualification_points, 0) desc,
        coalesce(hand_totals.wins, 0) desc
    )::integer as rank
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join hand_totals
    on hand_totals.event_guest_id = guest_base.event_guest_id
  order by qualification_points desc, wins desc, full_name asc;
$$;

create or replace function public.get_public_event_leaderboard(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  public_display_name text,
  total_points integer,
  hands_played integer,
  wins integer,
  self_draw_wins integer,
  discard_wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    score.event_guest_id,
    coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
    score.total_points,
    score.hands_played,
    score.hands_won as wins,
    score.self_draw_wins,
    score.discard_wins,
    dense_rank() over (order by score.total_points desc) as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
  where score.event_id = target_event_id
    and guest.event_id = target_event_id
    and guest.tournament_status = 'qualified'
    and guest.attendance_status = 'checked_in'
  order by score.total_points desc, public_display_name asc;
$$;

create or replace function public.get_public_event_summary(
  target_event_id uuid
)
returns table (
  event_id uuid,
  title text
)
language sql
security definer
set search_path = public
as $$
  select
    event.id,
    event.title
  from public.events as event
  where event.id = target_event_id;
$$;

create or replace function public.get_public_event_bonus_results(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  public_display_name text,
  result_label text,
  placement integer,
  points_delta integer
)
language sql
security definer
set search_path = public
as $$
  with completed_bonus_rounds as (
    select *
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'completed'
  ),
  champion_result as (
    select
      guest.id as event_guest_id,
      coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
      'Table of Champions'::text as result_label,
      1::integer as placement,
      coalesce(bonus_round.champion_award_points, 0)::integer as points_delta
    from completed_bonus_rounds as bonus_round
    join public.event_guests as guest
      on guest.id = bonus_round.champion_event_guest_id
      and guest.event_id = bonus_round.event_id
      and guest.tournament_status = 'qualified'
  ),
  redemption_points as (
    select
      seat.event_guest_id,
      coalesce(sum(case when settlement.payee_event_guest_id = seat.event_guest_id then settlement.amount_points else 0 end), 0)
      - coalesce(sum(case when settlement.payer_event_guest_id = seat.event_guest_id then settlement.amount_points else 0 end), 0) as total_points
    from completed_bonus_rounds as bonus_round
    join public.table_sessions as session
      on session.bonus_round_id = bonus_round.id
      and session.scoring_phase = 'bonus'
      and session.bonus_table_role = 'table_of_redemption'
    join public.table_session_seats as seat
      on seat.table_session_id = session.id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded'
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and (
        settlement.payee_event_guest_id = seat.event_guest_id
        or settlement.payer_event_guest_id = seat.event_guest_id
      )
    group by seat.event_guest_id
  ),
  redemption_winner as (
    select
      guest.id as event_guest_id,
      coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
      'Table of Redemption'::text as result_label,
      1::integer as placement,
      0::integer as points_delta
    from redemption_points
    join public.event_guests as guest
      on guest.id = redemption_points.event_guest_id
      and guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
    order by redemption_points.total_points desc, guest.public_display_name asc, guest.id asc
    limit 1
  )
  select *
  from champion_result
  union all
  select *
  from redemption_winner
  order by result_label asc;
$$;

grant execute on function public.get_public_event_summary(uuid) to anon, authenticated;
grant execute on function public.get_public_event_leaderboard(uuid) to anon, authenticated;
grant execute on function public.get_public_event_bonus_results(uuid) to anon, authenticated;

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
    and guest.attendance_status = 'checked_in'
    and guest.tournament_status = 'qualified';

  if eligible_player_count < 4 then
    raise exception 'At least four qualified checked-in players with active player tags are required to generate seating assignments.'
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
      and guest.tournament_status = 'qualified'
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
    and guest.tournament_status = 'qualified'
  join public.event_guest_tag_assignments as tag_assignment
    on tag_assignment.event_guest_id = guest.id
    and tag_assignment.event_id = guest.event_id
    and tag_assignment.status = 'assigned'
  join public.nfc_tags as tag
    on tag.id = tag_assignment.nfc_tag_id
    and tag.default_tag_type = 'player'
    and tag.status = 'active'
  where exists (
    select 1
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.scoring_phase = 'tournament'
  );

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
      and guest.tournament_status = 'qualified'
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
    where exists (
      select 1
      from public.table_sessions as session
      where session.event_id = target_event_id
        and session.scoring_phase = 'tournament'
    )
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

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_event_score_totals(event_row.id);
  end loop;
end;
$$;
