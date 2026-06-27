create or replace function app_private.refresh_event_guest_cover_status(
  target_event_guest_id uuid
)
returns public.event_guests
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  refreshed_guest public.event_guests%rowtype;
  paid_total_cents integer;
  has_comp_entry boolean;
  has_refund_entry boolean;
  next_cover_status text;
  next_is_comped boolean;
begin
  select *
  into guest_row
  from public.event_guests
  where id = target_event_guest_id
  for update;

  if not found then
    raise exception 'Guest not found: %', target_event_guest_id
      using errcode = 'P0001';
  end if;

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
  where id = guest_row.id
    and (
      cover_status is distinct from next_cover_status
      or is_comped is distinct from next_is_comped
    )
  returning *
  into refreshed_guest;

  if not found then
    select *
    into refreshed_guest
    from public.event_guests
    where id = guest_row.id;
  end if;

  return refreshed_guest;
end;
$$;

do $$
declare
  guest_row record;
begin
  for guest_row in
    select distinct event_guest_id as id
    from public.guest_cover_entries
  loop
    perform app_private.refresh_event_guest_cover_status(guest_row.id);
  end loop;
end $$;

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
  refreshed_guest public.event_guests%rowtype;
  entry_amount_cents integer;
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

  refreshed_guest := app_private.refresh_event_guest_cover_status(guest_row.id);

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
      'cover_status', refreshed_guest.cover_status
    )
  );

  return inserted_entry;
end;
$$;

create or replace function public.update_cover_entry(
  target_cover_entry_id uuid,
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
  original_entry public.guest_cover_entries%rowtype;
  updated_entry public.guest_cover_entries%rowtype;
  refreshed_guest public.event_guests%rowtype;
  entry_amount_cents integer;
begin
  select *
  into original_entry
  from public.guest_cover_entries
  where id = target_cover_entry_id;

  if not found then
    raise exception 'Cover entry not found.'
      using errcode = 'P0001';
  end if;

  guest_row := app_private.require_owned_guest(original_entry.event_guest_id);

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

  update public.guest_cover_entries
  set
    amount_cents = entry_amount_cents,
    method = target_method,
    transaction_on = target_transaction_on,
    note = nullif(trim(coalesce(target_note, '')), '')
  where id = original_entry.id
  returning *
  into updated_entry;

  refreshed_guest := app_private.refresh_event_guest_cover_status(guest_row.id);

  perform app_private.insert_audit_log(
    updated_entry.event_id,
    'guest_cover_entry',
    updated_entry.id::text,
    'update',
    to_jsonb(original_entry),
    to_jsonb(updated_entry),
    jsonb_build_object(
      'event_guest_id', updated_entry.event_guest_id,
      'amount_cents', updated_entry.amount_cents,
      'method', updated_entry.method,
      'transaction_on', updated_entry.transaction_on,
      'cover_status', refreshed_guest.cover_status
    )
  );

  return updated_entry;
end;
$$;

create or replace function public.delete_cover_entry(
  target_cover_entry_id uuid
)
returns public.guest_cover_entries
language plpgsql
security definer
set search_path = public
as $$
declare
  guest_row public.event_guests%rowtype;
  original_entry public.guest_cover_entries%rowtype;
  deleted_entry public.guest_cover_entries%rowtype;
  refreshed_guest public.event_guests%rowtype;
begin
  select *
  into original_entry
  from public.guest_cover_entries
  where id = target_cover_entry_id;

  if not found then
    raise exception 'Cover entry not found.'
      using errcode = 'P0001';
  end if;

  guest_row := app_private.require_owned_guest(original_entry.event_guest_id);

  delete from public.guest_cover_entries
  where id = original_entry.id
  returning *
  into deleted_entry;

  refreshed_guest := app_private.refresh_event_guest_cover_status(guest_row.id);

  perform app_private.insert_audit_log(
    deleted_entry.event_id,
    'guest_cover_entry',
    deleted_entry.id::text,
    'delete',
    to_jsonb(deleted_entry),
    null,
    jsonb_build_object(
      'event_guest_id', deleted_entry.event_guest_id,
      'amount_cents', deleted_entry.amount_cents,
      'method', deleted_entry.method,
      'transaction_on', deleted_entry.transaction_on,
      'cover_status', refreshed_guest.cover_status
    )
  );

  return deleted_entry;
end;
$$;

select pg_notify('pgrst', 'reload schema');
