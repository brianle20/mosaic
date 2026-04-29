-- Remove event-level prize budgets; prize totals are derived from prize tiers.

create or replace function app_private.validate_prize_plan_input(
  target_mode text,
  target_reserve_fixed_cents integer,
  target_reserve_percentage_bps integer,
  target_tiers jsonb
)
returns void
language plpgsql
immutable
as $$
declare
  tier_row jsonb;
  seen_places integer[] := '{}';
  current_place integer;
begin
  if target_mode not in ('none', 'fixed') then
    raise exception 'Prize plan mode must be none or fixed.'
      using errcode = 'P0001';
  end if;

  if target_reserve_fixed_cents < 0 then
    raise exception 'Reserve fixed cents must be zero or more.'
      using errcode = 'P0001';
  end if;

  if target_reserve_percentage_bps not between 0 and 10000 then
    raise exception 'Reserve percentage must be between 0 and 10000 basis points.'
      using errcode = 'P0001';
  end if;

  if jsonb_typeof(coalesce(target_tiers, '[]'::jsonb)) <> 'array' then
    raise exception 'Prize tiers must be a JSON array.'
      using errcode = 'P0001';
  end if;

  if target_mode = 'none' then
    if jsonb_array_length(coalesce(target_tiers, '[]'::jsonb)) > 0 then
      raise exception 'None mode cannot include prize tiers.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if jsonb_array_length(coalesce(target_tiers, '[]'::jsonb)) = 0 then
    raise exception 'Prize tiers are required for fixed mode.'
      using errcode = 'P0001';
  end if;

  for tier_row in
    select value
    from jsonb_array_elements(coalesce(target_tiers, '[]'::jsonb))
  loop
    current_place := (tier_row ->> 'place')::integer;

    if current_place is null or current_place <= 0 then
      raise exception 'Prize tier place must be a positive integer.'
        using errcode = 'P0001';
    end if;

    if current_place = any(seen_places) then
      raise exception 'Prize tier places must be unique.'
        using errcode = 'P0001';
    end if;

    seen_places := array_append(seen_places, current_place);

    if (tier_row ? 'percentage_bps') and tier_row -> 'percentage_bps' is not null then
      raise exception 'Fixed prize tiers cannot include percentage values.'
        using errcode = 'P0001';
    end if;

    if not (tier_row ? 'fixed_amount_cents')
      or tier_row ->> 'fixed_amount_cents' is null then
      raise exception 'Fixed prize tiers require fixed_amount_cents.'
        using errcode = 'P0001';
    end if;

    if (tier_row ->> 'fixed_amount_cents')::integer < 0 then
      raise exception 'Fixed prize amounts must be zero or more.'
        using errcode = 'P0001';
    end if;
  end loop;
end;
$$;

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
    join public.event_guests as guest
      on guest.id = leaderboard.event_guest_id
    where guest.has_scored_play = true
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

alter table public.events
  drop column if exists prize_budget_cents,
  drop column if exists prize_budget_note;

select pg_notify('pgrst', 'reload schema');
