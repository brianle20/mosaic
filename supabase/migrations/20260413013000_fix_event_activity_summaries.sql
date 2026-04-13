-- Mosaic MVP event activity summary follow-up fixes
-- Checklist:
--   [x] align summary mapping with emitted table-tag audit action
--   [x] align prize-lock summary with emitted prize-plan audit action

create or replace function public.list_event_activity(
  target_event_id uuid,
  target_category text default 'all'
)
returns table (
  id uuid,
  event_id uuid,
  entity_type text,
  entity_id text,
  action text,
  category text,
  summary_text text,
  metadata_json jsonb,
  reason text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  with owned_event as (
    select app_private.require_owned_event(target_event_id) as event_row
  ),
  scoped_logs as (
    select
      log.id,
      log.event_id,
      log.entity_type,
      log.entity_id,
      log.action,
      case
        when log.entity_type in ('event_guest', 'event_guest_tag_assignment') then 'guests'
        when log.entity_type = 'guest_cover_entry' then 'payments'
        when log.entity_type in ('event_table', 'table_session', 'hand_result') then 'sessions'
        when log.entity_type in ('prize_plan', 'prize_award') then 'prizes'
        when log.entity_type = 'event' then 'event'
        else 'other'
      end as category,
      case
        when log.entity_type = 'guest_cover_entry' and log.action = 'record' then
          format(
            'Recorded cover entry: %s %s',
            coalesce(log.metadata_json ->> 'method', 'entry'),
            coalesce(log.metadata_json ->> 'amount_cents', '0')
          )
        when log.entity_type = 'event_guest' and log.action = 'check_in' then
          format(
            'Checked in %s',
            coalesce(log.after_json ->> 'display_name', log.entity_id)
          )
        when log.entity_type = 'event_guest' and log.action = 'create' then
          format(
            'Added guest %s',
            coalesce(log.after_json ->> 'display_name', log.entity_id)
          )
        when log.entity_type = 'event_guest' and log.action = 'update' then
          format(
            'Updated guest %s',
            coalesce(log.after_json ->> 'display_name', log.entity_id)
          )
        when log.entity_type = 'event_guest_tag_assignment' and log.action = 'assign' then
          'Assigned player tag'
        when log.entity_type = 'event_guest_tag_assignment' and log.action = 'replace' then
          'Replaced player tag'
        when log.entity_type = 'event_table' and log.action = 'create' then
          format(
            'Created table %s',
            coalesce(log.after_json ->> 'label', log.entity_id)
          )
        when log.entity_type = 'event_table' and log.action = 'bind_table_tag' then
          format(
            'Bound table tag for %s',
            coalesce(log.after_json ->> 'label', log.entity_id)
          )
        when log.entity_type = 'table_session' and log.action = 'start' then
          'Started session'
        when log.entity_type = 'table_session' and log.action = 'pause' then
          'Paused session'
        when log.entity_type = 'table_session' and log.action = 'resume' then
          'Resumed session'
        when log.entity_type = 'table_session' and log.action = 'end_early' then
          'Ended session early'
        when log.entity_type = 'hand_result' and log.action = 'record' then
          format(
            'Recorded hand %s',
            coalesce(log.after_json ->> 'hand_number', '?')
          )
        when log.entity_type = 'hand_result' and log.action = 'edit' then
          format(
            'Edited hand %s',
            coalesce(log.after_json ->> 'hand_number', '?')
          )
        when log.entity_type = 'hand_result' and log.action = 'void' then
          format(
            'Voided hand %s',
            coalesce(log.after_json ->> 'hand_number', '?')
          )
        when log.entity_type = 'prize_plan' and log.action = 'upsert' then
          'Updated prize plan'
        when log.entity_type = 'prize_plan' and log.action = 'lock' then
          'Locked prize awards'
        when log.entity_type = 'prize_award' and log.action = 'mark_paid' then
          'Marked prize award paid'
        when log.entity_type = 'prize_award' and log.action = 'void' then
          'Voided prize award'
        when log.entity_type = 'event' and log.action = 'start' then
          'Started event'
        when log.entity_type = 'event' and log.action = 'set_operational_flags' then
          'Updated live operations'
        when log.entity_type = 'event' and log.action = 'complete' then
          'Completed event'
        when log.entity_type = 'event' and log.action = 'finalize' then
          'Finalized event'
        else initcap(replace(log.entity_type, '_', ' ')) || ': ' || replace(log.action, '_', ' ')
      end as summary_text,
      log.metadata_json,
      log.reason,
      log.created_at
    from public.audit_logs as log
    cross join owned_event
    where log.event_id = (owned_event.event_row).id
  )
  select
    scoped_logs.id,
    scoped_logs.event_id,
    scoped_logs.entity_type,
    scoped_logs.entity_id,
    scoped_logs.action,
    scoped_logs.category,
    scoped_logs.summary_text,
    scoped_logs.metadata_json,
    scoped_logs.reason,
    scoped_logs.created_at
  from scoped_logs
  where target_category = 'all'
     or scoped_logs.category = target_category
  order by scoped_logs.created_at desc, scoped_logs.id desc;
$$;
