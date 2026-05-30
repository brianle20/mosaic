-- Qualify id references inside staff mutation RPCs.
--
-- These functions return TABLE(id ...), so unqualified `id` in PL/pgSQL
-- can bind ambiguously to either an output variable or a table column.

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
      unique using index event_staff_memberships_event_identity_unique;
  end if;
end $$;

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

grant execute on function public.upsert_event_staff_membership(uuid, text, text, text, text)
  to authenticated;
grant execute on function public.disable_event_staff_membership(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
