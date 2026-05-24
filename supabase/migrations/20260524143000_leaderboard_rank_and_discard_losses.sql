-- Competition ranking and explicit discard-loss stats for leaderboards.

alter table public.event_score_totals
  add column if not exists discard_losses integer not null default 0
    check (discard_losses >= 0);

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
    discard_losses,
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
  hand_result_totals as (
    select
      seat.event_guest_id,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index) as hands_won,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'self_draw') as self_draw_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.winner_seat_index = seat.seat_index and hand_result.win_type = 'discard') as discard_wins,
      count(*) filter (where hand_result.result_type = 'win' and hand_result.win_type = 'discard' and hand_result.discarder_seat_index = seat.seat_index) as discard_losses
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
    coalesce(hand_result_totals.hands_won, 0),
    coalesce(hand_result_totals.self_draw_wins, 0),
    coalesce(hand_result_totals.discard_wins, 0),
    coalesce(hand_result_totals.discard_losses, 0),
    coalesce(session_counts.sessions_started, 0),
    coalesce(session_counts.sessions_completed, 0)
  from guest_base
  left join points_totals
    on points_totals.event_guest_id = guest_base.event_guest_id
  left join adjustment_totals
    on adjustment_totals.event_guest_id = guest_base.event_guest_id
  left join hand_play_totals
    on hand_play_totals.event_guest_id = guest_base.event_guest_id
  left join hand_result_totals
    on hand_result_totals.event_guest_id = guest_base.event_guest_id
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
        (rank() over (order by total_points desc))::integer as rank
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
  discard_losses integer,
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
    score.discard_losses,
    (rank() over (order by score.total_points desc))::integer as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
  where score.event_id = target_event_id
    and guest.tournament_status = 'qualified'
    and app_private.is_event_owner(target_event_id)
  order by score.total_points desc, guest.display_name asc;
$$;

drop function if exists public.get_public_event_leaderboard(uuid);

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
  discard_losses integer,
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
    score.discard_losses,
    (rank() over (order by score.total_points desc))::integer as rank
  from public.event_score_totals as score
  join public.event_guests as guest
    on guest.id = score.event_guest_id
  where score.event_id = target_event_id
    and guest.event_id = target_event_id
    and guest.tournament_status = 'qualified'
    and guest.attendance_status = 'checked_in'
  order by score.total_points desc, public_display_name asc;
$$;

grant execute on function public.get_event_leaderboard(uuid) to authenticated;
grant execute on function public.get_public_event_leaderboard(uuid) to anon, authenticated;

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_event_score_totals(event_row.id);
  end loop;
end;
$$;
