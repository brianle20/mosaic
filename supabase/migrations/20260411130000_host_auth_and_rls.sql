-- Mosaic MVP host auth and row-level security
-- Checklist:
--   [x] mirror auth.users into public.users
--   [x] backfill existing auth users into public.users
--   [x] enable RLS on current and near-future event tables
--   [x] add owner-scoped policies keyed to auth.uid()

create or replace function app_private.default_display_name_from_email(
  source_email text
)
returns text
language sql
immutable
as $$
  select coalesce(nullif(split_part(source_email, '@', 1), ''), 'Host')
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
    display_name,
    status,
    created_at,
    updated_at
  )
  values (
    new.id,
    new.email,
    app_private.default_display_name_from_email(new.email),
    'active',
    coalesce(new.created_at, now()),
    now()
  )
  on conflict (id) do update
  set
    email = excluded.email,
    updated_at = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_or_updated on auth.users;

create trigger on_auth_user_created_or_updated
after insert or update of email
on auth.users
for each row
when (new.email is not null)
execute function app_private.handle_auth_user_sync();

insert into public.users (
  id,
  email,
  display_name,
  status,
  created_at,
  updated_at
)
select
  auth_user.id,
  auth_user.email,
  app_private.default_display_name_from_email(auth_user.email),
  'active',
  coalesce(auth_user.created_at, now()),
  now()
from auth.users as auth_user
where auth_user.email is not null
on conflict (id) do update
set
  email = excluded.email,
  updated_at = now();

create or replace function app_private.is_event_owner(target_event_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.events
    where id = target_event_id
      and owner_user_id = auth.uid()
  )
$$;

create or replace function app_private.is_session_owner(target_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.table_sessions as session
    join public.events as event
      on event.id = session.event_id
    where session.id = target_session_id
      and event.owner_user_id = auth.uid()
  )
$$;

create or replace function app_private.is_hand_result_owner(target_hand_result_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.hand_results as hand_result
    join public.table_sessions as session
      on session.id = hand_result.table_session_id
    join public.events as event
      on event.id = session.event_id
    where hand_result.id = target_hand_result_id
      and event.owner_user_id = auth.uid()
  )
$$;

alter table public.users enable row level security;
alter table public.events enable row level security;
alter table public.event_guests enable row level security;
alter table public.guest_cover_entries enable row level security;
alter table public.event_guest_tag_assignments enable row level security;
alter table public.event_tables enable row level security;
alter table public.table_sessions enable row level security;
alter table public.table_session_seats enable row level security;
alter table public.hand_results enable row level security;
alter table public.hand_settlements enable row level security;
alter table public.event_score_totals enable row level security;
alter table public.prize_plans enable row level security;
alter table public.prize_tiers enable row level security;
alter table public.prize_awards enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists users_select_own on public.users;
create policy users_select_own
on public.users
for select
to authenticated
using (id = auth.uid());

drop policy if exists users_update_own on public.users;
create policy users_update_own
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists events_select_own on public.events;
create policy events_select_own
on public.events
for select
to authenticated
using (owner_user_id = auth.uid());

drop policy if exists events_insert_own on public.events;
create policy events_insert_own
on public.events
for insert
to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists events_update_own on public.events;
create policy events_update_own
on public.events
for update
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists events_delete_own on public.events;
create policy events_delete_own
on public.events
for delete
to authenticated
using (owner_user_id = auth.uid());

drop policy if exists event_guests_owner_all on public.event_guests;
create policy event_guests_owner_all
on public.event_guests
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists guest_cover_entries_owner_all on public.guest_cover_entries;
create policy guest_cover_entries_owner_all
on public.guest_cover_entries
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists event_guest_tag_assignments_owner_all on public.event_guest_tag_assignments;
create policy event_guest_tag_assignments_owner_all
on public.event_guest_tag_assignments
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists event_tables_owner_all on public.event_tables;
create policy event_tables_owner_all
on public.event_tables
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists table_sessions_owner_all on public.table_sessions;
create policy table_sessions_owner_all
on public.table_sessions
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists table_session_seats_owner_all on public.table_session_seats;
create policy table_session_seats_owner_all
on public.table_session_seats
for all
to authenticated
using (app_private.is_session_owner(table_session_id))
with check (app_private.is_session_owner(table_session_id));

drop policy if exists hand_results_owner_all on public.hand_results;
create policy hand_results_owner_all
on public.hand_results
for all
to authenticated
using (app_private.is_session_owner(table_session_id))
with check (app_private.is_session_owner(table_session_id));

drop policy if exists hand_settlements_owner_all on public.hand_settlements;
create policy hand_settlements_owner_all
on public.hand_settlements
for all
to authenticated
using (app_private.is_hand_result_owner(hand_result_id))
with check (app_private.is_hand_result_owner(hand_result_id));

drop policy if exists event_score_totals_owner_all on public.event_score_totals;
create policy event_score_totals_owner_all
on public.event_score_totals
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists prize_plans_owner_all on public.prize_plans;
create policy prize_plans_owner_all
on public.prize_plans
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists prize_tiers_owner_all on public.prize_tiers;
create policy prize_tiers_owner_all
on public.prize_tiers
for all
to authenticated
using (
  exists (
    select 1
    from public.prize_plans as prize_plan
    join public.events as event
      on event.id = prize_plan.event_id
    where prize_plan.id = prize_tiers.prize_plan_id
      and event.owner_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.prize_plans as prize_plan
    join public.events as event
      on event.id = prize_plan.event_id
    where prize_plan.id = prize_tiers.prize_plan_id
      and event.owner_user_id = auth.uid()
  )
);

drop policy if exists prize_awards_owner_all on public.prize_awards;
create policy prize_awards_owner_all
on public.prize_awards
for all
to authenticated
using (app_private.is_event_owner(event_id))
with check (app_private.is_event_owner(event_id));

drop policy if exists audit_logs_owner_all on public.audit_logs;
create policy audit_logs_owner_all
on public.audit_logs
for all
to authenticated
using (
  event_id is null
  or app_private.is_event_owner(event_id)
)
with check (
  event_id is null
  or app_private.is_event_owner(event_id)
);
