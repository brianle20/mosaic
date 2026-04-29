-- Roll cover ledger entries into guest cover status.

update public.guest_cover_entries
set amount_cents = -abs(amount_cents)
where method = 'refund'
  and amount_cents > 0;

with ledger_totals as (
  select
    guest.id as event_guest_id,
    coalesce(sum(entry.amount_cents), 0) as paid_total_cents,
    bool_or(entry.method = 'comp') as has_comp_entry,
    bool_or(entry.method = 'refund') as has_refund_entry
  from public.event_guests as guest
  join public.guest_cover_entries as entry
    on entry.event_guest_id = guest.id
  group by guest.id
),
status_rollup as (
  select
    guest.id as event_guest_id,
    case
      when guest.is_comped or ledger.has_comp_entry then 'comped'
      when ledger.paid_total_cents < 0 then 'refunded'
      when ledger.paid_total_cents = 0 and ledger.has_refund_entry then 'refunded'
      when ledger.paid_total_cents = 0 then 'unpaid'
      when guest.cover_amount_cents = 0 then 'paid'
      when ledger.paid_total_cents >= guest.cover_amount_cents then 'paid'
      else 'partial'
    end as next_cover_status,
    guest.is_comped or ledger.has_comp_entry as next_is_comped
  from public.event_guests as guest
  join ledger_totals as ledger
    on ledger.event_guest_id = guest.id
)
update public.event_guests as guest
set
  cover_status = rollup.next_cover_status,
  is_comped = rollup.next_is_comped,
  updated_at = now(),
  row_version = guest.row_version + 1
from status_rollup as rollup
where rollup.event_guest_id = guest.id
  and (
    guest.cover_status is distinct from rollup.next_cover_status
    or guest.is_comped is distinct from rollup.next_is_comped
  );

drop function if exists public.record_cover_entry(uuid, integer, text, date, text);

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
  entry_amount_cents integer;
  paid_total_cents integer;
  has_comp_entry boolean;
  has_refund_entry boolean;
  next_cover_status text;
  next_is_comped boolean;
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

  entry_amount_cents := case
    when target_method = 'refund' then -abs(target_amount_cents)
    else target_amount_cents
  end;

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
    entry_amount_cents,
    target_method,
    auth.uid(),
    target_transaction_on,
    nullif(trim(coalesce(target_note, '')), '')
  )
  returning *
  into inserted_entry;

  select
    coalesce(sum(entry.amount_cents), 0),
    coalesce(bool_or(entry.method = 'comp'), false),
    coalesce(bool_or(entry.method = 'refund'), false)
  into paid_total_cents, has_comp_entry, has_refund_entry
  from public.guest_cover_entries as entry
  where entry.event_guest_id = guest_row.id;

  next_is_comped := has_comp_entry;
  next_cover_status := case
    when next_is_comped then 'comped'
    when paid_total_cents < 0 then 'refunded'
    when paid_total_cents = 0 and has_refund_entry then 'refunded'
    when paid_total_cents = 0 then 'unpaid'
    when guest_row.cover_amount_cents = 0 then 'paid'
    when paid_total_cents >= guest_row.cover_amount_cents then 'paid'
    else 'partial'
  end;

  update public.event_guests
  set
    cover_status = next_cover_status,
    is_comped = next_is_comped,
    updated_at = now(),
    row_version = row_version + 1
  where id = guest_row.id;

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
      'transaction_on', inserted_entry.transaction_on,
      'cover_status', next_cover_status
    )
  );

  return inserted_entry;
end;
$$;

select pg_notify('pgrst', 'reload schema');
