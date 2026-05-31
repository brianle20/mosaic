alter table public.events
  add column if not exists archived_at timestamptz;

create index if not exists events_unarchived_created_at_idx
  on public.events (created_at desc)
  where archived_at is null;
