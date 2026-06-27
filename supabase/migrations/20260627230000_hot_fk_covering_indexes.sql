-- Add covering indexes for live advisor-confirmed hot foreign keys.
--
-- Keep this pass additive. The current unused-index warnings are low-volume
-- or future-facing guardrails, so they are not dropped here.

create index if not exists event_score_totals_event_guest_idx
  on public.event_score_totals (event_guest_id);

create index if not exists table_session_seats_event_guest_idx
  on public.table_session_seats (event_guest_id);

create index if not exists table_sessions_tournament_round_event_idx
  on public.table_sessions (tournament_round_id, event_id);

create index if not exists event_seating_assignments_event_guest_event_idx
  on public.event_seating_assignments (event_guest_id, event_id);

create index if not exists event_seating_assignments_event_table_event_idx
  on public.event_seating_assignments (event_table_id, event_id);

create index if not exists event_seating_assignments_round_event_idx
  on public.event_seating_assignments (tournament_round_id, event_id);

create index if not exists event_guest_tag_assignments_event_guest_idx
  on public.event_guest_tag_assignments (event_guest_id);

create index if not exists event_guest_tag_assignments_nfc_tag_idx
  on public.event_guest_tag_assignments (nfc_tag_id);

create index if not exists event_tables_nfc_tag_idx
  on public.event_tables (nfc_tag_id);

create index if not exists prize_awards_event_guest_idx
  on public.prize_awards (event_guest_id);

create index if not exists rating_snapshots_table_session_idx
  on public.rating_snapshots (table_session_id);

create index if not exists event_staff_memberships_approved_identity_idx
  on public.event_staff_memberships (approved_identity_id);
