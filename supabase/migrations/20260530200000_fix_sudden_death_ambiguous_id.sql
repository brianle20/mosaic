-- Fix ambiguous PL/pgSQL id reference when starting Table of Champions sudden death.

create or replace function public.start_bonus_round_sudden_death(
  target_event_id uuid,
  sudden_death_table_id uuid
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
  bonus_round_row public.event_bonus_rounds%rowtype;
  champions_session_id uuid;
  next_assignment_round integer;
  tied_top_count integer;
  selected_sudden_death_table_id uuid := sudden_death_table_id;
begin
  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status = 'active'
    and bonus_round.sudden_death_status = 'required'
  order by bonus_round.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Sudden death is not required for this event.'
      using errcode = 'P0001';
  end if;

  if not app_private.is_event_owner(bonus_round_row.event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = selected_sudden_death_table_id
      and event_table.event_id = bonus_round_row.event_id
  ) then
    raise exception 'Sudden death table must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_table_id = selected_sudden_death_table_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End the active or paused session at this table before starting sudden death.'
      using errcode = 'P0001';
  end if;

  select session.id
  into champions_session_id
  from public.table_sessions as session
  where session.bonus_round_id = bonus_round_row.id
    and session.bonus_table_role = 'table_of_champions'
    and session.status = 'completed'
  order by coalesce(session.ended_at, session.started_at, session.created_at) desc
  limit 1;

  if champions_session_id is null then
    raise exception 'Complete the Table of Champions before starting sudden death.'
      using errcode = 'P0001';
  end if;

  with scores as (
    select *
    from app_private.table_of_champions_scores(
      bonus_round_row.id,
      champions_session_id
    )
  ),
  max_score as (
    select max(scores.bonus_score_points) as value
    from scores
  ),
  tied_top_players as (
    select scores.event_guest_id
    from scores
    cross join max_score
    where scores.bonus_score_points = max_score.value
  )
  select count(*)::integer
  into tied_top_count
  from tied_top_players;

  if tied_top_count not between 2 and 4 then
    raise exception 'Sudden death requires 2 to 4 tied top players.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = bonus_round_row.event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = bonus_round_row.event_id
    and assignment.event_table_id = selected_sudden_death_table_id
    and assignment.status = 'active';

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_sudden_death'
    and assignment.status = 'active';

  with scores as (
    select *
    from app_private.table_of_champions_scores(
      bonus_round_row.id,
      champions_session_id
    )
  ),
  max_score as (
    select max(scores.bonus_score_points) as value
    from scores
  ),
  tied_top_players as (
    select
      scores.event_guest_id,
      scores.seed_rank,
      row_number() over (order by random(), scores.event_guest_id)::integer - 1
        as seat_index
    from scores
    cross join max_score
    where scores.bonus_score_points = max_score.value
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
    bonus_round_row.event_id,
    selected_sudden_death_table_id,
    tied_top_players.event_guest_id,
    tied_top_players.seat_index,
    next_assignment_round,
    'bonus',
    bonus_round_row.id,
    'table_of_champions_sudden_death',
    tied_top_players.seed_rank,
    'active',
    now(),
    auth.uid()
  from tied_top_players;

  update public.event_bonus_rounds as bonus_round
  set
    champion_resolution_method = 'sudden_death',
    sudden_death_status = 'active',
    sudden_death_table_id = selected_sudden_death_table_id,
    sudden_death_session_id = null
  where bonus_round.id = bonus_round_row.id;

  return query
  select *
  from public.get_event_seating_assignments(
    bonus_round_row.event_id
  ) as assignment
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_sudden_death';
end;
$$;

grant execute on function public.start_bonus_round_sudden_death(uuid, uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
