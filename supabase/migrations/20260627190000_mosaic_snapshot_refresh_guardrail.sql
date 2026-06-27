create or replace function app_private.refresh_mosaic_player_snapshots_for_event(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  event_row public.events%rowtype;
  player_row record;
begin
  select *
  into event_row
  from public.events
  where id = target_event_id;

  if event_row.id is null then
    return;
  end if;

  if lower(event_row.title) not in (
    'fv mahjong 1',
    'fv mahjong 2',
    'south wind 3'
  ) then
    return;
  end if;

  for player_row in
    select distinct guest.player_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.player_id is not null
  loop
    perform app_private.refresh_mosaic_player_snapshots(player_row.player_id);
  end loop;
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
    left join public.table_sessions as hand_session
      on hand_session.id = hand_result.table_session_id
    left join public.hand_false_win_penalties as penalty
      on penalty.id = settlement.hand_false_win_penalty_id
    left join public.table_sessions as penalty_session
      on penalty_session.id = penalty.table_session_id
    where settlement.id is null
      or (
        hand_session.event_id = target_event_id
        and hand_session.scoring_phase = 'tournament'
        and hand_result.status = 'recorded'
      )
      or (
        settlement.hand_result_id is null
        and penalty_session.event_id = target_event_id
        and penalty_session.scoring_phase = 'tournament'
        and penalty.status = 'pending'
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

  perform app_private.refresh_event_guest_scored_play(target_event_id);
  perform app_private.refresh_public_event_standings_snapshot(target_event_id);
  perform app_private.refresh_mosaic_player_snapshots_for_event(target_event_id);
end;
$$;

create or replace function app_private.refresh_mosaic_player_snapshots_for_bridge_change()
returns trigger
language plpgsql
security definer
set search_path = public, app_private
as $$
begin
  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if new.status = 'active' then
      update public.event_guests as guest
      set player_id = new.player_id
      from public.events as event,
        public.guest_profiles as profile
      where guest.guest_profile_id = new.guest_profile_id
        and event.id = guest.event_id
        and profile.id = guest.guest_profile_id
        and profile.owner_user_id = event.owner_user_id
        and new.owner_user_id = event.owner_user_id
        and guest.player_id is distinct from new.player_id;
    end if;
  end if;

  if tg_op = 'UPDATE' or tg_op = 'DELETE' then
    if old.player_id is not null then
      perform app_private.refresh_mosaic_player_snapshots(old.player_id);
    end if;
  end if;

  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if new.player_id is not null
      and (tg_op = 'INSERT' or new.player_id is distinct from old.player_id)
    then
      perform app_private.refresh_mosaic_player_snapshots(new.player_id);
    end if;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

drop trigger if exists player_guest_profiles_refresh_mosaic_snapshots_insert_delete
  on public.player_guest_profiles;
create trigger player_guest_profiles_refresh_mosaic_snapshots_insert_delete
after insert or delete
on public.player_guest_profiles
for each row execute function app_private.refresh_mosaic_player_snapshots_for_bridge_change();

drop trigger if exists player_guest_profiles_refresh_mosaic_snapshots_update
  on public.player_guest_profiles;
create trigger player_guest_profiles_refresh_mosaic_snapshots_update
after update of player_id, guest_profile_id, owner_user_id, status
on public.player_guest_profiles
for each row execute function app_private.refresh_mosaic_player_snapshots_for_bridge_change();

select app_private.refresh_mosaic_player_snapshots();

select pg_notify('pgrst', 'reload schema');
