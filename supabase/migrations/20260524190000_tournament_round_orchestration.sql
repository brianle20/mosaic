-- Tournament round orchestration.

create table if not exists public.event_tournament_rounds (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  round_number integer not null check (round_number > 0),
  scoring_phase text not null check (scoring_phase in ('tournament', 'bonus')),
  status text not null default 'active'
    check (status in ('seating', 'active', 'complete', 'cancelled')),
  assignment_round integer not null check (assignment_round > 0),
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by_user_id uuid references public.users(id) on delete set null,
  constraint event_tournament_rounds_event_round_phase_unique
    unique (event_id, round_number, scoring_phase),
  constraint event_tournament_rounds_event_assignment_round_unique
    unique (event_id, assignment_round),
  constraint event_tournament_rounds_id_event_unique
    unique (id, event_id)
);

create unique index if not exists event_tournament_rounds_one_current_idx
  on public.event_tournament_rounds (event_id, scoring_phase)
  where status in ('seating', 'active');

drop trigger if exists event_tournament_rounds_touch_updated_at
  on public.event_tournament_rounds;
create trigger event_tournament_rounds_touch_updated_at
before update on public.event_tournament_rounds
for each row
execute function app_private.touch_updated_at();

alter table public.event_tournament_rounds enable row level security;

drop policy if exists event_tournament_rounds_owner_all
  on public.event_tournament_rounds;
create policy event_tournament_rounds_owner_all
on public.event_tournament_rounds
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

alter table public.event_seating_assignments
add column if not exists tournament_round_id uuid;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_tournament_round_event_fk;
alter table public.event_seating_assignments
add constraint event_seating_assignments_tournament_round_event_fk
foreign key (tournament_round_id, event_id)
references public.event_tournament_rounds(id, event_id)
on delete set null (tournament_round_id);

create index if not exists event_seating_assignments_tournament_round_idx
  on public.event_seating_assignments (tournament_round_id, event_table_id);

alter table public.table_sessions
add column if not exists tournament_round_id uuid;

alter table public.table_sessions
drop constraint if exists table_sessions_tournament_round_event_fk;
alter table public.table_sessions
add constraint table_sessions_tournament_round_event_fk
foreign key (tournament_round_id, event_id)
references public.event_tournament_rounds(id, event_id)
on delete set null (tournament_round_id);

alter table public.table_sessions
add column if not exists assignment_round integer;

create index if not exists table_sessions_tournament_round_idx
  on public.table_sessions (tournament_round_id, event_table_id, status);

create or replace function app_private.balanced_table_sizes(player_count integer)
returns integer[]
language plpgsql
security definer
set search_path = public
as $$
declare
  table_count integer;
  base_size integer;
  extra_players integer;
  sizes integer[] := '{}';
begin
  if player_count < 2 then
    raise exception 'At least 2 qualified, checked-in, tagged players are required.'
      using errcode = 'P0001';
  end if;

  table_count := ceil(player_count / 4.0)::integer;
  loop
    base_size := floor(player_count::numeric / table_count)::integer;
    extra_players := player_count - (base_size * table_count);
    exit when base_size >= 2;
    table_count := table_count - 1;
  end loop;

  for index_value in 1..table_count loop
    sizes := array_append(
      sizes,
      base_size + case when index_value <= extra_players then 1 else 0 end
    );
  end loop;

  return sizes;
end;
$$;

create or replace function public.get_tournament_round_summary(
  target_event_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  round_row public.event_tournament_rounds%rowtype;
  current_round_tables jsonb := '[]'::jsonb;
  other_tables jsonb := '[]'::jsonb;
  assigned_table_count integer := 0;
  complete_table_count integer := 0;
  active_table_count integer := 0;
  paused_table_count integer := 0;
  not_started_table_count integer := 0;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select *
  into round_row
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament'
    and tournament_round.status in ('seating', 'active')
  order by tournament_round.round_number desc, tournament_round.created_at desc
  limit 1;

  if round_row.id is null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_table_id', event_table.id,
          'table_label', event_table.label,
          'table_display_order', event_table.display_order,
          'status', 'other',
          'assigned_players', jsonb_build_array(),
          'active_session_id', null,
          'latest_ended_session_id', null
        )
        order by event_table.display_order asc, event_table.id asc
      ),
      '[]'::jsonb
    )
    into other_tables
    from public.event_tables as event_table
    where event_table.event_id = target_event_id;

    return jsonb_build_object(
      'round', null,
      'assigned_table_count', 0,
      'complete_table_count', 0,
      'active_table_count', 0,
      'paused_table_count', 0,
      'not_started_table_count', 0,
      'current_round_tables', jsonb_build_array(),
      'other_tables', other_tables
    );
  end if;

  with current_table_assignments as (
    select distinct
      assignment.event_table_id
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.tournament_round_id = round_row.id
      and assignment.status = 'active'
  ),
  current_table_summaries as (
    select
      event_table.id as event_table_id,
      event_table.label as table_label,
      event_table.display_order as table_display_order,
      active_session.id as active_session_id,
      latest_ended_session.id as latest_ended_session_id,
      case
        when active_session.status = 'active' then 'active'
        when active_session.status = 'paused' then 'paused'
        when latest_ended_session.id is not null then 'complete'
        else 'not_started'
      end as table_status,
      coalesce(assigned_players.players, '[]'::jsonb) as assigned_players
    from current_table_assignments
    join public.event_tables as event_table
      on event_table.id = current_table_assignments.event_table_id
      and event_table.event_id = target_event_id
    left join lateral (
      select session.id, session.status
      from public.table_sessions as session
      where session.event_id = target_event_id
        and session.event_table_id = event_table.id
        and session.tournament_round_id = round_row.id
        and session.scoring_phase = 'tournament'
        and session.status in ('active', 'paused')
      order by session.started_at desc, session.created_at desc
      limit 1
    ) as active_session on true
    left join lateral (
      select session.id
      from public.table_sessions as session
      where session.event_id = target_event_id
        and session.event_table_id = event_table.id
        and session.tournament_round_id = round_row.id
        and session.scoring_phase = 'tournament'
        and session.status in ('completed', 'ended_early', 'aborted')
      order by coalesce(session.ended_at, session.updated_at, session.created_at) desc
      limit 1
    ) as latest_ended_session on true
    left join lateral (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'event_guest_id', assignment.event_guest_id,
            'display_name', guest.display_name,
            'seat_index', assignment.seat_index
          )
          order by assignment.seat_index asc, guest.display_name asc, guest.id asc
        ),
        '[]'::jsonb
      ) as players
      from public.event_seating_assignments as assignment
      join public.event_guests as guest
        on guest.id = assignment.event_guest_id
        and guest.event_id = assignment.event_id
      where assignment.event_id = target_event_id
        and assignment.event_table_id = event_table.id
        and assignment.tournament_round_id = round_row.id
        and assignment.status = 'active'
    ) as assigned_players on true
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_table_id', table_row.event_table_id,
          'table_label', table_row.table_label,
          'table_display_order', table_row.table_display_order,
          'status', table_row.table_status,
          'assigned_players', table_row.assigned_players,
          'active_session_id', table_row.active_session_id,
          'latest_ended_session_id', table_row.latest_ended_session_id
        )
        order by table_row.table_display_order asc, table_row.event_table_id asc
      ),
      '[]'::jsonb
    ),
    count(*)::integer,
    count(*) filter (where table_row.table_status = 'complete')::integer,
    count(*) filter (where table_row.table_status = 'active')::integer,
    count(*) filter (where table_row.table_status = 'paused')::integer,
    count(*) filter (where table_row.table_status = 'not_started')::integer
  into
    current_round_tables,
    assigned_table_count,
    complete_table_count,
    active_table_count,
    paused_table_count,
    not_started_table_count
  from current_table_summaries as table_row;

  with current_table_assignments as (
    select distinct
      assignment.event_table_id
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.tournament_round_id = round_row.id
      and assignment.status = 'active'
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_table_id', event_table.id,
        'table_label', event_table.label,
        'table_display_order', event_table.display_order,
        'status', 'other',
        'assigned_players', jsonb_build_array(),
        'active_session_id', null,
        'latest_ended_session_id', null
      )
      order by event_table.display_order asc, event_table.id asc
    ),
    '[]'::jsonb
  )
  into other_tables
  from public.event_tables as event_table
  where event_table.event_id = target_event_id
    and not exists (
      select 1
      from current_table_assignments
      where current_table_assignments.event_table_id = event_table.id
    );

  return jsonb_build_object(
    'round', jsonb_build_object(
      'id', round_row.id,
      'event_id', round_row.event_id,
      'round_number', round_row.round_number,
      'scoring_phase', round_row.scoring_phase,
      'status', round_row.status,
      'assignment_round', round_row.assignment_round,
      'started_at', round_row.started_at,
      'completed_at', round_row.completed_at
    ),
    'assigned_table_count', assigned_table_count,
    'complete_table_count', complete_table_count,
    'active_table_count', active_table_count,
    'paused_table_count', paused_table_count,
    'not_started_table_count', not_started_table_count,
    'current_round_tables', current_round_tables,
    'other_tables', other_tables
  );
end;
$$;

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
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  )
  select count(*)::integer
  into player_count
  from eligible_players;

  if player_count < 2 then
    raise exception 'At least 2 qualified, checked-in, tagged players are required.'
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
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
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
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.event_id = target_event_id
    order by event_table.display_order, event_table.id
    limit required_table_count
  ),
  eligible_players as (
    select distinct
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
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  ),
  randomized_players as (
    select
      eligible_players.event_guest_id,
      row_number() over (
        order by eligible_players.random_sort, eligible_players.event_guest_id
      )::integer - 1 as player_offset
    from eligible_players
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
    ready_tables.event_table_id,
    randomized_players.event_guest_id,
    (randomized_players.player_offset - table_ranges.start_offset)::integer,
    next_assignment_round,
    'random',
    'active',
    now(),
    auth.uid(),
    tournament_round_row.id
  from randomized_players
  join table_ranges
    on randomized_players.player_offset >= table_ranges.start_offset
    and randomized_players.player_offset
      < table_ranges.start_offset + table_ranges.table_size
  join ready_tables
    on ready_tables.table_number = table_ranges.table_number;

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

create or replace function app_private.avoid_identical_tournament_round_seating()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
  target_tournament_round_id uuid;
  target_assignment_round integer;
  assignment_count integer;
  new_order uuid[];
  previous_order uuid[];
begin
  if pg_trigger_depth() > 1 then
    return null;
  end if;

  if exists (
    select 1
    from new_assignments as new_assignment
    where new_assignment.tournament_round_id is null
      or new_assignment.assignment_type <> 'random'
  ) then
    return null;
  end if;

  select
    (array_agg(new_assignment.event_id))[1],
    (array_agg(new_assignment.tournament_round_id))[1],
    min(new_assignment.assignment_round),
    count(*)::integer,
    array_agg(
      new_assignment.event_guest_id
      order by event_table.display_order, new_assignment.seat_index,
        new_assignment.id
    )
  into
    target_event_id,
    target_tournament_round_id,
    target_assignment_round,
    assignment_count,
    new_order
  from new_assignments as new_assignment
  join public.event_tables as event_table
    on event_table.id = new_assignment.event_table_id;

  if assignment_count < 2 then
    return null;
  end if;

  if exists (
    select 1
    from new_assignments as new_assignment
    where new_assignment.event_id <> target_event_id
      or new_assignment.tournament_round_id <> target_tournament_round_id
      or new_assignment.assignment_round <> target_assignment_round
  ) then
    return null;
  end if;

  select array_agg(
    previous_assignment.event_guest_id
    order by event_table.display_order, previous_assignment.seat_index,
      previous_assignment.id
  )
  into previous_order
  from public.event_seating_assignments as previous_assignment
  join public.event_tables as event_table
    on event_table.id = previous_assignment.event_table_id
  where previous_assignment.event_id = target_event_id
    and previous_assignment.assignment_round = target_assignment_round - 1
    and previous_assignment.assignment_type = 'random';

  if new_order = previous_order then
    delete from public.event_seating_assignments as assignment
    using new_assignments as new_assignment
    where assignment.id = new_assignment.id;

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
      assigned_by_user_id,
      created_at,
      updated_at,
      tournament_round_id
    )
    select
      ordered_new.event_id,
      ordered_new.event_table_id,
      case
        when ordered_new.slot_number = 1 then new_order[assignment_count]
        else new_order[ordered_new.slot_number - 1]
      end,
      ordered_new.seat_index,
      ordered_new.assignment_round,
      ordered_new.assignment_type,
      ordered_new.bonus_round_id,
      ordered_new.bonus_table_role,
      ordered_new.seed_rank,
      ordered_new.status,
      ordered_new.assigned_at,
      ordered_new.assigned_by_user_id,
      ordered_new.created_at,
      ordered_new.updated_at,
      ordered_new.tournament_round_id
    from (
      select
        new_assignment.*,
        row_number() over (
          order by event_table.display_order, new_assignment.seat_index,
            new_assignment.id
        )::integer as slot_number
      from new_assignments as new_assignment
      join public.event_tables as event_table
        on event_table.id = new_assignment.event_table_id
    ) as ordered_new
    order by ordered_new.slot_number;
  end if;

  return null;
end;
$$;

drop trigger if exists event_seating_assignments_avoid_identical_tournament_round
  on public.event_seating_assignments;
create trigger event_seating_assignments_avoid_identical_tournament_round
after insert on public.event_seating_assignments
referencing new table as new_assignments
for each statement
execute function app_private.avoid_identical_tournament_round_seating();

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
language sql
security definer
set search_path = public
as $$
  select
    generated_round.id,
    generated_round.event_id,
    generated_round.event_table_id,
    generated_round.table_label,
    generated_round.table_display_order,
    generated_round.event_guest_id,
    generated_round.guest_display_name,
    generated_round.seat_index,
    generated_round.assignment_round,
    generated_round.assignment_type,
    generated_round.bonus_round_id,
    generated_round.bonus_table_role,
    generated_round.seed_rank,
    generated_round.status,
    generated_round.assigned_at,
    generated_round.assigned_by_user_id,
    generated_round.created_at,
    generated_round.updated_at
  from public.generate_tournament_round(target_event_id) as generated_round;
$$;

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
  assignment_rows public.event_seating_assignments[];
  effective_scoring_phase text;
  initial_winds text[] := array['east', 'south', 'west', 'north'];
  seat_assignment_count integer;
begin
  table_row := app_private.require_owned_table(target_event_table_id);
  perform app_private.require_event_for_scoring(table_row.event_id);

  select *
  into event_row
  from public.events
  where id = table_row.event_id;

  effective_scoring_phase := coalesce(
    event_row.current_scoring_phase,
    'qualification'
  );

  if effective_scoring_phase = 'qualification' then
    raise exception 'Assigned seating is only available after qualification.'
      using errcode = 'P0001';
  end if;

  if scanned_table_uid is not null then
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

  select array_agg(assignment order by assignment.seat_index asc)
  into assignment_rows
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.status = 'active';

  if assignment_rows is null
    or not (array_length(assignment_rows, 1) between 2 and 4)
  then
    raise exception 'Two to four active seating assignments are required to start this assigned table.'
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
    where assignment.assignment_round is distinct from assignment_rows[1].assignment_round
  ) then
    raise exception 'All active seating assignments must use the same assignment round.'
      using errcode = 'P0001';
  end if;

  if assignment_rows[1].assignment_type = 'bonus' then
    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type is distinct from assignment_rows[1].assignment_type
        or assignment.bonus_round_id is distinct from assignment_rows[1].bonus_round_id
        or assignment.bonus_table_role is distinct from assignment_rows[1].bonus_table_role
    ) then
      raise exception 'All active bonus assignments must use the same bonus metadata.'
        using errcode = 'P0001';
    end if;
  elsif assignment_rows[1].tournament_round_id is null
    or exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type is distinct from assignment_rows[1].assignment_type
        or assignment.tournament_round_id is distinct from assignment_rows[1].tournament_round_id
    )
  then
    raise exception 'All active tournament assignments must belong to the same tournament round.'
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
    where existing_session.event_id = table_row.event_id
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
    case
      when assignment_rows[1].assignment_type = 'bonus' then 'bonus'
      else effective_scoring_phase
    end,
    assignment_rows[1].bonus_round_id,
    assignment_rows[1].bonus_table_role,
    assignment_rows[1].tournament_round_id,
    assignment_rows[1].assignment_round,
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  for seat_assignment_count in 1..array_length(assignment_rows, 1) loop
    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values (
      session_row.id,
      assignment_rows[seat_assignment_count].seat_index,
      initial_winds[assignment_rows[seat_assignment_count].seat_index + 1],
      assignment_rows[seat_assignment_count].event_guest_id
    );
  end loop;

  return session_row;
end;
$$;

grant execute on function public.get_tournament_round_summary(uuid)
  to authenticated;
grant execute on function public.generate_tournament_round(uuid)
  to authenticated;
grant execute on function public.start_assigned_table_session(uuid, text)
  to authenticated;

alter table public.event_bonus_rounds
alter column redemption_table_id drop not null;

create or replace function public.generate_bonus_round_seating_assignments(
  target_event_id uuid,
  champions_table_id uuid,
  redemption_table_id uuid default null
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
    raise exception 'Finals tables must be different.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_tournament_rounds as current_round
    join public.table_sessions as session
      on session.event_id = current_round.event_id
      and session.tournament_round_id = current_round.id
      and session.scoring_phase = 'tournament'
      and session.status in ('active', 'paused')
    where current_round.event_id = target_event_id
      and current_round.scoring_phase = 'tournament'
      and current_round.status in ('seating', 'active')
  ) then
    raise exception 'End active or paused current tournament round sessions before beginning finals.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
  ) then
    raise exception 'Active finals already exist for this event.'
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

  if redemption_table_id is not null
    and not exists (
      select 1
      from public.event_tables as event_table
      join public.nfc_tags as tag
        on tag.id = event_table.nfc_tag_id
        and tag.default_tag_type = 'table'
        and tag.status = 'active'
      where event_table.id = redemption_table_id
        and event_table.event_id = target_event_id
    )
  then
    raise exception 'Table of Redemption must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  perform app_private.refresh_event_score_totals(target_event_id);

  with scored_hands as (
    select leaderboard.hands_played
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil((
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        )
      ) * 0.5)::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  ranked_players as (
    select distinct
      leaderboard.event_guest_id
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
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
    where leaderboard.hands_played >= minimum.minimum_hands_played
  )
  select count(*)::integer
  into ranked_player_count
  from ranked_players;

  if ranked_player_count = 0 then
    raise exception 'No prize-eligible players are available for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count = 1 then
    raise exception 'At least 2 prize-eligible players are required for finals.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count >= 6 and redemption_table_id is null then
    raise exception 'A second ready table is required for Table of Redemption.'
      using errcode = 'P0001';
  end if;

  if ranked_player_count between 2 and 5 then
    redemption_table_id := null;
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

  with scored_hands as (
    select leaderboard.hands_played
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.hands_played > 0
  ),
  minimum as (
    select greatest(
      1,
      ceil((
        coalesce(
          percentile_cont(0.5) within group (order by hands_played),
          0
        )
      ) * 0.5)::integer
    ) as minimum_hands_played
    from scored_hands
  ),
  ranked_players as (
    select
      leaderboard.event_guest_id,
      (row_number() over (
        order by leaderboard.rank asc, leaderboard.total_points desc,
          leaderboard.display_name asc, leaderboard.event_guest_id asc
      ))::integer as seed_rank,
      count(*) over ()::integer as player_count
    from public.get_event_leaderboard(target_event_id) as leaderboard
    cross join minimum
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
    where leaderboard.hands_played >= minimum.minimum_hands_played
  ),
  champions as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      case
        when ranked_player_count >= 4 then
          case
            when ranked_players.seed_rank = 4 then 0
            when ranked_players.seed_rank = 3 then 1
            when ranked_players.seed_rank = 2 then 2
            when ranked_players.seed_rank = 1 then 3
          end
        else ranked_players.seed_rank - 1
      end as seat_index
    from ranked_players
    where ranked_players.seed_rank between 1 and least(4, ranked_player_count)
  ),
  redemption as (
    select
      ranked_players.event_guest_id,
      ranked_players.seed_rank,
      (row_number() over (order by ranked_players.seed_rank asc))::integer - 1
        as seat_index
    from ranked_players
    where redemption_table_id is not null
      and ranked_players.seed_rank > 4
    order by ranked_players.seed_rank asc
    limit 4
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

grant execute on function public.generate_bonus_round_seating_assignments(uuid, uuid, uuid)
  to authenticated;

create or replace function app_private.tournament_round_orchestration_finals_policy_placeholder()
returns text[]
language sql
stable
security definer
set search_path = public
as $$
  select array[
    'No prize-eligible players are available for finals.',
    'table_of_champions',
    'table_of_redemption'
  ]::text[];
$$;

select pg_notify('pgrst', 'reload schema');
