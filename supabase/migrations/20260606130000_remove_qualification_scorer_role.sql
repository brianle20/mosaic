-- Remove the qualification-only staff role now that qualification game
-- tracking has been deprecated. Existing memberships are promoted to the
-- single event scorer role before tightening the role constraint.

update public.event_staff_memberships
set
  role = 'event_scorer',
  updated_at = now()
where role = 'qualification_scorer';

alter table public.event_staff_memberships
  drop constraint if exists event_staff_memberships_role_check;

alter table public.event_staff_memberships
  add constraint event_staff_memberships_role_check
    check (role = 'event_scorer');

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
  select app_private.can_score_tournament(target_event_id, target_user_id)
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
    and app_private.can_score_tournament(event.id);

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
  if target_scoring_phase in ('qualification', 'tournament') then
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
          then app_private.can_score_tournament(session.event_id, target_user_id)
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

  select coalesce(event.current_scoring_phase, 'tournament')
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
      or app_private.can_score_tournament(guest.event_id)
    )
  for update;

  if not found then
    raise exception 'Guest not found for current check-in operator.'
      using errcode = 'P0001';
  end if;

  return guest_row;
end;
$$;

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
    case membership.role
      when 'qualification_scorer' then 'event_scorer'
      else membership.role
    end as role
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

  if staff_role <> 'event_scorer' then
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
