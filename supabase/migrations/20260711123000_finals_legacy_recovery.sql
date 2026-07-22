-- Guarded recovery for legacy Finals that have durable seating but missing
-- table sessions. Legacy rows remain legacy; seating remains source data.

create or replace function app_private.finals_session_matches_assignments(
  target_session_id uuid,
  target_event_id uuid,
  target_bonus_round_id uuid,
  target_bonus_table_role text,
  target_event_table_id uuid,
  target_assignment_round integer,
  target_finals_contest_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.table_sessions as session
    where session.id = target_session_id
      and session.event_id = target_event_id
      and session.bonus_round_id = target_bonus_round_id
      and session.bonus_table_role = target_bonus_table_role
      and session.event_table_id = target_event_table_id
      and session.assignment_round = target_assignment_round
      and session.finals_contest_id is not distinct from target_finals_contest_id
      and session.status in ('active', 'paused', 'completed')
      and (
        select count(*)
        from public.table_session_seats as seat
        where seat.table_session_id = session.id
      ) = (
        select count(*)
        from public.event_seating_assignments as assignment
        where assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
      )
      and not exists (
        select 1
        from public.table_session_seats as seat
        left join public.event_seating_assignments as assignment
          on assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
          and assignment.seat_index = seat.seat_index
          and assignment.event_guest_id = seat.event_guest_id
        where seat.table_session_id = session.id
          and assignment.id is null
      )
      and not exists (
        select 1
        from public.event_seating_assignments as assignment
        left join public.table_session_seats as seat
          on seat.table_session_id = session.id
          and seat.seat_index = assignment.seat_index
          and seat.event_guest_id = assignment.event_guest_id
        where assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.event_table_id = target_event_table_id
          and assignment.assignment_round = target_assignment_round
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is not distinct from target_finals_contest_id
          and seat.table_session_id is null
      )
  );
$$;

create or replace function app_private.legacy_finals_session_matches_assignments(
  target_session_id uuid,
  target_event_id uuid,
  target_bonus_round_id uuid,
  target_bonus_table_role text,
  target_event_table_id uuid,
  target_assignment_round integer
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.finals_session_matches_assignments(
    target_session_id,
    target_event_id,
    target_bonus_round_id,
    target_bonus_table_role,
    target_event_table_id,
    target_assignment_round,
    null
  );
$$;

create or replace function app_private.legacy_finals_recovery_state(
  target_event_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  recovery_token_value text;
  champions_count integer := 0;
  redemption_count integer := 0;
  champions_table_count integer := 0;
  redemption_table_count integer := 0;
  champions_seat_count integer := 0;
  redemption_seat_count integer := 0;
  champions_min_seat integer;
  champions_max_seat integer;
  redemption_min_seat integer;
  redemption_max_seat integer;
  champions_table_id_value uuid;
  redemption_table_id_value uuid;
  champions_session_id uuid;
  redemption_session_id uuid;
  champions_session_status text;
  redemption_session_status text;
  champions_session_count integer := 0;
  redemption_session_count integer := 0;
  roles_overlap boolean := false;
  overlap_count integer := 0;
  union_count integer := 0;
  blocking_reason_value text;
  technical_reason_value text;
  candidates_value jsonb := '[]'::jsonb;
  existing_sessions_value jsonb := '[]'::jsonb;
  classification_value text := 'already_started';
begin
  select bonus_round.*
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.flow_version = 'legacy'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc, bonus_round.created_at desc
  limit 1;

  if not found then
    return jsonb_build_object(
      'classification', 'not_legacy',
      'recovery_token', null,
      'candidates', jsonb_build_array(),
      'existing_session_ids', jsonb_build_array(),
      'blocking_reason', null,
      'technical_reason', null
    );
  end if;

  select encode(
    extensions.digest(
      jsonb_build_object(
        'bonus_round', jsonb_build_object(
          'id', bonus_round_row.id,
          'status', bonus_round_row.status,
          'flow_version', bonus_round_row.flow_version,
          'assignment_round', bonus_round_row.assignment_round,
          'champions_table_id', bonus_round_row.champions_table_id,
          'redemption_table_id', bonus_round_row.redemption_table_id
        ),
        'assignments', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', assignment.id,
              'role', assignment.bonus_table_role,
              'table_id', assignment.event_table_id,
              'seat_index', assignment.seat_index,
              'guest_id', assignment.event_guest_id,
              'assignment_round', assignment.assignment_round
            ) order by assignment.id
          )
          from public.event_seating_assignments as assignment
          where assignment.event_id = target_event_id
            and assignment.bonus_round_id = bonus_round_row.id
            and assignment.status = 'active'
        ), '[]'::jsonb),
        'tables', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', event_table.id,
              'nfc_tag_id', event_table.nfc_tag_id,
              'default_tag_type', tag.default_tag_type,
              'tag_status', tag.status
            ) order by event_table.id
          )
          from public.event_tables as event_table
          left join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
          where event_table.id in (
            bonus_round_row.champions_table_id,
            bonus_round_row.redemption_table_id
          )
        ), '[]'::jsonb),
        'sessions', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', session.id,
              'status', session.status,
              'role', session.bonus_table_role,
              'table_id', session.event_table_id,
              'assignment_round', session.assignment_round
            ) order by session.id
          )
          from public.table_sessions as session
          where session.event_id = target_event_id
            and session.bonus_round_id = bonus_round_row.id
        ), '[]'::jsonb)
      )::text,
      'sha256'
    ),
    'hex'
  ) into recovery_token_value;

  select
    count(*) filter (where assignment.bonus_table_role = 'table_of_champions')::integer,
    count(*) filter (where assignment.bonus_table_role = 'table_of_redemption')::integer,
    count(distinct assignment.event_table_id)
      filter (where assignment.bonus_table_role = 'table_of_champions')::integer,
    count(distinct assignment.event_table_id)
      filter (where assignment.bonus_table_role = 'table_of_redemption')::integer,
    count(distinct assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_champions')::integer,
    count(distinct assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_redemption')::integer,
    min(assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_champions'),
    max(assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_champions'),
    min(assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_redemption'),
    max(assignment.seat_index)
      filter (where assignment.bonus_table_role = 'table_of_redemption'),
    (min(assignment.event_table_id::text)
      filter (where assignment.bonus_table_role = 'table_of_champions'))::uuid,
    (min(assignment.event_table_id::text)
      filter (where assignment.bonus_table_role = 'table_of_redemption'))::uuid
  into
    champions_count, redemption_count,
    champions_table_count, redemption_table_count,
    champions_seat_count, redemption_seat_count,
    champions_min_seat, champions_max_seat,
    redemption_min_seat, redemption_max_seat,
    champions_table_id_value, redemption_table_id_value
  from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id
    and assignment.bonus_round_id = bonus_round_row.id
    and assignment.status = 'active';

  if champions_count not between 2 and 4
    or champions_table_count <> 1
    or champions_seat_count <> champions_count
    or champions_min_seat <> 0
    or champions_max_seat <> champions_count - 1
    or (
      bonus_round_row.redemption_table_id is not null
      and redemption_count not between 2 and 4
    )
    or (
      redemption_count > 0
      and (
        redemption_table_count <> 1
        or redemption_seat_count <> redemption_count
        or redemption_min_seat <> 0
        or redemption_max_seat <> redemption_count - 1
      )
    )
  then
    blocking_reason_value := 'Finals seating is incomplete.';
    technical_reason_value := 'seat_count_or_range_invalid';
  elsif exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.bonus_round_id = bonus_round_row.id
      and assignment.status = 'active'
      and (
        assignment.assignment_type is distinct from 'bonus'
        or assignment.assignment_round is distinct from bonus_round_row.assignment_round
        or assignment.bonus_table_role not in (
          'table_of_champions', 'table_of_redemption'
        )
        or assignment.finals_contest_id is not null
      )
  ) then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'assignment_metadata_invalid';
  elsif champions_table_id_value is distinct from bonus_round_row.champions_table_id
    or (
      redemption_count > 0
      and redemption_table_id_value is distinct from bonus_round_row.redemption_table_id
    )
    or (redemption_count > 0 and bonus_round_row.redemption_table_id is null)
  then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'assignment_role_table_mismatch';
  elsif exists (
    select 1
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.bonus_round_id = bonus_round_row.id
      and assignment.status = 'active'
    group by assignment.bonus_table_role, assignment.event_guest_id
    having count(*) > 1
  ) then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'duplicate_guest_within_role';
  end if;

  select
    count(*)::integer,
    (
      select count(distinct assignment.event_guest_id)::integer
      from public.event_seating_assignments as assignment
      where assignment.event_id = target_event_id
        and assignment.bonus_round_id = bonus_round_row.id
        and assignment.status = 'active'
        and assignment.bonus_table_role in (
          'table_of_champions', 'table_of_redemption'
        )
    )
  into overlap_count, union_count
  from public.event_seating_assignments as champions
  join public.event_seating_assignments as redemption
    on redemption.event_id = champions.event_id
    and redemption.bonus_round_id = champions.bonus_round_id
    and redemption.event_guest_id = champions.event_guest_id
    and redemption.status = 'active'
    and redemption.bonus_table_role = 'table_of_redemption'
  where champions.event_id = target_event_id
    and champions.bonus_round_id = bonus_round_row.id
    and champions.status = 'active'
    and champions.bonus_table_role = 'table_of_champions';

  roles_overlap := overlap_count > 0;

  if blocking_reason_value is null
    and roles_overlap
    and not (
      champions_count = 4
      and redemption_count = 4
      and (
        (overlap_count = 2 and union_count = 6)
        or (overlap_count = 1 and union_count = 7)
      )
    )
  then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'ambiguous_overlap_shape';
  end if;

  select count(*)::integer, min(session.id::text)::uuid
  into champions_session_count, champions_session_id
  from public.table_sessions as session
  where session.event_id = target_event_id
    and session.bonus_round_id = bonus_round_row.id
    and session.bonus_table_role = 'table_of_champions'
    and session.event_table_id = champions_table_id_value
    and session.assignment_round = bonus_round_row.assignment_round
    and session.finals_contest_id is null
    and session.status in ('active', 'paused', 'completed');

  select session.status into champions_session_status
  from public.table_sessions as session
  where session.id = champions_session_id;

  select count(*)::integer, min(session.id::text)::uuid
  into redemption_session_count, redemption_session_id
  from public.table_sessions as session
  where session.event_id = target_event_id
    and session.bonus_round_id = bonus_round_row.id
    and session.bonus_table_role = 'table_of_redemption'
    and session.event_table_id = redemption_table_id_value
    and session.assignment_round = bonus_round_row.assignment_round
    and session.finals_contest_id is null
    and session.status in ('active', 'paused', 'completed');

  select session.status into redemption_session_status
  from public.table_sessions as session
  where session.id = redemption_session_id;

  if blocking_reason_value is null
    and champions_session_count = 1
    and not app_private.legacy_finals_session_matches_assignments(
      champions_session_id,
      target_event_id,
      bonus_round_row.id,
      'table_of_champions',
      champions_table_id_value,
      bonus_round_row.assignment_round
    )
  then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'existing_session_seats_mismatch';
  end if;

  if blocking_reason_value is null
    and redemption_session_count = 1
    and not app_private.legacy_finals_session_matches_assignments(
      redemption_session_id,
      target_event_id,
      bonus_round_row.id,
      'table_of_redemption',
      redemption_table_id_value,
      bonus_round_row.assignment_round
    )
  then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'existing_session_seats_mismatch';
  end if;

  if blocking_reason_value is null
    and roles_overlap
    and champions_session_id is not null
    and (
      redemption_session_id is null
      or redemption_session_status <> 'completed'
    )
  then
    blocking_reason_value :=
      'A Finals player is already playing at another table.';
    technical_reason_value := 'overlapping_champions_session_conflict';
  end if;

  if blocking_reason_value is null and (
    champions_session_count > 1 or redemption_session_count > 1
    or exists (
      select 1
      from public.table_sessions as session
      where session.event_id = target_event_id
        and session.bonus_round_id = bonus_round_row.id
        and not (
          session.status in ('active', 'paused', 'completed')
          and session.finals_contest_id is null
          and session.assignment_round = bonus_round_row.assignment_round
          and (
            (
              session.bonus_table_role = 'table_of_champions'
              and session.event_table_id = champions_table_id_value
            )
            or (
              session.bonus_table_role = 'table_of_redemption'
              and redemption_count > 0
              and session.event_table_id = redemption_table_id_value
            )
          )
        )
    )
  ) then
    blocking_reason_value :=
      'Finals could not be safely recovered. Review the table assignments.';
    technical_reason_value := 'unexpected_existing_session';
  end if;

  if blocking_reason_value is null and exists (
    select 1
    from public.table_sessions as session
    where session.status in ('active', 'paused')
      and session.event_table_id in (
        champions_table_id_value, redemption_table_id_value
      )
      and session.id not in (
        coalesce(champions_session_id, '00000000-0000-0000-0000-000000000000'),
        coalesce(redemption_session_id, '00000000-0000-0000-0000-000000000000')
      )
  ) then
    blocking_reason_value := 'One of these Finals tables is already active.';
    technical_reason_value := 'candidate_table_conflict';
  end if;

  if blocking_reason_value is null then
    if redemption_count > 0 and redemption_session_id is null then
      candidates_value := candidates_value || jsonb_build_array(
        jsonb_build_object(
          'bonus_table_role', 'table_of_redemption',
          'event_table_id', redemption_table_id_value
        )
      );
    end if;
    if champions_session_id is null
      and (
        not roles_overlap
        or redemption_session_status = 'completed'
      )
    then
      candidates_value := jsonb_build_array(
        jsonb_build_object(
          'bonus_table_role', 'table_of_champions',
          'event_table_id', champions_table_id_value
        )
      ) || candidates_value;
    end if;

    if exists (
      select 1
      from jsonb_array_elements(candidates_value) as candidate
      join public.event_seating_assignments as assignment
        on assignment.event_id = target_event_id
        and assignment.bonus_round_id = bonus_round_row.id
        and assignment.status = 'active'
        and assignment.bonus_table_role = candidate ->> 'bonus_table_role'
      join public.table_session_seats as seat
        on seat.event_guest_id = assignment.event_guest_id
      join public.table_sessions as session
        on session.id = seat.table_session_id
      where session.event_id = target_event_id
        and session.status in ('active', 'paused')
        and session.id not in (
          coalesce(champions_session_id, '00000000-0000-0000-0000-000000000000'),
          coalesce(redemption_session_id, '00000000-0000-0000-0000-000000000000')
        )
    ) then
      blocking_reason_value :=
        'A Finals player is already playing at another table.';
      technical_reason_value := 'candidate_player_conflict';
      candidates_value := '[]'::jsonb;
    elsif exists (
      select 1
      from jsonb_array_elements(candidates_value) as candidate
      join public.event_seating_assignments as assignment
        on assignment.event_id = target_event_id
        and assignment.bonus_round_id = bonus_round_row.id
        and assignment.status = 'active'
        and assignment.bonus_table_role = candidate ->> 'bonus_table_role'
      join public.event_guests as guest on guest.id = assignment.event_guest_id
      where guest.attendance_status <> 'checked_in'
    ) then
      blocking_reason_value :=
        'All Finals players must be checked in before starting.';
      technical_reason_value := 'candidate_player_not_checked_in';
      candidates_value := '[]'::jsonb;
    elsif exists (
      select 1
      from jsonb_array_elements(candidates_value) as candidate
      left join public.event_tables as event_table
        on event_table.id = (candidate ->> 'event_table_id')::uuid
      left join public.nfc_tags as tag on tag.id = event_table.nfc_tag_id
      left join public.rulesets as ruleset
        on ruleset.id = event_table.default_ruleset_id
      where event_table.id is null
        or event_table.event_id is distinct from target_event_id
        or ruleset.id is null
        or tag.id is null
        or tag.default_tag_type is distinct from 'table'
        or tag.status is distinct from 'active'
    ) then
      blocking_reason_value :=
        'Finals could not be safely recovered. Review the table assignments.';
      technical_reason_value := 'candidate_helper_precondition_failed';
      candidates_value := '[]'::jsonb;
    end if;
  end if;

  existing_sessions_value := (
    select coalesce(jsonb_agg(session_id order by session_id), '[]'::jsonb)
    from unnest(array[champions_session_id, redemption_session_id]) as session_id
    where session_id is not null
  );

  if blocking_reason_value is not null then
    classification_value := 'blocked_legacy_state';
  elsif jsonb_array_length(candidates_value) > 0 then
    classification_value := case
      when roles_overlap and redemption_session_status = 'completed'
        then 'overlap_champions_after_redemption'
      when roles_overlap then 'overlap_redemption_only'
      when champions_session_id is not null or redemption_session_id is not null
        then 'partial_disjoint'
      when redemption_count = 0 then 'champions_only'
      else 'disjoint_parallel'
    end;
  end if;

  return jsonb_build_object(
    'bonus_round_id', bonus_round_row.id,
    'classification', classification_value,
    'recovery_token', recovery_token_value,
    'candidates', candidates_value,
    'existing_session_ids', existing_sessions_value,
    'blocking_reason', blocking_reason_value,
    'technical_reason', technical_reason_value,
    'roles_overlap', roles_overlap
  );
end;
$$;

alter function public.get_event_finals_state(uuid)
  rename to get_event_finals_state_before_legacy_recovery;

create or replace function public.get_event_finals_state(
  target_event_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  state_value jsonb;
  recovery_value jsonb;
  action_value text;
  sessions_value jsonb := '[]'::jsonb;
begin
  state_value := public.get_event_finals_state_before_legacy_recovery(
    target_event_id
  );
  if state_value ->> 'flow_version' is distinct from 'legacy'
    or not (state_value ->> 'overall_status' in ('active', 'complete'))
  then
    return state_value || jsonb_build_object('recovery_token', null);
  end if;

  recovery_value := app_private.legacy_finals_recovery_state(target_event_id);
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', session.id,
        'bonus_table_role', session.bonus_table_role,
        'table_label', event_table.label,
        'status', session.status,
        'started_at', session.started_at
      ) order by event_table.display_order, session.started_at, session.id
    ),
    '[]'::jsonb
  )
  into sessions_value
  from public.table_sessions as session
  join public.event_tables as event_table on event_table.id = session.event_table_id
  where session.event_id = target_event_id
    and session.bonus_round_id = (recovery_value ->> 'bonus_round_id')::uuid
    and session.status in ('active', 'paused', 'completed');
  state_value := state_value || jsonb_build_object('sessions', sessions_value);
  if recovery_value ->> 'classification' = 'blocked_legacy_state' then
    return state_value || jsonb_build_object(
      'overall_status', 'blocked_legacy_state',
      'allowed_actions', jsonb_build_array(),
      'blocking_reason', recovery_value ->> 'blocking_reason',
      'recovery_token', recovery_value ->> 'recovery_token'
    );
  end if;

  if jsonb_array_length(recovery_value -> 'candidates') > 0
    and app_private.can_manage_event(target_event_id) then
    action_value := case
      when jsonb_array_length(recovery_value -> 'existing_session_ids') = 0
        then 'start_finals_tables'
      else 'resume_finals_start'
    end;
    return state_value || jsonb_build_object(
      'overall_status', 'recoverable_missing_sessions',
      'allowed_actions', jsonb_build_array(jsonb_build_object(
        'action', action_value,
        'label', case action_value
          when 'start_finals_tables' then 'Start Finals Tables'
          else 'Resume Finals Start'
        end,
        'recovery_token', recovery_value ->> 'recovery_token'
      )),
      'blocking_reason', null,
      'recovery_token', recovery_value ->> 'recovery_token'
    );
  end if;

  if jsonb_array_length(recovery_value -> 'candidates') > 0 then
    return state_value || jsonb_build_object(
      'overall_status', 'recoverable_missing_sessions',
      'allowed_actions', jsonb_build_array(),
      'blocking_reason', null,
      'recovery_token', recovery_value ->> 'recovery_token'
    );
  end if;

  return state_value || jsonb_build_object(
    'allowed_actions', jsonb_build_array(),
    'blocking_reason', null,
    'recovery_token', recovery_value ->> 'recovery_token'
  );
end;
$$;

create or replace function app_private.guard_active_session_guest_conflict()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_session public.table_sessions%rowtype;
begin
  select session.* into target_session
  from public.table_sessions as session
  where session.id = new.table_session_id;
  if not found or target_session.status not in ('active', 'paused') then
    return new;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(target_session.event_id::text, 1)
  );
  if exists (
    select 1
    from public.table_session_seats as existing_seat
    join public.table_sessions as existing_session
      on existing_session.id = existing_seat.table_session_id
    where existing_seat.event_guest_id = new.event_guest_id
      and existing_seat.table_session_id <> new.table_session_id
      and existing_session.event_id = target_session.event_id
      and existing_session.status in ('active', 'paused')
  ) then
    if target_session.scoring_phase = 'bonus' then
      raise exception 'A Finals player is already playing at another table.'
        using errcode = 'P0001';
    end if;
    raise exception 'A player is already playing at another table.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists table_session_seats_guard_active_guest_conflict
  on public.table_session_seats;
create trigger table_session_seats_guard_active_guest_conflict
before insert or update of table_session_id, event_guest_id
on public.table_session_seats
for each row execute function app_private.guard_active_session_guest_conflict();

create or replace function app_private.start_assigned_finals_session(
  target_event_id uuid,
  target_bonus_round_id uuid,
  target_bonus_table_role text,
  target_finals_contest_id uuid,
  target_started_at timestamptz
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  contest_row public.event_finals_contests%rowtype;
  table_row public.event_tables%rowtype;
  tag_row public.nfc_tags%rowtype;
  session_row public.table_sessions%rowtype;
  assignment_rows public.event_seating_assignments[];
  initial_winds constant text[] := array['east', 'south', 'west', 'north'];
  next_session_number integer;
  assignment_index integer;
begin
  if not exists (
    select 1 from public.events as event
    where event.id = target_event_id
      and event.lifecycle_status = 'active'
      and event.current_scoring_phase = 'bonus'
      and event.scoring_open
  ) then
    raise exception 'Event must be active and open for bonus scoring.'
      using errcode = 'P0001';
  end if;

  if target_finals_contest_id is not null then
    select contest.* into contest_row
    from public.event_finals_contests as contest
    where contest.id = target_finals_contest_id
      and contest.event_id = target_event_id
      and contest.bonus_round_id = target_bonus_round_id
    for update;
    if not found then
      raise exception 'Finals contest not found for this event.' using errcode = 'P0001';
    end if;
    if contest_row.table_session_id is not null then
      select * into session_row from public.table_sessions as session
      where session.id = contest_row.table_session_id
        and session.event_id = target_event_id
        and session.finals_contest_id = contest_row.id;
      if found and app_private.finals_session_matches_assignments(
        session_row.id,
        target_event_id,
        target_bonus_round_id,
        target_bonus_table_role,
        session_row.event_table_id,
        session_row.assignment_round,
        contest_row.id
      ) then
        return session_row;
      end if;
      if found then
        raise exception
          'Existing Finals session seats do not match the durable assignments.'
          using errcode = 'P0001';
      end if;
      raise exception 'Finals contest references an unexpected session.' using errcode = 'P0001';
    end if;
    if contest_row.status <> 'ready' then
      raise exception 'This Finals contest is no longer ready to start.' using errcode = 'P0001';
    end if;
    select event_table.* into table_row
    from public.event_tables as event_table
    where event_table.id = contest_row.event_table_id
      and event_table.event_id = target_event_id
    for update;
  else
    select event_table.* into table_row
    from public.event_tables as event_table
    where event_table.event_id = target_event_id
      and event_table.id = (
        select min(assignment.event_table_id::text)::uuid
        from public.event_seating_assignments as assignment
        where assignment.event_id = target_event_id
          and assignment.bonus_round_id = target_bonus_round_id
          and assignment.bonus_table_role = target_bonus_table_role
          and assignment.assignment_type = 'bonus'
          and assignment.status = 'active'
          and assignment.finals_contest_id is null
        having count(distinct assignment.event_table_id) = 1
      )
    for update;
  end if;
  if not found then
    raise exception 'Selected Finals table is not available for this event.' using errcode = 'P0001';
  end if;

  select tag.* into tag_row
  from public.nfc_tags as tag
  where tag.id = table_row.nfc_tag_id
  order by tag.id
  for update of tag;
  if not found
    or tag_row.default_tag_type <> 'table'
    or tag_row.status <> 'active'
  then
    raise exception 'Selected Finals table is not available for this event.'
      using errcode = 'P0001';
  end if;

  if target_finals_contest_id is null then
    select * into session_row
    from public.table_sessions as session
    where session.event_id = target_event_id
      and session.event_table_id = table_row.id
      and session.bonus_round_id = target_bonus_round_id
      and session.bonus_table_role = target_bonus_table_role
      and session.finals_contest_id is null
      and session.status in ('active', 'paused', 'completed')
    order by session.created_at
    limit 1;
    if found and app_private.finals_session_matches_assignments(
      session_row.id,
      target_event_id,
      target_bonus_round_id,
      target_bonus_table_role,
      session_row.event_table_id,
      session_row.assignment_round,
      null
    ) then
      return session_row;
    end if;
    if found then
      raise exception
        'Existing Finals session seats do not match the durable assignments.'
        using errcode = 'P0001';
    end if;
  end if;

  begin
    perform existing_session.id
    from public.table_sessions as existing_session
      where existing_session.event_table_id = table_row.id
        and existing_session.status in ('active', 'paused')
    order by existing_session.id
    for update nowait;
  exception
    when lock_not_available then
      raise exception
        'Finals tables are currently being scored. Refresh and try again.'
        using errcode = 'P0001';
  end;
  if found then
    raise exception 'The selected Finals table already has an active session.' using errcode = 'P0001';
  end if;

  with locked_assignments as (
    select assignment.*
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.bonus_round_id = target_bonus_round_id
      and assignment.bonus_table_role = target_bonus_table_role
      and assignment.finals_contest_id is not distinct from target_finals_contest_id
      and assignment.event_table_id = table_row.id
      and assignment.assignment_type = 'bonus'
      and assignment.status = 'active'
    order by assignment.seat_index
    for update
  )
  select array_agg(assignment order by assignment.seat_index)
  into assignment_rows
  from locked_assignments as assignment;

  if assignment_rows is null or not (array_length(assignment_rows, 1) between 2 and 4) then
    raise exception 'Two to four active Finals seating assignments are required.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from generate_subscripts(assignment_rows, 1) as item
    where assignment_rows[item].seat_index <> item - 1
  ) then
    raise exception 'Assigned seating must fill seats contiguously from East.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    where assignment.assignment_round is distinct from assignment_rows[1].assignment_round
      or assignment.assignment_type is distinct from 'bonus'
      or assignment.bonus_round_id is distinct from target_bonus_round_id
      or assignment.bonus_table_role is distinct from target_bonus_table_role
      or assignment.finals_contest_id is distinct from target_finals_contest_id
  ) then
    raise exception 'All Finals assignments must share one assignment round and metadata set.' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    join public.event_guests as guest on guest.id = assignment.event_guest_id
    where guest.attendance_status <> 'checked_in'
  ) then
    raise exception 'All Finals players must be checked in before starting.'
      using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(assignment_rows) as assignment
    join public.table_session_seats as seat on seat.event_guest_id = assignment.event_guest_id
    join public.table_sessions as existing_session on existing_session.id = seat.table_session_id
    where existing_session.event_id = target_event_id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'A Finals player is already playing at another table.'
      using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.rulesets where id = table_row.default_ruleset_id) then
    raise exception 'Default ruleset not found for the selected Finals table.' using errcode = 'P0001';
  end if;

  select coalesce(max(session.session_number_for_table), 0) + 1
  into next_session_number
  from public.table_sessions as session
  where session.event_table_id = table_row.id;

  insert into public.table_sessions (
    event_id, event_table_id, session_number_for_table, ruleset_id,
    rotation_policy_type, rotation_policy_config_json, status,
    initial_east_seat_index, current_dealer_seat_index, scoring_phase,
    bonus_round_id, bonus_table_role, assignment_round, finals_contest_id,
    started_at, started_by_user_id
  ) values (
    target_event_id, table_row.id, next_session_number, table_row.default_ruleset_id,
    table_row.default_rotation_policy_type, table_row.default_rotation_policy_config_json,
    'active', 0, 0, 'bonus', target_bonus_round_id, target_bonus_table_role,
    assignment_rows[1].assignment_round, target_finals_contest_id,
    coalesce(target_started_at, now()), auth.uid()
  ) returning * into session_row;

  for assignment_index in 1..array_length(assignment_rows, 1) loop
    insert into public.table_session_seats (
      table_session_id, seat_index, initial_wind, event_guest_id
    ) values (
      session_row.id,
      assignment_rows[assignment_index].seat_index,
      initial_winds[assignment_rows[assignment_index].seat_index + 1],
      assignment_rows[assignment_index].event_guest_id
    );
  end loop;

  if target_finals_contest_id is not null then
    update public.event_finals_contests
    set status = 'active', table_session_id = session_row.id,
        started_at = session_row.started_at, updated_at = now()
    where id = target_finals_contest_id;
  end if;
  return session_row;
end;
$$;

create or replace function public.resume_event_finals_start(
  target_event_id uuid,
  expected_recovery_token text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  bonus_round_row public.event_bonus_rounds%rowtype;
  recovery_value jsonb;
  candidate_value jsonb;
  candidate_table_ids uuid[];
  started_session public.table_sessions%rowtype;
  newly_started_sessions jsonb := '[]'::jsonb;
  transition_started_at timestamptz := now();
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current Finals operator.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(target_event_id::text, 0));
  select * into event_row from public.events as event
  where event.id = target_event_id for update;
  if not found or event_row.lifecycle_status <> 'active'
    or event_row.current_scoring_phase <> 'bonus' or not event_row.scoring_open
  then
    raise exception 'Event must be active and open for bonus scoring.' using errcode = 'P0001';
  end if;
  select * into bonus_round_row from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.flow_version = 'legacy'
    and bonus_round.status in ('active', 'completed')
  order by bonus_round.assignment_round desc, bonus_round.created_at desc
  limit 1 for update;
  if not found then
    raise exception 'Finals could not be safely recovered. Review the table assignments.' using errcode = 'P0001';
  end if;

  perform 1 from public.event_seating_assignments as assignment
  where assignment.event_id = target_event_id
    and assignment.bonus_round_id = bonus_round_row.id
    and assignment.status = 'active'
  order by assignment.id for update;
  perform 1 from public.event_tables as event_table
  where event_table.id in (
    bonus_round_row.champions_table_id, bonus_round_row.redemption_table_id
  ) order by event_table.id for update;
  perform tag.id
  from public.nfc_tags as tag
  join public.event_tables as tagged_table on tagged_table.nfc_tag_id = tag.id
  where tagged_table.id in (
    bonus_round_row.champions_table_id, bonus_round_row.redemption_table_id
  )
  order by tag.id
  for update of tag;

  recovery_value := app_private.legacy_finals_recovery_state(target_event_id);
  select coalesce(
    array_agg(candidate_table.event_table_id order by candidate_table.event_table_id),
    array[]::uuid[]
  )
  into candidate_table_ids
  from (
    select distinct (candidate ->> 'event_table_id')::uuid as event_table_id
    from jsonb_array_elements(recovery_value -> 'candidates') as candidate
  ) as candidate_table;

  begin
    perform 1 from public.table_sessions as session
    where session.event_table_id = any(candidate_table_ids)
      and session.status in ('active', 'paused')
    order by session.id for update nowait;
  exception
    when lock_not_available then
      raise exception
        'Finals tables are currently being scored. Refresh and try again.'
        using errcode = 'P0001';
  end;

  recovery_value := app_private.legacy_finals_recovery_state(target_event_id);
  if expected_recovery_token is distinct from recovery_value ->> 'recovery_token' then
    if exists (
      select 1 from public.audit_logs as audit
      where audit.event_id = target_event_id
        and audit.entity_id = bonus_round_row.id::text
        and audit.action = 'resume_event_finals_start'
        and audit.metadata_json ->> 'expected_recovery_token' = expected_recovery_token
    ) and recovery_value ->> 'classification' = 'already_started' then
      return public.get_event_finals_state(target_event_id);
    end if;
    raise exception 'Finals changed since this screen loaded. Refresh and try again.' using errcode = 'P0001';
  end if;
  if recovery_value ->> 'classification' = 'blocked_legacy_state' then
    raise exception '%', recovery_value ->> 'blocking_reason' using errcode = 'P0001';
  end if;

  if bonus_round_row.status = 'completed'
    and jsonb_array_length(recovery_value -> 'candidates') > 0
  then
    update public.event_bonus_rounds
    set status = 'active', completed_at = null, updated_at = now()
    where id = bonus_round_row.id;
  end if;

  for candidate_value in
    select candidate
    from jsonb_array_elements(recovery_value -> 'candidates') as candidate
    order by case candidate ->> 'bonus_table_role'
      when 'table_of_champions' then 1 else 2 end
  loop
    started_session := app_private.start_assigned_finals_session(
      target_event_id,
      bonus_round_row.id,
      candidate_value ->> 'bonus_table_role',
      null,
      transition_started_at
    );
    newly_started_sessions := newly_started_sessions
      || jsonb_build_array(started_session.id);
  end loop;

  perform app_private.insert_audit_log(
    target_event_id, 'event_bonus_round', bonus_round_row.id::text,
    'resume_event_finals_start', null,
    public.get_event_finals_state(target_event_id),
    jsonb_build_object(
      'actor_user_id', auth.uid(),
      'expected_recovery_token', expected_recovery_token,
      'candidate_tables', recovery_value -> 'candidates',
      'existing_session_ids', recovery_value -> 'existing_session_ids',
      'newly_started_session_ids', newly_started_sessions,
      'recovery_classification', recovery_value ->> 'classification'
    )
  );
  return public.get_event_finals_state(target_event_id);
end;
$$;

create or replace function public.start_bonus_assigned_table_sessions(
  target_event_id uuid,
  target_bonus_table_role text
)
returns setof public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  recovery_value jsonb;
  candidate_value jsonb;
  candidate_table_ids uuid[];
  contest_row public.event_finals_contests%rowtype;
  session_row public.table_sessions%rowtype;
  started_contest_ids uuid[] := array[]::uuid[];
  started_session_ids uuid[] := array[]::uuid[];
  compatibility_changed boolean := false;
begin
  if not app_private.can_manage_event(target_event_id) then
    raise exception 'Event not found for current Finals operator.' using errcode = 'P0001';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(target_event_id::text, 0));

  select * into bonus_round_row from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id and bonus_round.status = 'active'
  order by bonus_round.assignment_round desc, bonus_round.created_at desc
  limit 1 for update;
  if not found then
    raise exception 'Active bonus round not found for this seating.' using errcode = 'P0001';
  end if;

  if bonus_round_row.flow_version = 'legacy' then
    if target_bonus_table_role is null or target_bonus_table_role in (
      'table_of_champions', 'table_of_redemption'
    ) then
      recovery_value := app_private.legacy_finals_recovery_state(target_event_id);
      if recovery_value ->> 'classification' = 'blocked_legacy_state' then
        raise exception '%', recovery_value ->> 'blocking_reason' using errcode = 'P0001';
      end if;
      select array_agg(candidate_table.event_table_id order by candidate_table.event_table_id)
      into candidate_table_ids
      from (
        select distinct (candidate ->> 'event_table_id')::uuid as event_table_id
        from jsonb_array_elements(recovery_value -> 'candidates') as candidate
        where target_bonus_table_role is null
          or candidate ->> 'bonus_table_role' = target_bonus_table_role
      ) as candidate_table;

      -- Prelock the complete legacy compatibility candidate set.
      perform 1
      from public.event_tables as event_table
      where event_table.id = any(coalesce(candidate_table_ids, array[]::uuid[]))
      order by event_table.id for update;
      perform 1
      from public.nfc_tags as tag
      where tag.id in (
        select event_table.nfc_tag_id
        from public.event_tables as event_table
        where event_table.id = any(coalesce(candidate_table_ids, array[]::uuid[]))
      )
      order by tag.id for update;
      begin
        perform 1
        from public.table_sessions as session
        where session.event_table_id = any(coalesce(candidate_table_ids, array[]::uuid[]))
          and session.status in ('active', 'paused')
        order by session.id for update nowait;
      exception
        when lock_not_available then
          raise exception
            'Finals tables are currently being scored. Refresh and try again.'
            using errcode = 'P0001';
      end;
      for candidate_value in
        select candidate from jsonb_array_elements(recovery_value -> 'candidates') as candidate
        where target_bonus_table_role is null
          or candidate ->> 'bonus_table_role' = target_bonus_table_role
        order by case candidate ->> 'bonus_table_role'
          when 'table_of_champions' then 1 else 2 end
      loop
        session_row := app_private.start_assigned_finals_session(
          target_event_id, bonus_round_row.id,
          candidate_value ->> 'bonus_table_role', null, now()
        );
        compatibility_changed := true;
        started_session_ids := array_append(started_session_ids, session_row.id);
        return next session_row;
      end loop;
      if compatibility_changed then
        perform app_private.insert_audit_log(
          target_event_id,
          'event_bonus_round',
          bonus_round_row.id::text,
          'start_bonus_assigned_table_sessions',
          null,
          public.get_event_finals_state(target_event_id),
          jsonb_build_object(
            'actor_user_id', auth.uid(),
            'flow_version', 'legacy',
            'bonus_table_role', target_bonus_table_role,
            'started_session_ids', to_jsonb(started_session_ids)
          )
        );
        return;
      end if;
      if target_bonus_table_role is not null then
        select * into session_row from public.table_sessions as session
        where session.event_id = target_event_id
          and session.bonus_round_id = bonus_round_row.id
          and session.bonus_table_role = target_bonus_table_role
          and session.finals_contest_id is null
        order by session.created_at limit 1;
        if found then
          if app_private.finals_session_matches_assignments(
            session_row.id,
            target_event_id,
            bonus_round_row.id,
            target_bonus_table_role,
            session_row.event_table_id,
            session_row.assignment_round,
            null
          ) then
            return next session_row;
          else
            raise exception
              'Existing Finals session seats do not match the durable assignments.'
              using errcode = 'P0001';
          end if;
        end if;
      end if;
      return;
    elsif target_bonus_table_role in (
      'table_of_champions_sudden_death',
      'table_of_champions_play_in'
    ) then
      compatibility_changed := not exists (
        select 1 from public.table_sessions as session
        where session.event_id = target_event_id
          and session.bonus_round_id = bonus_round_row.id
          and session.bonus_table_role = target_bonus_table_role
          and session.finals_contest_id is null
          and session.status in ('active', 'paused', 'completed')
      );
      session_row := app_private.start_assigned_finals_session(
        target_event_id, bonus_round_row.id, target_bonus_table_role, null, now()
      );
      if compatibility_changed then
        perform app_private.insert_audit_log(
          target_event_id,
          'event_bonus_round',
          bonus_round_row.id::text,
          'start_bonus_assigned_table_sessions',
          null,
          public.get_event_finals_state(target_event_id),
          jsonb_build_object(
            'actor_user_id', auth.uid(),
            'flow_version', 'legacy',
            'bonus_table_role', target_bonus_table_role,
            'started_session_ids', jsonb_build_array(session_row.id)
          )
        );
      end if;
      return next session_row;
      return;
    end if;
    raise exception 'Unsupported bonus table role.' using errcode = 'P0001';
  end if;

  select array_agg(candidate_table.event_table_id order by candidate_table.event_table_id)
  into candidate_table_ids
  from (
    select distinct contest.event_table_id
    from public.event_finals_contests as contest
    where contest.bonus_round_id = bonus_round_row.id
      and contest.status = 'ready'
      and (target_bonus_table_role is null or target_bonus_table_role = case contest.contest_type
        when 'table_of_champions' then 'table_of_champions'
        when 'table_of_redemption' then 'table_of_redemption'
        when 'champions_sudden_death' then 'table_of_champions_sudden_death'
        when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_winner_tiebreak' then 'table_of_redemption'
        else null end)
  ) as candidate_table;

  -- Prelock the complete orchestrated compatibility candidate set.
  -- Only not-yet-started contests are in this set. Scoring locks an active
  -- session before the event advisory lock, so including active contest
  -- sessions here would invert the lock order.
  perform 1
  from public.event_tables as event_table
  where event_table.id = any(coalesce(candidate_table_ids, array[]::uuid[]))
  order by event_table.id for update;
  perform 1
  from public.nfc_tags as tag
  where tag.id in (
    select event_table.nfc_tag_id
    from public.event_tables as event_table
    where event_table.id = any(coalesce(candidate_table_ids, array[]::uuid[]))
  )
  order by tag.id for update;
  begin
    perform 1
    from public.table_sessions as session
    where session.event_table_id = any(coalesce(candidate_table_ids, array[]::uuid[]))
      and session.status in ('active', 'paused')
    order by session.id for update nowait;
  exception
    when lock_not_available then
      raise exception
        'Finals tables are currently being scored. Refresh and try again.'
        using errcode = 'P0001';
  end;

  for contest_row in
    select contest.* from public.event_finals_contests as contest
    where contest.bonus_round_id = bonus_round_row.id
      and contest.status in ('ready', 'active')
      and (target_bonus_table_role is null or target_bonus_table_role = case contest.contest_type
        when 'table_of_champions' then 'table_of_champions'
        when 'table_of_redemption' then 'table_of_redemption'
        when 'champions_sudden_death' then 'table_of_champions_sudden_death'
        when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_winner_tiebreak' then 'table_of_redemption'
        else null end)
    order by contest.sequence_number
  loop
    if contest_row.status = 'ready' then
      perform app_private.prepare_finals_contest(contest_row.id);
      compatibility_changed := true;
      started_contest_ids := array_append(started_contest_ids, contest_row.id);
    end if;
    session_row := app_private.start_assigned_finals_session(
      target_event_id, bonus_round_row.id,
      case contest_row.contest_type
        when 'table_of_champions' then 'table_of_champions'
        when 'table_of_redemption' then 'table_of_redemption'
        when 'champions_sudden_death' then 'table_of_champions_sudden_death'
        when 'direct_qualification_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_advancement_tiebreak' then 'table_of_champions_play_in'
        when 'redemption_winner_tiebreak' then 'table_of_redemption'
        else contest_row.contest_type
      end,
      contest_row.id, now()
    );
    if contest_row.status = 'ready' then
      started_session_ids := array_append(started_session_ids, session_row.id);
    end if;
    return next session_row;
  end loop;

  if compatibility_changed then
    update public.event_bonus_rounds
    set state_version = state_version + 1, updated_at = now()
    where id = bonus_round_row.id;

    perform app_private.insert_audit_log(
      target_event_id,
      'event_bonus_round',
      bonus_round_row.id::text,
      'start_bonus_assigned_table_sessions',
      jsonb_build_object('state_version', bonus_round_row.state_version),
      public.get_event_finals_state(target_event_id),
      jsonb_build_object(
        'actor_user_id', auth.uid(),
        'bonus_table_role', target_bonus_table_role,
        'started_contest_ids', to_jsonb(started_contest_ids),
        'started_session_ids', to_jsonb(started_session_ids)
      )
    );
  end if;
  return;
end;
$$;

create or replace function app_private.reconcile_legacy_finals_completion(
  target_table_session_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  source_session public.table_sessions%rowtype;
  bonus_round_row public.event_bonus_rounds%rowtype;
begin
  select session.* into source_session
  from public.table_sessions as session
  where session.id = target_table_session_id
  for update;

  if not found
    or source_session.bonus_table_role <> 'table_of_redemption'
    or source_session.status <> 'completed'
  then
    return;
  end if;

  select root.* into bonus_round_row
  from public.event_bonus_rounds as root
  where root.id = source_session.bonus_round_id
    and root.flow_version = 'legacy'
  for update;

  if not found or bonus_round_row.champion_event_guest_id is null then
    return;
  end if;

  if exists (
    select 1
    from (values
      ('table_of_champions'::text, bonus_round_row.champions_table_id),
      ('table_of_redemption'::text, bonus_round_row.redemption_table_id)
    ) as required(role_value, table_id)
    where required.table_id is not null
      and not exists (
        select 1
        from public.table_sessions as session
        where session.event_id = bonus_round_row.event_id
          and session.bonus_round_id = bonus_round_row.id
          and session.bonus_table_role = required.role_value
          and session.event_table_id = required.table_id
          and session.assignment_round = bonus_round_row.assignment_round
          and session.finals_contest_id is null
          and session.status = 'completed'
          and app_private.finals_session_matches_assignments(
            session.id,
            bonus_round_row.event_id,
            bonus_round_row.id,
            required.role_value,
            required.table_id,
            bonus_round_row.assignment_round,
            null
          )
      )
  ) then
    return;
  end if;

  update public.event_bonus_rounds
  set status = 'completed',
      completed_at = coalesce(completed_at, now()),
      updated_at = now()
  where id = bonus_round_row.id;
end;
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
    perform app_private.reconcile_legacy_finals_completion(
      target_table_session_id
    );
  end if;
end;
$$;

revoke all on function app_private.finals_session_matches_assignments(
  uuid, uuid, uuid, text, uuid, integer, uuid
) from public;
revoke all on function app_private.legacy_finals_session_matches_assignments(
  uuid, uuid, uuid, text, uuid, integer
) from public;
revoke all on function app_private.legacy_finals_recovery_state(uuid) from public;
revoke all on function app_private.reconcile_legacy_finals_completion(uuid) from public;
revoke all on function app_private.guard_active_session_guest_conflict() from public;
revoke all on function public.get_event_finals_state_before_legacy_recovery(uuid) from public;
revoke all on function public.get_event_finals_state_before_legacy_recovery(uuid) from anon;
revoke all on function public.get_event_finals_state_before_legacy_recovery(uuid) from authenticated;
revoke all on function public.get_event_finals_state_before_legacy_recovery(uuid) from service_role;
revoke all on function public.get_event_finals_state(uuid) from public;
revoke all on function public.resume_event_finals_start(uuid, text) from public;
revoke all on function public.resume_event_finals_start(uuid, text) from anon;
revoke all on function public.start_bonus_assigned_table_sessions(uuid, text) from public;
revoke all on function public.start_bonus_assigned_table_sessions(uuid, text) from anon;

grant execute on function public.get_event_finals_state(uuid) to authenticated;
grant execute on function public.resume_event_finals_start(uuid, text) to authenticated;
grant execute on function public.start_bonus_assigned_table_sessions(uuid, text) to authenticated;

select pg_notify('pgrst', 'reload schema');
