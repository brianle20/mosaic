-- A standalone Table of Redemption can finish with co-winners. Tiebreaks that
-- allocate a limited number of Champions slots continue to use the existing
-- progression path.

alter table public.event_bonus_rounds
drop constraint if exists event_bonus_rounds_redemption_resolution_check;
alter table public.event_bonus_rounds
add constraint event_bonus_rounds_redemption_resolution_check
check (
  redemption_resolution_method is null
  or redemption_resolution_method in (
    'standing_fifth',
    'table_score',
    'table_score_tie',
    'sudden_death'
  )
);

create or replace function app_private.mark_redemption_co_winners(
  source_contest_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  source public.event_finals_contests%rowtype;
begin
  select *
  into source
  from public.event_finals_contests
  where id = source_contest_id
    and contest_type = 'table_of_redemption'
    and slots_to_fill = 0
  for update;

  if not found then
    raise exception
      'Standalone Table of Redemption was not found for co-winner resolution.'
      using errcode = 'P0001';
  end if;

  with ranked_scores as (
    select
      score.event_guest_id,
      dense_rank() over (
        order by score.score_points desc
      )::integer as finish_rank
    from app_private.finals_contest_scores(source_contest_id) as score
  )
  update public.event_finals_contest_participants as participant
  set outcome = case
        when ranked.finish_rank = 1 then 'winner'
        else 'eliminated'
      end,
      outcome_order = case
        when ranked.finish_rank = 1 then 1
        else null
      end,
      advanced_champions_slot = null
  from ranked_scores as ranked
  where participant.contest_id = source_contest_id
    and participant.event_guest_id = ranked.event_guest_id;

  update public.event_bonus_rounds
  set redemption_winner_event_guest_id = null,
      redemption_resolution_method = 'table_score_tie',
      updated_at = now()
  where id = source.bonus_round_id;

  perform app_private.insert_audit_log(
    source.event_id,
    'event_bonus_round',
    source.bonus_round_id::text,
    'resolve_redemption_co_winners',
    null,
    jsonb_build_object(
      'redemption_winner_event_guest_id', null,
      'redemption_resolution_method', 'table_score_tie'
    ),
    jsonb_build_object(
      'actor_user_id', auth.uid(),
      'source_contest_id', source_contest_id
    )
  );
end;
$$;

create or replace function app_private.resolve_redemption_co_winners(
  target_bonus_round_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  contest public.event_finals_contests%rowtype;
  source_contest_id uuid;
  changed boolean := false;
begin
  for contest in
    select child.*
    from public.event_finals_contests as child
    join public.event_finals_contests as parent
      on parent.id = child.parent_contest_id
    where child.bonus_round_id = target_bonus_round_id
      and child.contest_type = 'redemption_winner_tiebreak'
      and child.status in ('pending', 'ready', 'active')
      and parent.contest_type = 'table_of_redemption'
      and parent.slots_to_fill = 0
      and parent.status = 'complete'
    order by child.sequence_number
    for update of child
  loop
    source_contest_id := contest.parent_contest_id;

    update public.table_sessions
    set status = 'completed',
        ended_at = coalesce(ended_at, now()),
        ended_by_user_id = coalesce(ended_by_user_id, auth.uid()),
        end_reason = coalesce(end_reason, 'redemption_co_winners'),
        round_timer_paused_at = null
    where id = contest.table_session_id
      and status in ('active', 'paused');

    update public.event_seating_assignments
    set status = 'cleared'
    where finals_contest_id = contest.id
      and status = 'active';

    update public.event_finals_contests
    set status = 'cancelled',
        completed_at = null,
        updated_at = now()
    where id = contest.id;

    perform app_private.mark_redemption_co_winners(source_contest_id);

    perform app_private.insert_audit_log(
      contest.event_id,
      'event_finals_contest',
      contest.id::text,
      'cancel_finals_contest',
      to_jsonb(contest),
      to_jsonb(contest) || jsonb_build_object('status', 'cancelled'),
      jsonb_build_object(
        'actor_user_id', auth.uid(),
        'reason', 'redemption_co_winners'
      )
    );
    changed := true;
  end loop;

  return changed;
end;
$$;

alter function app_private.create_finals_tiebreak(
  uuid, text, integer, integer, integer
)
rename to create_finals_tiebreak_before_redemption_co_winners;

create or replace function app_private.create_finals_tiebreak(
  source_contest_id uuid,
  target_type text,
  tied_score integer,
  target_slot integer,
  target_slots_to_fill integer
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  source public.event_finals_contests%rowtype;
begin
  if target_type = 'redemption_winner_tiebreak' then
    select *
    into source
    from public.event_finals_contests
    where id = source_contest_id
    for update;

    if source.contest_type = 'table_of_redemption'
      and source.slots_to_fill = 0
    then
      perform app_private.mark_redemption_co_winners(source_contest_id);
      return source_contest_id;
    end if;
  end if;

  return app_private.create_finals_tiebreak_before_redemption_co_winners(
    source_contest_id,
    target_type,
    tied_score,
    target_slot,
    target_slots_to_fill
  );
end;
$$;

alter function app_private.recalculate_finals_state(uuid)
  rename to recalculate_finals_state_before_redemption_co_winners;

create or replace function app_private.recalculate_finals_state(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  event_id_value uuid;
  bonus_round_id_value uuid;
  co_winners_changed boolean := false;
  completed_root_count integer := 0;
begin
  perform app_private.recalculate_finals_state_before_redemption_co_winners(
    target_table_session_id
  );

  select contest.event_id, contest.bonus_round_id
  into event_id_value, bonus_round_id_value
  from public.table_sessions as session
  join public.event_finals_contests as contest
    on contest.id = session.finals_contest_id
  where session.id = target_table_session_id;

  if bonus_round_id_value is null then
    return;
  end if;

  co_winners_changed :=
    app_private.resolve_redemption_co_winners(bonus_round_id_value);

  update public.event_bonus_rounds as root
  set status = 'completed',
      completed_at = coalesce(root.completed_at, now()),
      updated_at = now()
  where root.id = bonus_round_id_value
    and root.status <> 'completed'
    and root.champion_event_guest_id is not null
    and (
      root.eligible_player_count <= 4
      or root.redemption_winner_event_guest_id is not null
      or exists (
        select 1
        from public.event_finals_contests as contest
        join public.event_finals_contest_participants as participant
          on participant.contest_id = contest.id
        where contest.bonus_round_id = root.id
          and contest.contest_type = 'table_of_redemption'
          and contest.slots_to_fill = 0
          and contest.status = 'complete'
          and participant.outcome = 'winner'
      )
    )
    and not exists (
      select 1
      from public.event_finals_contests as unresolved
      where unresolved.bonus_round_id = root.id
        and unresolved.status in ('pending', 'ready', 'active')
    );
  get diagnostics completed_root_count = row_count;

  if co_winners_changed or completed_root_count > 0 then
    update public.event_bonus_rounds
    set state_version = state_version + 1,
        updated_at = now()
    where id = bonus_round_id_value;

    perform app_private.insert_audit_log(
      event_id_value,
      'event_bonus_round',
      bonus_round_id_value::text,
      'recalculate_finals_state',
      null,
      public.get_event_finals_state(event_id_value),
      jsonb_build_object(
        'actor_user_id', auth.uid(),
        'source_table_session_id', target_table_session_id,
        'redemption_co_winners', co_winners_changed
      )
    );
    perform app_private.refresh_event_score_totals(event_id_value);
  end if;
end;
$$;

do $$
declare
  target record;
  co_winners_changed boolean;
begin
  for target in
    select distinct root.id as bonus_round_id, root.event_id
    from public.event_bonus_rounds as root
    join public.event_finals_contests as contest
      on contest.bonus_round_id = root.id
    where root.flow_version = 'orchestrated'
      and contest.contest_type = 'redemption_winner_tiebreak'
      and contest.status in ('pending', 'ready', 'active')
  loop
    co_winners_changed :=
      app_private.resolve_redemption_co_winners(target.bonus_round_id);
    if not co_winners_changed then
      continue;
    end if;

    update public.event_bonus_rounds as root
    set status = 'completed',
        completed_at = coalesce(root.completed_at, now()),
        updated_at = now()
    where root.id = target.bonus_round_id
      and root.status <> 'completed'
      and root.champion_event_guest_id is not null
      and exists (
        select 1
        from public.event_finals_contests as contest
        join public.event_finals_contest_participants as participant
          on participant.contest_id = contest.id
        where contest.bonus_round_id = root.id
          and contest.contest_type = 'table_of_redemption'
          and contest.slots_to_fill = 0
          and contest.status = 'complete'
          and participant.outcome = 'winner'
      )
      and not exists (
        select 1
        from public.event_finals_contests as unresolved
        where unresolved.bonus_round_id = root.id
          and unresolved.status in ('pending', 'ready', 'active')
      );
    update public.event_bonus_rounds
    set state_version = state_version + 1,
        updated_at = now()
    where id = target.bonus_round_id;
    perform app_private.refresh_event_score_totals(target.event_id);
  end loop;
end;
$$;

revoke all on function
  app_private.recalculate_finals_state_before_redemption_co_winners(uuid)
from public;
revoke all on function
  app_private.mark_redemption_co_winners(uuid)
from public;
revoke all on function
  app_private.resolve_redemption_co_winners(uuid)
from public;
revoke all on function
  app_private.create_finals_tiebreak_before_redemption_co_winners(
    uuid, text, integer, integer, integer
  )
from public;
revoke all on function
  app_private.create_finals_tiebreak(
    uuid, text, integer, integer, integer
  )
from public;
revoke all on function
  app_private.recalculate_finals_state(uuid)
from public;

select pg_notify('pgrst', 'reload schema');
