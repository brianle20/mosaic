-- Stream complete public standings snapshots so spectators do not fan out RPC reads.

create table if not exists public.public_event_standings_snapshots (
  event_id uuid primary key references public.events(id) on delete cascade,
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.public_event_standings_snapshots enable row level security;

drop policy if exists public_event_standings_snapshots_public_read
  on public.public_event_standings_snapshots;
create policy public_event_standings_snapshots_public_read
on public.public_event_standings_snapshots
for select
to anon, authenticated
using (true);

grant select on public.public_event_standings_snapshots to anon, authenticated;

do $$
begin
  alter publication supabase_realtime
  add table public.public_event_standings_snapshots;
exception
  when duplicate_object then null;
  when undefined_object then null;
end;
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
  )
  select jsonb_build_object(
    'eventTitle', coalesce((select event_title from event_summary), 'Mosaic tournament'),
    'leaderboard', (select rows from leaderboard_rows),
    'bonusResults', (select rows from bonus_rows),
    'updatedAt', now()
  );
$$;

create or replace function app_private.refresh_public_event_standings_snapshot(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  snapshot_payload jsonb;
begin
  if target_event_id is null then
    return;
  end if;

  snapshot_payload :=
    app_private.build_public_event_standings_snapshot(target_event_id);

  insert into public.public_event_standings_snapshots (
    event_id,
    payload,
    updated_at
  )
  values (
    target_event_id,
    snapshot_payload,
    now()
  )
  on conflict (event_id) do update
  set
    payload = excluded.payload,
    updated_at = excluded.updated_at;
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
    if tg_table_name not in (
      'event_score_totals',
      'event_score_adjustments',
      'hand_results',
      'table_sessions'
    ) then
      perform app_private.refresh_public_event_standings_snapshot(target_event_id);
    end if;

    insert into public.public_event_updates (event_id, topic)
    values (target_event_id, tg_table_name);
  end if;

  return coalesce(new, old);
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

  perform app_private.refresh_public_event_standings_snapshot(target_event_id);
end;
$$;

do $$
declare
  event_row record;
begin
  for event_row in select id from public.events loop
    perform app_private.refresh_public_event_standings_snapshot(event_row.id);
  end loop;
end;
$$;
