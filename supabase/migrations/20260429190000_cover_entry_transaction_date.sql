-- Cover ledger transaction dates

alter table public.guest_cover_entries
  add column if not exists transaction_on date;

update public.guest_cover_entries
set transaction_on = coalesce(
  transaction_on,
  recorded_at::date,
  created_at::date
)
where transaction_on is null;

alter table public.guest_cover_entries
  alter column transaction_on set not null;

alter table public.guest_cover_entries
  drop column if exists recorded_at;

drop function if exists public.record_cover_entry(uuid, integer, text, text);

create or replace function public.record_cover_entry(
  target_event_guest_id uuid,
  target_amount_cents integer,
  target_method text,
  target_transaction_on date,
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

  if target_transaction_on is null then
    raise exception 'Cover entry date is required.'
      using errcode = 'P0001';
  end if;

  insert into public.guest_cover_entries (
    event_id,
    event_guest_id,
    amount_cents,
    method,
    recorded_by_user_id,
    transaction_on,
    note
  )
  values (
    guest_row.event_id,
    guest_row.id,
    target_amount_cents,
    target_method,
    auth.uid(),
    target_transaction_on,
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
      'method', inserted_entry.method,
      'transaction_on', inserted_entry.transaction_on
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
  order by entry.transaction_on desc, entry.created_at desc, entry.id desc;
end;
$$;

select pg_notify('pgrst', 'reload schema');
