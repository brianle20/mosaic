-- Logistics roles and approved staff access.

alter table public.users
  drop constraint if exists users_email_not_null;

alter table public.users
  alter column email drop not null,
  add column if not exists phone_e164 text,
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists users_phone_e164_unique
  on public.users (phone_e164)
  where phone_e164 is not null;

create table if not exists public.approved_logistics_identities (
  id uuid primary key default gen_random_uuid(),
  email text,
  email_lower text,
  phone_e164 text,
  display_name text not null,
  status text not null default 'active',
  approved_by_user_id uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint approved_logistics_identities_status_check
    check (status in ('active', 'disabled')),
  constraint approved_logistics_identities_contact_required
    check (
      nullif(btrim(email), '') is not null
      or nullif(btrim(phone_e164), '') is not null
    ),
  constraint approved_logistics_identities_email_lower_matches
    check (email_lower is null or email_lower = lower(email)),
  constraint approved_logistics_identities_display_name_nonempty
    check (length(btrim(display_name)) > 0)
);

create unique index if not exists approved_logistics_identities_email_lower_unique
  on public.approved_logistics_identities (email_lower)
  where email_lower is not null;

create unique index if not exists approved_logistics_identities_phone_e164_unique
  on public.approved_logistics_identities (phone_e164)
  where phone_e164 is not null;

create or replace function app_private.default_display_name_from_identity(
  source_email text,
  source_phone text
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select identity.display_name
      from public.approved_logistics_identities as identity
      where identity.status = 'active'
        and (
          (source_email is not null and identity.email_lower = lower(source_email))
          or (source_phone is not null and identity.phone_e164 = source_phone)
        )
      order by identity.updated_at desc
      limit 1
    ),
    app_private.default_display_name_from_email(source_email),
    source_phone,
    'Mosaic User'
  )
$$;

drop trigger if exists approved_logistics_identities_touch_updated_at
  on public.approved_logistics_identities;
create trigger approved_logistics_identities_touch_updated_at
before update on public.approved_logistics_identities
for each row
execute function app_private.touch_updated_at();

create table if not exists public.event_staff_memberships (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  approved_identity_id uuid not null
    references public.approved_logistics_identities(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  role text not null,
  status text not null default 'active',
  created_by_user_id uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint event_staff_memberships_role_check
    check (role in ('qualification_scorer', 'event_scorer')),
  constraint event_staff_memberships_status_check
    check (status in ('active', 'disabled'))
);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_staff_memberships_event_identity_unique'
      and conrelid = 'public.event_staff_memberships'::regclass
  ) then
    alter table public.event_staff_memberships
      add constraint event_staff_memberships_event_identity_unique
      unique (event_id, approved_identity_id);
  end if;
end $$;

create unique index if not exists event_staff_memberships_event_user_unique
  on public.event_staff_memberships (event_id, user_id)
  where user_id is not null;

create index if not exists event_staff_memberships_event_status_idx
  on public.event_staff_memberships (event_id, status, role);

drop trigger if exists event_staff_memberships_touch_updated_at
  on public.event_staff_memberships;
create trigger event_staff_memberships_touch_updated_at
before update on public.event_staff_memberships
for each row
execute function app_private.touch_updated_at();

alter table public.approved_logistics_identities enable row level security;
alter table public.event_staff_memberships enable row level security;

create or replace function app_private.link_event_staff_memberships_for_user(
  target_user_id uuid,
  target_email text,
  target_phone text
)
returns void
language sql
security definer
set search_path = public
as $$
  update public.event_staff_memberships as membership
  set user_id = target_user_id
  from public.approved_logistics_identities as identity
  where identity.id = membership.approved_identity_id
    and membership.status = 'active'
    and identity.status = 'active'
    and membership.user_id is null
    and (
      (target_email is not null and identity.email_lower = lower(target_email))
      or (target_phone is not null and identity.phone_e164 = target_phone)
    )
    and not exists (
      select 1
      from public.event_staff_memberships as existing
      where existing.event_id = membership.event_id
        and existing.user_id = target_user_id
        and existing.id <> membership.id
    );
$$;

create or replace function app_private.handle_auth_user_sync()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  insert into public.users (
    id,
    email,
    phone_e164,
    display_name,
    status,
    created_at,
    updated_at
  )
  values (
    new.id,
    new.email,
    new.phone,
    app_private.default_display_name_from_identity(new.email, new.phone),
    'active',
    coalesce(new.created_at, now()),
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    phone_e164 = excluded.phone_e164,
    display_name = coalesce(nullif(public.users.display_name, ''), excluded.display_name),
    updated_at = now();

  perform app_private.link_event_staff_memberships_for_user(
    new.id,
    new.email,
    new.phone
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_or_updated on auth.users;

create trigger on_auth_user_created_or_updated
after insert or update of email, phone
on auth.users
for each row
when (new.email is not null or new.phone is not null)
execute function app_private.handle_auth_user_sync();

insert into public.users (
  id,
  email,
  phone_e164,
  display_name,
  status,
  created_at,
  updated_at
)
select
  auth_user.id,
  auth_user.email,
  auth_user.phone,
  app_private.default_display_name_from_identity(auth_user.email, auth_user.phone),
  'active',
  coalesce(auth_user.created_at, now()),
  now()
from auth.users as auth_user
where auth_user.email is not null
  or auth_user.phone is not null
on conflict (id) do update
set
  email = excluded.email,
  phone_e164 = excluded.phone_e164,
  updated_at = now();

select app_private.link_event_staff_memberships_for_user(
  auth_user.id,
  auth_user.email,
  auth_user.phone
)
from auth.users as auth_user
where auth_user.email is not null
  or auth_user.phone is not null;

create or replace function app_private.is_event_owner(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events as event
    where event.id = target_event_id
      and event.owner_user_id = target_user_id
  )
$$;

create or replace function app_private.event_staff_role(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select membership.role
  from public.event_staff_memberships as membership
  join public.approved_logistics_identities as identity
    on identity.id = membership.approved_identity_id
  left join public.users as app_user
    on app_user.id = target_user_id
  where membership.event_id = target_event_id
    and membership.status = 'active'
    and identity.status = 'active'
    and (
      membership.user_id = target_user_id
      or (
        membership.user_id is null
        and app_user.id is not null
        and (
          (app_user.email is not null and identity.email_lower = lower(app_user.email))
          or (app_user.phone_e164 is not null and identity.phone_e164 = app_user.phone_e164)
        )
      )
    )
  order by case membership.role when 'event_scorer' then 1 else 2 end
  limit 1
$$;

create or replace function app_private.can_view_event(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, target_user_id)
    or app_private.event_staff_role(target_event_id, target_user_id) is not null
$$;

create or replace function app_private.can_manage_event(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, target_user_id)
$$;

create or replace function app_private.can_score_qualification(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, target_user_id)
    or app_private.event_staff_role(target_event_id, target_user_id)
      in ('qualification_scorer', 'event_scorer')
    -- Explicit role boundary: role = 'qualification_scorer' can score qualification only.
$$;

create or replace function app_private.can_score_tournament(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, target_user_id)
    or app_private.event_staff_role(target_event_id, target_user_id) = 'event_scorer'
    -- Explicit role boundary: role = 'event_scorer' can score tournament.
$$;

create or replace function app_private.can_score_bonus(
  target_event_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select app_private.is_event_owner(target_event_id, target_user_id)
    or app_private.event_staff_role(target_event_id, target_user_id) = 'event_scorer'
    -- Explicit role boundary: role = 'event_scorer' can score bonus.
$$;

create or replace function app_private.require_owned_event(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  select event.*
  into event_row
  from public.events as event
  where event.id = target_event_id
    and app_private.can_manage_event(event.id)
  for update;

  if not found then
    raise exception 'Event not found for current host.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_viewable_event(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  select event.*
  into event_row
  from public.events as event
  where event.id = target_event_id
    and app_private.can_view_event(event.id);

  if not found then
    raise exception 'Event not found for current user.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_scoring(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
begin
  select event.*
  into event_row
  from public.events as event
  where event.id = target_event_id
    and app_private.can_score_qualification(event.id);

  if not found then
    raise exception 'Event not found for current scorer.'
      using errcode = 'P0001';
  end if;

  if event_row.lifecycle_status <> 'active' then
    raise exception 'Scoring is only available while the event is active.'
      using errcode = 'P0001';
  end if;

  if not event_row.scoring_open then
    raise exception 'Scoring is closed for this event.'
      using errcode = 'P0001';
  end if;

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_phase_scoring(
  target_event_id uuid,
  target_scoring_phase text
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  allowed boolean := false;
begin
  if target_scoring_phase = 'qualification' then
    allowed := app_private.can_score_qualification(target_event_id);
  elsif target_scoring_phase = 'tournament' then
    allowed := app_private.can_score_tournament(target_event_id);
  elsif target_scoring_phase = 'bonus' then
    allowed := app_private.can_score_bonus(target_event_id);
  else
    raise exception 'Unsupported scoring phase.'
      using errcode = 'P0001';
  end if;

  if not allowed then
    raise exception 'Current user cannot score this phase.'
      using errcode = 'P0001';
  end if;

  event_row := app_private.require_event_for_scoring(target_event_id);

  return event_row;
end;
$$;

create or replace function app_private.require_event_for_live_scoring(
  target_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
begin
  return app_private.require_event_for_scoring(target_event_id);
end;
$$;

create or replace function app_private.can_score_session(
  target_table_session_id uuid,
  target_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select case session.scoring_phase
        when 'qualification'
          then app_private.can_score_qualification(session.event_id, target_user_id)
        when 'tournament'
          then app_private.can_score_tournament(session.event_id, target_user_id)
        when 'bonus'
          then app_private.can_score_bonus(session.event_id, target_user_id)
        else false
      end
      from public.table_sessions as session
      where session.id = target_table_session_id
    ),
    false
  )
$$;

create or replace function app_private.require_owned_table(
  target_event_table_id uuid
)
returns public.event_tables
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
begin
  select event_table.*
  into table_row
  from public.event_tables as event_table
  where event_table.id = target_event_table_id
    and app_private.can_manage_event(event_table.event_id)
  for update;

  if not found then
    raise exception 'Table not found for current host.'
      using errcode = 'P0001';
  end if;

  return table_row;
end;
$$;

create or replace function app_private.require_table_for_scoring(
  target_event_table_id uuid
)
returns public.event_tables
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  scoring_phase text;
begin
  select event_table.*
  into table_row
  from public.event_tables as event_table
  where event_table.id = target_event_table_id
    and app_private.can_view_event(event_table.event_id)
  for update;

  if not found then
    raise exception 'Table not found for current scorer.'
      using errcode = 'P0001';
  end if;

  select coalesce(event.current_scoring_phase, 'qualification')
  into scoring_phase
  from public.events as event
  where event.id = table_row.event_id;

  perform app_private.require_event_for_phase_scoring(
    table_row.event_id,
    scoring_phase
  );

  return table_row;
end;
$$;

create or replace function app_private.require_guest_for_check_in(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
begin
  select guest.*
  into guest_row
  from public.event_guests as guest
  where guest.id = target_event_guest_id
    and (
      app_private.can_manage_event(guest.event_id)
      or app_private.can_score_qualification(guest.event_id)
    )
  for update;

  if not found then
    raise exception 'Guest not found for current check-in operator.'
      using errcode = 'P0001';
  end if;

  return guest_row;
end;
$$;

create or replace function app_private.require_owned_session(
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
  select session.*
  into session_row
  from public.table_sessions as session
  where session.id = target_table_session_id
    and app_private.can_score_session(session.id)
  for update;

  if not found then
    raise exception 'Session not found for current scorer.'
      using errcode = 'P0001';
  end if;

  perform app_private.require_event_for_phase_scoring(
    session_row.event_id,
    session_row.scoring_phase
  );

  return session_row;
end;
$$;

create or replace function app_private.require_owned_hand_result(
  target_hand_result_id uuid
)
returns public.hand_results
language plpgsql
security definer
set search_path = public
as $$
declare
  hand_row public.hand_results%rowtype;
begin
  select hand_result.*
  into hand_row
  from public.hand_results as hand_result
  where hand_result.id = target_hand_result_id
    and app_private.can_score_session(hand_result.table_session_id)
  for update;

  if not found then
    raise exception 'Hand result not found for current scorer.'
      using errcode = 'P0001';
  end if;

  return hand_row;
end;
$$;

create or replace function public.check_in_guest(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  updated_guest public.event_guests%rowtype;
begin
  guest_row := app_private.require_guest_for_check_in(target_event_guest_id);
  perform app_private.require_event_for_checkin(guest_row.event_id);

  update public.event_guests
  set
    attendance_status = 'checked_in',
    checked_in_at = coalesce(checked_in_at, now())
  where id = guest_row.id
  returning *
  into updated_guest;

  perform app_private.insert_audit_log(
    updated_guest.event_id,
    'event_guest',
    updated_guest.id::text,
    'check_in',
    to_jsonb(guest_row),
    to_jsonb(updated_guest)
  );

  return updated_guest;
end;
$$;

create or replace function public.resolve_event_table_by_tag(
  target_event_id uuid,
  scanned_uid text
)
returns public.event_tables
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_uid text;
  tag_row public.nfc_tags%rowtype;
  table_row public.event_tables%rowtype;
begin
  if not app_private.can_view_event(target_event_id) then
    raise exception 'Event not found for current scorer.'
      using errcode = 'P0001';
  end if;

  normalized_uid := app_private.normalize_tag_uid(scanned_uid);

  select *
  into tag_row
  from public.nfc_tags
  where uid_hex = normalized_uid;

  if not found then
    raise exception 'Unknown table tag. Bind this tag to a table first.'
      using errcode = 'P0001';
  end if;

  if tag_row.default_tag_type <> 'table' then
    raise exception 'Expected a table tag.'
      using errcode = 'P0001';
  end if;

  select *
  into table_row
  from public.event_tables
  where event_id = target_event_id
    and nfc_tag_id = tag_row.id;

  if not found then
    raise exception 'This tag is not assigned to a table in this event.'
      using errcode = 'P0001';
  end if;

  return table_row;
end;
$$;

create or replace function public.start_table_session(
  target_event_table_id uuid,
  scanned_table_uid text,
  east_player_uid text,
  south_player_uid text,
  west_player_uid text,
  north_player_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  event_row public.events%rowtype;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  normalized_table_uid text;
  bound_tag_uid text;
  next_session_number integer;
  seat_guest_ids uuid[];
  seat_index integer;
  scanned_uid text;
  resolved_tag_row public.nfc_tags%rowtype;
  resolved_assignment_row public.event_guest_tag_assignments%rowtype;
  resolved_guest_row public.event_guests%rowtype;
  bonus_assignment_row public.event_seating_assignments%rowtype;
  effective_scoring_phase text;
  scanned_player_uids text[] := array[
    east_player_uid,
    south_player_uid,
    west_player_uid,
    north_player_uid
  ];
  initial_winds text[] := array['east', 'south', 'west', 'north'];
begin
  table_row := app_private.require_table_for_scoring(target_event_table_id);

  select *
  into event_row
  from public.events
  where id = table_row.event_id;

  effective_scoring_phase := coalesce(
    event_row.current_scoring_phase,
    'qualification'
  );

  if table_row.nfc_tag_id is null then
    raise exception 'A bound table tag is required before starting a session.'
      using errcode = 'P0001';
  end if;

  normalized_table_uid := app_private.normalize_tag_uid(scanned_table_uid);

  select uid_hex
  into bound_tag_uid
  from public.nfc_tags
  where id = table_row.nfc_tag_id;

  if bound_tag_uid is null or bound_tag_uid <> normalized_table_uid then
    raise exception 'The scanned table tag does not match the selected table.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'This table already has an active session.'
      using errcode = 'P0001';
  end if;

  seat_guest_ids := array[]::uuid[];

  for seat_index in 1..array_length(scanned_player_uids, 1) loop
    scanned_uid := app_private.normalize_tag_uid(
      scanned_player_uids[seat_index]
    );

    if scanned_uid = '' then
      raise exception 'Each seat requires a player tag.'
        using errcode = 'P0001';
    end if;

    if scanned_uid = any (
      coalesce(scanned_player_uids[1:seat_index - 1], array[]::text[])
    ) then
      raise exception 'Duplicate player tag scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    select *
    into resolved_tag_row
    from public.nfc_tags
    where uid_hex = scanned_uid
    for update;

    if not found then
      raise exception 'Unknown player tag. Register player tags during check-in first.'
        using errcode = 'P0001';
    end if;

    if resolved_tag_row.default_tag_type <> 'player' then
      raise exception 'Expected a player tag for seat assignment.'
        using errcode = 'P0001';
    end if;

    select assignment.*
    into resolved_assignment_row
    from public.event_guest_tag_assignments as assignment
    where assignment.event_id = table_row.event_id
      and assignment.nfc_tag_id = resolved_tag_row.id
      and assignment.status = 'assigned'
    for update;

    if not found then
      raise exception 'The scanned player tag is not assigned to an eligible guest in this event.'
        using errcode = 'P0001';
    end if;

    select guest.*
    into resolved_guest_row
    from public.event_guests as guest
    where guest.id = resolved_assignment_row.event_guest_id
    for update;

    if resolved_guest_row.attendance_status <> 'checked_in' then
      raise exception 'All session players must be checked in.'
        using errcode = 'P0001';
    end if;

    if resolved_guest_row.id = any (seat_guest_ids) then
      raise exception 'Duplicate guest scanned in the same session setup.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.table_session_seats as seat
      join public.table_sessions as existing_session
        on existing_session.id = seat.table_session_id
      where seat.event_guest_id = resolved_guest_row.id
        and existing_session.event_id = table_row.event_id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'A scanned guest is already seated in another active session.'
        using errcode = 'P0001';
    end if;

    perform app_private.validate_random_seating_assignment(
      table_row.id,
      seat_index - 1,
      resolved_guest_row.id
    );

    seat_guest_ids := array_append(seat_guest_ids, resolved_guest_row.id);
  end loop;

  select *
  into ruleset_row
  from public.rulesets
  where id = table_row.default_ruleset_id;

  if not found then
    raise exception 'Default ruleset not found for the selected table.'
      using errcode = 'P0001';
  end if;

  select assignment.*
  into bonus_assignment_row
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.assignment_type = 'bonus'
    and assignment.status = 'active'
  order by assignment.seat_index asc
  limit 1;

  select coalesce(max(session_number_for_table), 0) + 1
  into next_session_number
  from public.table_sessions
  where event_table_id = table_row.id;

  insert into public.table_sessions (
    event_id,
    event_table_id,
    session_number_for_table,
    ruleset_id,
    rotation_policy_type,
    rotation_policy_config_json,
    status,
    initial_east_seat_index,
    current_dealer_seat_index,
    dealer_pass_count,
    completed_games_count,
    hand_count,
    scoring_phase,
    bonus_round_id,
    bonus_table_role,
    started_at,
    started_by_user_id
  )
  values (
    table_row.event_id,
    table_row.id,
    next_session_number,
    table_row.default_ruleset_id,
    table_row.default_rotation_policy_type,
    table_row.default_rotation_policy_config_json,
    'active',
    0,
    0,
    0,
    0,
    0,
    case
      when bonus_assignment_row.id is null then effective_scoring_phase
      else 'bonus'
    end,
    case
      when bonus_assignment_row.id is null then null
      else bonus_assignment_row.bonus_round_id
    end,
    case
      when bonus_assignment_row.id is null then null
      else bonus_assignment_row.bonus_table_role
    end,
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  for seat_index in 1..array_length(seat_guest_ids, 1) loop
    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values (
      session_row.id,
      seat_index - 1,
      initial_winds[seat_index],
      seat_guest_ids[seat_index]
    );
  end loop;

  perform app_private.insert_audit_log(
    session_row.event_id,
    'table_session',
    session_row.id::text,
    'start',
    null,
    to_jsonb(session_row),
    jsonb_build_object(
      'event_table_id', table_row.id,
      'seat_guest_ids', seat_guest_ids,
      'scanned_table_uid', normalized_table_uid,
      'scoring_phase', session_row.scoring_phase
    )
  );

  return session_row;
end;
$$;

create or replace function public.start_assigned_table_session(
  target_event_table_id uuid,
  scanned_table_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  event_row public.events%rowtype;
  bound_tag_uid text;
  normalized_table_uid text;
  next_session_number integer;
  session_row public.table_sessions%rowtype;
  ruleset_row public.rulesets%rowtype;
  assignment_rows public.event_seating_assignments[];
  effective_scoring_phase text;
  initial_winds text[] := array['east', 'south', 'west', 'north'];
  seat_assignment_count integer;
begin
  table_row := app_private.require_table_for_scoring(target_event_table_id);

  select *
  into event_row
  from public.events
  where id = table_row.event_id;

  effective_scoring_phase := coalesce(
    event_row.current_scoring_phase,
    'qualification'
  );

  if effective_scoring_phase = 'qualification' then
    raise exception 'Assigned seating is only available after qualification.'
      using errcode = 'P0001';
  end if;

  if scanned_table_uid is not null then
    if table_row.nfc_tag_id is null then
      raise exception 'A bound table tag is required before starting a session.'
        using errcode = 'P0001';
    end if;

    normalized_table_uid := app_private.normalize_tag_uid(scanned_table_uid);

    select uid_hex
    into bound_tag_uid
    from public.nfc_tags
    where id = table_row.nfc_tag_id;

    if bound_tag_uid is null or bound_tag_uid <> normalized_table_uid then
      raise exception 'The scanned table tag does not match the selected table.'
        using errcode = 'P0001';
    end if;
  end if;

  if exists (
    select 1
    from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'This table already has an active session.'
      using errcode = 'P0001';
  end if;

  select array_agg(assignment order by assignment.seat_index asc)
  into assignment_rows
  from public.event_seating_assignments as assignment
  where assignment.event_id = table_row.event_id
    and assignment.event_table_id = table_row.id
    and assignment.status = 'active';

  if assignment_rows is null
    or not (array_length(assignment_rows, 1) between 2 and 4)
  then
    raise exception 'Two to four active seating assignments are required to start this assigned table.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from generate_subscripts(assignment_rows, 1) as assignment_index
    where assignment_rows[assignment_index].seat_index <> assignment_index - 1
  ) then
    raise exception 'Assigned seating must fill seats contiguously from East.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from unnest(assignment_rows) as assignment
    where assignment.assignment_round is distinct from assignment_rows[1].assignment_round
  ) then
    raise exception 'All active seating assignments must use the same assignment round.'
      using errcode = 'P0001';
  end if;

  if assignment_rows[1].assignment_type = 'bonus' then
    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type is distinct from assignment_rows[1].assignment_type
        or assignment.bonus_round_id is distinct from assignment_rows[1].bonus_round_id
        or assignment.bonus_table_role is distinct from assignment_rows[1].bonus_table_role
    ) then
      raise exception 'All active bonus assignments must use the same bonus metadata.'
        using errcode = 'P0001';
    end if;
  elsif assignment_rows[1].tournament_round_id is null
    or exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type is distinct from assignment_rows[1].assignment_type
        or assignment.tournament_round_id is distinct from assignment_rows[1].tournament_round_id
    )
  then
    raise exception 'All active tournament assignments must belong to the same tournament round.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.event_guests as guest
    where guest.id = any (
        select assignment.event_guest_id
        from unnest(assignment_rows) as assignment
      )
      and guest.attendance_status <> 'checked_in'
  ) then
    raise exception 'All assigned session players must be checked in.'
      using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from unnest(assignment_rows) as assignment
    join public.table_session_seats as seat
      on seat.event_guest_id = assignment.event_guest_id
    join public.table_sessions as existing_session
      on existing_session.id = seat.table_session_id
    where existing_session.event_id = table_row.event_id
      and existing_session.status in ('active', 'paused')
  ) then
    raise exception 'An assigned guest is already seated in another active session.'
      using errcode = 'P0001';
  end if;

  select *
  into ruleset_row
  from public.rulesets
  where id = table_row.default_ruleset_id;

  if not found then
    raise exception 'Default ruleset not found for the selected table.'
      using errcode = 'P0001';
  end if;

  select coalesce(max(session_number_for_table), 0) + 1
  into next_session_number
  from public.table_sessions
  where event_table_id = table_row.id;

  insert into public.table_sessions (
    event_id,
    event_table_id,
    session_number_for_table,
    ruleset_id,
    rotation_policy_type,
    rotation_policy_config_json,
    status,
    initial_east_seat_index,
    current_dealer_seat_index,
    dealer_pass_count,
    completed_games_count,
    hand_count,
    scoring_phase,
    bonus_round_id,
    bonus_table_role,
    tournament_round_id,
    assignment_round,
    started_at,
    started_by_user_id
  )
  values (
    table_row.event_id,
    table_row.id,
    next_session_number,
    table_row.default_ruleset_id,
    table_row.default_rotation_policy_type,
    table_row.default_rotation_policy_config_json,
    'active',
    0,
    0,
    0,
    0,
    0,
    case
      when assignment_rows[1].assignment_type = 'bonus' then 'bonus'
      else effective_scoring_phase
    end,
    assignment_rows[1].bonus_round_id,
    assignment_rows[1].bonus_table_role,
    assignment_rows[1].tournament_round_id,
    assignment_rows[1].assignment_round,
    now(),
    auth.uid()
  )
  returning *
  into session_row;

  for seat_assignment_count in 1..array_length(assignment_rows, 1) loop
    insert into public.table_session_seats (
      table_session_id,
      seat_index,
      initial_wind,
      event_guest_id
    )
    values (
      session_row.id,
      assignment_rows[seat_assignment_count].seat_index,
      initial_winds[assignment_rows[seat_assignment_count].seat_index + 1],
      assignment_rows[seat_assignment_count].event_guest_id
    );
  end loop;

  return session_row;
end;
$$;

grant execute on function public.start_table_session(uuid, text, text, text, text, text)
  to authenticated;
grant execute on function public.start_assigned_table_session(uuid, text)
  to authenticated;
grant execute on function public.check_in_guest(uuid)
  to authenticated;
grant execute on function public.resolve_event_table_by_tag(uuid, text)
  to authenticated;

drop policy if exists approved_logistics_identities_owner_read
  on public.approved_logistics_identities;
create policy approved_logistics_identities_owner_read
on public.approved_logistics_identities
for select
to authenticated
using (
  approved_by_user_id = auth.uid()
  or exists (
    select 1
    from public.event_staff_memberships as membership
    where membership.approved_identity_id = id
      and app_private.can_manage_event(membership.event_id)
  )
);

drop policy if exists event_staff_memberships_owner_all
  on public.event_staff_memberships;
create policy event_staff_memberships_owner_all
on public.event_staff_memberships
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists events_select_own on public.events;
drop policy if exists events_select_owned_or_staff on public.events;
create policy events_select_owned_or_staff
on public.events
for select
to authenticated
using (app_private.can_view_event(id));

drop policy if exists events_insert_own on public.events;
drop policy if exists events_insert_owner on public.events;
create policy events_insert_owner
on public.events
for insert
to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists events_update_own on public.events;
drop policy if exists events_update_owner on public.events;
create policy events_update_owner
on public.events
for update
to authenticated
using (app_private.can_manage_event(id))
with check (app_private.can_manage_event(id));

drop policy if exists events_delete_own on public.events;
drop policy if exists events_delete_owner on public.events;
create policy events_delete_owner
on public.events
for delete
to authenticated
using (app_private.can_manage_event(id));

drop policy if exists event_guests_owner_all on public.event_guests;
drop policy if exists event_guests_owner_manage on public.event_guests;
create policy event_guests_owner_manage
on public.event_guests
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_guests_owner_or_staff_read on public.event_guests;
create policy event_guests_owner_or_staff_read
on public.event_guests
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists guest_cover_entries_owner_all on public.guest_cover_entries;
drop policy if exists guest_cover_entries_owner_manage on public.guest_cover_entries;
create policy guest_cover_entries_owner_manage
on public.guest_cover_entries
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists guest_cover_entries_owner_or_staff_read
  on public.guest_cover_entries;
create policy guest_cover_entries_owner_or_staff_read
on public.guest_cover_entries
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_guest_tag_assignments_owner_all
  on public.event_guest_tag_assignments;
drop policy if exists event_guest_tag_assignments_owner_manage
  on public.event_guest_tag_assignments;
create policy event_guest_tag_assignments_owner_manage
on public.event_guest_tag_assignments
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_guest_tag_assignments_owner_or_staff_read
  on public.event_guest_tag_assignments;
create policy event_guest_tag_assignments_owner_or_staff_read
on public.event_guest_tag_assignments
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_tables_owner_all on public.event_tables;
drop policy if exists event_tables_owner_manage on public.event_tables;
create policy event_tables_owner_manage
on public.event_tables
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_tables_owner_or_staff_read on public.event_tables;
create policy event_tables_owner_or_staff_read
on public.event_tables
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists table_sessions_owner_all on public.table_sessions;
drop policy if exists table_sessions_owner_manage on public.table_sessions;
create policy table_sessions_owner_manage
on public.table_sessions
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists table_sessions_owner_or_staff_read on public.table_sessions;
create policy table_sessions_owner_or_staff_read
on public.table_sessions
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists table_sessions_owner_or_staff_score on public.table_sessions;
create policy table_sessions_owner_or_staff_score
on public.table_sessions
for update
to authenticated
using (app_private.can_score_session(id))
with check (app_private.can_score_session(id));

drop policy if exists table_session_seats_owner_all on public.table_session_seats;
drop policy if exists table_session_seats_owner_manage on public.table_session_seats;
create policy table_session_seats_owner_manage
on public.table_session_seats
for all
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_manage_event(session.event_id)
  )
)
with check (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists table_session_seats_owner_or_staff_read
  on public.table_session_seats;
create policy table_session_seats_owner_or_staff_read
on public.table_session_seats
for select
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_view_event(session.event_id)
  )
);

drop policy if exists hand_results_owner_all on public.hand_results;
drop policy if exists hand_results_owner_manage on public.hand_results;
create policy hand_results_owner_manage
on public.hand_results
for all
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_manage_event(session.event_id)
  )
)
with check (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_manage_event(session.event_id)
  )
);

drop policy if exists hand_results_owner_or_staff_read on public.hand_results;
create policy hand_results_owner_or_staff_read
on public.hand_results
for select
to authenticated
using (
  exists (
    select 1
    from public.table_sessions as session
    where session.id = table_session_id
      and app_private.can_view_event(session.event_id)
  )
);

drop policy if exists hand_results_owner_or_staff_score on public.hand_results;
create policy hand_results_owner_or_staff_score
on public.hand_results
for insert
to authenticated
with check (app_private.can_score_session(table_session_id));

drop policy if exists hand_results_owner_or_staff_update_score
  on public.hand_results;
create policy hand_results_owner_or_staff_update_score
on public.hand_results
for update
to authenticated
using (app_private.can_score_session(table_session_id))
with check (app_private.can_score_session(table_session_id));

drop policy if exists hand_settlements_owner_all on public.hand_settlements;
drop policy if exists hand_settlements_owner_or_staff_read on public.hand_settlements;
create policy hand_settlements_owner_or_staff_read
on public.hand_settlements
for select
to authenticated
using (
  exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    where hand_result.id = hand_result_id
      and app_private.can_view_event(session.event_id)
  )
);

drop policy if exists event_score_totals_owner_all on public.event_score_totals;
drop policy if exists event_score_totals_owner_or_staff_read
  on public.event_score_totals;
create policy event_score_totals_owner_or_staff_read
on public.event_score_totals
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_seating_assignments_owner_all
  on public.event_seating_assignments;
drop policy if exists event_seating_assignments_owner_manage
  on public.event_seating_assignments;
create policy event_seating_assignments_owner_manage
on public.event_seating_assignments
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_seating_assignments_owner_or_staff_read
  on public.event_seating_assignments;
create policy event_seating_assignments_owner_or_staff_read
on public.event_seating_assignments
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_tournament_rounds_owner_all
  on public.event_tournament_rounds;
drop policy if exists event_tournament_rounds_owner_manage
  on public.event_tournament_rounds;
create policy event_tournament_rounds_owner_manage
on public.event_tournament_rounds
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_tournament_rounds_owner_or_staff_read
  on public.event_tournament_rounds;
create policy event_tournament_rounds_owner_or_staff_read
on public.event_tournament_rounds
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_bonus_rounds_owner_all on public.event_bonus_rounds;
drop policy if exists event_bonus_rounds_owner_manage on public.event_bonus_rounds;
create policy event_bonus_rounds_owner_manage
on public.event_bonus_rounds
for all
to authenticated
using (app_private.can_manage_event(event_id))
with check (app_private.can_manage_event(event_id));

drop policy if exists event_bonus_rounds_owner_or_staff_read
  on public.event_bonus_rounds;
create policy event_bonus_rounds_owner_or_staff_read
on public.event_bonus_rounds
for select
to authenticated
using (app_private.can_view_event(event_id));

drop policy if exists event_score_adjustments_owner_all
  on public.event_score_adjustments;
drop policy if exists event_score_adjustments_owner_or_staff_read
  on public.event_score_adjustments;
create policy event_score_adjustments_owner_or_staff_read
on public.event_score_adjustments
for select
to authenticated
using (app_private.can_view_event(event_id));

create or replace function public.get_current_mosaic_access()
returns table (
  event_id uuid,
  event_title text,
  role text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    event.id as event_id,
    event.title as event_title,
    'owner'::text as role
  from public.events as event
  where event.owner_user_id = auth.uid()

  union

  select
    event.id as event_id,
    event.title as event_title,
    membership.role
  from public.event_staff_memberships as membership
  join public.events as event
    on event.id = membership.event_id
  join public.approved_logistics_identities as identity
    on identity.id = membership.approved_identity_id
  left join public.users as app_user
    on app_user.id = auth.uid()
  where membership.status = 'active'
    and identity.status = 'active'
    and event.owner_user_id <> auth.uid()
    and (
      membership.user_id = auth.uid()
      or (
        membership.user_id is null
        and app_user.id is not null
        and (
          (app_user.email is not null and identity.email_lower = lower(app_user.email))
          or (app_user.phone_e164 is not null and identity.phone_e164 = app_user.phone_e164)
        )
      )
    )
  order by event_title asc;
$$;

create or replace function public.list_event_staff_memberships(
  target_event_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  approved_identity_id uuid,
  user_id uuid,
  email text,
  phone_e164 text,
  display_name text,
  role text,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    membership.id,
    membership.event_id,
    membership.approved_identity_id,
    membership.user_id,
    identity.email,
    identity.phone_e164,
    identity.display_name,
    membership.role,
    membership.status,
    membership.created_at,
    membership.updated_at
  from public.event_staff_memberships as membership
  join public.approved_logistics_identities as identity
    on identity.id = membership.approved_identity_id
  where membership.event_id = target_event_id
    and app_private.can_manage_event(membership.event_id)
  order by identity.display_name asc, identity.email asc, identity.phone_e164 asc;
$$;

create or replace function public.upsert_event_staff_membership(
  target_event_id uuid,
  staff_email text,
  staff_phone_e164 text,
  staff_display_name text,
  staff_role text
)
returns table (
  id uuid,
  event_id uuid,
  approved_identity_id uuid,
  user_id uuid,
  email text,
  phone_e164 text,
  display_name text,
  role text,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text := lower(nullif(btrim(staff_email), ''));
  normalized_phone text := nullif(btrim(staff_phone_e164), '');
  normalized_display_name text := nullif(btrim(staff_display_name), '');
  identity_row public.approved_logistics_identities%rowtype;
  matched_user_id uuid;
  membership_id uuid;
begin
  perform app_private.require_owned_event(target_event_id);

  if normalized_email is null and normalized_phone is null then
    raise exception 'Staff email or phone is required.'
      using errcode = 'P0001';
  end if;

  if normalized_display_name is null then
    normalized_display_name := coalesce(staff_email, staff_phone_e164);
  end if;

  if staff_role not in ('qualification_scorer', 'event_scorer') then
    raise exception 'Unsupported staff role.'
      using errcode = 'P0001';
  end if;

  select *
  into identity_row
  from public.approved_logistics_identities as identity
  where (normalized_email is not null and identity.email_lower = normalized_email)
    or (normalized_phone is not null and identity.phone_e164 = normalized_phone)
  order by identity.updated_at desc
  limit 1
  for update;

  if found then
    update public.approved_logistics_identities as identity
    set
      email = coalesce(staff_email, identity.email),
      email_lower = coalesce(normalized_email, identity.email_lower),
      phone_e164 = coalesce(normalized_phone, identity.phone_e164),
      display_name = normalized_display_name,
      status = 'active'
    where identity.id = identity_row.id
    returning identity.*
    into identity_row;
  else
    insert into public.approved_logistics_identities (
      email,
      email_lower,
      phone_e164,
      display_name,
      status,
      approved_by_user_id
    )
    values (
      nullif(btrim(staff_email), ''),
      normalized_email,
      normalized_phone,
      normalized_display_name,
      'active',
      auth.uid()
    )
    returning *
    into identity_row;
  end if;

  select app_user.id
  into matched_user_id
  from public.users as app_user
  where (identity_row.email_lower is not null and lower(app_user.email) = identity_row.email_lower)
    or (identity_row.phone_e164 is not null and app_user.phone_e164 = identity_row.phone_e164)
  order by app_user.created_at asc
  limit 1;

  insert into public.event_staff_memberships (
    event_id,
    approved_identity_id,
    user_id,
    role,
    status,
    created_by_user_id
  )
  values (
    target_event_id,
    identity_row.id,
    matched_user_id,
    staff_role,
    'active',
    auth.uid()
  )
  on conflict on constraint event_staff_memberships_event_identity_unique do update
  set
    user_id = coalesce(excluded.user_id, public.event_staff_memberships.user_id),
    role = excluded.role,
    status = 'active',
    updated_at = now()
  returning public.event_staff_memberships.id
  into membership_id;

  return query
  select *
  from public.list_event_staff_memberships(target_event_id) as membership
  where membership.id = membership_id;
end;
$$;

create or replace function public.disable_event_staff_membership(
  target_membership_id uuid
)
returns table (
  id uuid,
  event_id uuid,
  approved_identity_id uuid,
  user_id uuid,
  email text,
  phone_e164 text,
  display_name text,
  role text,
  status text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  select membership.event_id
  into target_event_id
  from public.event_staff_memberships as membership
  where membership.id = target_membership_id
  for update;

  if target_event_id is null then
    raise exception 'Staff membership not found.'
      using errcode = 'P0001';
  end if;

  perform app_private.require_owned_event(target_event_id);

  update public.event_staff_memberships as membership
  set status = 'disabled'
  where membership.id = target_membership_id;

  return query
  select *
  from public.list_event_staff_memberships(target_event_id) as membership
  where membership.id = target_membership_id;
end;
$$;

grant select on public.approved_logistics_identities to authenticated;
grant select on public.event_staff_memberships to authenticated;

grant execute on function public.get_current_mosaic_access() to authenticated;
grant execute on function public.list_event_staff_memberships(uuid)
  to authenticated;
grant execute on function public.upsert_event_staff_membership(uuid, text, text, text, text) to authenticated;
grant execute on function public.disable_event_staff_membership(uuid)
  to authenticated;
