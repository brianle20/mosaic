-- Retire the legacy public_event_updates realtime path.
--
-- Public clients now subscribe directly to public_event_standings_snapshots.
-- Keep snapshot refreshes for guest display/status changes, but stop writing
-- duplicate public_event_updates rows.

drop trigger if exists public_event_updates_event_score_totals
  on public.event_score_totals;
drop trigger if exists public_event_updates_event_score_adjustments
  on public.event_score_adjustments;
drop trigger if exists public_event_updates_hand_results
  on public.hand_results;
drop trigger if exists public_event_updates_table_sessions
  on public.table_sessions;
drop trigger if exists public_event_updates_event_bonus_rounds
  on public.event_bonus_rounds;
drop trigger if exists public_event_updates_event_guests
  on public.event_guests;

create or replace function app_private.refresh_public_standings_snapshot_for_event_guest_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_event_id uuid;
begin
  target_event_id := case
    when tg_op = 'DELETE' then old.event_id
    else new.event_id
  end;

  if target_event_id is not null then
    perform app_private.refresh_public_event_standings_snapshot(target_event_id);
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists public_standings_snapshots_event_guests
  on public.event_guests;

create trigger public_standings_snapshots_event_guests
after insert or update or delete on public.event_guests
for each row execute function app_private.refresh_public_standings_snapshot_for_event_guest_change();

do $$
begin
  alter publication supabase_realtime drop table public.public_event_updates;
exception
  when undefined_object then null;
  when undefined_table then null;
end;
$$;

drop function if exists app_private.insert_public_event_update();

drop table if exists public.public_event_updates;

select pg_notify('pgrst', 'reload schema');
