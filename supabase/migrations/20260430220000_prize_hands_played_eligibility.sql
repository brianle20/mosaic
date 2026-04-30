-- Require meaningful points-game participation for points prize eligibility.

create or replace function app_private.build_prize_preview(
  target_event_id uuid
)
returns table (
  event_guest_id uuid,
  display_name text,
  rank_start integer,
  rank_end integer,
  display_rank text,
  award_amount_cents integer
)
language plpgsql
security definer
set search_path = public
as $$
declare
  plan_row public.prize_plans%rowtype;
  total_scored_hands integer;
  minimum_hands_played integer;
begin
  perform app_private.require_owned_event(target_event_id);

  select plan.*
  into plan_row
  from public.prize_plans as plan
  where plan.event_id = target_event_id;

  if not found or plan_row.mode = 'none' then
    return;
  end if;

  if plan_row.mode <> 'fixed' then
    raise exception 'Only fixed prize plans are supported.'
      using errcode = 'P0001';
  end if;

  select count(hand_result.id)::integer
  into total_scored_hands
  from public.hand_results as hand_result
  join public.table_sessions as session
    on session.id = hand_result.table_session_id
  where session.event_id = target_event_id
    and hand_result.status = 'recorded';

  minimum_hands_played := ceil(total_scored_hands / 2.0)::integer;

  if minimum_hands_played <= 0 then
    return;
  end if;

  return query
  with tier_amounts as (
    select
      tier.place,
      coalesce(tier.fixed_amount_cents, 0) as award_amount_cents
    from public.prize_tiers as tier
    where tier.prize_plan_id = plan_row.id
  ),
  eligible_leaderboard as (
    select
      leaderboard.event_guest_id,
      leaderboard.display_name,
      leaderboard.total_points,
      row_number() over (
        order by leaderboard.total_points desc, leaderboard.display_name asc
      )::integer as leaderboard_position,
      dense_rank() over (
        order by leaderboard.total_points desc
      )::integer as dense_rank_position
    from public.get_event_leaderboard(target_event_id) as leaderboard
    where leaderboard.hands_played >= minimum_hands_played
  ),
  rank_groups as (
    select
      eligible_leaderboard.dense_rank_position,
      min(eligible_leaderboard.leaderboard_position)::integer as rank_start,
      max(eligible_leaderboard.leaderboard_position)::integer as rank_end
    from eligible_leaderboard
    group by eligible_leaderboard.dense_rank_position
  ),
  pooled_ranks as (
    select
      rank_groups.dense_rank_position,
      rank_groups.rank_start,
      rank_groups.rank_end,
      coalesce(sum(tier_amounts.award_amount_cents), 0) as pooled_amount_cents
    from rank_groups
    left join tier_amounts
      on tier_amounts.place between rank_groups.rank_start and rank_groups.rank_end
    group by
      rank_groups.dense_rank_position,
      rank_groups.rank_start,
      rank_groups.rank_end
  ),
  ranked_members as (
    select
      eligible_leaderboard.event_guest_id,
      eligible_leaderboard.display_name,
      pooled_ranks.rank_start,
      pooled_ranks.rank_end,
      pooled_ranks.pooled_amount_cents,
      count(*) over (
        partition by eligible_leaderboard.dense_rank_position
      )::integer as tied_guest_count,
      row_number() over (
        partition by eligible_leaderboard.dense_rank_position
        order by eligible_leaderboard.display_name asc
      )::integer as alphabetical_tie_order
    from eligible_leaderboard
    join pooled_ranks
      on pooled_ranks.dense_rank_position = eligible_leaderboard.dense_rank_position
  )
  select
    ranked_members.event_guest_id,
    ranked_members.display_name,
    ranked_members.rank_start,
    ranked_members.rank_end,
    case
      when ranked_members.rank_start = ranked_members.rank_end then ranked_members.rank_start::text
      else 'T-' || ranked_members.rank_start::text
    end as display_rank,
    (
      ranked_members.pooled_amount_cents / ranked_members.tied_guest_count
      + case
          when ranked_members.alphabetical_tie_order
            <= mod(ranked_members.pooled_amount_cents, ranked_members.tied_guest_count)
          then 1
          else 0
        end
    )::integer as award_amount_cents
  from ranked_members
  where ranked_members.pooled_amount_cents > 0
  order by ranked_members.rank_start, ranked_members.display_name asc;
end;
$$;

select pg_notify('pgrst', 'reload schema');
