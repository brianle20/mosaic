create or replace function public.resolve_guest_by_active_tag(
  target_event_id uuid,
  scanned_uid text
)
returns table (
  guest jsonb,
  assignment jsonb
)
language plpgsql
security definer
set search_path = public, app_private
as $$
declare
  normalized_uid text;
begin
  if not app_private.can_view_event(target_event_id) then
    raise exception 'You do not have permission to view this event.'
      using errcode = '42501';
  end if;

  normalized_uid := app_private.normalize_tag_uid(scanned_uid);

  if normalized_uid = '' then
    return;
  end if;

  return query
  select
    (
      to_jsonb(event_guest_row.*)
      || jsonb_build_object(
        'guest_profile',
        case
          when guest_profile_row.id is null then null
          else to_jsonb(guest_profile_row.*)
        end
      )
    ) as guest,
    jsonb_build_object(
      'assignment_id', assignment_row.id,
      'event_id', assignment_row.event_id,
      'event_guest_id', assignment_row.event_guest_id,
      'nfc_tag_id', assignment_row.nfc_tag_id,
      'status', assignment_row.status,
      'assigned_at', assignment_row.assigned_at,
      'nfc_tag', jsonb_build_object(
        'id', tag_row.id,
        'uid_hex', tag_row.uid_hex,
        'uid_fingerprint', tag_row.uid_fingerprint,
        'default_tag_type', tag_row.default_tag_type,
        'status', tag_row.status,
        'display_label', tag_row.display_label,
        'note', tag_row.note,
        'created_at', tag_row.created_at,
        'updated_at', tag_row.updated_at
      )
    ) as assignment
  from public.event_guest_tag_assignments as assignment_row
  join public.nfc_tags as tag_row
    on tag_row.id = assignment_row.nfc_tag_id
  join public.event_guests as event_guest_row
    on event_guest_row.id = assignment_row.event_guest_id
  left join public.guest_profiles as guest_profile_row
    on guest_profile_row.id = event_guest_row.guest_profile_id
  where assignment_row.event_id = target_event_id
    and assignment_row.status = 'assigned'
    and tag_row.uid_hex = normalized_uid
  order by assignment_row.assigned_at desc;
end;
$$;

grant execute on function public.resolve_guest_by_active_tag(uuid, text)
  to authenticated;
