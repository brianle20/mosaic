-- Historical Rating/Profile Seed Projections.

create or replace function app_private.ensure_players_for_event(
  target_event_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  guest_row public.event_guests%rowtype;
  inserted_player_id uuid;
begin
  for guest_row in
    select guest.*
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.player_id is null
    order by guest.created_at asc, guest.id asc
    for update
  loop
    insert into public.players (
      display_name,
      rating_state_json,
      profile_state_json
    )
    values (
      guest_row.display_name,
      jsonb_build_object(
        'seededFrom', 'event_guest',
        'eventGuestId', guest_row.id,
        'eventId', guest_row.event_id,
        'inputsVersion', 'mosaic_projection_v1'
      ),
      jsonb_build_object(
        'seededFrom', 'event_guest',
        'eventGuestId', guest_row.id,
        'eventId', guest_row.event_id,
        'inputsVersion', 'mosaic_projection_v1'
      )
    )
    returning id into inserted_player_id;

    update public.event_guests
    set player_id = inserted_player_id
    where id = guest_row.id
      and player_id is null;
  end loop;
end;
$$;

create or replace function app_private.refresh_mosaic_player_snapshots(
  target_player_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  event_row record;
begin
  for event_row in
    select event.id
    from public.events as event
    where lower(event.title) in (
      'fv mahjong 1',
      'fv mahjong 2',
      'south wind 3'
    )
    order by event.starts_at asc, event.id asc
  loop
    perform app_private.ensure_players_for_event(event_row.id);
  end loop;

  delete from public.rating_snapshots as snapshot
  where snapshot.source_quality = 'mosaic_hand_ledger'
    and (target_player_id is null or snapshot.player_id = target_player_id);

  delete from public.profile_snapshots as snapshot
  where snapshot.source_quality = 'mosaic_hand_ledger'
    and (target_player_id is null or snapshot.player_id = target_player_id);

  with historical_events as (
    select
      event.id,
      event.title,
      event.starts_at,
      case lower(event.title)
        when 'fv mahjong 1' then 'fv_mahjong_1'
        when 'fv mahjong 2' then 'fv_mahjong_2'
        when 'south wind 3' then 'south_wind_3'
      end as historical_series
    from public.events as event
    where lower(event.title) in (
      'fv mahjong 1',
      'fv mahjong 2',
      'south wind 3'
    )
  ),
  event_players as (
    select
      event.id as event_id,
      event.title,
      event.starts_at,
      event.historical_series,
      guest.id as event_guest_id,
      guest.player_id,
      guest.display_name,
      coalesce(total.total_points, 0) as total_points,
      coalesce(total.hands_played, 0) as hands_played,
      coalesce(total.hands_won, 0) as hands_won,
      coalesce(total.self_draw_wins, 0) as self_draw_wins,
      coalesce(total.discard_wins, 0) as discard_wins,
      coalesce(total.sessions_started, 0) as sessions_started,
      coalesce(total.sessions_completed, 0) as sessions_completed
    from historical_events as event
    join public.event_guests as guest
      on guest.event_id = event.id
     and guest.player_id is not null
    left join public.event_score_totals as total
      on total.event_id = event.id
     and total.event_guest_id = guest.id
    where target_player_id is null or guest.player_id = target_player_id
  ),
  official_hand_inputs as (
    select
      event_player.player_id,
      event_player.event_id,
      jsonb_agg(
        distinct jsonb_build_object(
          'handResultId', hand_result.id,
          'tableSessionId', hand_result.table_session_id,
          'handNumber', hand_result.hand_number,
          'resultType', hand_result.result_type,
          'winType', hand_result.win_type,
          'declared_fan_count', hand_result.fan_count,
          'status', hand_result.status,
          'enteredAt', hand_result.entered_at
        )
      ) filter (where settlement.id is not null) as hand_results_json,
      jsonb_agg(
        distinct jsonb_build_object(
          'handSettlementId', settlement.id,
          'handResultId', settlement.hand_result_id,
          'payerEventGuestId', settlement.payer_event_guest_id,
          'payeeEventGuestId', settlement.payee_event_guest_id,
          'amountPoints', settlement.amount_points
        )
      ) filter (where settlement.id is not null) as hand_settlements_json,
      max(hand_result.entered_at)
        filter (where settlement.id is not null) as official_data_through
    from event_players as event_player
    left join public.table_sessions as session
      on session.event_id = event_player.event_id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
     and hand_result.status = 'recorded'
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
     and (
       settlement.payer_event_guest_id = event_player.event_guest_id
       or settlement.payee_event_guest_id = event_player.event_guest_id
     )
    group by event_player.player_id, event_player.event_id
  ),
  ordered_projection as (
    select
      event_player.*,
      official_inputs.hand_results_json,
      official_inputs.hand_settlements_json,
      official_inputs.official_data_through,
      coalesce(
        sum(event_player.total_points) over (
          partition by event_player.player_id
          order by event_player.starts_at asc, event_player.event_id asc
          rows between unbounded preceding and 1 preceding
        ),
        0
      ) as prior_total_points,
      sum(event_player.total_points) over (
        partition by event_player.player_id
        order by event_player.starts_at asc, event_player.event_id asc
        rows between unbounded preceding and current row
      ) as cumulative_total_points,
      sum(event_player.hands_played) over (
        partition by event_player.player_id
        order by event_player.starts_at asc, event_player.event_id asc
        rows between unbounded preceding and current row
      ) as cumulative_hands_played,
      sum(event_player.hands_won) over (
        partition by event_player.player_id
        order by event_player.starts_at asc, event_player.event_id asc
        rows between unbounded preceding and current row
      ) as cumulative_hands_won,
      sum(event_player.self_draw_wins) over (
        partition by event_player.player_id
        order by event_player.starts_at asc, event_player.event_id asc
        rows between unbounded preceding and current row
      ) as cumulative_self_draw_wins,
      sum(event_player.discard_wins) over (
        partition by event_player.player_id
        order by event_player.starts_at asc, event_player.event_id asc
        rows between unbounded preceding and current row
      ) as cumulative_discard_wins
    from event_players as event_player
    left join official_hand_inputs as official_inputs
      on official_inputs.player_id = event_player.player_id
     and official_inputs.event_id = event_player.event_id
  ),
  inserted_ratings as (
    insert into public.rating_snapshots (
      player_id,
      event_id,
      rating_before,
      rating_after,
      rating_delta,
      provisional_state,
      source_quality,
      inputs_version,
      inputs_json
    )
    select
      projection.player_id,
      projection.event_id,
      1000 + projection.prior_total_points,
      1000 + projection.cumulative_total_points,
      projection.total_points,
      case
        when projection.cumulative_hands_played >= 80 then 'established'
        when projection.cumulative_hands_played >= 24 then 'semi_provisional'
        else 'provisional'
      end,
      'mosaic_hand_ledger',
      'mosaic_projection_v1',
      jsonb_build_object(
        'source', 'mosaic_hand_ledger',
        'inputsVersion', 'mosaic_projection_v1',
        'eventScoreTotals', jsonb_build_object(
          'table', 'public.event_score_totals',
          'eventId', projection.event_id,
          'eventGuestId', projection.event_guest_id,
          'totalPoints', projection.total_points,
          'handsPlayed', projection.hands_played,
          'handsWon', projection.hands_won,
          'selfDrawWins', projection.self_draw_wins,
          'discardWins', projection.discard_wins,
          'sessionsStarted', projection.sessions_started,
          'sessionsCompleted', projection.sessions_completed
        ),
        'handResults', coalesce(projection.hand_results_json, '[]'::jsonb),
        'handSettlements',
          coalesce(projection.hand_settlements_json, '[]'::jsonb),
        'historicalSeries', projection.historical_series
      )
    from ordered_projection as projection
    returning id
  )
  insert into public.profile_snapshots (
    player_id,
    event_id,
    profile_dimensions_json,
    style_archetype,
    confidence,
    source_quality,
    tile_derived_confidence,
    generated_from_official_data_through,
    generated_from_tile_data_through,
    inputs_version,
    private_review_json
  )
  select
    projection.player_id,
    projection.event_id,
    jsonb_build_object(
      'totalPoints', projection.cumulative_total_points,
      'handsPlayed', projection.cumulative_hands_played,
      'handsWon', projection.cumulative_hands_won,
      'winRate',
        case
          when projection.cumulative_hands_played = 0 then 0
          else round(
            projection.cumulative_hands_won::numeric
            / projection.cumulative_hands_played::numeric,
            4
          )
        end,
      'selfDrawWins', projection.cumulative_self_draw_wins,
      'discardWins', projection.cumulative_discard_wins,
      'officialScoringSource', 'public.event_score_totals',
      'officialHandSource', 'public.hand_results',
      'officialSettlementSource', 'public.hand_settlements'
    ),
    case
      when projection.cumulative_self_draw_wins
        > projection.cumulative_discard_wins then 'self_draw_leaning'
      when projection.cumulative_discard_wins
        > projection.cumulative_self_draw_wins then 'discard_leaning'
      when projection.cumulative_hands_won > 0 then 'balanced_winner'
      else null
    end,
    'early_read',
    'mosaic_hand_ledger',
    'none',
    projection.official_data_through,
    null,
    'mosaic_projection_v1',
    jsonb_build_object(
      'source', 'mosaic_hand_ledger',
      'inputsVersion', 'mosaic_projection_v1',
      'tileDerivedConfidence', 'none',
      'declaredFanCountSource', 'public.hand_results.fan_count',
      'handResults', coalesce(projection.hand_results_json, '[]'::jsonb),
      'handSettlements', coalesce(projection.hand_settlements_json, '[]'::jsonb),
      'historicalSeries', projection.historical_series
    )
  from ordered_projection as projection;
end;
$$;

select app_private.refresh_mosaic_player_snapshots();

select pg_notify('pgrst', 'reload schema');
