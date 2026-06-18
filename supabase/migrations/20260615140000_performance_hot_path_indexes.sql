-- Add indexes for high-frequency event-day reads and score refresh joins.

create index if not exists hand_settlements_payee_guest_idx
  on public.hand_settlements (payee_event_guest_id);

create index if not exists hand_settlements_payer_guest_idx
  on public.hand_settlements (payer_event_guest_id);

create index if not exists table_sessions_event_started_idx
  on public.table_sessions (event_id, started_at desc);

create index if not exists event_tables_event_display_idx
  on public.event_tables (event_id, display_order, label);

create index if not exists event_guests_event_display_idx
  on public.event_guests (event_id, display_name);

create index if not exists guest_cover_entries_guest_date_idx
  on public.guest_cover_entries (event_guest_id, transaction_on desc, created_at desc, id desc);

create index if not exists events_owner_unarchived_created_idx
  on public.events (owner_user_id, created_at desc)
  where archived_at is null;

create index if not exists hand_results_session_hand_idx
  on public.hand_results (table_session_id, hand_number);
