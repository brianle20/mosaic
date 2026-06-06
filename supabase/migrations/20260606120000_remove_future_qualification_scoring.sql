-- Remove qualification game tracking from future active workflows while
-- preserving legacy qualification rows for archived event history.

do $$
begin
  if exists (
    select 1
    from public.events as event
    join public.table_sessions as session
      on session.event_id = event.id
    where event.archived_at is null
      and session.scoring_phase = 'qualification'
  ) then
    raise exception 'Unarchived qualification sessions exist. Archive them or migrate them before removing qualification scoring.'
      using errcode = 'P0001';
  end if;
end;
$$;

alter table public.events
  alter column current_scoring_phase set default 'tournament';

alter table public.table_sessions
  alter column scoring_phase set default 'tournament';

update public.events as event
set
  current_scoring_phase = 'tournament',
  updated_at = now(),
  row_version = row_version + 1
where event.archived_at is null
  and event.current_scoring_phase = 'qualification';

update public.event_staff_memberships as membership
set
  role = 'event_scorer',
  updated_at = now()
from public.events as event
where event.id = membership.event_id
  and event.archived_at is null
  and membership.role = 'qualification_scorer';

create or replace function public.copy_event_for_testing(
  source_event_id uuid
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  source_event public.events%rowtype;
  copied_event public.events%rowtype;
  source_prize_plan public.prize_plans%rowtype;
  copied_prize_plan public.prize_plans%rowtype;
begin
  source_event := app_private.require_owned_event(source_event_id);

  insert into public.events (
    owner_user_id,
    title,
    description,
    venue_name,
    venue_address,
    timezone,
    starts_at,
    lifecycle_status,
    checkin_open,
    scoring_open,
    cover_charge_cents,
    default_ruleset_id,
    prevailing_wind,
    current_scoring_phase,
    seating_mode
  )
  values (
    source_event.owner_user_id,
    source_event.title || ' Copy',
    source_event.description,
    source_event.venue_name,
    source_event.venue_address,
    source_event.timezone,
    source_event.starts_at,
    'draft',
    false,
    false,
    source_event.cover_charge_cents,
    source_event.default_ruleset_id,
    source_event.prevailing_wind,
    'tournament',
    source_event.seating_mode
  )
  returning *
  into copied_event;

  insert into public.event_guests (
    event_id,
    guest_profile_id,
    display_name,
    normalized_name,
    public_display_name,
    phone_e164,
    email_lower,
    attendance_status,
    tournament_status,
    cover_status,
    cover_amount_cents,
    is_comped,
    has_scored_play,
    note,
    checked_in_at
  )
  select
    copied_event.id,
    guest.guest_profile_id,
    guest.display_name,
    guest.normalized_name,
    guest.public_display_name,
    guest.phone_e164,
    guest.email_lower,
    'expected',
    'open_play_only',
    guest.cover_status,
    guest.cover_amount_cents,
    guest.is_comped,
    false,
    guest.note,
    null
  from public.event_guests as guest
  where guest.event_id = source_event.id
  order by guest.created_at asc, guest.id asc;

  insert into public.event_tables (
    event_id,
    label,
    display_order,
    default_ruleset_id,
    default_rotation_policy_type,
    default_rotation_policy_config_json
  )
  select
    copied_event.id,
    event_table.label,
    event_table.display_order,
    event_table.default_ruleset_id,
    event_table.default_rotation_policy_type,
    event_table.default_rotation_policy_config_json
  from public.event_tables as event_table
  where event_table.event_id = source_event.id
  order by event_table.display_order asc, event_table.id asc;

  select *
  into source_prize_plan
  from public.prize_plans as prize_plan
  where prize_plan.event_id = source_event.id;

  if source_prize_plan.id is not null then
    insert into public.prize_plans (
      event_id,
      mode,
      status,
      reserve_fixed_cents,
      reserve_percentage_bps,
      note,
      created_by_user_id
    )
    values (
      copied_event.id,
      source_prize_plan.mode,
      'draft',
      source_prize_plan.reserve_fixed_cents,
      source_prize_plan.reserve_percentage_bps,
      source_prize_plan.note,
      auth.uid()
    )
    returning *
    into copied_prize_plan;

    insert into public.prize_tiers (
      prize_plan_id,
      place,
      label,
      percentage_bps,
      fixed_amount_cents
    )
    select
      copied_prize_plan.id,
      tier.place,
      tier.label,
      tier.percentage_bps,
      tier.fixed_amount_cents
    from public.prize_tiers as tier
    where tier.prize_plan_id = source_prize_plan.id
    order by tier.place asc, tier.id asc;
  end if;

  perform app_private.insert_audit_log(
    copied_event.id,
    'event',
    copied_event.id::text,
    'copy_for_testing',
    to_jsonb(source_event),
    to_jsonb(copied_event),
    jsonb_build_object('source_event_id', source_event.id)
  );

  return copied_event;
end;
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
