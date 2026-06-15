create or replace function public.start_tournament_round(
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
  existing_round public.event_tournament_rounds%rowtype;
  session_row public.table_sessions%rowtype;
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
    and event.current_scoring_phase in ('qualification', 'tournament');

  if event_row.id is null then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  for session_row in
    select session.*
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.scoring_phase = 'qualification'
      and session.status in ('active', 'paused')
    order by session.started_at, session.id
  loop
    perform public.end_table_session(
      session_row.id,
      'tournament_started'
    );
  end loop;

  if event_row.current_scoring_phase = 'qualification' then
    update public.events as event
    set
      current_scoring_phase = 'tournament',
      updated_at = now(),
      row_version = row_version + 1
    where event.id = target_event_id;
  end if;

  select *
  into existing_round
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament'
    and tournament_round.status = 'seating'
    and not exists (
      select 1
      from public.table_sessions as existing_session
      where existing_session.event_id = target_event_id
        and existing_session.tournament_round_id = tournament_round.id
        and existing_session.scoring_phase = 'tournament'
        and existing_session.status in (
          'active',
          'paused',
          'completed',
          'ended_early',
          'aborted'
        )
    )
    and exists (
      select 1
      from public.event_seating_assignments as assignment
      where assignment.event_id = target_event_id
        and assignment.tournament_round_id = tournament_round.id
        and assignment.assignment_type = 'random'
        and assignment.status = 'active'
    )
  order by tournament_round.round_number desc,
    tournament_round.created_at desc
  limit 1
  for update;

  if existing_round.id is not null then
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
      and assignment.tournament_round_id = existing_round.id
      and assignment.assignment_type = 'random'
      and assignment.status = 'active'
    order by event_table.display_order asc,
      event_table.label asc,
      event_table.id asc,
      assignment.seat_index asc;

    return;
  end if;

  return query
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
    generated_round.updated_at,
    generated_round.tournament_round_id
  from public.generate_tournament_round(target_event_id) as generated_round;
end;
$$;

grant execute on function public.start_tournament_round(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
