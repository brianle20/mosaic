-- Reconcile completed tournament rounds after their table sessions finish.

create or replace function app_private.complete_finished_tournament_rounds(
  target_event_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.event_tournament_rounds as round
  set
    status = 'complete',
    completed_at = coalesce(round.completed_at, now())
  where (target_event_id is null or round.event_id = target_event_id)
    and round.scoring_phase = 'tournament'
    and round.status in ('seating', 'active')
    and exists (
      select 1
      from public.event_seating_assignments as assignment
      where assignment.event_id = round.event_id
        and assignment.tournament_round_id = round.id
        and assignment.status = 'active'
    )
    and not exists (
      select 1
      from public.event_seating_assignments as assignment
      where assignment.event_id = round.event_id
        and assignment.tournament_round_id = round.id
        and assignment.status = 'active'
        and (
          exists (
            select 1
            from public.table_sessions as session
            where session.event_id = assignment.event_id
              and session.event_table_id = assignment.event_table_id
              and session.tournament_round_id = round.id
              and session.scoring_phase = round.scoring_phase
              and session.status in ('active', 'paused')
          )
          or not exists (
            select 1
            from public.table_sessions as session
            where session.event_id = assignment.event_id
              and session.event_table_id = assignment.event_table_id
              and session.tournament_round_id = round.id
              and session.scoring_phase = round.scoring_phase
              and session.status in ('completed', 'ended_early', 'aborted')
          )
        )
    );
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

  perform app_private.complete_finished_tournament_rounds(target_event_id);

  select *
  into round_row
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament'
    and tournament_round.status in ('seating', 'active', 'complete')
  order by
    case tournament_round.status
      when 'seating' then 0
      when 'active' then 1
      when 'complete' then 2
      else 3
    end,
    tournament_round.round_number desc,
    tournament_round.created_at desc
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

drop function if exists public.record_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean
);

create or replace function public.record_hand_result(
  target_table_session_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  inserted_hand public.hand_results%rowtype;
  next_hand_number integer;
begin
  session_row := app_private.require_owned_session(target_table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if session_row.status <> 'active' then
    raise exception 'Hands can only be recorded for active sessions.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  select coalesce(max(hand_number), 0) + 1
  into next_hand_number
  from public.hand_results
  where
    table_session_id = session_row.id
    and status = 'recorded';

  insert into public.hand_results (
    table_session_id,
    hand_number,
    result_type,
    winner_seat_index,
    win_type,
    discarder_seat_index,
    penalty_seat_index,
    fan_count,
    base_points,
    dealer_was_waiting_at_draw,
    east_seat_index_before_hand,
    east_seat_index_after_hand,
    dealer_rotated,
    session_completed_after_hand,
    status,
    entered_by_user_id,
    entered_at,
    correction_note
  )
  values (
    session_row.id,
    next_hand_number,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_penalty_seat_index,
    case
      when target_result_type = 'false_win_penalty' then 6
      else target_fan_count
    end,
    null,
    case
      when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
      else null
    end,
    session_row.current_dealer_seat_index,
    session_row.current_dealer_seat_index,
    false,
    false,
    'recorded',
    auth.uid(),
    now(),
    target_correction_note
  )
  returning *
  into inserted_hand;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into inserted_hand
  from public.hand_results
  where id = inserted_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    inserted_hand.id::text,
    'create',
    null,
    to_jsonb(inserted_hand)
  );

  return inserted_hand;
end;
$$;

drop function if exists public.edit_hand_result(
  uuid,
  text,
  integer,
  text,
  integer,
  integer,
  text,
  boolean
);

create or replace function public.edit_hand_result(
  target_hand_result_id uuid,
  target_result_type text,
  target_winner_seat_index integer default null,
  target_win_type text default null,
  target_discarder_seat_index integer default null,
  target_fan_count integer default null,
  target_correction_note text default null,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if existing_hand.status <> 'recorded' then
    raise exception 'Only recorded hands can be edited.'
      using errcode = 'P0001';
  end if;

  perform app_private.validate_hand_result_input(
    session_row.ruleset_id,
    target_result_type,
    target_winner_seat_index,
    target_win_type,
    target_discarder_seat_index,
    target_fan_count,
    target_dealer_was_waiting_at_draw,
    target_penalty_seat_index
  );

  update public.hand_results
  set
    result_type = target_result_type,
    winner_seat_index = target_winner_seat_index,
    win_type = target_win_type,
    discarder_seat_index = target_discarder_seat_index,
    penalty_seat_index = target_penalty_seat_index,
    fan_count = case
      when target_result_type = 'false_win_penalty' then 6
      else target_fan_count
    end,
    dealer_was_waiting_at_draw = case
      when target_result_type = 'washout' then target_dealer_was_waiting_at_draw
      else null
    end,
    correction_note = target_correction_note
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'edit',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

create or replace function public.void_hand_result(
  target_hand_result_id uuid,
  target_correction_note text default null
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_hand public.hand_results%rowtype;
  updated_hand public.hand_results%rowtype;
  session_row public.table_sessions%rowtype;
begin
  existing_hand := app_private.require_owned_hand_result(target_hand_result_id);
  session_row := app_private.require_owned_session(existing_hand.table_session_id);
  perform app_private.require_event_for_scoring(session_row.event_id);

  if existing_hand.status = 'voided' then
    return existing_hand;
  end if;

  update public.hand_results
  set
    status = 'voided',
    correction_note = coalesce(target_correction_note, correction_note)
  where id = existing_hand.id
  returning *
  into updated_hand;

  perform public.recalculate_session(session_row.id);
  perform app_private.complete_finished_tournament_rounds(session_row.event_id);

  select *
  into updated_hand
  from public.hand_results
  where id = updated_hand.id;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'hand_result',
    updated_hand.id::text,
    'void',
    to_jsonb(existing_hand),
    to_jsonb(updated_hand)
  );

  return updated_hand;
end;
$$;

select pg_notify('pgrst', 'reload schema');
