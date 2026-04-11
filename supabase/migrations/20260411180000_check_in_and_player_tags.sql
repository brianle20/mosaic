-- Mosaic MVP check-in and player tag assignment
-- Checklist:
--   [x] enable RLS on nfc_tags
--   [x] add owner-safe tag policies for authenticated host
--   [x] add guest check-in RPC
--   [x] add player tag registration helper
--   [x] add assign/replace player tag RPCs
--   [x] add active assignment summary RPC
--   [x] audit check-in and tag operations

alter table public.nfc_tags enable row level security;

drop policy if exists nfc_tags_authenticated_all on public.nfc_tags;
create policy nfc_tags_authenticated_all
on public.nfc_tags
for all
to authenticated
using (true)
with check (true);

create or replace function app_private.insert_audit_log(
  target_event_id uuid,
  target_entity_type text,
  target_entity_id text,
  target_action text,
  target_before jsonb default null,
  target_after jsonb default null,
  target_metadata jsonb default '{}'::jsonb,
  target_reason text default null
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.audit_logs (
    event_id,
    actor_user_id,
    entity_type,
    entity_id,
    action,
    before_json,
    after_json,
    metadata_json,
    reason
  )
  values (
    target_event_id,
    auth.uid(),
    target_entity_type,
    target_entity_id,
    target_action,
    target_before,
    target_after,
    coalesce(target_metadata, '{}'::jsonb),
    target_reason
  );
$$;

create or replace function app_private.normalize_tag_uid(source_uid text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(coalesce(source_uid, ''), '[^0-9A-Za-z]+', '', 'g'))
$$;

create or replace function app_private.require_owned_guest(target_event_guest_id uuid)
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
  join public.events as event
    on event.id = guest.event_id
  where guest.id = target_event_guest_id
    and event.owner_user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Guest not found for current host.'
      using errcode = 'P0001';
  end if;

  return guest_row;
end;
$$;

create or replace function app_private.ensure_player_tag(
  scanned_uid text,
  scanned_display_label text default null
)
returns public.nfc_tags
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_uid text;
  tag_row public.nfc_tags%rowtype;
begin
  normalized_uid := app_private.normalize_tag_uid(scanned_uid);

  if normalized_uid = '' then
    raise exception 'Tag UID is required.'
      using errcode = 'P0001';
  end if;

  select *
  into tag_row
  from public.nfc_tags
  where uid_hex = normalized_uid
  for update;

  if not found then
    insert into public.nfc_tags (
      uid_hex,
      uid_fingerprint,
      default_tag_type,
      display_label,
      status,
      first_seen_at,
      last_seen_at
    )
    values (
      normalized_uid,
      normalized_uid,
      'player',
      scanned_display_label,
      'active',
      now(),
      now()
    )
    returning *
    into tag_row;

    return tag_row;
  end if;

  if tag_row.default_tag_type = 'table' then
    raise exception 'Only player tags can be assigned to guests.'
      using errcode = 'P0001';
  end if;

  update public.nfc_tags
  set
    default_tag_type = 'player',
    display_label = coalesce(scanned_display_label, display_label),
    last_seen_at = now(),
    updated_at = now()
  where id = tag_row.id
  returning *
  into tag_row;

  return tag_row;
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
  guest_row := app_private.require_owned_guest(target_event_guest_id);

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

create or replace function public.register_nfc_tag(
  scanned_uid text,
  requested_tag_type text,
  scanned_display_label text default null
)
returns public.nfc_tags
language plpgsql
security definer
set search_path = public
as $$
declare
  tag_row public.nfc_tags%rowtype;
  normalized_uid text;
begin
  if requested_tag_type <> 'player' then
    raise exception 'Only player tag registration is supported in this slice.'
      using errcode = 'P0001';
  end if;

  normalized_uid := app_private.normalize_tag_uid(scanned_uid);
  tag_row := app_private.ensure_player_tag(normalized_uid, scanned_display_label);

  perform app_private.insert_audit_log(
    null,
    'nfc_tag',
    tag_row.id::text,
    'register',
    null,
    to_jsonb(tag_row),
    jsonb_build_object('requested_tag_type', requested_tag_type)
  );

  return tag_row;
end;
$$;

create or replace function public.get_guest_tag_assignment_summary(
  target_event_guest_id uuid
)
returns table (
  assignment_id uuid,
  event_id uuid,
  event_guest_id uuid,
  status text,
  assigned_at timestamptz,
  nfc_tag jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    assignment.id as assignment_id,
    assignment.event_id,
    assignment.event_guest_id,
    assignment.status,
    assignment.assigned_at,
    jsonb_build_object(
      'id', tag.id,
      'uid_hex', tag.uid_hex,
      'uid_fingerprint', tag.uid_fingerprint,
      'default_tag_type', tag.default_tag_type,
      'status', tag.status,
      'display_label', tag.display_label,
      'note', tag.note
    ) as nfc_tag
  from public.event_guest_tag_assignments as assignment
  join public.events as event
    on event.id = assignment.event_id
  join public.nfc_tags as tag
    on tag.id = assignment.nfc_tag_id
  where assignment.event_guest_id = target_event_guest_id
    and assignment.status = 'assigned'
    and event.owner_user_id = auth.uid()
  order by assignment.assigned_at desc
  limit 1
$$;

create or replace function public.assign_guest_tag(
  target_event_guest_id uuid,
  scanned_uid text,
  scanned_display_label text default null
)
returns table (
  assignment_id uuid,
  event_id uuid,
  event_guest_id uuid,
  status text,
  assigned_at timestamptz,
  nfc_tag jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  tag_row public.nfc_tags%rowtype;
  existing_assignment_id uuid;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);

  if guest_row.cover_status not in ('paid', 'comped') then
    raise exception 'Guest must be paid or comped before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  if guest_row.attendance_status <> 'checked_in' then
    raise exception 'Guest must be checked in before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  select assignment.id
  into existing_assignment_id
  from public.event_guest_tag_assignments as assignment
  where assignment.event_guest_id = guest_row.id
    and assignment.event_id = guest_row.event_id
    and assignment.status = 'assigned'
  limit 1;

  if existing_assignment_id is not null then
    raise exception 'This guest already has an active player tag.'
      using errcode = 'P0001';
  end if;

  tag_row := app_private.ensure_player_tag(scanned_uid, scanned_display_label);

  if exists (
    select 1
    from public.event_guest_tag_assignments as assignment
    where assignment.event_id = guest_row.event_id
      and assignment.nfc_tag_id = tag_row.id
      and assignment.status = 'assigned'
  ) then
    raise exception 'This tag is already assigned to another guest in this event.'
      using errcode = 'P0001';
  end if;

  insert into public.event_guest_tag_assignments (
    event_id,
    event_guest_id,
    nfc_tag_id,
    status,
    assigned_at,
    assigned_by_user_id
  )
  values (
    guest_row.event_id,
    guest_row.id,
    tag_row.id,
    'assigned',
    now(),
    auth.uid()
  );

  perform app_private.insert_audit_log(
    guest_row.event_id,
    'event_guest_tag_assignment',
    guest_row.id::text,
    'assign',
    null,
    jsonb_build_object(
      'event_guest_id', guest_row.id,
      'nfc_tag_id', tag_row.id,
      'uid_hex', tag_row.uid_hex
    )
  );

  return query
  select *
  from public.get_guest_tag_assignment_summary(guest_row.id);
end;
$$;

create or replace function public.replace_guest_tag(
  target_event_guest_id uuid,
  scanned_uid text,
  scanned_display_label text default null
)
returns table (
  assignment_id uuid,
  event_id uuid,
  event_guest_id uuid,
  status text,
  assigned_at timestamptz,
  nfc_tag jsonb
)
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  current_assignment public.event_guest_tag_assignments%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);

  if guest_row.cover_status not in ('paid', 'comped') then
    raise exception 'Guest must be paid or comped before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  if guest_row.attendance_status <> 'checked_in' then
    raise exception 'Guest must be checked in before receiving a player tag.'
      using errcode = 'P0001';
  end if;

  select *
  into current_assignment
  from public.event_guest_tag_assignments
  where event_guest_id = guest_row.id
    and event_id = guest_row.event_id
    and status = 'assigned'
  for update;

  if not found then
    raise exception 'Guest does not have an active tag to replace.'
      using errcode = 'P0001';
  end if;

  update public.event_guest_tag_assignments
  set
    status = 'replaced',
    released_at = now(),
    release_reason = 'replacement'
  where id = current_assignment.id;

  perform app_private.insert_audit_log(
    guest_row.event_id,
    'event_guest_tag_assignment',
    guest_row.id::text,
    'replace',
    to_jsonb(current_assignment),
    jsonb_build_object(
      'previous_assignment_id', current_assignment.id,
      'replacement_reason', 'replacement'
    )
  );

  return query
  select *
  from public.assign_guest_tag(
    guest_row.id,
    scanned_uid,
    scanned_display_label
  );
end;
$$;
