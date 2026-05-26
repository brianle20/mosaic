-- Resolve tied Table of Champions finals through sudden death.

alter table public.event_bonus_rounds
add column if not exists champion_resolution_method text not null
  default 'standard',
add column if not exists sudden_death_status text not null
  default 'not_required',
add column if not exists sudden_death_table_id uuid,
add column if not exists sudden_death_session_id uuid;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_champion_resolution_method_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_champion_resolution_method_check
check (champion_resolution_method in ('standard', 'sudden_death'));

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_sudden_death_status_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_sudden_death_status_check
check (
  sudden_death_status in (
    'not_required',
    'required',
    'active',
    'completed'
  )
);

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_sudden_death_table_same_event_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_sudden_death_table_same_event_fk
foreign key (sudden_death_table_id, event_id)
references public.event_tables(id, event_id)
on delete restrict;

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_sudden_death_session_fk;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_sudden_death_session_fk
foreign key (sudden_death_session_id)
references public.table_sessions(id)
on delete set null;

alter table public.event_seating_assignments
drop constraint if exists event_seating_assignments_bonus_table_role_check;
alter table public.event_seating_assignments
add constraint event_seating_assignments_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in (
    'table_of_champions',
    'table_of_redemption',
    'table_of_champions_sudden_death'
  )
);

alter table public.table_sessions
drop constraint if exists table_sessions_bonus_table_role_check;
alter table public.table_sessions
add constraint table_sessions_bonus_table_role_check
check (
  bonus_table_role is null
  or bonus_table_role in (
    'table_of_champions',
    'table_of_redemption',
    'table_of_champions_sudden_death'
  )
);

create or replace function app_private.table_of_champions_scores(
  scores_bonus_round_id uuid,
  target_table_session_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  bonus_score_points integer,
  seed_rank integer
)
language sql
security definer
set search_path = public
as $$
  select
    seat.event_guest_id,
    guest.display_name,
    (
      coalesce(
        sum(
          case
            when settlement.payee_event_guest_id = seat.event_guest_id
              then settlement.amount_points
            else 0
          end
        ),
        0
      )
      - coalesce(
        sum(
          case
            when settlement.payer_event_guest_id = seat.event_guest_id
              then settlement.amount_points
            else 0
          end
        ),
        0
      )
    )::integer as bonus_score_points,
    min(assignment.seed_rank)::integer as seed_rank
  from public.table_session_seats as seat
  join public.event_guests as guest
    on guest.id = seat.event_guest_id
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
    on assignment.bonus_round_id = scores_bonus_round_id
    and assignment.event_guest_id = seat.event_guest_id
    and assignment.bonus_table_role = 'table_of_champions'
  where seat.table_session_id = target_table_session_id
  group by seat.event_guest_id, guest.display_name
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
  champion_bonus_score_points_value integer := 0;
  champion_base_total_value integer;
  top_non_champion_total_value integer;
  champion_top_up_points_value integer;
  champion_award_points_value integer;
  top_score integer;
  tied_top_count integer;
  sudden_death_winner uuid;
begin
  select *
  into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;

  if not found
    or session_row.bonus_round_id is null
    or session_row.bonus_table_role not in (
      'table_of_champions',
      'table_of_champions_sudden_death'
    ) then
    return;
  end if;

  delete from public.event_score_adjustments as adjustment
  using public.table_sessions as source_session
  where adjustment.adjustment_type = 'finals_champion_award'
    and adjustment.source_table_session_id = source_session.id
    and source_session.bonus_round_id = session_row.bonus_round_id
    and source_session.bonus_table_role in (
      'table_of_champions',
      'table_of_champions_sudden_death'
    );

  if session_row.bonus_table_role = 'table_of_champions' then
    if session_row.status <> 'completed' then
      update public.event_bonus_rounds
      set
        status = 'active',
        champion_resolution_method = 'standard',
        sudden_death_status = 'not_required',
        sudden_death_table_id = null,
        sudden_death_session_id = null,
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

    with scores as (
      select *
      from app_private.table_of_champions_scores(
        session_row.bonus_round_id,
        session_row.id
      )
    ),
    max_score as (
      select max(scores.bonus_score_points) as value
      from scores
    ),
    tied_top_players as (
      select scores.*
      from scores
      cross join max_score
      where scores.bonus_score_points = max_score.value
    )
    select
      max_score.value,
      count(tied_top_players.event_guest_id)::integer
    into top_score, tied_top_count
    from max_score
    left join tied_top_players on true
    group by max_score.value;

    if tied_top_count > 1 then
      -- Mark sudden death required instead of breaking a finals tie by seed.
      update public.event_bonus_rounds
      set
        status = 'active',
        champion_resolution_method = 'sudden_death',
        sudden_death_status = 'required',
        sudden_death_table_id = null,
        sudden_death_session_id = null,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    select scores.event_guest_id, scores.bonus_score_points
    into champion_event_guest_id_value, champion_bonus_score_points_value
    from app_private.table_of_champions_scores(
      session_row.bonus_round_id,
      session_row.id
    ) as scores
    order by scores.bonus_score_points desc, scores.event_guest_id asc
    limit 1;
  end if;

  if session_row.bonus_table_role = 'table_of_champions_sudden_death' then
    select seat.event_guest_id
    into sudden_death_winner
    from public.hand_results as hand_result
    join public.table_session_seats as seat
      on seat.table_session_id = hand_result.table_session_id
      and seat.seat_index = hand_result.winner_seat_index
    where hand_result.table_session_id = session_row.id
      and hand_result.status = 'recorded'
      and hand_result.result_type = 'win'
    order by hand_result.hand_number desc, hand_result.created_at desc
    limit 1;

    if sudden_death_winner is null then
      update public.event_bonus_rounds
      set
        champion_resolution_method = 'sudden_death',
        sudden_death_status = 'active',
        sudden_death_session_id = session_row.id,
        champion_event_guest_id = null,
        champion_bonus_score_points = null,
        champion_top_up_points = null,
        champion_award_points = null,
        completed_at = null
      where id = session_row.bonus_round_id;

      perform app_private.refresh_event_score_totals(session_row.event_id);
      return;
    end if;

    champion_event_guest_id_value := sudden_death_winner;
    champion_bonus_score_points_value := 0;

    update public.table_sessions
    set
      status = 'completed',
      ended_at = coalesce(ended_at, now()),
      ended_by_user_id = coalesce(ended_by_user_id, auth.uid()),
      end_reason = coalesce(end_reason, 'sudden_death_resolved')
    where id = session_row.id
      and status in ('active', 'paused');
  end if;

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
    champion_resolution_method =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then 'sudden_death'
        else 'standard'
      end,
    sudden_death_status =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then 'completed'
        else 'not_required'
      end,
    sudden_death_table_id =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then sudden_death_table_id
        else null
      end,
    sudden_death_session_id =
      case
        when session_row.bonus_table_role = 'table_of_champions_sudden_death'
          then session_row.id
        else null
      end,
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
        'award_points = finals score or sudden death resolution + top-up',
        'champion_bonus_score_points', champion_bonus_score_points_value,
        'champion_base_total', champion_base_total_value,
        'top_non_champion_event_total_before_champion_award',
          top_non_champion_total_value,
        'champion_top_up_points', champion_top_up_points_value,
        'award_points', champion_award_points_value,
        'champion_resolution_method',
          case
            when session_row.bonus_table_role =
              'table_of_champions_sudden_death'
              then 'sudden_death'
            else 'standard'
          end
      ),
      auth.uid()
    );
  end if;

  perform app_private.refresh_event_score_totals(session_row.event_id);
end;
$$;

create or replace function public.get_bonus_round_state(
  target_event_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  champions_session_id uuid;
  tied_top_players jsonb := '[]'::jsonb;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status in ('active', 'completed')
  order by
    case when bonus_round.status = 'active' then 0 else 1 end,
    bonus_round.created_at desc
  limit 1;

  if bonus_round_row.id is null then
    return jsonb_build_object(
      'bonus_round_id', null,
      'event_id', target_event_id,
      'status', null,
      'champions_table_id', null,
      'redemption_table_id', null,
      'champion_resolution_method', 'standard',
      'sudden_death_status', 'not_required',
      'sudden_death_table_id', null,
      'sudden_death_session_id', null,
      'champion_event_guest_id', null,
      'champion_bonus_score_points', null,
      'champion_top_up_points', null,
      'champion_award_points', null,
      'tied_top_players', jsonb_build_array()
    );
  end if;

  select session.id
  into champions_session_id
  from public.table_sessions as session
  where session.bonus_round_id = bonus_round_row.id
    and session.bonus_table_role = 'table_of_champions'
  order by coalesce(session.ended_at, session.started_at, session.created_at) desc
  limit 1;

  if bonus_round_row.sudden_death_status in ('required', 'active')
    and champions_session_id is not null then
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
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'event_guest_id', scores.event_guest_id,
          'display_name', scores.display_name,
          'bonus_score_points', scores.bonus_score_points,
          'seed_rank', scores.seed_rank
        )
        order by scores.seed_rank asc nulls last, scores.display_name asc
      ),
      '[]'::jsonb
    )
    into tied_top_players
    from scores
    cross join max_score
    where scores.bonus_score_points = max_score.value;
  end if;

  return jsonb_build_object(
    'bonus_round_id', bonus_round_row.id,
    'event_id', bonus_round_row.event_id,
    'status', bonus_round_row.status,
    'champions_table_id', bonus_round_row.champions_table_id,
    'redemption_table_id', bonus_round_row.redemption_table_id,
    'champion_resolution_method', bonus_round_row.champion_resolution_method,
    'sudden_death_status', bonus_round_row.sudden_death_status,
    'sudden_death_table_id', bonus_round_row.sudden_death_table_id,
    'sudden_death_session_id', bonus_round_row.sudden_death_session_id,
    'champion_event_guest_id', bonus_round_row.champion_event_guest_id,
    'champion_bonus_score_points', bonus_round_row.champion_bonus_score_points,
    'champion_top_up_points', bonus_round_row.champion_top_up_points,
    'champion_award_points', bonus_round_row.champion_award_points,
    'tied_top_players', tied_top_players
  );
end;
$$;

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

  update public.event_bonus_rounds
  set
    champion_resolution_method = 'sudden_death',
    sudden_death_status = 'active',
    sudden_death_table_id = selected_sudden_death_table_id,
    sudden_death_session_id = null
  where id = bonus_round_row.id;

  return query
  select *
  from public.get_event_seating_assignments(
    bonus_round_row.event_id
  ) as assignment
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_sudden_death';
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
  sudden_death_player_count integer := 0;
  sudden_death_has_win boolean := false;
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

  if session_row.bonus_table_role = 'table_of_champions_sudden_death' then
    select count(*)::integer
    into sudden_death_player_count
    from public.table_session_seats as seat
    where seat.table_session_id = session_row.id;

    if sudden_death_player_count not between 2 and 4 then
      raise exception 'Sudden death requires 2 to 4 seated players.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.hand_results as hand_result
      where hand_result.table_session_id = session_row.id
        and hand_result.status = 'recorded'
        and hand_result.result_type = 'win'
        and not exists (
          select 1
          from public.table_session_seats as seat
          where seat.table_session_id = hand_result.table_session_id
            and seat.seat_index = hand_result.winner_seat_index
        )
    ) then
      raise exception 'Sudden death winner seat must be occupied.'
        using errcode = 'P0001';
    end if;

    delete from public.hand_settlements as settlement
    using public.hand_results as hand_result
    where settlement.hand_result_id = hand_result.id
      and hand_result.table_session_id = session_row.id;

    for hand_row in
      select *
      from public.hand_results
      where table_session_id = session_row.id
        and status = 'recorded'
      order by hand_number asc
    loop
      recorded_hand_count := recorded_hand_count + 1;
      sudden_death_has_win :=
        sudden_death_has_win or hand_row.result_type = 'win';

      update public.hand_results
      set
        base_points = case
          when hand_row.result_type = 'win'
            then app_private.ruleset_base_points(
              session_row.ruleset_id,
              hand_row.fan_count
            )
          else null
        end,
        east_seat_index_before_hand = session_row.current_dealer_seat_index,
        east_seat_index_after_hand = session_row.current_dealer_seat_index,
        dealer_rotated = false,
        session_completed_after_hand = hand_row.result_type = 'win'
      where id = hand_row.id;
    end loop;

    update public.table_sessions
    set
      completed_games_count = recorded_hand_count,
      hand_count = recorded_hand_count,
      status = case
        when session_row.status in ('ended_early', 'aborted') then session_row.status
        when sudden_death_has_win then 'completed'
        when session_row.status = 'paused' then 'paused'
        else 'active'
      end,
      ended_at = case
        when session_row.status in ('ended_early', 'aborted') then session_row.ended_at
        when sudden_death_has_win then coalesce(session_row.ended_at, now())
        else null
      end,
      ended_by_user_id = case
        when session_row.status in ('ended_early', 'aborted') then session_row.ended_by_user_id
        when sudden_death_has_win then coalesce(session_row.ended_by_user_id, auth.uid())
        else null
      end,
      end_reason = case
        when session_row.status in ('ended_early', 'aborted') then session_row.end_reason
        when sudden_death_has_win then coalesce(session_row.end_reason, 'sudden_death_resolved')
        else null
      end,
      round_timer_paused_at = case
        when sudden_death_has_win then null
        else session_row.round_timer_paused_at
      end
    where id = session_row.id
    returning *
    into updated_session;

    perform app_private.refresh_event_score_totals(updated_session.event_id);
    perform app_private.apply_bonus_round_champion_award(updated_session.id);

    return updated_session;
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
      base_points_value :=
        app_private.ruleset_base_points(session_row.ruleset_id, 6);
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
      and session_row.scoring_phase in ('tournament', 'bonus')
      and hand_row.entered_at >= round_time_limit_effective_at
      and hand_row.entered_at >=
        session_row.started_at + round_time_limit_duration +
        make_interval(secs => session_row.round_timer_paused_seconds) then
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
      when session_row.status = 'paused' then 'paused'
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
    end,
    round_timer_paused_at = case
      when round_time_completed
        or (current_east = initial_east and next_pass_count >= 4)
        then null
      else session_row.round_timer_paused_at
    end
  where id = session_row.id
  returning *
  into updated_session;

  perform app_private.refresh_event_score_totals(updated_session.event_id);
  perform app_private.apply_bonus_round_champion_award(updated_session.id);

  return updated_session;
end;
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
      case bonus_round.champion_resolution_method
        when 'sudden_death' then 'Table of Champions Sudden Death'
        else 'Table of Champions'
      end as result_label,
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

drop function if exists public.get_public_event_finals_leaderboard(uuid);

create or replace function public.get_public_event_finals_leaderboard(
  target_event_id uuid
)
returns table (
  bonus_table_role text,
  table_label text,
  event_guest_id uuid,
  public_display_name text,
  seat_index integer,
  total_points integer,
  hands_played integer,
  wins integer,
  rank integer
)
language sql
security definer
set search_path = public
as $$
  with bonus_assignments as (
    select
      assignment.id as assignment_id,
      assignment.event_table_id,
      event_table.label as table_label,
      assignment.event_guest_id,
      assignment.seat_index,
      assignment.bonus_round_id,
      assignment.bonus_table_role
    from public.event_seating_assignments as assignment
    join public.event_tables as event_table
      on event_table.id = assignment.event_table_id
      and event_table.event_id = assignment.event_id
    where assignment.event_id = target_event_id
      and assignment.assignment_type = 'bonus'
      and assignment.status = 'active'
      and assignment.bonus_round_id is not null
      and assignment.bonus_table_role is not null
  ),
  finals_scores as (
    select
      assignment.bonus_table_role,
      assignment.table_label,
      assignment.event_guest_id,
      coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
      assignment.seat_index,
      coalesce(
        sum(
          case
            when settlement.payee_event_guest_id = assignment.event_guest_id then settlement.amount_points
            when settlement.payer_event_guest_id = assignment.event_guest_id then -settlement.amount_points
            else 0
          end
        ),
        0
      )::integer as total_points,
      count(distinct hand_result.id)::integer as hands_played,
      count(distinct hand_result.id) filter (
        where hand_result.result_type = 'win'
          and hand_result.winner_seat_index = seat.seat_index
      )::integer as wins
    from bonus_assignments as assignment
    join public.event_guests as guest
      on guest.id = assignment.event_guest_id
      and guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
    left join public.table_sessions as session
      on session.event_id = target_event_id
      and session.event_table_id = assignment.event_table_id
      and session.bonus_round_id = assignment.bonus_round_id
      and session.bonus_table_role = assignment.bonus_table_role
      and session.scoring_phase = 'bonus'
    left join public.table_session_seats as seat
      on seat.table_session_id = session.id
      and seat.event_guest_id = assignment.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded'
      and seat.id is not null
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and (
        settlement.payee_event_guest_id = assignment.event_guest_id
        or settlement.payer_event_guest_id = assignment.event_guest_id
      )
    group by
      assignment.bonus_table_role,
      assignment.table_label,
      assignment.event_guest_id,
      guest.public_display_name,
      assignment.seat_index
  )
  select
    finals_scores.bonus_table_role,
    finals_scores.table_label,
    finals_scores.event_guest_id,
    finals_scores.public_display_name,
    finals_scores.seat_index,
    finals_scores.total_points,
    finals_scores.hands_played,
    finals_scores.wins,
    (
      rank() over (
        partition by finals_scores.bonus_table_role, finals_scores.table_label
        order by finals_scores.total_points desc
      )
    )::integer as rank
  from finals_scores
  order by
    case finals_scores.bonus_table_role
      when 'table_of_champions' then 0
      when 'table_of_champions_sudden_death' then 1
      when 'table_of_redemption' then 2
      else 3
    end,
    finals_scores.table_label asc,
    rank asc,
    finals_scores.seat_index asc;
$$;

create or replace function app_private.build_public_event_standings_snapshot(
  target_event_id uuid
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  with event_summary as (
    select coalesce(nullif(btrim(summary.title), ''), 'Mosaic tournament') as event_title
    from public.get_public_event_summary(target_event_id) as summary
    limit 1
  ),
  leaderboard_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', leaderboard.event_guest_id,
          'publicDisplayName', leaderboard.public_display_name,
          'totalPoints', leaderboard.total_points,
          'handsPlayed', leaderboard.hands_played,
          'wins', leaderboard.wins,
          'selfDrawWins', leaderboard.self_draw_wins,
          'discardWins', leaderboard.discard_wins,
          'discardLosses', leaderboard.discard_losses,
          'rank', leaderboard.rank
        )
        order by leaderboard.total_points desc, leaderboard.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_leaderboard(target_event_id) as leaderboard
  ),
  bonus_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', bonus.event_guest_id,
          'publicDisplayName', bonus.public_display_name,
          'resultLabel', bonus.result_label,
          'placement', bonus.placement,
          'pointsDelta', bonus.points_delta
        )
        order by bonus.result_label asc, bonus.public_display_name asc
      ),
      '[]'::jsonb
    ) as rows
    from public.get_public_event_bonus_results(target_event_id) as bonus
  ),
  finals_table_rows as (
    select
      finals.bonus_table_role,
      case finals.bonus_table_role
        when 'table_of_champions' then 'Table of Champions'
        when 'table_of_champions_sudden_death' then 'Table of Champions Sudden Death'
        when 'table_of_redemption' then 'Table of Redemption'
        else 'Finals Table'
      end as title,
      finals.table_label,
      bool_or(finals.hands_played > 0) as has_scores,
      jsonb_agg(
        jsonb_build_object(
          'eventGuestId', finals.event_guest_id,
          'publicDisplayName', finals.public_display_name,
          'seatIndex', finals.seat_index,
          'totalPoints', finals.total_points,
          'handsPlayed', finals.hands_played,
          'wins', finals.wins,
          'rank', finals.rank
        )
        order by
          case when finals.hands_played > 0 then finals.rank else finals.seat_index end,
          finals.public_display_name asc
      ) as rows
    from public.get_public_event_finals_leaderboard(target_event_id) as finals
    group by finals.bonus_table_role, finals.table_label
  ),
  finals_leaderboard_rows as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'tableRole', finals_table_rows.bonus_table_role,
          'title', finals_table_rows.title,
          'tableLabel', finals_table_rows.table_label,
          'hasScores', finals_table_rows.has_scores,
          'rows', finals_table_rows.rows
        )
        order by
          case finals_table_rows.bonus_table_role
            when 'table_of_champions' then 0
            when 'table_of_champions_sudden_death' then 1
            when 'table_of_redemption' then 2
            else 3
          end,
          finals_table_rows.table_label asc
      ),
      '[]'::jsonb
    ) as rows
    from finals_table_rows
  )
  select jsonb_build_object(
    'eventTitle', coalesce((select event_title from event_summary), 'Mosaic tournament'),
    'leaderboard', (select rows from leaderboard_rows),
    'bonusResults', (select rows from bonus_rows),
    'finalsLeaderboards', (select rows from finals_leaderboard_rows),
    'updatedAt', now()
  );
$$;

create or replace function public.complete_event(
  target_event_id uuid
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

  if existing_event.lifecycle_status <> 'active' then
    raise exception 'Only active events can be completed.'
      using errcode = 'P0001';
  end if;

  perform app_private.assert_event_has_no_live_sessions(target_event_id);

  if exists (
    select 1
    from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.status = 'active'
      and bonus_round.sudden_death_status in ('required', 'active')
  ) then
    raise exception 'Resolve Table of Champions sudden death before completing the event.'
      using errcode = 'P0001';
  end if;

  update public.events
  set
    lifecycle_status = 'completed',
    scoring_open = false,
    updated_at = now(),
    row_version = row_version + 1
  where id = existing_event.id
  returning *
  into updated_event;

  perform app_private.insert_audit_log(
    updated_event.id,
    'event',
    updated_event.id::text,
    'complete',
    to_jsonb(existing_event),
    to_jsonb(updated_event)
  );

  return updated_event;
end;
$$;

grant execute on function public.get_bonus_round_state(uuid)
  to authenticated;

grant execute on function public.start_bonus_round_sudden_death(uuid, uuid)
  to authenticated;

grant execute on function public.get_public_event_bonus_results(uuid)
  to anon, authenticated;

grant execute on function public.get_public_event_finals_leaderboard(uuid)
  to anon, authenticated;

select pg_notify('pgrst', 'reload schema');
