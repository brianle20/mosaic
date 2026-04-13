-- Mosaic MVP manual cover ledger
-- Checklist:
--   [x] add cover ledger record RPC
--   [x] add cover ledger list RPC
--   [x] validate method and amount
--   [x] keep cover_status host-authored
--   [x] audit guest_cover_entries writes

create or replace function public.record_cover_entry(
  target_event_guest_id uuid,
  target_amount_cents integer,
  target_method text,
  target_note text default null
)
returns public.guest_cover_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  inserted_entry public.guest_cover_entries%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);

  if target_amount_cents is null or target_amount_cents = 0 then
    raise exception 'Cover entry amount must be non-zero.'
      using errcode = 'P0001';
  end if;

  if target_method not in ('cash', 'venmo', 'zelle', 'other', 'comp', 'refund') then
    raise exception 'Unsupported cover entry method.'
      using errcode = 'P0001';
  end if;

  insert into public.guest_cover_entries (
    event_id,
    event_guest_id,
    amount_cents,
    method,
    recorded_by_user_id,
    recorded_at,
    note
  )
  values (
    guest_row.event_id,
    guest_row.id,
    target_amount_cents,
    target_method,
    auth.uid(),
    now(),
    nullif(trim(coalesce(target_note, '')), '')
  )
  returning *
  into inserted_entry;

  perform app_private.insert_audit_log(
    inserted_entry.event_id,
    'guest_cover_entry',
    inserted_entry.id::text,
    'record',
    null,
    to_jsonb(inserted_entry),
    jsonb_build_object(
      'event_guest_id', inserted_entry.event_guest_id,
      'amount_cents', inserted_entry.amount_cents,
      'method', inserted_entry.method
    )
  );

  return inserted_entry;
end;
$$;

create or replace function public.list_guest_cover_entries(
  target_event_guest_id uuid
)
returns setof public.guest_cover_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
begin
  guest_row := app_private.require_owned_guest(target_event_guest_id);

  return query
  select entry.*
  from public.guest_cover_entries as entry
  where entry.event_guest_id = guest_row.id
  order by entry.recorded_at desc, entry.created_at desc, entry.id desc;
end;
$$;
