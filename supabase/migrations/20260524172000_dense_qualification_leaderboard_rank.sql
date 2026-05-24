-- Qualification standings use dense placement by points only so ties do not
-- skip the next displayed place.

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
    dense_rank() over (order by coalesce(points_totals.qualification_points, 0) desc)::integer as rank
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join hand_totals
    on hand_totals.event_guest_id = guest_base.event_guest_id
  order by qualification_points desc, wins desc, full_name asc;
$$;
