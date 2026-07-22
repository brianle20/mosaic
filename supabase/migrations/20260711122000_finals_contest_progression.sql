-- Progress durable Finals contests from authoritative session scoring data.

create or replace function app_private.finals_contest_scores(
  target_contest_id uuid
)
returns table (
  event_guest_id uuid,
  score_points integer,
  entry_seed integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    participant.event_guest_id,
    coalesce(sum(
      case
        when settlement.payee_event_guest_id = participant.event_guest_id
          then settlement.amount_points
        when settlement.payer_event_guest_id = participant.event_guest_id
          then -settlement.amount_points
        else 0
      end
    ) filter (where hand_result.status = 'recorded'), 0)::integer,
    participant.entry_seed
  from public.event_finals_contest_participants as participant
  join public.event_finals_contests as contest
    on contest.id = participant.contest_id
  left join public.hand_results as hand_result
    on hand_result.table_session_id = contest.table_session_id
  left join public.hand_settlements as settlement
    on settlement.hand_result_id = hand_result.id
    and participant.event_guest_id in (
      settlement.payee_event_guest_id,
      settlement.payer_event_guest_id
    )
  where participant.contest_id = target_contest_id
  group by participant.event_guest_id, participant.entry_seed;
$$;

create or replace function app_private.prepare_finals_contest(
  target_contest_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  root_row public.event_bonus_rounds%rowtype;
  role_value text;
  next_assignment_round integer;
begin
  select * into contest_row
  from public.event_finals_contests
  where id = target_contest_id
  for update;
  if not found then
    raise exception 'Finals contest not found.' using errcode = 'P0001';
  end if;

  select * into root_row
  from public.event_bonus_rounds
  where id = contest_row.bonus_round_id
  for update;

  role_value := case contest_row.contest_type
    when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'
    when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'
    when 'redemption_winner_tiebreak' then 'table_of_redemption'
    when 'champions_sudden_death' then 'table_of_champions_sudden_death'
    else contest_row.contest_type
  end;

  delete from public.event_seating_assignments
  where finals_contest_id = contest_row.id
    and status <> 'active';

  if not exists (
    select 1 from public.event_seating_assignments
    where finals_contest_id = contest_row.id and status = 'active'
  ) then
    update public.event_seating_assignments as prior_assignment
    set status = 'cleared'
    where prior_assignment.event_id = contest_row.event_id
      and prior_assignment.status = 'active'
      and (
        prior_assignment.event_table_id = contest_row.event_table_id
        or prior_assignment.event_guest_id in (
          select participant.event_guest_id
          from public.event_finals_contest_participants as participant
          where participant.contest_id = contest_row.id
        )
      )
      and not exists (
        select 1 from public.table_sessions as live_session
        where live_session.finals_contest_id = prior_assignment.finals_contest_id
          and live_session.status in ('active', 'paused')
      );

    select coalesce(max(assignment.assignment_round), 0) + 1
    into next_assignment_round
    from public.event_seating_assignments as assignment
    where assignment.event_id = contest_row.event_id;

    insert into public.event_seating_assignments (
      event_id, event_table_id, event_guest_id, seat_index, assignment_round,
      assignment_type, bonus_round_id, bonus_table_role, seed_rank, status,
      assigned_at, assigned_by_user_id, finals_contest_id
    )
    select
      contest_row.event_id, contest_row.event_table_id,
      participant.event_guest_id,
      row_number() over (
        order by coalesce(participant.seat_index, participant.entry_seed),
          participant.entry_seed
      )::integer - 1,
      next_assignment_round, 'bonus', root_row.id, role_value,
      participant.entry_seed, 'active', now(), auth.uid(), contest_row.id
    from public.event_finals_contest_participants as participant
    where participant.contest_id = contest_row.id
    order by coalesce(participant.seat_index, participant.entry_seed),
      participant.entry_seed;
  end if;
end;
$$;

create or replace function public.get_public_event_finals_leaderboard(
  target_event_id uuid
)
returns table (
  bonus_table_role text, table_label text, event_guest_id uuid,
  public_display_name text, seat_index integer, total_points integer,
  hands_played integer, wins integer, rank integer
)
language sql
security definer
set search_path = public
as $$
  with bonus_assignments as (
    select assignment.event_table_id, event_table.label as table_label,
      assignment.event_guest_id, assignment.seat_index,
      assignment.bonus_round_id, assignment.bonus_table_role,
      assignment.finals_contest_id
    from public.event_seating_assignments as assignment
    join public.event_tables as event_table
      on event_table.id = assignment.event_table_id
      and event_table.event_id = assignment.event_id
    left join public.event_finals_contests as contest
      on contest.id = assignment.finals_contest_id
    where assignment.event_id = target_event_id
      and assignment.assignment_type = 'bonus'
      and (
        assignment.status = 'active'
        or (assignment.status = 'cleared' and contest.status = 'complete')
      )
      and assignment.bonus_round_id is not null
      and assignment.bonus_table_role is not null
  ),
  finals_scores as (
    select assignment.bonus_table_role, assignment.table_label,
      assignment.event_guest_id,
      coalesce(nullif(btrim(guest.public_display_name), ''), 'Player') as public_display_name,
      assignment.seat_index,
      coalesce(sum(case
        when settlement.payee_event_guest_id = assignment.event_guest_id then settlement.amount_points
        when settlement.payer_event_guest_id = assignment.event_guest_id then -settlement.amount_points
        else 0 end), 0)::integer as total_points,
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
      on session.finals_contest_id = assignment.finals_contest_id
      and session.scoring_phase = 'bonus'
    left join public.table_session_seats as seat
      on seat.table_session_id = session.id
      and seat.event_guest_id = assignment.event_guest_id
    left join public.hand_results as hand_result
      on hand_result.table_session_id = session.id
      and hand_result.status = 'recorded' and seat.id is not null
    left join public.hand_settlements as settlement
      on settlement.hand_result_id = hand_result.id
      and assignment.event_guest_id in (
        settlement.payee_event_guest_id, settlement.payer_event_guest_id
      )
    group by assignment.bonus_table_role, assignment.table_label,
      assignment.event_guest_id, guest.public_display_name, assignment.seat_index
  )
  select finals_scores.bonus_table_role, finals_scores.table_label,
    finals_scores.event_guest_id, finals_scores.public_display_name,
    finals_scores.seat_index, finals_scores.total_points,
    finals_scores.hands_played, finals_scores.wins,
    rank() over (
      partition by finals_scores.bonus_table_role, finals_scores.table_label
      order by finals_scores.total_points desc
    )::integer
  from finals_scores
  order by case finals_scores.bonus_table_role
      when 'table_of_champions' then 0
      when 'table_of_redemption' then 1 else 2 end,
    finals_scores.table_label, rank, finals_scores.seat_index;
$$;

create or replace function public.start_finals_contest(
  target_contest_id uuid,
  selected_table_id uuid,
  expected_state_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  bonus_round_row public.event_bonus_rounds%rowtype;
  original_table_id uuid;
  original_table_label text;
  replacement_table_label text;
  original_table_ready boolean := false;
  original_table_occupied boolean := false;
  contest_before_start jsonb;
  role_value text;
  started_session public.table_sessions%rowtype;
begin
  select * into contest_row
  from public.event_finals_contests
  where id = target_contest_id;
  if not found or not app_private.can_manage_event(contest_row.event_id) then
    raise exception 'Finals contest not found for current operator.' using errcode = 'P0001';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(contest_row.event_id::text, 0));

  select * into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.id = contest_row.bonus_round_id
    and bonus_round.flow_version = 'orchestrated'
  for update;
  select * into contest_row
  from public.event_finals_contests
  where id = target_contest_id
  for update;

  role_value := case contest_row.contest_type
    when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'
    when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'
    when 'redemption_winner_tiebreak' then 'table_of_redemption'
    when 'champions_sudden_death' then 'table_of_champions_sudden_death'
    else contest_row.contest_type
  end;

  if contest_row.status = 'active' then
    select session.* into started_session
    from public.table_sessions as session
    where session.id = contest_row.table_session_id
      and session.event_id = contest_row.event_id
      and session.finals_contest_id = contest_row.id
      and session.status in ('active', 'paused', 'completed');
    if not found then
      raise exception 'Finals contest references an unexpected session.'
        using errcode = 'P0001';
    end if;
    if not app_private.finals_session_matches_assignments(
      started_session.id,
      contest_row.event_id,
      contest_row.bonus_round_id,
      role_value,
      contest_row.event_table_id,
      started_session.assignment_round,
      contest_row.id
    ) then
      raise exception
        'Existing Finals session seats do not match the durable assignments.'
        using errcode = 'P0001';
    end if;
    return public.get_event_finals_state(contest_row.event_id);
  end if;
  if contest_row.status in ('complete', 'cancelled') then
    raise exception 'This Finals contest is no longer available to start.' using errcode = 'P0001';
  end if;
  if contest_row.status <> 'ready' then
    raise exception 'This Finals contest is not ready to start.' using errcode = 'P0001';
  end if;
  if bonus_round_row.state_version is distinct from expected_state_version then
    raise exception 'Finals changed since this screen was loaded. Refresh and try again.' using errcode = 'P0001';
  end if;
  if exists (
    select 1
    from public.event_finals_contest_participants as participant
    join public.event_guests as guest on guest.id = participant.event_guest_id
    where participant.contest_id = contest_row.id
      and guest.attendance_status <> 'checked_in'
  ) then
    raise exception 'All Finals players must be checked in before starting.'
      using errcode = 'P0001';
  end if;
  if exists (
    select 1
    from public.event_finals_contest_participants as participant
    join public.table_session_seats as seat
      on seat.event_guest_id = participant.event_guest_id
    join public.table_sessions as session on session.id = seat.table_session_id
    where participant.contest_id = contest_row.id
      and session.event_id = contest_row.event_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'A Finals player is already playing at another table.'
      using errcode = 'P0001';
  end if;

  original_table_id := contest_row.event_table_id;
  contest_before_start := to_jsonb(contest_row);

  perform event_table.id
  from public.event_tables as event_table
  where event_table.id in (original_table_id, selected_table_id)
  order by event_table.id
  for update;

  perform tag.id
  from public.nfc_tags as tag
  join public.event_tables as tagged_table
    on tagged_table.nfc_tag_id = tag.id
  where tagged_table.id in (original_table_id, selected_table_id)
  order by tag.id
  for update of tag;

  begin
    perform session.id
    from public.table_sessions as session
    where session.event_table_id in (original_table_id, selected_table_id)
      and session.status in ('active', 'paused')
    order by session.event_table_id, session.id
    for update nowait;
  exception
    when lock_not_available then
      raise exception
        'Selected Finals table is currently being scored. Refresh and try again.'
        using errcode = 'P0001';
  end;

  select event_table.label,
    tag.id is not null
  into original_table_label, original_table_ready
  from public.event_tables as event_table
  left join public.nfc_tags as tag
    on tag.id = event_table.nfc_tag_id
    and tag.default_tag_type = 'table'
    and tag.status = 'active'
  where event_table.id = original_table_id
    and event_table.event_id = contest_row.event_id;

  select exists (
    select 1
    from public.table_sessions as session
    where session.event_table_id = original_table_id
      and session.status in ('active', 'paused')
  ) into original_table_occupied;

  if selected_table_id is distinct from contest_row.event_table_id then
    if original_table_id is not null
      and original_table_ready
      and not original_table_occupied
    then
      raise exception 'This Finals contest is assigned to a different table. Refresh and try again.' using errcode = 'P0001';
    end if;
    select event_table.label
    into replacement_table_label
    from public.event_tables as event_table
      join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
        and tag.default_tag_type = 'table' and tag.status = 'active'
    where event_table.id = selected_table_id
      and event_table.event_id = contest_row.event_id
      and not exists (
        select 1
        from public.table_sessions as session
        where session.event_table_id = event_table.id
          and session.status in ('active', 'paused')
      );
    if not found then
      raise exception 'Selected Finals table is not available for this event.' using errcode = 'P0001';
    end if;
    update public.event_finals_contests
    set event_table_id = selected_table_id
    where id = contest_row.id;
    contest_row.event_table_id := selected_table_id;
  else
    replacement_table_label := original_table_label;
  end if;

  perform app_private.prepare_finals_contest(contest_row.id);
  started_session := app_private.start_assigned_finals_session(
    contest_row.event_id, contest_row.bonus_round_id, role_value,
    contest_row.id, now()
  );

  update public.event_bonus_rounds
  set state_version = state_version + 1, updated_at = now()
  where id = bonus_round_row.id;

  perform app_private.insert_audit_log(
    contest_row.event_id, 'event_finals_contest', contest_row.id::text,
    'start_finals_contest', contest_before_start,
    to_jsonb((select updated from public.event_finals_contests as updated where updated.id = contest_row.id)),
    jsonb_build_object(
      'actor_user_id', auth.uid(),
      'original_table_id', original_table_id,
      'original_table_label', original_table_label,
      'table_id', contest_row.event_table_id,
      'table_label', replacement_table_label,
      'table_rebound', original_table_id is distinct from contest_row.event_table_id,
      'table_session_id', started_session.id
    )
  );

  return public.get_event_finals_state(contest_row.event_id);
end;
$$;

create or replace function app_private.assert_finals_eligible_snapshot_complete(
  target_bonus_round_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  eligible_count integer;
  snapshot_count integer;
  minimum_seed integer;
  maximum_seed integer;
begin
  select root.eligible_player_count
  into eligible_count
  from public.event_bonus_rounds as root
  where root.id = target_bonus_round_id
    and root.flow_version = 'orchestrated';

  if not found then
    raise exception 'Finals eligible snapshot root was not found.'
      using errcode = 'P0001';
  end if;

  select count(*)::integer, min(seed_rank), max(seed_rank)
  into snapshot_count, minimum_seed, maximum_seed
  from public.event_finals_eligible_snapshot
  where bonus_round_id = target_bonus_round_id;

  if snapshot_count is distinct from eligible_count
    or minimum_seed is distinct from 1
    or maximum_seed is distinct from eligible_count
  then
    raise exception 'Finals eligible snapshot is incomplete for this root.'
      using errcode = 'P0001';
  end if;
end;
$$;

create or replace function app_private.ensure_champions_contest_ready(
  target_bonus_round_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  slot_count integer;
  filled_count integer;
begin
  perform app_private.assert_finals_eligible_snapshot_complete(
    target_bonus_round_id
  );

  select count(*), count(event_guest_id)
  into slot_count, filled_count
  from public.event_finals_champions_slots
  where bonus_round_id = target_bonus_round_id;
  if slot_count = 0 or slot_count <> filled_count then return; end if;

  select * into contest_row
  from public.event_finals_contests
  where bonus_round_id = target_bonus_round_id
    and contest_type = 'table_of_champions'
    and status = 'pending'
  order by sequence_number
  limit 1
  for update;
  if not found then return; end if;

  if exists (
    select 1
    from public.event_finals_champions_slots as slot
    where slot.bonus_round_id = target_bonus_round_id
      and slot.event_guest_id is not null
      and not exists (
        select 1
        from public.event_finals_eligible_snapshot as snapshot
        where snapshot.bonus_round_id = slot.bonus_round_id
          and snapshot.event_guest_id = slot.event_guest_id
      )
  ) then
    raise exception 'Finals eligible snapshot is incomplete for this root.'
      using errcode = 'P0001';
  end if;

  delete from public.event_finals_contest_participants
  where contest_id = contest_row.id;
  insert into public.event_finals_contest_participants (
    contest_id, event_guest_id, entry_seed, seat_index
  )
  select contest_row.id, slot.event_guest_id,
    snapshot.seed_rank,
    case when slot_count = 4 then 4 - slot.slot_index else slot.slot_index - 1 end
  from public.event_finals_champions_slots as slot
  join public.event_finals_eligible_snapshot as snapshot
    on snapshot.bonus_round_id = slot.bonus_round_id
    and snapshot.event_guest_id = slot.event_guest_id
  where slot.bonus_round_id = target_bonus_round_id;

  update public.event_finals_contests
  set status = 'ready', updated_at = now()
  where id = contest_row.id;
end;
$$;

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
  source_row public.event_finals_contests%rowtype;
  child_id uuid;
  next_sequence integer;
begin
  select * into source_row from public.event_finals_contests
  where id = source_contest_id for update;
  select coalesce(max(sequence_number), 0) + 1 into next_sequence
  from public.event_finals_contests where bonus_round_id = source_row.bonus_round_id;

  select id into child_id
  from public.event_finals_contests
  where parent_contest_id = source_row.id
    and contest_type = target_type
    and status in ('ready', 'active')
  order by sequence_number desc limit 1;
  if child_id is not null then return child_id; end if;

  insert into public.event_finals_contests (
    bonus_round_id, event_id, contest_type, status, parent_contest_id,
    event_table_id, slots_to_fill, slot_start_index, sequence_number,
    created_by_user_id
  ) values (
    source_row.bonus_round_id, source_row.event_id, target_type, 'ready', source_row.id,
    source_row.event_table_id, target_slots_to_fill, target_slot, next_sequence,
    auth.uid()
  ) returning id into child_id;

  insert into public.event_finals_contest_participants (
    contest_id, event_guest_id, entry_seed, seat_index
  )
  select child_id, score.event_guest_id, score.entry_seed,
    row_number() over (order by score.entry_seed)::integer - 1
  from app_private.finals_contest_scores(source_row.id) as score
  where score.score_points = tied_score;
  perform app_private.insert_audit_log(
    source_row.event_id, 'event_finals_contest', child_id::text,
    'create_finals_contest', null,
    to_jsonb((select created from public.event_finals_contests as created where created.id = child_id)),
    jsonb_build_object(
      'actor_user_id', auth.uid(), 'parent_contest_id', source_row.id,
      'target_slot', target_slot, 'slots_to_fill', target_slots_to_fill
    )
  );
  return child_id;
end;
$$;

create or replace function app_private.finish_orchestrated_champion(
  target_contest_id uuid,
  champion_guest_id uuid,
  champion_score integer,
  resolution_method text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  root_row public.event_bonus_rounds%rowtype;
  base_total integer;
  other_total integer;
  top_up integer;
  award integer;
begin
  select * into contest_row from public.event_finals_contests
  where id = target_contest_id for update;
  select * into root_row from public.event_bonus_rounds
  where id = contest_row.bonus_round_id for update;

  delete from public.event_score_adjustments as adjustment
  using public.table_sessions as source
  where adjustment.adjustment_type = 'finals_champion_award'
    and adjustment.source_table_session_id = source.id
    and source.bonus_round_id = root_row.id;
  perform app_private.refresh_event_score_totals(contest_row.event_id);
  select coalesce(total_points, 0) into base_total
  from public.event_score_totals
  where event_id = contest_row.event_id and event_guest_id = champion_guest_id;
  select coalesce(max(total_points), 0) into other_total
  from public.event_score_totals
  where event_id = contest_row.event_id and event_guest_id <> champion_guest_id;
  base_total := coalesce(base_total, 0);
  other_total := coalesce(other_total, 0);
  top_up := greatest(0, other_total + 1 - (base_total + champion_score));
  award := champion_score + top_up;

  if award > 0 then
    insert into public.event_score_adjustments (
      event_id, event_guest_id, adjustment_type, amount_points, label,
      source_table_session_id, context_json, created_by_user_id
    ) values (
      contest_row.event_id, champion_guest_id, 'finals_champion_award', award,
      'Finals champion award', contest_row.table_session_id,
      jsonb_build_object(
        'formula', 'award_points = finals score or sudden death resolution + top-up',
        'champion_bonus_score_points', champion_score,
        'champion_base_total', base_total,
        'top_non_champion_event_total_before_champion_award', other_total,
        'champion_top_up_points', top_up,
        'award_points', award,
        'champion_resolution_method', resolution_method
      ), auth.uid()
    );
  end if;

  update public.event_bonus_rounds
  set champion_event_guest_id = champion_guest_id,
      champion_bonus_score_points = champion_score,
      champion_top_up_points = top_up,
      champion_award_points = award,
      champion_resolution_method = resolution_method,
      sudden_death_status = case when resolution_method = 'sudden_death' then 'completed' else 'not_required' end,
      sudden_death_session_id = case when resolution_method = 'sudden_death' then contest_row.table_session_id else null end,
      updated_at = now()
  where id = root_row.id;
  perform app_private.insert_audit_log(
    contest_row.event_id, 'event_bonus_round', root_row.id::text,
    'award_finals_champion', to_jsonb(root_row),
    to_jsonb((select updated from public.event_bonus_rounds as updated where updated.id = root_row.id)),
    jsonb_build_object(
      'actor_user_id', auth.uid(), 'source_contest_id', contest_row.id,
      'champion_event_guest_id', champion_guest_id, 'award_points', award
    )
  );
  perform app_private.refresh_event_score_totals(contest_row.event_id);
end;
$$;

create or replace function app_private.resolve_finals_tiebreak_participant_outcomes(
  target_contest_id uuid,
  winner_event_guest_id uuid,
  runner_up_event_guest_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  source_row public.event_finals_contests%rowtype;
  source_found boolean := false;
  source_finish_order integer := 1;
begin
  select * into contest_row
  from public.event_finals_contests
  where id = target_contest_id;
  if not found then return; end if;

  update public.event_finals_contest_participants as participant
  set outcome = case
        when participant.event_guest_id = winner_event_guest_id then 'winner'
        when participant.event_guest_id = runner_up_event_guest_id then 'runner_up'
        else 'pending'
      end,
      outcome_order = case
        when participant.event_guest_id = winner_event_guest_id then 1
        when participant.event_guest_id = runner_up_event_guest_id then 2
        else null
      end,
      advanced_champions_slot = case
        when participant.event_guest_id = winner_event_guest_id
          then contest_row.slot_start_index
        when participant.event_guest_id = runner_up_event_guest_id
          and contest_row.slot_start_index is not null
          then contest_row.slot_start_index + 1
        else null
      end
  where participant.contest_id = contest_row.id;

  with recursive lineage as (
    select contest.*, 0 as depth
    from public.event_finals_contests as contest
    where contest.id = contest_row.id
    union all
    select parent.*, lineage.depth + 1
    from lineage
    join public.event_finals_contests as parent
      on parent.id = lineage.parent_contest_id
  )
  select lineage.* into source_row
  from lineage
  where lineage.contest_type in ('table_of_redemption', 'table_of_champions')
  order by lineage.depth
  limit 1;
  source_found := found;

  if source_found and source_row.contest_type = 'table_of_redemption' then
    source_finish_order := case
      when contest_row.slot_start_index is not null
        and source_row.slot_start_index is not null
        then contest_row.slot_start_index - source_row.slot_start_index + 1
      else 1
    end;

    update public.event_finals_contest_participants as participant
    set outcome = case
          when participant.event_guest_id = winner_event_guest_id then case
            when source_finish_order = 1 then 'winner'
            when source_finish_order = 2 then 'runner_up'
            else 'advanced'
          end
          when participant.event_guest_id = runner_up_event_guest_id then case
            when source_finish_order + 1 = 1 then 'winner'
            when source_finish_order + 1 = 2 then 'runner_up'
            else 'advanced'
          end
          else participant.outcome
        end,
        outcome_order = case
          when participant.event_guest_id = winner_event_guest_id
            then source_finish_order
          when participant.event_guest_id = runner_up_event_guest_id
            then source_finish_order + 1
          else participant.outcome_order
        end,
        advanced_champions_slot = case
          when participant.event_guest_id = winner_event_guest_id
            then contest_row.slot_start_index
          when participant.event_guest_id = runner_up_event_guest_id
            and contest_row.slot_start_index is not null
            then contest_row.slot_start_index + 1
          else participant.advanced_champions_slot
        end
    where participant.contest_id = source_row.id
      and participant.event_guest_id in (
        winner_event_guest_id, runner_up_event_guest_id
      );
  elsif source_found and source_row.contest_type = 'table_of_champions' then
    update public.event_finals_contest_participants as participant
    set outcome = case
          when participant.event_guest_id = winner_event_guest_id
            then 'winner'
          else 'eliminated'
        end,
        outcome_order = case
          when participant.event_guest_id = winner_event_guest_id then 1
          else null
        end,
        advanced_champions_slot = null
    where participant.contest_id = source_row.id;
  end if;

  -- A chained tiebreak may span several child contests. Record each resolved
  -- participant in every tiebreak they appeared in, while retaining pending
  -- participants that still have a ready or active child contest.
  with recursive ancestors as (
    select contest.id, contest.parent_contest_id, contest.contest_type, 0 as depth
    from public.event_finals_contests as contest
    where contest.id = contest_row.id
    union all
    select parent.id, parent.parent_contest_id, parent.contest_type,
      ancestors.depth + 1
    from ancestors
    join public.event_finals_contests as parent
      on parent.id = ancestors.parent_contest_id
  )
  update public.event_finals_contest_participants as participant
  set outcome = case
        when participant.event_guest_id = winner_event_guest_id then 'winner'
        else 'runner_up'
      end,
      outcome_order = case
        when participant.event_guest_id = winner_event_guest_id then 1
        else 2
      end,
      advanced_champions_slot = case
        when participant.event_guest_id = winner_event_guest_id
          then contest_row.slot_start_index
        when contest_row.slot_start_index is not null
          then contest_row.slot_start_index + 1
        else null
      end
  from ancestors
  where ancestors.depth > 0
    and ancestors.contest_type in (
      'direct_qualification_tiebreak', 'redemption_advancement_tiebreak',
      'redemption_winner_tiebreak', 'champions_sudden_death'
    )
    and participant.contest_id = ancestors.id
    and participant.event_guest_id in (
      winner_event_guest_id, runner_up_event_guest_id
    );

  with recursive lineage_ids as (
    select contest.id, contest.parent_contest_id
    from public.event_finals_contests as contest
    where contest.id = contest_row.id
    union all
    select parent.id, parent.parent_contest_id
    from lineage_ids
    join public.event_finals_contests as parent
      on parent.id = lineage_ids.parent_contest_id
  )
  update public.event_finals_contest_participants as participant
  set outcome = 'eliminated', outcome_order = null,
      advanced_champions_slot = null
  where participant.contest_id in (select id from lineage_ids)
    and participant.outcome = 'pending'
    and not exists (
      select 1
      from public.event_finals_contests as unresolved
      join public.event_finals_contest_participants as unresolved_participant
        on unresolved_participant.contest_id = unresolved.id
      where unresolved.bonus_round_id = contest_row.bonus_round_id
        and unresolved.status in ('ready', 'active')
        and unresolved.contest_type in (
          'direct_qualification_tiebreak', 'redemption_advancement_tiebreak',
          'redemption_winner_tiebreak', 'champions_sudden_death'
        )
        and unresolved_participant.event_guest_id = participant.event_guest_id
    );
end;
$$;

create or replace function app_private.recalculate_finals_state(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
  contest_row public.event_finals_contests%rowtype;
  bonus_round_row public.event_bonus_rounds%rowtype;
  score_row record;
  winner_id uuid;
  winner_score integer;
  tied_count integer;
  relevant_positions integer;
  position_index integer := 0;
  target_slot integer;
  tied_score integer;
  child_id uuid;
  remaining_count integer;
  runner_up_id uuid;
  changed boolean := false;
  event_id_value uuid;
begin
  select event_id into event_id_value
  from public.table_sessions
  where id = target_table_session_id;
  if event_id_value is null then return; end if;
  perform pg_advisory_xact_lock(hashtextextended(event_id_value::text, 0));

  select * into session_row from public.table_sessions
  where id = target_table_session_id for update;
  if not found or session_row.finals_contest_id is null then return; end if;
  select * into contest_row from public.event_finals_contests
  where id = session_row.finals_contest_id for update;
  select * into bonus_round_row from public.event_bonus_rounds
  where id = contest_row.bonus_round_id for update;
  if bonus_round_row.flow_version <> 'orchestrated' then return; end if;

  if contest_row.status = 'complete' and exists (
    select 1 from public.event_finals_contests as dependent
    where dependent.bonus_round_id = contest_row.bonus_round_id
      and dependent.id <> contest_row.id
      and dependent.status in ('active', 'complete')
      and (
        dependent.parent_contest_id = contest_row.id
        or (
          contest_row.contest_type = 'direct_qualification_tiebreak'
          and dependent.contest_type = 'table_of_redemption'
        )
        or (
          (
            contest_row.contest_type in (
              'direct_qualification_tiebreak', 'redemption_advancement_tiebreak'
            )
            or (
              contest_row.contest_type = 'table_of_redemption'
              and bonus_round_row.format = 'redemption_advancement'
            )
          )
          and dependent.contest_type = 'table_of_champions'
        )
      )
  ) then
    raise exception 'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.'
      using errcode = 'P0001';
  end if;

  if contest_row.status = 'complete'
    and contest_row.contest_type in ('table_of_champions', 'champions_sudden_death') then
    for score_row in
      select child.* from public.event_finals_contests as child
      where child.parent_contest_id = contest_row.id and child.status = 'ready'
    loop
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_finals_contest', score_row.id::text,
        'cancel_finals_contest', to_jsonb(score_row),
        to_jsonb(score_row) || jsonb_build_object('status', 'cancelled'),
        jsonb_build_object('actor_user_id', auth.uid(), 'reason', 'upstream_result_changed')
      );
    end loop;
    update public.event_seating_assignments as assignment
    set status = 'cleared'
    where assignment.finals_contest_id in (
      select child.id from public.event_finals_contests as child
      where child.parent_contest_id = contest_row.id and child.status = 'ready'
    ) and assignment.status = 'active';
    update public.event_finals_contests
    set status = 'cancelled', updated_at = now()
    where parent_contest_id = contest_row.id and status = 'ready';
    delete from public.event_score_adjustments as adjustment
    using public.table_sessions as source
    where adjustment.adjustment_type = 'finals_champion_award'
      and adjustment.source_table_session_id = source.id
      and source.bonus_round_id = contest_row.bonus_round_id;
    update public.event_bonus_rounds
    set status = 'active', champion_event_guest_id = null,
        champion_bonus_score_points = null, champion_top_up_points = null,
        champion_award_points = null, completed_at = null,
        sudden_death_status = 'not_required', sudden_death_session_id = null
    where id = contest_row.bonus_round_id;
    update public.event_finals_contest_participants
    set outcome = 'pending', outcome_order = null
    where contest_id = contest_row.id;
    if session_row.status <> 'completed' then
      update public.event_finals_contests
      set status = 'active', completed_at = null, updated_at = now()
      where id = contest_row.id;
      changed := true;
    end if;
  elsif contest_row.status = 'complete'
    and contest_row.contest_type in (
      'direct_qualification_tiebreak', 'redemption_advancement_tiebreak',
      'redemption_winner_tiebreak'
    ) then
    for score_row in
      select child.* from public.event_finals_contests as child
      where child.parent_contest_id = contest_row.id and child.status = 'ready'
    loop
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_finals_contest', score_row.id::text,
        'cancel_finals_contest', to_jsonb(score_row),
        to_jsonb(score_row) || jsonb_build_object('status', 'cancelled'),
        jsonb_build_object('actor_user_id', auth.uid(), 'reason', 'upstream_result_changed')
      );
    end loop;
    update public.event_seating_assignments as assignment
    set status = 'cleared'
    where assignment.finals_contest_id in (
      select child.id from public.event_finals_contests as child
      where child.parent_contest_id = contest_row.id and child.status = 'ready'
    ) and assignment.status = 'active';
    update public.event_finals_contests
    set status = 'cancelled', updated_at = now()
    where parent_contest_id = contest_row.id and status = 'ready';
    update public.event_finals_champions_slots
    set event_guest_id = null, qualification_method = null,
        source_contest_id = null, source_finish_order = null
    where bonus_round_id = contest_row.bonus_round_id
      and source_contest_id = contest_row.id;
    if contest_row.contest_type in (
      'direct_qualification_tiebreak', 'redemption_advancement_tiebreak'
    ) then
      update public.event_finals_contests
      set status = 'pending', updated_at = now()
      where bonus_round_id = contest_row.bonus_round_id
        and contest_type = 'table_of_champions' and status = 'ready';
    end if;
    update public.event_finals_contest_participants
    set outcome = 'pending', advanced_champions_slot = null, outcome_order = null
    where contest_id = contest_row.id;
    if contest_row.contest_type in ('redemption_advancement_tiebreak', 'redemption_winner_tiebreak') then
      update public.event_bonus_rounds
      set status = 'active', completed_at = null,
          redemption_winner_event_guest_id = case
            when redemption_winner_event_guest_id in (
              select participant.event_guest_id
              from public.event_finals_contest_participants as participant
              where participant.contest_id = contest_row.id
            ) then null else redemption_winner_event_guest_id end,
          redemption_resolution_method = case
            when redemption_winner_event_guest_id in (
              select participant.event_guest_id
              from public.event_finals_contest_participants as participant
              where participant.contest_id = contest_row.id
            ) then null else redemption_resolution_method end
      where id = contest_row.bonus_round_id;
    end if;
    if session_row.status <> 'completed' then
      update public.event_finals_contests
      set status = 'active', completed_at = null, updated_at = now()
      where id = contest_row.id;
      changed := true;
    end if;
  end if;

  if contest_row.status = 'complete'
    and contest_row.contest_type = 'table_of_redemption' then
    if exists (
      select 1 from public.event_finals_contests as dependent
      where dependent.bonus_round_id = contest_row.bonus_round_id
        and (
          dependent.parent_contest_id = contest_row.id
          or (
            dependent.contest_type = 'table_of_champions'
            and bonus_round_row.format = 'redemption_advancement'
          )
        )
        and dependent.status in ('active', 'complete')
    ) then
      raise exception 'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.'
        using errcode = 'P0001';
    end if;

    for score_row in
      select child.* from public.event_finals_contests as child
      where child.parent_contest_id = contest_row.id and child.status = 'ready'
    loop
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_finals_contest', score_row.id::text,
        'cancel_finals_contest', to_jsonb(score_row),
        to_jsonb(score_row) || jsonb_build_object('status', 'cancelled'),
        jsonb_build_object('actor_user_id', auth.uid(), 'reason', 'upstream_result_changed')
      );
    end loop;
    update public.event_seating_assignments as assignment
    set status = 'cleared'
    where assignment.finals_contest_id in (
      select dependent.id from public.event_finals_contests as dependent
      where dependent.parent_contest_id = contest_row.id
        and dependent.status = 'ready'
    ) and assignment.status = 'active';
    update public.event_finals_contests
    set status = 'cancelled', updated_at = now()
    where parent_contest_id = contest_row.id and status = 'ready';
    update public.event_finals_contests
    set status = 'pending', completed_at = null, updated_at = now()
    where bonus_round_id = contest_row.bonus_round_id
      and contest_type = 'table_of_champions' and status = 'ready';
    update public.event_finals_champions_slots
    set event_guest_id = null, qualification_method = null,
        source_contest_id = null, source_finish_order = null
    where bonus_round_id = contest_row.bonus_round_id
      and source_contest_id = contest_row.id;
    update public.event_finals_contest_participants
    set outcome = 'pending', advanced_champions_slot = null, outcome_order = null
    where contest_id = contest_row.id;
    update public.event_bonus_rounds
    set redemption_winner_event_guest_id = null,
        redemption_resolution_method = null, status = 'active', completed_at = null
    where id = contest_row.bonus_round_id;
    if session_row.status <> 'completed' then
      update public.event_finals_contests
      set status = 'active', completed_at = null, updated_at = now()
      where id = contest_row.id;
      changed := true;
    end if;
  end if;

  if contest_row.contest_type in (
    'direct_qualification_tiebreak', 'redemption_advancement_tiebreak',
    'redemption_winner_tiebreak', 'champions_sudden_death'
  ) then
    select seat.event_guest_id into winner_id
    from public.hand_results as hand_result
    join public.table_session_seats as seat
      on seat.table_session_id = hand_result.table_session_id
      and seat.seat_index = hand_result.winner_seat_index
    where hand_result.table_session_id = session_row.id
      and hand_result.status = 'recorded' and hand_result.result_type = 'win'
    order by hand_result.hand_number, hand_result.created_at
    limit 1;
    if winner_id is null then
      if changed then
        update public.event_bonus_rounds
        set state_version = state_version + 1, updated_at = now()
        where id = bonus_round_row.id;
        perform app_private.refresh_event_score_totals(bonus_round_row.event_id);
      end if;
      return;
    end if;

    update public.table_sessions
    set status = 'completed',
        ended_at = coalesce(ended_at, now()),
        ended_by_user_id = coalesce(ended_by_user_id, auth.uid()),
        end_reason = 'finals_tiebreak_resolved',
        round_timer_paused_at = null
    where id = session_row.id
      and status in ('active', 'paused');
    session_row.status := 'completed';

    update public.event_finals_contest_participants
    set outcome = case when event_guest_id = winner_id then 'winner' else 'pending' end,
        outcome_order = case when event_guest_id = winner_id then 1 else null end,
        advanced_champions_slot = case
          when event_guest_id = winner_id and contest_row.slot_start_index is not null
            then contest_row.slot_start_index
          else null end
    where contest_id = contest_row.id;
    update public.event_finals_contests
    set status = 'complete', completed_at = now(), updated_at = now()
    where id = contest_row.id;
    perform app_private.insert_audit_log(
      contest_row.event_id, 'event_finals_contest', contest_row.id::text,
      'complete_finals_contest', to_jsonb(contest_row),
      to_jsonb((select updated from public.event_finals_contests as updated where updated.id = contest_row.id)),
      jsonb_build_object('actor_user_id', auth.uid(), 'winner_event_guest_id', winner_id)
    );
    changed := true;

    if contest_row.contest_type = 'champions_sudden_death' then
      perform app_private.finish_orchestrated_champion(
        contest_row.id, winner_id, 0, 'sudden_death'
      );
    elsif contest_row.contest_type = 'redemption_winner_tiebreak' then
      update public.event_bonus_rounds
      set redemption_winner_event_guest_id = winner_id,
          redemption_resolution_method = 'sudden_death'
      where id = contest_row.bonus_round_id;
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
        'resolve_redemption_winner', to_jsonb(bonus_round_row),
        to_jsonb((select updated from public.event_bonus_rounds as updated where updated.id = contest_row.bonus_round_id)),
        jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
      );
    elsif contest_row.slot_start_index is not null then
      update public.event_finals_champions_slots
      set event_guest_id = winner_id, qualification_method = 'tiebreak_win',
          source_contest_id = contest_row.id, source_finish_order = 1
      where bonus_round_id = contest_row.bonus_round_id
        and slot_index = contest_row.slot_start_index;
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
        'fill_finals_champions_slot', null,
        to_jsonb((select slot from public.event_finals_champions_slots as slot
          where slot.bonus_round_id = contest_row.bonus_round_id
            and slot.slot_index = contest_row.slot_start_index)),
        jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
      );

      if contest_row.contest_type in ('redemption_advancement_tiebreak', 'redemption_winner_tiebreak')
        and contest_row.slot_start_index = (
          select min(slot_start_index) from public.event_finals_contests
          where id = contest_row.id or id = contest_row.parent_contest_id
        ) then
        update public.event_bonus_rounds
        set redemption_winner_event_guest_id = winner_id,
            redemption_resolution_method = 'sudden_death'
        where id = contest_row.bonus_round_id;
        perform app_private.insert_audit_log(
          contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
          'resolve_redemption_winner', to_jsonb(bonus_round_row),
          to_jsonb((select updated from public.event_bonus_rounds as updated where updated.id = contest_row.bonus_round_id)),
          jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
        );
      end if;

      select count(*) into remaining_count
      from public.event_finals_contest_participants
      where contest_id = contest_row.id and event_guest_id <> winner_id;
      if contest_row.slots_to_fill > 1 and remaining_count > 1 then
        select coalesce(max(sequence_number), 0) + 1 into position_index
        from public.event_finals_contests where bonus_round_id = contest_row.bonus_round_id;
        insert into public.event_finals_contests (
          bonus_round_id, event_id, contest_type, status, parent_contest_id,
          event_table_id, slots_to_fill, slot_start_index, sequence_number,
          created_by_user_id
        ) values (
          contest_row.bonus_round_id, contest_row.event_id, contest_row.contest_type,
          'ready', contest_row.id, contest_row.event_table_id,
          contest_row.slots_to_fill - 1, contest_row.slot_start_index + 1,
          position_index, auth.uid()
        ) returning id into child_id;
        insert into public.event_finals_contest_participants (
          contest_id, event_guest_id, entry_seed, seat_index
        )
        select child_id, event_guest_id, entry_seed,
          row_number() over (order by entry_seed)::integer - 1
        from public.event_finals_contest_participants
        where contest_id = contest_row.id and event_guest_id <> winner_id;
        perform app_private.insert_audit_log(
          contest_row.event_id, 'event_finals_contest', child_id::text,
          'create_finals_contest', null,
          to_jsonb((select created from public.event_finals_contests as created where created.id = child_id)),
          jsonb_build_object(
            'actor_user_id', auth.uid(), 'parent_contest_id', contest_row.id,
            'reason', 'remaining_tied_players'
          )
        );
      elsif contest_row.slots_to_fill > 1 and remaining_count = 1 then
        select event_guest_id into runner_up_id
        from public.event_finals_contest_participants
        where contest_id = contest_row.id and event_guest_id <> winner_id;
        update public.event_finals_champions_slots
        set event_guest_id = runner_up_id, qualification_method = 'tiebreak_win',
            source_contest_id = contest_row.id, source_finish_order = 2
        where bonus_round_id = contest_row.bonus_round_id
          and slot_index = contest_row.slot_start_index + 1;
        perform app_private.insert_audit_log(
          contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
          'fill_finals_champions_slot', null,
          to_jsonb((select slot from public.event_finals_champions_slots as slot
            where slot.bonus_round_id = contest_row.bonus_round_id
              and slot.slot_index = contest_row.slot_start_index + 1)),
          jsonb_build_object(
            'actor_user_id', auth.uid(), 'source_contest_id', contest_row.id,
            'resolution', 'sole_remaining_player'
          )
        );
      end if;
      if contest_row.contest_type = 'redemption_advancement_tiebreak' then
        perform app_private.ensure_champions_contest_ready(contest_row.bonus_round_id);
      end if;
    end if;

    perform app_private.resolve_finals_tiebreak_participant_outcomes(
      contest_row.id, winner_id, runner_up_id
    );

    if contest_row.contest_type = 'direct_qualification_tiebreak'
      and contest_row.slots_to_fill = 1 then
      if bonus_round_row.eligible_player_count = 5 then
        select participant.event_guest_id into winner_id
        from public.event_finals_contest_participants as participant
        where participant.contest_id = contest_row.id
          and participant.outcome <> 'winner'
        order by participant.entry_seed limit 1;
        update public.event_bonus_rounds
        set redemption_winner_event_guest_id = winner_id,
            redemption_resolution_method = 'standing_fifth'
        where id = contest_row.bonus_round_id;
        perform app_private.insert_audit_log(
          contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
          'resolve_redemption_winner', to_jsonb(bonus_round_row),
          to_jsonb((select updated from public.event_bonus_rounds as updated where updated.id = contest_row.bonus_round_id)),
          jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
        );
      else
        perform app_private.assert_finals_eligible_snapshot_complete(
          bonus_round_row.id
        );
        select * into contest_row
        from public.event_finals_contests
        where bonus_round_id = bonus_round_row.id
          and contest_type = 'table_of_redemption'
        order by sequence_number limit 1 for update;
        if found then
          delete from public.event_finals_contest_participants
          where contest_id = contest_row.id;
          insert into public.event_finals_contest_participants (
            contest_id, event_guest_id, entry_seed, seat_index
          )
          select contest_row.id, snapshot.event_guest_id, snapshot.seed_rank,
            row_number() over (order by snapshot.seed_rank)::integer - 1
          from public.event_finals_eligible_snapshot as snapshot
          where snapshot.bonus_round_id = bonus_round_row.id
            and (
              (
                bonus_round_row.eligible_player_count in (6, 7)
                and not exists (
                  select 1 from public.event_finals_champions_slots as slot
                  where slot.bonus_round_id = bonus_round_row.id
                    and slot.event_guest_id = snapshot.event_guest_id
                )
              )
              or (
                bonus_round_row.eligible_player_count >= 8
                and snapshot.event_guest_id in (
                  select candidate.event_guest_id
                  from public.event_finals_eligible_snapshot as candidate
                  where candidate.bonus_round_id = bonus_round_row.id
                    and not exists (
                      select 1
                      from public.event_finals_champions_slots as occupied_slot
                      where occupied_slot.bonus_round_id = bonus_round_row.id
                        and occupied_slot.event_guest_id = candidate.event_guest_id
                    )
                  order by
                    (candidate.seed_rank > bonus_round_row.eligible_player_count - 4) desc,
                    candidate.seed_rank
                  limit 4
                )
              )
            );
          update public.event_finals_contests set status = 'ready'
          where id = contest_row.id;
        end if;
      end if;
      perform app_private.ensure_champions_contest_ready(bonus_round_row.id);
    end if;
  elsif session_row.status = 'completed' then
    if contest_row.contest_type = 'table_of_champions' then
      select max(score_points) into winner_score
      from app_private.finals_contest_scores(contest_row.id);
      select count(*), (array_agg(event_guest_id order by entry_seed))[1]
      into tied_count, winner_id
      from app_private.finals_contest_scores(contest_row.id)
      where score_points = winner_score;
      if tied_count > 1 then
        child_id := app_private.create_finals_tiebreak(
          contest_row.id, 'champions_sudden_death', winner_score, null, 1
        );
        update public.event_finals_contests
        set status = 'complete', completed_at = now(), updated_at = now()
        where id = contest_row.id;
        update public.event_bonus_rounds
        set champion_resolution_method = 'sudden_death', sudden_death_status = 'required'
        where id = contest_row.bonus_round_id;
      else
        update public.event_finals_contest_participants
        set outcome = case when event_guest_id = winner_id then 'winner' else 'eliminated' end,
            outcome_order = case when event_guest_id = winner_id then 1 else null end
        where contest_id = contest_row.id;
        update public.event_finals_contests set status = 'complete', completed_at = now()
        where id = contest_row.id;
        perform app_private.insert_audit_log(
          contest_row.event_id, 'event_finals_contest', contest_row.id::text,
          'complete_finals_contest', to_jsonb(contest_row),
          to_jsonb((select updated from public.event_finals_contests as updated where updated.id = contest_row.id)),
          jsonb_build_object('actor_user_id', auth.uid(), 'winner_event_guest_id', winner_id)
        );
        perform app_private.finish_orchestrated_champion(
          contest_row.id, winner_id, winner_score, 'standard'
        );
      end if;
      changed := true;
    elsif contest_row.contest_type = 'table_of_redemption' then
      relevant_positions := case when contest_row.slots_to_fill > 0 then contest_row.slots_to_fill else 1 end;
      for score_row in
        select score.*,
          rank() over (order by score.score_points desc)::integer as finish_rank,
          count(*) over (partition by score.score_points)::integer as score_tie_count
        from app_private.finals_contest_scores(contest_row.id) as score
        order by score.score_points desc, score.entry_seed
      loop
        if score_row.finish_rank > relevant_positions then exit; end if;
        if score_row.score_tie_count > 1 then
          tied_score := score_row.score_points;
          target_slot := case when contest_row.slots_to_fill > 0
            then contest_row.slot_start_index + score_row.finish_rank - 1 else null end;
          child_id := app_private.create_finals_tiebreak(
            contest_row.id,
            case when contest_row.slots_to_fill > 0
              then 'redemption_advancement_tiebreak'
              else 'redemption_winner_tiebreak' end,
            tied_score, target_slot,
            least(relevant_positions - score_row.finish_rank + 1, score_row.score_tie_count)
          );
          exit;
        end if;
        position_index := score_row.finish_rank;
        if position_index = 1 then
          update public.event_bonus_rounds
          set redemption_winner_event_guest_id = score_row.event_guest_id,
              redemption_resolution_method = 'table_score'
          where id = contest_row.bonus_round_id;
          perform app_private.insert_audit_log(
            contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
            'resolve_redemption_winner', to_jsonb(bonus_round_row),
            to_jsonb((select updated from public.event_bonus_rounds as updated where updated.id = contest_row.bonus_round_id)),
            jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
          );
        end if;
        update public.event_finals_contest_participants
        set outcome = case
              when position_index = 1 then 'winner'
              when position_index = 2 then 'runner_up'
              else 'advanced'
            end,
            outcome_order = position_index
        where contest_id = contest_row.id
          and event_guest_id = score_row.event_guest_id;
        if contest_row.slots_to_fill > 0 then
          update public.event_finals_champions_slots
          set event_guest_id = score_row.event_guest_id,
              qualification_method = 'redemption_finish',
              source_contest_id = contest_row.id,
              source_finish_order = position_index
          where bonus_round_id = contest_row.bonus_round_id
            and slot_index = contest_row.slot_start_index + position_index - 1;
          perform app_private.insert_audit_log(
            contest_row.event_id, 'event_bonus_round', contest_row.bonus_round_id::text,
            'fill_finals_champions_slot', null,
            to_jsonb((select slot from public.event_finals_champions_slots as slot
              where slot.bonus_round_id = contest_row.bonus_round_id
                and slot.slot_index = contest_row.slot_start_index + position_index - 1)),
            jsonb_build_object('actor_user_id', auth.uid(), 'source_contest_id', contest_row.id)
          );
          update public.event_finals_contest_participants
          set advanced_champions_slot = contest_row.slot_start_index + position_index - 1
          where contest_id = contest_row.id and event_guest_id = score_row.event_guest_id;
        end if;
      end loop;
      update public.event_finals_contest_participants
      set outcome = 'eliminated'
      where contest_id = contest_row.id and outcome = 'pending'
        and not exists (
          select 1 from public.event_finals_contests as child
          join public.event_finals_contest_participants as child_participant
            on child_participant.contest_id = child.id
          where child.parent_contest_id = contest_row.id
            and child.status in ('ready', 'active')
            and child_participant.event_guest_id = event_finals_contest_participants.event_guest_id
        );
      update public.event_finals_contests set status = 'complete', completed_at = now()
      where id = contest_row.id;
      perform app_private.insert_audit_log(
        contest_row.event_id, 'event_finals_contest', contest_row.id::text,
        'complete_finals_contest', to_jsonb(contest_row),
        to_jsonb((select updated from public.event_finals_contests as updated where updated.id = contest_row.id)),
        jsonb_build_object('actor_user_id', auth.uid())
      );
      perform app_private.ensure_champions_contest_ready(contest_row.bonus_round_id);
      changed := true;
    end if;
  end if;

  update public.event_bonus_rounds as root
  set status = 'completed', completed_at = coalesce(completed_at, now())
  where root.id = bonus_round_row.id
    and root.champion_event_guest_id is not null
    and (root.eligible_player_count <= 4 or root.redemption_winner_event_guest_id is not null)
    and not exists (
      select 1 from public.event_finals_contests as required
      where required.bonus_round_id = root.id
        and required.status in ('pending', 'ready', 'active')
        and not (
          required.contest_type in ('redemption_advancement_tiebreak', 'redemption_winner_tiebreak')
          and exists (
            select 1 from public.event_finals_contests as completed_child
            where completed_child.parent_contest_id = required.id
              and completed_child.status = 'complete'
          )
        )
    );

  if changed then
    update public.event_bonus_rounds
    set state_version = state_version + 1, updated_at = now()
    where id = bonus_round_row.id;
    perform app_private.insert_audit_log(
      bonus_round_row.event_id, 'event_bonus_round', bonus_round_row.id::text,
      'recalculate_finals_state', null,
      public.get_event_finals_state(bonus_round_row.event_id),
      jsonb_build_object('actor_user_id', auth.uid(), 'source_table_session_id', target_table_session_id)
    );
    perform app_private.refresh_event_score_totals(bonus_round_row.event_id);
  end if;
end;
$$;

-- Preserve the legacy implementation under a stable private name, then keep
-- the existing scoring hook as the flow-version dispatcher.
alter function app_private.apply_bonus_round_champion_award(uuid)
  rename to apply_legacy_bonus_round_champion_award;

create or replace function app_private.apply_bonus_round_champion_award(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
begin
  select root.* into bonus_round_row
  from public.table_sessions as session
  join public.event_bonus_rounds as root on root.id = session.bonus_round_id
  where session.id = target_table_session_id;

  if not found then return; end if;
  if bonus_round_row.flow_version = 'orchestrated' then
    perform app_private.recalculate_finals_state(target_table_session_id);
  else
    perform app_private.apply_legacy_bonus_round_champion_award(
      target_table_session_id
    );
  end if;
end;
$$;

create or replace function app_private.recalculate_finals_resolution_session(
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
  seated_player_count integer := 0;
  recorded_hand_count integer := 0;
  has_decisive_win boolean := false;
begin
  select * into session_row
  from public.table_sessions
  where id = target_table_session_id
  for update;
  if not found then
    raise exception 'Session not found: %', target_table_session_id
      using errcode = 'P0001';
  end if;

  select count(*)::integer into seated_player_count
  from public.table_session_seats as seat
  where seat.table_session_id = session_row.id;
  if seated_player_count not between 2 and 4 then
    raise exception 'Finals resolution requires 2 to 4 seated players.'
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
    raise exception 'Finals resolution winner seat must be occupied.'
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
    order by hand_number
  loop
    recorded_hand_count := recorded_hand_count + 1;
    has_decisive_win := has_decisive_win or hand_row.result_type = 'win';

    update public.hand_results
    set base_points = case
          when hand_row.result_type = 'win'
            then app_private.ruleset_base_points(
              session_row.ruleset_id, hand_row.fan_count
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
  set completed_games_count = recorded_hand_count,
      hand_count = recorded_hand_count,
      status = case
        when session_row.status in ('ended_early', 'aborted')
          then session_row.status
        when has_decisive_win then 'completed'
        when session_row.status = 'paused' then 'paused'
        else 'active'
      end,
      ended_at = case
        when session_row.status in ('ended_early', 'aborted')
          then session_row.ended_at
        when has_decisive_win then coalesce(session_row.ended_at, now())
        else null
      end,
      ended_by_user_id = case
        when session_row.status in ('ended_early', 'aborted')
          then session_row.ended_by_user_id
        when has_decisive_win
          then coalesce(session_row.ended_by_user_id, auth.uid())
        else null
      end,
      end_reason = case
        when session_row.status in ('ended_early', 'aborted')
          then session_row.end_reason
        when has_decisive_win then 'finals_tiebreak_resolved'
        else null
      end,
      round_timer_paused_at = case
        when has_decisive_win then null
        else session_row.round_timer_paused_at
      end
  where id = session_row.id
  returning * into updated_session;

  perform app_private.refresh_event_score_totals(updated_session.event_id);
  perform app_private.apply_bonus_round_champion_award(updated_session.id);

  select * into updated_session
  from public.table_sessions
  where id = session_row.id;
  return updated_session;
end;
$$;

create or replace function public.recalculate_session(
  target_table_session_id uuid
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  session_row public.table_sessions%rowtype;
begin
  session_row := app_private.require_owned_session(target_table_session_id);

  if exists (
    select 1
    from public.event_finals_contests as contest
    join public.event_bonus_rounds as root
      on root.id = contest.bonus_round_id
    where contest.id = session_row.finals_contest_id
      and root.flow_version = 'orchestrated'
      and contest.contest_type in (
        'direct_qualification_tiebreak', 'redemption_advancement_tiebreak',
        'redemption_winner_tiebreak', 'champions_sudden_death'
      )
  ) then
    return app_private.recalculate_finals_resolution_session(session_row.id);
  end if;

  return app_private.recalculate_session_unowned(session_row.id);
end;
$$;

create or replace function app_private.guard_orchestrated_finals_hand_correction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  root_row public.event_bonus_rounds%rowtype;
begin
  select contest.* into contest_row
  from public.table_sessions as session
  join public.event_finals_contests as contest on contest.id = session.finals_contest_id
  where session.id = old.table_session_id;
  if not found or contest_row.status <> 'complete' then return new; end if;
  select * into root_row from public.event_bonus_rounds
  where id = contest_row.bonus_round_id;
  if root_row.flow_version <> 'orchestrated' then return new; end if;

  if exists (
    select 1 from public.event_finals_contests as dependent
    where dependent.bonus_round_id = contest_row.bonus_round_id
      and dependent.id <> contest_row.id
      and dependent.status in ('active', 'complete')
      and (
        dependent.parent_contest_id = contest_row.id
        or (
          contest_row.contest_type = 'direct_qualification_tiebreak'
          and dependent.contest_type = 'table_of_redemption'
        )
        or (
          dependent.contest_type = 'table_of_champions'
          and (
            contest_row.contest_type in (
              'direct_qualification_tiebreak', 'redemption_advancement_tiebreak'
            )
            or (
              contest_row.contest_type = 'table_of_redemption'
              and root_row.format = 'redemption_advancement'
            )
          )
        )
      )
  ) then
    raise exception 'A dependent Finals contest already started. Resolve or administratively unwind it before changing this result.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists hand_results_guard_orchestrated_finals_correction
  on public.hand_results;
create trigger hand_results_guard_orchestrated_finals_correction
before update of status, result_type, winner_seat_index, win_type,
  discarder_seat_index, fan_count, dealer_was_waiting_at_draw,
  penalty_seat_index
on public.hand_results
for each row
execute function app_private.guard_orchestrated_finals_hand_correction();

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
    raise exception 'Only active events can be completed.' using errcode = 'P0001';
  end if;
  perform app_private.assert_event_has_no_live_sessions(target_event_id);
  if exists (
    select 1 from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id
      and bonus_round.flow_version = 'orchestrated'
      and bonus_round.status <> 'completed'
  ) then
    raise exception 'Resolve every required Finals contest before completing the event.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id and bonus_round.status = 'active'
      and bonus_round.sudden_death_status in ('required', 'active')
  ) then
    raise exception 'Resolve Table of Champions sudden death before completing the event.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.event_bonus_rounds as bonus_round
    where bonus_round.event_id = target_event_id and bonus_round.status = 'active'
      and bonus_round.play_in_status in ('required', 'active')
  ) then
    raise exception 'Resolve Table of Champions play-in before completing the event.' using errcode = 'P0001';
  end if;
  update public.events
  set lifecycle_status = 'completed', scoring_open = false,
      updated_at = now(), row_version = row_version + 1
  where id = existing_event.id returning * into updated_event;
  perform app_private.insert_audit_log(
    updated_event.id, 'event', updated_event.id::text, 'complete',
    to_jsonb(existing_event), to_jsonb(updated_event)
  );
  return updated_event;
end;
$$;

revoke all on function app_private.finals_contest_scores(uuid) from public;
revoke all on function app_private.prepare_finals_contest(uuid) from public;
revoke all on function app_private.assert_finals_eligible_snapshot_complete(uuid) from public;
revoke all on function app_private.ensure_champions_contest_ready(uuid) from public;
revoke all on function app_private.create_finals_tiebreak(uuid, text, integer, integer, integer) from public;
revoke all on function app_private.finish_orchestrated_champion(uuid, uuid, integer, text) from public;
revoke all on function app_private.resolve_finals_tiebreak_participant_outcomes(
  uuid, uuid, uuid
) from public;
revoke all on function app_private.recalculate_finals_state(uuid) from public;
revoke all on function app_private.recalculate_finals_resolution_session(uuid) from public;
revoke all on function app_private.apply_legacy_bonus_round_champion_award(uuid) from public;
revoke all on function app_private.guard_orchestrated_finals_hand_correction() from public;
revoke all on function public.start_finals_contest(uuid, uuid, bigint) from public;
grant execute on function public.start_finals_contest(uuid, uuid, bigint) to authenticated;

select pg_notify('pgrst', 'reload schema');
