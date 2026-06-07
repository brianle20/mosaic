-- Block future player-tag-based table starts while preserving the legacy
-- implementation behind an internal-only wrapper for archived history.

alter function public.start_table_session(uuid, text, text, text, text, text)
  rename to start_table_session_legacy_player_tags;

revoke all on function public.start_table_session_legacy_player_tags(
  uuid,
  text,
  text,
  text,
  text,
  text
) from authenticated;

revoke all on function public.start_table_session_legacy_player_tags(
  uuid,
  text,
  text,
  text,
  text,
  text
) from public;

revoke all on function public.start_table_session_legacy_player_tags(
  uuid,
  text,
  text,
  text,
  text,
  text
) from anon;

create or replace function public.start_table_session(
  target_event_table_id uuid,
  scanned_table_uid text,
  east_player_uid text,
  south_player_uid text,
  west_player_uid text,
  north_player_uid text
)
returns public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  table_row public.event_tables%rowtype;
  event_row public.events%rowtype;
begin
  table_row := app_private.require_table_for_scoring(target_event_table_id);

  select event.*
  into event_row
  from public.events as event
  where event.id = table_row.event_id;

  if event_row.archived_at is null then
    raise exception 'Player tag session start is no longer available. Use assigned seating.'
      using errcode = 'P0001';
  end if;

  return public.start_table_session_legacy_player_tags(
    target_event_table_id,
    scanned_table_uid,
    east_player_uid,
    south_player_uid,
    west_player_uid,
    north_player_uid
  );
end;
$$;

revoke all on function public.start_table_session(
  uuid,
  text,
  text,
  text,
  text,
  text
) from public;

revoke all on function public.start_table_session(
  uuid,
  text,
  text,
  text,
  text,
  text
) from anon;

grant execute on function public.start_table_session(
  uuid,
  text,
  text,
  text,
  text,
  text
) to authenticated;

select pg_notify('pgrst', 'reload schema');
