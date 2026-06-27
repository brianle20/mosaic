-- Qualify ambiguous PL/pgSQL references reported by live db lint.

create or replace function public.start_table_of_champions_play_in(
  target_event_id uuid,
  play_in_table_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  event_table_id uuid,
  table_label text,
  table_display_order integer,
  event_guest_id uuid,
  guest_display_name text,
  seat_index integer,
  assignment_round integer,
  assignment_type text,
  bonus_round_id uuid,
  bonus_table_role text,
  seed_rank integer,
  status text,
  assigned_at timestamptz,
  assigned_by_user_id uuid,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  bonus_round_row public.event_bonus_rounds%rowtype;
  next_assignment_round integer;
  play_in_player_count integer;
  cutoff_player_count integer;
  selected_play_in_table_id uuid := play_in_table_id;
begin
  select *
  into bonus_round_row
  from public.event_bonus_rounds as bonus_round
  where bonus_round.event_id = target_event_id
    and bonus_round.status = 'active'
    and bonus_round.play_in_status = 'required'
  order by bonus_round.created_at desc
  limit 1
  for update;

  if not found then
    raise exception 'Table of Champions play-in is not required for this event.'
      using errcode = 'P0001';
  end if;

  if not app_private.is_event_owner(bonus_round_row.event_id) then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  if not exists (
    select 1
    from public.event_tables as event_table
    join public.nfc_tags as tag
      on tag.id = event_table.nfc_tag_id
      and tag.default_tag_type = 'table'
      and tag.status = 'active'
    where event_table.id = selected_play_in_table_id
      and event_table.event_id = bonus_round_row.event_id
  ) then
    raise exception 'Play-in table must be a ready event table with an active table NFC tag.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as session
    where session.event_table_id = selected_play_in_table_id
      and session.status in ('active', 'paused')
  ) then
    raise exception 'End the active or paused session at this table before starting the play-in.'
      using errcode = 'P0001';
  end if;

  select count(*)::integer
  into play_in_player_count
  from app_private.table_of_champions_play_in_candidates(
    bonus_round_row.event_id
  );

  select count(*)::integer
  into cutoff_player_count
  from app_private.table_of_champions_play_in_candidates(
    bonus_round_row.event_id
  ) as candidates
  where candidates.total_points = (
    select cutoff.total_points
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as cutoff
    where cutoff.seed_rank = 4
  );

  if play_in_player_count not between 2 and 4 then
    raise exception 'Play-in requires 2 to 4 players.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(assignment.assignment_round), 0) + 1
  into next_assignment_round
  from public.event_seating_assignments as assignment
  where assignment.event_id = bonus_round_row.event_id;

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.event_id = bonus_round_row.event_id
    and assignment.status = 'active';

  update public.event_seating_assignments as assignment
  set status = 'cleared'
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_play_in'
    and assignment.status = 'active';

  with cutoff_players as (
    select *
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as candidates
    where candidates.seed_rank <= (
      select coalesce(max(candidates.seed_rank), 4)
      from app_private.table_of_champions_play_in_candidates(
        bonus_round_row.event_id
      ) as candidates
      where candidates.total_points = (
        select cutoff.total_points
        from app_private.table_of_champions_play_in_candidates(
          bonus_round_row.event_id
        ) as cutoff
        where cutoff.seed_rank = 4
      )
    )
  ),
  lower_seed_players as (
    select *
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as candidates
    where candidates.seed_rank > (
      select coalesce(max(cutoff_players.seed_rank), 4)
      from cutoff_players
    )
    order by candidates.seed_rank asc
    limit greatest(0, 4 - cutoff_player_count)
  ),
  selected_play_in_players as (
    select
      candidates.event_guest_id,
      candidates.seed_rank,
      row_number() over (order by random(), candidates.event_guest_id)::integer - 1
        as seat_index
    from app_private.table_of_champions_play_in_candidates(
      bonus_round_row.event_id
    ) as candidates
    order by candidates.seed_rank asc
  )
  insert into public.event_seating_assignments (
    event_id,
    event_table_id,
    event_guest_id,
    seat_index,
    assignment_round,
    assignment_type,
    bonus_round_id,
    bonus_table_role,
    seed_rank,
    status,
    assigned_at,
    assigned_by_user_id
  )
  select
    bonus_round_row.event_id,
    selected_play_in_table_id,
    selected_play_in_players.event_guest_id,
    selected_play_in_players.seat_index,
    next_assignment_round,
    'bonus',
    bonus_round_row.id,
    'table_of_champions_play_in',
    selected_play_in_players.seed_rank,
    'active',
    now(),
    auth.uid()
  from selected_play_in_players;

  update public.event_bonus_rounds
  set
    play_in_status = 'active',
    play_in_table_id = selected_play_in_table_id,
    play_in_session_id = null,
    play_in_winner_event_guest_id = null,
    play_in_winner_seed_rank = null
  where event_bonus_rounds.id = bonus_round_row.id;

  return query
  select *
  from public.get_event_seating_assignments(
    bonus_round_row.event_id
  ) as assignment
  where assignment.bonus_round_id = bonus_round_row.id
    and assignment.bonus_table_role = 'table_of_champions_play_in';
end;
$$;

create or replace function public.add_saved_guests_to_event(
  target_event_id uuid,
  target_guest_profile_ids uuid[],
  target_tournament_status text default 'qualified',
  target_cover_status text default 'unpaid',
  target_cover_amount_cents integer default 0,
  target_is_comped boolean default false
)
returns table (
  id uuid,
  event_id uuid,
  guest_profile_id uuid,
  display_name text,
  normalized_name text,
  public_display_name text,
  player_id uuid,
  phone_e164 text,
  email_lower text,
  instagram_handle text,
  attendance_status text,
  tournament_status text,
  cover_status text,
  cover_amount_cents integer,
  is_comped boolean,
  has_scored_play boolean,
  note text,
  checked_in_at timestamptz,
  row_version integer,
  guest_profile jsonb
)
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  event_row public.events%rowtype;
  inserted_count integer := 0;
begin
  if not app_private.is_event_owner(target_event_id) then
    raise exception 'Event not found or access denied.'
      using errcode = 'P0001';
  end if;

  if target_guest_profile_ids is null
    or cardinality(target_guest_profile_ids) = 0
  then
    return;
  end if;

  if target_tournament_status not in (
    'open_play_only',
    'qualifying',
    'qualified',
    'withdrawn'
  ) then
    raise exception 'Invalid tournament status: %', target_tournament_status
      using errcode = 'P0001';
  end if;

  if target_cover_status not in (
    'unpaid',
    'paid',
    'partial',
    'comped',
    'refunded'
  ) then
    raise exception 'Invalid cover status: %', target_cover_status
      using errcode = 'P0001';
  end if;

  if target_cover_amount_cents < 0 then
    raise exception 'Cover amount must be zero or more.'
      using errcode = 'P0001';
  end if;

  select *
  into event_row
  from public.events as event_record
  where event_record.id = target_event_id;

  perform set_config('app.bulk_saved_guest_insert', 'on', true);

  return query
  with requested as (
    select distinct on (profile_id)
      profile_id,
      requested_order
    from unnest(target_guest_profile_ids)
      with ordinality as requested_profiles(profile_id, requested_order)
    where profile_id is not null
    order by profile_id, requested_order
  ),
  inserted as (
    insert into public.event_guests (
      event_id,
      guest_profile_id,
      display_name,
      normalized_name,
      public_display_name,
      attendance_status,
      tournament_status,
      cover_status,
      cover_amount_cents,
      is_comped,
      has_scored_play
    )
    select
      target_event_id,
      profile.id,
      profile.display_name,
      profile.normalized_name,
      coalesce(
        nullif(btrim(profile.public_display_name), ''),
        public.default_public_display_name(profile.display_name)
      ),
      'expected',
      target_tournament_status,
      target_cover_status,
      target_cover_amount_cents,
      target_is_comped,
      false
    from requested
    join public.guest_profiles as profile
      on profile.id = requested.profile_id
     and profile.owner_user_id = event_row.owner_user_id
    left join public.event_guests as existing_guest
      on existing_guest.event_id = target_event_id
     and existing_guest.guest_profile_id = profile.id
    where existing_guest.id is null
    order by requested.requested_order
    on conflict (event_id, guest_profile_id) do nothing
    returning *
  ),
  returned_rows as (
    select
      guest.id,
      guest.event_id,
      guest.guest_profile_id,
      guest.display_name,
      guest.normalized_name,
      guest.public_display_name,
      guest.player_id,
      guest.phone_e164,
      guest.email_lower,
      profile.instagram_handle,
      guest.attendance_status,
      guest.tournament_status,
      guest.cover_status,
      guest.cover_amount_cents,
      guest.is_comped,
      guest.has_scored_play,
      guest.note,
      guest.checked_in_at,
      guest.row_version,
      jsonb_build_object(
        'id', profile.id,
        'owner_user_id', profile.owner_user_id,
        'display_name', profile.display_name,
        'normalized_name', profile.normalized_name,
        'public_display_name', profile.public_display_name,
        'phone_e164', profile.phone_e164,
        'email_lower', profile.email_lower,
        'instagram_handle', profile.instagram_handle,
        'row_version', profile.row_version
      ) as guest_profile,
      requested.requested_order
    from inserted as guest
    join public.guest_profiles as profile
      on profile.id = guest.guest_profile_id
    join requested
      on requested.profile_id = guest.guest_profile_id
  )
  select
    returned_rows.id,
    returned_rows.event_id,
    returned_rows.guest_profile_id,
    returned_rows.display_name,
    returned_rows.normalized_name,
    returned_rows.public_display_name,
    returned_rows.player_id,
    returned_rows.phone_e164,
    returned_rows.email_lower,
    returned_rows.instagram_handle,
    returned_rows.attendance_status,
    returned_rows.tournament_status,
    returned_rows.cover_status,
    returned_rows.cover_amount_cents,
    returned_rows.is_comped,
    returned_rows.has_scored_play,
    returned_rows.note,
    returned_rows.checked_in_at,
    returned_rows.row_version,
    returned_rows.guest_profile
  from returned_rows
  order by returned_rows.requested_order;

  get diagnostics inserted_count = row_count;

  if inserted_count > 0 then
    perform app_private.refresh_public_event_standings_snapshot(
      target_event_id
    );
  end if;
end;
$$;

select pg_notify('pgrst', 'reload schema');
