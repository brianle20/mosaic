-- Preserve guest tournament intent when copying an event sandbox.

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
    guest.tournament_status,
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
