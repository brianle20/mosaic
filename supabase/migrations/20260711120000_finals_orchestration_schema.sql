-- Durable Finals orchestration state and read-model foundation.

alter table public.event_bonus_rounds
  alter column redemption_table_id drop not null,
  add column if not exists flow_version text not null default 'legacy',
  add column if not exists state_version bigint not null default 0,
  add column if not exists eligible_player_count integer,
  add column if not exists format text,
  add column if not exists redemption_winner_event_guest_id uuid,
  add column if not exists redemption_resolution_method text;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_status_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_status_check
check (status in ('active', 'completed', 'cancelled'));

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_flow_version_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_flow_version_check
check (flow_version in ('legacy', 'orchestrated'));

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_state_version_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_state_version_check
check (state_version >= 0);

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_eligible_player_count_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_eligible_player_count_check
check (eligible_player_count is null or eligible_player_count >= 2);

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_format_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_format_check
check (
  format is null
  or format in ('champions_only', 'automatic_redemption', 'redemption_advancement', 'parallel_finals')
);

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_redemption_resolution_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_redemption_resolution_check
check (
  redemption_resolution_method is null
  or redemption_resolution_method in ('standing_fifth', 'table_score', 'sudden_death')
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.event_bonus_rounds'::regclass
      and conname = 'event_bonus_rounds_id_event_unique'
  ) then
    alter table public.event_bonus_rounds
    add constraint event_bonus_rounds_id_event_unique
    unique (id, event_id);
  end if;
end;
$$;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_redemption_winner_same_event_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_redemption_winner_same_event_fk
foreign key (redemption_winner_event_guest_id, event_id)
references public.event_guests(id, event_id)
on delete restrict;

create table public.event_finals_eligible_snapshot (
  bonus_round_id uuid not null,
  event_id uuid not null,
  event_guest_id uuid not null,
  display_name text not null,
  total_points integer not null,
  hands_played integer not null,
  standing_rank integer not null,
  seed_rank integer not null,
  created_at timestamptz not null default now(),
  constraint event_finals_eligible_snapshot_standing_rank_check
    check (standing_rank > 0),
  constraint event_finals_eligible_snapshot_seed_rank_check
    check (seed_rank > 0),
  constraint event_finals_eligible_snapshot_root_event_fk
    foreign key (bonus_round_id, event_id)
    references public.event_bonus_rounds(id, event_id)
    on delete cascade,
  constraint event_finals_eligible_snapshot_guest_event_fk
    foreign key (event_guest_id, event_id)
    references public.event_guests(id, event_id)
    on delete restrict,
  primary key (bonus_round_id, event_guest_id),
  unique (bonus_round_id, seed_rank)
);

create index event_finals_eligible_snapshot_event_seed_idx
  on public.event_finals_eligible_snapshot (event_id, bonus_round_id, seed_rank);

create table public.event_finals_contests (
  id uuid primary key default gen_random_uuid(),
  bonus_round_id uuid not null references public.event_bonus_rounds(id) on delete cascade,
  event_id uuid not null references public.events(id) on delete cascade,
  contest_type text not null,
  status text not null default 'pending',
  parent_contest_id uuid references public.event_finals_contests(id) on delete restrict,
  event_table_id uuid references public.event_tables(id) on delete restrict,
  table_session_id uuid references public.table_sessions(id) on delete set null,
  slots_to_fill integer not null default 0,
  slot_start_index integer,
  sequence_number integer not null,
  created_by_user_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  started_at timestamptz,
  completed_at timestamptz,
  constraint event_finals_contests_contest_type_check
    check (
      contest_type in (
        'direct_qualification_tiebreak',
        'table_of_redemption',
        'redemption_advancement_tiebreak',
        'redemption_winner_tiebreak',
        'table_of_champions',
        'champions_sudden_death'
      )
    ),
  constraint event_finals_contests_status_check
    check (status in ('pending', 'ready', 'active', 'complete', 'cancelled')),
  constraint event_finals_contests_slots_to_fill_check
    check (slots_to_fill >= 0),
  constraint event_finals_contests_slot_start_index_check
    check (slot_start_index is null or slot_start_index between 1 and 4),
  constraint event_finals_contests_sequence_number_check
    check (sequence_number > 0),
  constraint event_finals_contests_id_event_unique
    unique (id, event_id),
  constraint event_finals_contests_bonus_round_same_event_fk
    foreign key (bonus_round_id, event_id)
    references public.event_bonus_rounds(id, event_id)
    on delete cascade,
  constraint event_finals_contests_table_same_event_fk
    foreign key (event_table_id, event_id)
    references public.event_tables(id, event_id)
    on delete restrict,
  constraint event_finals_contests_parent_same_event_fk
    foreign key (parent_contest_id, event_id)
    references public.event_finals_contests(id, event_id)
    on delete restrict,
  unique (bonus_round_id, sequence_number),
  unique (table_session_id)
);

create unique index event_finals_contests_current_step_idx
  on public.event_finals_contests (
    bonus_round_id,
    contest_type,
    coalesce(slot_start_index, 0)
  )
  where status in ('ready', 'active');

create index event_finals_contests_event_status_idx
  on public.event_finals_contests (event_id, status, sequence_number);

create index event_finals_contests_bonus_status_idx
  on public.event_finals_contests (bonus_round_id, status, sequence_number);

create table public.event_finals_contest_participants (
  contest_id uuid not null references public.event_finals_contests(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete restrict,
  entry_seed integer not null,
  seat_index integer,
  outcome text not null default 'pending',
  advanced_champions_slot integer,
  outcome_order integer,
  created_at timestamptz not null default now(),
  constraint event_finals_contest_participants_entry_seed_check
    check (entry_seed > 0),
  constraint event_finals_contest_participants_seat_index_check
    check (seat_index is null or seat_index between 0 and 3),
  constraint event_finals_contest_participants_outcome_check
    check (outcome in ('pending', 'advanced', 'winner', 'runner_up', 'eliminated')),
  constraint event_finals_contest_participants_advanced_slot_check
    check (advanced_champions_slot is null or advanced_champions_slot between 1 and 4),
  constraint event_finals_contest_participants_outcome_order_check
    check (outcome_order is null or outcome_order > 0),
  primary key (contest_id, event_guest_id),
  unique (contest_id, seat_index)
);

create index event_finals_contest_participants_guest_idx
  on public.event_finals_contest_participants (event_guest_id, contest_id);

create table public.event_finals_champions_slots (
  bonus_round_id uuid not null references public.event_bonus_rounds(id) on delete cascade,
  slot_index integer not null,
  event_guest_id uuid references public.event_guests(id) on delete restrict,
  qualification_method text,
  source_contest_id uuid references public.event_finals_contests(id) on delete restrict,
  source_finish_order integer,
  created_at timestamptz not null default now(),
  constraint event_finals_champions_slots_slot_index_check
    check (slot_index between 1 and 4),
  constraint event_finals_champions_slots_qualification_method_check
    check (
      qualification_method is null
      or qualification_method in ('direct_seed', 'redemption_finish', 'tiebreak_win')
    ),
  constraint event_finals_champions_slots_source_finish_order_check
    check (source_finish_order is null or source_finish_order > 0),
  primary key (bonus_round_id, slot_index),
  unique (bonus_round_id, event_guest_id)
);

create index event_finals_champions_slots_guest_idx
  on public.event_finals_champions_slots (event_guest_id, bonus_round_id)
  where event_guest_id is not null;

create or replace function app_private.event_finals_contests_enforce_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  parent_bonus_round_id uuid;
  parent_event_id uuid;
  session_event_id uuid;
begin
  if new.parent_contest_id is not null then
    select parent.event_id, parent.bonus_round_id
    into parent_event_id, parent_bonus_round_id
    from public.event_finals_contests as parent
    where parent.id = new.parent_contest_id;

    if not found or parent_event_id is distinct from new.event_id then
      raise exception 'Finals parent contest must belong to the same event.'
        using errcode = 'P0001';
    end if;

    if parent_bonus_round_id is distinct from new.bonus_round_id then
      raise exception 'Finals parent contest must belong to the same Finals root.'
        using errcode = 'P0001';
    end if;
  end if;

  if new.table_session_id is not null then
    select session.event_id
    into session_event_id
    from public.table_sessions as session
    where session.id = new.table_session_id;

    if not found or session_event_id is distinct from new.event_id then
      raise exception 'Finals contest session must belong to the same event.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger event_finals_contests_enforce_scope
before insert or update of bonus_round_id, event_id, parent_contest_id, table_session_id
on public.event_finals_contests
for each row
execute function app_private.event_finals_contests_enforce_scope();

create or replace function app_private.event_finals_contest_participants_enforce_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_event_id uuid;
  guest_event_id uuid;
begin
  select contest.event_id
  into contest_event_id
  from public.event_finals_contests as contest
  where contest.id = new.contest_id;

  if not found then
    raise exception 'Finals contest participant contest was not found.'
      using errcode = 'P0001';
  end if;

  select guest.event_id
  into guest_event_id
  from public.event_guests as guest
  where guest.id = new.event_guest_id;

  if not found or guest_event_id is distinct from contest_event_id then
    raise exception 'Finals contest participant must belong to the same event.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

create trigger event_finals_contest_participants_enforce_scope
before insert or update of contest_id, event_guest_id
on public.event_finals_contest_participants
for each row
execute function app_private.event_finals_contest_participants_enforce_scope();

create or replace function app_private.event_finals_champions_slots_enforce_scope()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_event_id uuid;
  guest_event_id uuid;
  source_bonus_round_id uuid;
begin
  select bonus_round.event_id
  into bonus_event_id
  from public.event_bonus_rounds as bonus_round
  where bonus_round.id = new.bonus_round_id;

  if not found then
    raise exception 'Finals Champions slot root was not found.'
      using errcode = 'P0001';
  end if;

  if new.event_guest_id is not null then
    select guest.event_id
    into guest_event_id
    from public.event_guests as guest
    where guest.id = new.event_guest_id;

    if not found or guest_event_id is distinct from bonus_event_id then
      raise exception 'Finals Champions slot guest must belong to the same event.'
        using errcode = 'P0001';
    end if;
  end if;

  if new.source_contest_id is not null then
    select contest.bonus_round_id
    into source_bonus_round_id
    from public.event_finals_contests as contest
    where contest.id = new.source_contest_id;

    if not found or source_bonus_round_id is distinct from new.bonus_round_id then
      raise exception 'Finals Champions slot source contest must belong to the same Finals root.'
        using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

create trigger event_finals_champions_slots_enforce_scope
before insert or update of bonus_round_id, event_guest_id, source_contest_id
on public.event_finals_champions_slots
for each row
execute function app_private.event_finals_champions_slots_enforce_scope();

alter table public.event_seating_assignments
add column if not exists finals_contest_id uuid;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_finals_contest_event_fk;
alter table public.event_seating_assignments
add constraint event_seating_assignments_finals_contest_event_fk
foreign key (finals_contest_id, event_id)
references public.event_finals_contests(id, event_id)
on delete set null (finals_contest_id);

create index event_seating_assignments_finals_contest_idx
  on public.event_seating_assignments (finals_contest_id, event_table_id, status);

alter table public.table_sessions
add column if not exists finals_contest_id uuid;

alter table public.table_sessions
drop constraint if exists table_sessions_finals_contest_event_fk;
alter table public.table_sessions
add constraint table_sessions_finals_contest_event_fk
foreign key (finals_contest_id, event_id)
references public.event_finals_contests(id, event_id)
on delete set null (finals_contest_id);

create index table_sessions_finals_contest_idx
  on public.table_sessions (finals_contest_id, status);

create or replace function app_private.finals_session_matches_assignments(
  target_session_id uuid,
  target_event_id uuid,
  target_bonus_round_id uuid,
  target_bonus_table_role text,
  target_event_table_id uuid,
  target_assignment_round integer,
  target_finals_contest_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.table_sessions as session
    where session.id = target_session_id
      and session.event_id = target_event_id
      and session.bonus_round_id = target_bonus_round_id
      and session.bonus_table_role = target_bonus_table_role
      and session.event_table_id = target_event_table_id
      and session.assignment_round = target_assignment_round
      and session.finals_contest_id is not distinct from target_finals_contest_id
      and session.status in ('active', 'paused', 'completed')
      and (
        select count(*)
        from public.table_session_seats as seat
        where seat.table_session_id = session.id
      ) = (
        select count(*)
        from public.event_seating_assignments as assignment
        where assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
      )
      and not exists (
        select 1
        from public.table_session_seats as seat
        left join public.event_seating_assignments as assignment
          on assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
          and assignment.seat_index = seat.seat_index
          and assignment.event_guest_id = seat.event_guest_id
        where seat.table_session_id = session.id
          and assignment.id is null
      )
      and not exists (
        select 1
        from public.event_seating_assignments as assignment
        left join public.table_session_seats as seat
          on seat.table_session_id = session.id
          and seat.seat_index = assignment.seat_index
          and seat.event_guest_id = assignment.event_guest_id
        where assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
          and seat.table_session_id is null
      )
  );
$$;

drop trigger if exists event_finals_contests_touch_updated_at
  on public.event_finals_contests;
create trigger event_finals_contests_touch_updated_at
before update on public.event_finals_contests
for each row
execute function app_private.touch_updated_at();

alter table public.event_finals_contests enable row level security;
alter table public.event_finals_contest_participants enable row level security;
alter table public.event_finals_champions_slots enable row level security;
alter table public.event_finals_eligible_snapshot enable row level security;

create policy event_finals_eligible_snapshot_owner_or_staff_read
on public.event_finals_eligible_snapshot
for select
to authenticated
using (app_private.can_view_event(event_id));

revoke insert, update, delete, truncate, references, trigger
on public.event_finals_eligible_snapshot from anon, authenticated;
grant select on public.event_finals_eligible_snapshot to authenticated;

create policy event_finals_contests_owner_or_staff_read
on public.event_finals_contests
for select
to authenticated
using (app_private.can_view_event(event_id));

create policy event_finals_contest_participants_owner_or_staff_read
on public.event_finals_contest_participants
for select
to authenticated
using (
  exists (
    select 1
    from public.event_finals_contests as contest
    where contest.id = event_finals_contest_participants.contest_id
      and app_private.can_view_event(contest.event_id)
  )
);

create policy event_finals_champions_slots_owner_or_staff_read
on public.event_finals_champions_slots
for select
to authenticated
using (
  exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.id = event_finals_champions_slots.bonus_round_id
      and app_private.can_view_event(bonus_round.event_id)
  )
);

-- Finals orchestration state is server-owned. Event operators can read it, but
-- all mutations must pass through the security-definer orchestration RPCs.
revoke insert, update, delete, truncate, references, trigger
on public.event_finals_contests,
  public.event_finals_contest_participants,
  public.event_finals_champions_slots
from anon, authenticated;

grant select on public.event_finals_contests,
  public.event_finals_contest_participants,
  public.event_finals_champions_slots
to authenticated;

create or replace function app_private.finals_format_for_count(
  eligible_count integer
)
returns text
language sql
immutable
strict
set search_path = public
as $$
  select case
    when eligible_count between 2 and 4 then 'champions_only'
    when eligible_count = 5 then 'automatic_redemption'
    when eligible_count in (6, 7) then 'redemption_advancement'
    when eligible_count >= 8 then 'parallel_finals'
    else null
  end;
$$;

create or replace function app_private.finals_direct_slot_count(
  eligible_count integer
)
returns integer
language sql
immutable
strict
set search_path = public
as $$
  select case
    when eligible_count between 2 and 4 then eligible_count
    when eligible_count = 5 then 4
    when eligible_count = 6 then 2
    when eligible_count = 7 then 3
    when eligible_count >= 8 then 4
    else 0
  end;
$$;

create or replace function app_private.finals_standings_snapshot(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  total_points integer,
  hands_played integer,
  standing_rank integer,
  seed_rank integer
)
language sql
stable
security definer
set search_path = public
as $$
  with scored_hands as (
    select score.hands_played
    from public.event_score_totals as score
    join public.event_guests as guest
      on guest.id = score.event_guest_id
      and guest.event_id = score.event_id
    where score.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
      and score.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil(
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        ) * 0.5
      )::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  eligible as (
    select
      guest.id as event_guest_id,
      guest.display_name,
      score.total_points,
      score.hands_played
    from public.event_score_totals as score
    join public.event_guests as guest
      on guest.id = score.event_guest_id
      and guest.event_id = score.event_id
    cross join minimum
    where score.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
      and score.hands_played >= minimum.minimum_hands_played
  )
  select
    eligible.event_guest_id,
    eligible.display_name,
    eligible.total_points,
    eligible.hands_played,
    rank() over (order by eligible.total_points desc)::integer as standing_rank,
    row_number() over (
      order by eligible.total_points desc, eligible.display_name, eligible.event_guest_id
    )::integer as seed_rank
  from eligible
  order by seed_rank;
$$;

create or replace function app_private.finals_preview_token(
  target_event_id uuid
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select md5(
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', snapshot.event_guest_id,
          'display_name', snapshot.display_name,
          'total_points', snapshot.total_points,
          'hands_played', snapshot.hands_played,
          'standing_rank', snapshot.standing_rank,
          'seed_rank', snapshot.seed_rank
        ) order by snapshot.seed_rank
      )::text,
      '[]'
    )
  )
  from app_private.finals_standings_snapshot(target_event_id) as snapshot;
$$;

create or replace function public.preview_event_finals(
  target_event_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  eligible_count integer;
  finals_format text;
  direct_slot_count integer;
  cutoff_points integer;
  cutoff_min_seed integer;
  cutoff_max_seed integer;
  redemption_players_value jsonb := '[]'::jsonb;
  cutoff_tie_players_value jsonb := '[]'::jsonb;
  order_copy_value jsonb := '[]'::jsonb;
  available_table_ids_value jsonb := '[]'::jsonb;
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select count(*)::integer
  into eligible_count
  from app_private.finals_standings_snapshot(target_event_id);

  finals_format := app_private.finals_format_for_count(eligible_count);
  direct_slot_count := app_private.finals_direct_slot_count(eligible_count);

  select coalesce(
    jsonb_agg(event_table.id order by event_table.display_order, event_table.id),
    '[]'::jsonb
  )
  into available_table_ids_value
  from public.event_tables as event_table
  join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
  where event_table.event_id = target_event_id
    and tag.default_tag_type = 'table'
    and tag.status = 'active'
    and not exists (
      select 1
      from public.table_sessions as session
      where session.event_table_id = event_table.id
        and session.status in ('active', 'paused')
    );

  select snapshot.total_points
  into cutoff_points
  from app_private.finals_standings_snapshot(target_event_id) as snapshot
  where snapshot.seed_rank = direct_slot_count;

  if cutoff_points is not null then
    select min(snapshot.seed_rank), max(snapshot.seed_rank)
    into cutoff_min_seed, cutoff_max_seed
    from app_private.finals_standings_snapshot(target_event_id) as snapshot
    where snapshot.total_points = cutoff_points;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_guest_id', snapshot.event_guest_id,
        'display_name', snapshot.display_name,
        'seed_rank', snapshot.seed_rank,
        'total_points', snapshot.total_points
      ) order by snapshot.seed_rank
    ),
    '[]'::jsonb
  )
  into redemption_players_value
  from app_private.finals_standings_snapshot(target_event_id) as snapshot
  where (eligible_count = 5 and snapshot.seed_rank = 5)
    or (eligible_count in (6, 7) and snapshot.seed_rank > direct_slot_count)
    or (eligible_count >= 8 and snapshot.seed_rank > eligible_count - 4);

  if cutoff_min_seed <= direct_slot_count
    and cutoff_max_seed > direct_slot_count then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', snapshot.event_guest_id,
          'display_name', snapshot.display_name,
          'seed_rank', snapshot.seed_rank,
          'total_points', snapshot.total_points
        ) order by snapshot.seed_rank
      ),
      '[]'::jsonb
    )
    into cutoff_tie_players_value
    from app_private.finals_standings_snapshot(target_event_id) as snapshot
    where snapshot.total_points = cutoff_points;
  end if;

  order_copy_value := case finals_format
    when 'champions_only' then jsonb_build_array(
      'Table of Champions starts immediately.'
    )
    when 'automatic_redemption' then jsonb_build_array(
      'Seeds 1-4 start Table of Champions.',
      'Fifth place is the Redemption winner; no Redemption table is played.'
    )
    when 'redemption_advancement' then jsonb_build_array(
      'Table of Redemption starts first.',
      case when eligible_count = 6
        then 'First and second place advance to Table of Champions.'
        else 'The winner advances to Table of Champions.'
      end
    )
    when 'parallel_finals' then jsonb_build_array(
      'Table of Champions and Table of Redemption start together.'
    )
    else jsonb_build_array()
  end;

  return jsonb_build_object(
    'preview_token', app_private.finals_preview_token(target_event_id),
    'eligible_player_count', eligible_count,
    'format', finals_format,
    'direct_slots', direct_slot_count,
    'redemption_players', redemption_players_value,
    'cutoff_tie_players', cutoff_tie_players_value,
    'requires_champions_table', eligible_count >= 2,
    'requires_redemption_table', eligible_count >= 6,
    'available_table_ids', available_table_ids_value,
    'order_copy', order_copy_value
  );
end;
$$;

create or replace function public.get_event_finals_state(
  target_event_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  champions_slots_value jsonb := '[]'::jsonb;
  contests_value jsonb := '[]'::jsonb;
  allowed_actions_value jsonb := '[]'::jsonb;
  available_table_ids_value jsonb := '[]'::jsonb;
  champion_value jsonb;
  redemption_winner_value jsonb;
begin
  if not app_private.can_view_event(target_event_id) then
    raise exception 'Event not found for current user.'
      using errcode = 'P0001';
  end if;

  select bonus_round.*
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
  order by bonus_round.assignment_round desc, bonus_round.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'flow_version', null,
      'state_version', 0,
      'format', null,
      'overall_status', 'not_started',
      'eligible_player_count', null,
      'champions_slots', jsonb_build_array(),
      'contests', jsonb_build_array(),
      'allowed_actions', jsonb_build_array(),
      'blocking_reason', null,
      'champion', null,
      'redemption_winner', null
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'slot_index', slot.slot_index,
        'event_guest_id', slot.event_guest_id,
        'display_name', guest.display_name,
        'qualification_method', slot.qualification_method,
        'source_contest_id', slot.source_contest_id,
        'source_finish_order', slot.source_finish_order
      ) order by slot.slot_index
    ),
    '[]'::jsonb
  )
  into champions_slots_value
  from public.event_finals_champions_slots as slot
  left join public.event_guests as guest
    on guest.id = slot.event_guest_id
  where slot.bonus_round_id = bonus_round_row.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', contest.id,
        'contest_type', contest.contest_type,
        'title', case contest.contest_type
          when 'direct_qualification_tiebreak' then 'Direct Qualification Tiebreak'
          when 'table_of_redemption' then 'Table of Redemption'
          when 'redemption_advancement_tiebreak' then 'Redemption Tiebreak'
          when 'redemption_winner_tiebreak' then 'Redemption Winner Tiebreak'
          when 'table_of_champions' then 'Table of Champions'
          when 'champions_sudden_death' then 'Champions Sudden Death'
        end,
        'status', contest.status,
        'table_label', event_table.label,
        'table_session_id', contest.table_session_id,
        'slots_to_fill', contest.slots_to_fill,
        'slot_start_index', contest.slot_start_index,
        'sequence_number', contest.sequence_number,
        'started_at', contest.started_at,
        'completed_at', contest.completed_at,
        'participants', (
          select coalesce(
            jsonb_agg(
              jsonb_build_object(
                'event_guest_id', participant.event_guest_id,
                'display_name', participant_guest.display_name,
                'entry_seed', participant.entry_seed,
                'seat_index', participant.seat_index,
                'outcome', participant.outcome,
                'advanced_champions_slot', participant.advanced_champions_slot,
                'outcome_order', participant.outcome_order
              ) order by participant.entry_seed
            ),
            '[]'::jsonb
          )
          from public.event_finals_contest_participants as participant
          join public.event_guests as participant_guest
            on participant_guest.id = participant.event_guest_id
          where participant.contest_id = contest.id
        )
      ) order by contest.sequence_number
    ),
    '[]'::jsonb
  )
  into contests_value
  from public.event_finals_contests as contest
  left join public.event_tables as event_table
    on event_table.id = contest.event_table_id
  where contest.bonus_round_id = bonus_round_row.id;

  if bonus_round_row.flow_version = 'orchestrated'
    and bonus_round_row.status = 'active'
    and app_private.can_manage_event(target_event_id)
  then
    select coalesce(
      jsonb_agg(event_table.id order by event_table.display_order, event_table.id),
      '[]'::jsonb
    )
    into available_table_ids_value
    from public.event_tables as event_table
    join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
    where event_table.event_id = target_event_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
      and not exists (
        select 1
        from public.table_sessions as session
        where session.event_table_id = event_table.id
          and session.status in ('active', 'paused')
      );

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'action', 'start_contest',
          'label', case contest.contest_type
            when 'direct_qualification_tiebreak' then 'Start Direct Qualification Tiebreak'
            when 'table_of_redemption' then 'Start Table of Redemption'
            when 'redemption_advancement_tiebreak' then 'Start Redemption Tiebreak'
            when 'redemption_winner_tiebreak' then 'Start Redemption Winner Tiebreak'
            when 'table_of_champions' then 'Start Table of Champions'
            when 'champions_sudden_death' then 'Start Champions Sudden Death'
          end,
          'contest_id', contest.id,
          'table_id', case
            when available_table_ids_value ? contest.event_table_id::text
              then contest.event_table_id
            else null
          end,
          'available_table_ids', available_table_ids_value,
          'expected_state_version', bonus_round_row.state_version
        ) order by contest.sequence_number, contest.contest_type, contest.id
      ),
      '[]'::jsonb
    )
    into allowed_actions_value
    from public.event_finals_contests as contest
    where contest.bonus_round_id = bonus_round_row.id
      and contest.status = 'ready';
  end if;

  select jsonb_build_object(
    'event_guest_id', guest.id,
    'display_name', guest.display_name
  )
  into champion_value
  from public.event_guests as guest
  where guest.id = bonus_round_row.champion_event_guest_id;

  select jsonb_build_object(
    'event_guest_id', guest.id,
    'display_name', guest.display_name,
    'resolution_method', bonus_round_row.redemption_resolution_method
  )
  into redemption_winner_value
  from public.event_guests as guest
  where guest.id = bonus_round_row.redemption_winner_event_guest_id;

  return jsonb_build_object(
    'flow_version', bonus_round_row.flow_version,
    'state_version', bonus_round_row.state_version,
    'format', bonus_round_row.format,
    'overall_status', case
      when bonus_round_row.status = 'completed' then 'complete'
      else bonus_round_row.status
    end,
    'eligible_player_count', bonus_round_row.eligible_player_count,
    'champions_slots', champions_slots_value,
    'contests', contests_value,
    'allowed_actions', allowed_actions_value,
    'blocking_reason', null,
    'champion', champion_value,
    'redemption_winner', redemption_winner_value
  );
end;
$$;

revoke all on function app_private.finals_format_for_count(integer) from public;
revoke all on function app_private.finals_session_matches_assignments(
  uuid, uuid, uuid, text, uuid, integer, uuid
) from public;
revoke all on function app_private.finals_direct_slot_count(integer) from public;
revoke all on function app_private.finals_standings_snapshot(uuid) from public;
revoke all on function app_private.finals_preview_token(uuid) from public;
revoke all on function app_private.event_finals_contests_enforce_scope() from public;
revoke all on function app_private.event_finals_contest_participants_enforce_scope() from public;
revoke all on function app_private.event_finals_champions_slots_enforce_scope() from public;
revoke all on function public.preview_event_finals(uuid) from public;
revoke all on function public.get_event_finals_state(uuid) from public;

grant execute on function public.preview_event_finals(uuid) to authenticated;
grant execute on function public.get_event_finals_state(uuid) to authenticated;

select pg_notify('pgrst', 'reload schema');
