-- Add host-scoped guest profiles so repeat players can be reused across events.

create table if not exists public.guest_profiles (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete cascade,
  display_name text not null,
  normalized_name text not null,
  phone_e164 text,
  email_lower text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

alter table public.event_guests
add column if not exists guest_profile_id uuid;

create index if not exists guest_profiles_owner_name_idx
  on public.guest_profiles (owner_user_id, normalized_name);

create unique index if not exists guest_profiles_owner_phone_unique
  on public.guest_profiles (owner_user_id, phone_e164)
  where phone_e164 is not null;

create unique index if not exists guest_profiles_owner_email_unique
  on public.guest_profiles (owner_user_id, email_lower)
  where email_lower is not null;

insert into public.guest_profiles (
  owner_user_id,
  display_name,
  normalized_name,
  phone_e164,
  email_lower,
  created_at,
  updated_at,
  row_version
)
select distinct on (event.owner_user_id, guest.phone_e164)
  event.owner_user_id,
  guest.display_name,
  guest.normalized_name,
  guest.phone_e164,
  guest.email_lower,
  guest.created_at,
  guest.updated_at,
  guest.row_version
from public.event_guests as guest
join public.events as event
  on event.id = guest.event_id
where guest.phone_e164 is not null
order by event.owner_user_id, guest.phone_e164, guest.created_at, guest.id;

update public.event_guests as guest
set guest_profile_id = profile.id
from public.events as event
join public.guest_profiles as profile
  on profile.owner_user_id = event.owner_user_id
where event.id = guest.event_id
  and guest.guest_profile_id is null
  and guest.phone_e164 is not null
  and profile.phone_e164 = guest.phone_e164;

insert into public.guest_profiles (
  owner_user_id,
  display_name,
  normalized_name,
  phone_e164,
  email_lower,
  created_at,
  updated_at,
  row_version
)
select distinct on (event.owner_user_id, guest.email_lower)
  event.owner_user_id,
  guest.display_name,
  guest.normalized_name,
  guest.phone_e164,
  guest.email_lower,
  guest.created_at,
  guest.updated_at,
  guest.row_version
from public.event_guests as guest
join public.events as event
  on event.id = guest.event_id
where guest.guest_profile_id is null
  and guest.email_lower is not null
  and not exists (
    select 1
    from public.guest_profiles as existing_profile
    where existing_profile.owner_user_id = event.owner_user_id
      and existing_profile.email_lower = guest.email_lower
  )
order by event.owner_user_id, guest.email_lower, guest.created_at, guest.id;

update public.event_guests as guest
set guest_profile_id = profile.id
from public.events as event
join public.guest_profiles as profile
  on profile.owner_user_id = event.owner_user_id
where event.id = guest.event_id
  and guest.guest_profile_id is null
  and guest.email_lower is not null
  and profile.email_lower = guest.email_lower;

update public.event_guests as guest
set guest_profile_id = profile.id
from public.events as event
join public.guest_profiles as profile
  on profile.owner_user_id = event.owner_user_id
where event.id = guest.event_id
  and guest.guest_profile_id is null
  and guest.normalized_name = 'brian le'
  and profile.normalized_name = 'brian le';

insert into public.guest_profiles (
  owner_user_id,
  display_name,
  normalized_name,
  phone_e164,
  email_lower,
  created_at,
  updated_at,
  row_version
)
select distinct on (event.owner_user_id)
  event.owner_user_id,
  guest.display_name,
  guest.normalized_name,
  guest.phone_e164,
  guest.email_lower,
  guest.created_at,
  guest.updated_at,
  guest.row_version
from public.event_guests as guest
join public.events as event
  on event.id = guest.event_id
where guest.guest_profile_id is null
  and guest.normalized_name = 'brian le'
  and not exists (
    select 1
    from public.guest_profiles as existing_profile
    where existing_profile.owner_user_id = event.owner_user_id
      and existing_profile.normalized_name = 'brian le'
  )
order by event.owner_user_id, guest.created_at, guest.id;

update public.event_guests as guest
set guest_profile_id = profile.id
from public.events as event
join public.guest_profiles as profile
  on profile.owner_user_id = event.owner_user_id
where event.id = guest.event_id
  and guest.guest_profile_id is null
  and guest.normalized_name = 'brian le'
  and profile.normalized_name = 'brian le';

insert into public.guest_profiles (
  id,
  owner_user_id,
  display_name,
  normalized_name,
  phone_e164,
  email_lower,
  created_at,
  updated_at,
  row_version
)
select
  guest.id,
  event.owner_user_id,
  guest.display_name,
  guest.normalized_name,
  guest.phone_e164,
  guest.email_lower,
  guest.created_at,
  guest.updated_at,
  guest.row_version
from public.event_guests as guest
join public.events as event
  on event.id = guest.event_id
where guest.guest_profile_id is null;

update public.event_guests as guest
set guest_profile_id = profile.id
from public.guest_profiles as profile
where guest.guest_profile_id is null
  and profile.id = guest.id;

alter table public.event_guests
alter column guest_profile_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'event_guests_guest_profile_id_fkey'
      and conrelid = 'public.event_guests'::regclass
  ) then
    alter table public.event_guests
    add constraint event_guests_guest_profile_id_fkey
    foreign key (guest_profile_id)
    references public.guest_profiles(id)
    on delete restrict;
  end if;
end;
$$;

create unique index if not exists event_guests_event_profile_unique
  on public.event_guests (event_id, guest_profile_id);

create index if not exists event_guests_profile_idx
  on public.event_guests (guest_profile_id);

drop trigger if exists guest_profiles_touch_updated_at_and_row_version
on public.guest_profiles;
create trigger guest_profiles_touch_updated_at_and_row_version
before update on public.guest_profiles
for each row execute function app_private.touch_updated_at_and_row_version();

create or replace function app_private.is_guest_profile_owner(
  target_guest_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.guest_profiles
    where id = target_guest_profile_id
      and owner_user_id = auth.uid()
  )
$$;

alter table public.guest_profiles enable row level security;

drop policy if exists guest_profiles_owner_all on public.guest_profiles;
create policy guest_profiles_owner_all
on public.guest_profiles
for all
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists event_guests_owner_all on public.event_guests;
create policy event_guests_owner_all
on public.event_guests
for all
to authenticated
using (
  app_private.is_event_owner(event_id)
  and app_private.is_guest_profile_owner(guest_profile_id)
)
with check (
  app_private.is_event_owner(event_id)
  and app_private.is_guest_profile_owner(guest_profile_id)
);
