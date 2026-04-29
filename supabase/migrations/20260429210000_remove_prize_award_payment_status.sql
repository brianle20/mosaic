-- Remove prize award payment tracking; locked awards are final prize results.

drop function if exists public.mark_prize_award_paid(uuid, text, text);
drop function if exists public.void_prize_award(uuid, text);
drop function if exists app_private.require_owned_prize_award(uuid);

alter table public.prize_awards
  drop column if exists status,
  drop column if exists paid_method,
  drop column if exists paid_at,
  drop column if exists paid_note;

create or replace function public.lock_prize_awards(
  target_event_id uuid
)
returns setof public.prize_awards
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  existing_plan public.prize_plans%rowtype;
  locked_plan public.prize_plans%rowtype;
begin
  event_row := app_private.require_event_for_prize_configuration(target_event_id);

  select plan.*
  into existing_plan
  from public.prize_plans as plan
  where plan.event_id = target_event_id
  for update;

  if not found then
    raise exception 'Prize plan not found for this event.'
      using errcode = 'P0001';
  end if;

  if existing_plan.status = 'locked' then
    return query
    select award.*
    from public.prize_awards as award
    where award.event_id = target_event_id
    order by award.rank_start, award.display_rank, award.event_guest_id;
    return;
  end if;

  delete from public.prize_awards
  where event_id = target_event_id;

  insert into public.prize_awards (
    event_id,
    event_guest_id,
    rank_start,
    rank_end,
    display_rank,
    award_amount_cents
  )
  select
    target_event_id,
    preview.event_guest_id,
    preview.rank_start,
    preview.rank_end,
    preview.display_rank,
    preview.award_amount_cents
  from public.preview_prize_awards(target_event_id) as preview;

  update public.prize_plans
  set status = 'locked'
  where id = existing_plan.id
  returning *
  into locked_plan;

  perform app_private.insert_audit_log(
    event_row.id,
    'prize_plan',
    locked_plan.id::text,
    'lock',
    to_jsonb(existing_plan),
    to_jsonb(locked_plan)
  );

  return query
  select award.*
  from public.prize_awards as award
  where award.event_id = target_event_id
  order by award.rank_start, award.display_rank, award.event_guest_id;
end;
$$;

select pg_notify('pgrst', 'reload schema');
