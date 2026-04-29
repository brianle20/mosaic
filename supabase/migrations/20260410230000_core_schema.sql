-- Mosaic MVP Phase 1 core schema
-- Checklist:
--   [x] users
--   [x] events
--   [x] event_guests
--   [x] guest_cover_entries
--   [x] rulesets
--   [x] nfc_tags
--   [x] event_guest_tag_assignments
--   [x] event_tables
--   [x] table_sessions
--   [x] table_session_seats
--   [x] hand_results
--   [x] hand_settlements
--   [x] event_score_totals
--   [x] prize_plans
--   [x] prize_tiers
--   [x] prize_awards
--   [x] audit_logs
--   [x] HK_STANDARD_V1 seed

create extension if not exists pgcrypto with schema extensions;

create schema if not exists app_private;

create or replace function app_private.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function app_private.touch_updated_at_and_row_version()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.row_version = old.row_version + 1;
  return new;
end;
$$;

create table public.users (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  phone_e164 text,
  display_name text not null,
  status text not null default 'active'
    check (status in ('active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.rulesets (
  id text primary key,
  name text not null,
  version integer not null check (version > 0),
  status text not null check (status in ('active', 'retired')),
  definition_json jsonb not null,
  created_at timestamptz not null default now()
);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text,
  venue_name text,
  venue_address text,
  timezone text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  lifecycle_status text not null
    check (lifecycle_status in ('draft', 'active', 'completed', 'finalized', 'cancelled')),
  checkin_open boolean not null default false,
  scoring_open boolean not null default false,
  cover_charge_cents integer not null default 0 check (cover_charge_cents >= 0),
  default_ruleset_id text not null default 'HK_STANDARD_V1'
    references public.rulesets(id),
  prevailing_wind text not null default 'east'
    check (prevailing_wind in ('east', 'south', 'west', 'north')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create table public.event_guests (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  display_name text not null,
  normalized_name text not null,
  phone_e164 text,
  email_lower text,
  attendance_status text not null default 'expected'
    check (attendance_status in ('expected', 'checked_in', 'checked_out', 'no_show')),
  cover_status text not null default 'unpaid'
    check (cover_status in ('unpaid', 'paid', 'partial', 'comped', 'refunded')),
  cover_amount_cents integer not null default 0 check (cover_amount_cents >= 0),
  is_comped boolean not null default false,
  has_scored_play boolean not null default false,
  note text,
  checked_in_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create index event_guests_event_normalized_name_idx
  on public.event_guests (event_id, normalized_name);
create index event_guests_event_phone_idx
  on public.event_guests (event_id, phone_e164);
create index event_guests_event_email_idx
  on public.event_guests (event_id, email_lower);

create table public.guest_cover_entries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  amount_cents integer not null,
  method text not null
    check (method in ('cash', 'venmo', 'zelle', 'other', 'comp', 'refund')),
  recorded_by_user_id uuid not null references public.users(id),
  recorded_at timestamptz not null,
  note text,
  created_at timestamptz not null default now()
);

create index guest_cover_entries_event_guest_idx
  on public.guest_cover_entries (event_id, event_guest_id);

create table public.nfc_tags (
  id uuid primary key default gen_random_uuid(),
  uid_hex text not null unique,
  uid_fingerprint text not null unique,
  default_tag_type text not null
    check (default_tag_type in ('player', 'table', 'unknown')),
  display_label text,
  status text not null default 'active'
    check (status in ('active', 'retired')),
  first_seen_at timestamptz,
  last_seen_at timestamptz,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.event_guest_tag_assignments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  nfc_tag_id uuid not null references public.nfc_tags(id),
  status text not null
    check (status in ('assigned', 'replaced', 'released', 'lost')),
  assigned_at timestamptz not null,
  released_at timestamptz,
  assigned_by_user_id uuid not null references public.users(id),
  release_reason text,
  created_at timestamptz not null default now()
);

create unique index event_guest_tag_assignments_active_guest_idx
  on public.event_guest_tag_assignments (event_id, event_guest_id)
  where status = 'assigned';

create unique index event_guest_tag_assignments_active_tag_idx
  on public.event_guest_tag_assignments (event_id, nfc_tag_id)
  where status = 'assigned';

create table public.event_tables (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  label text not null,
  mode text not null check (mode in ('points', 'casual', 'inactive')),
  display_order integer not null default 0,
  nfc_tag_id uuid references public.nfc_tags(id) on delete set null,
  default_ruleset_id text not null default 'HK_STANDARD_V1'
    references public.rulesets(id),
  default_rotation_policy_type text not null default 'dealer_cycle_return_to_initial_east',
  default_rotation_policy_config_json jsonb not null default '{}'::jsonb,
  status text not null default 'active'
    check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index event_tables_event_tag_idx
  on public.event_tables (event_id, nfc_tag_id)
  where nfc_tag_id is not null;

create table public.table_sessions (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_table_id uuid not null references public.event_tables(id) on delete cascade,
  session_number_for_table integer not null check (session_number_for_table > 0),
  ruleset_id text not null references public.rulesets(id),
  ruleset_version integer not null check (ruleset_version > 0),
  rotation_policy_type text not null,
  rotation_policy_config_json jsonb not null default '{}'::jsonb,
  status text not null
    check (status in ('active', 'paused', 'completed', 'ended_early', 'aborted')),
  initial_east_seat_index integer not null check (initial_east_seat_index between 0 and 3),
  current_dealer_seat_index integer not null check (current_dealer_seat_index between 0 and 3),
  dealer_pass_count integer not null default 0 check (dealer_pass_count >= 0),
  completed_games_count integer not null default 0 check (completed_games_count >= 0),
  hand_count integer not null default 0 check (hand_count >= 0),
  started_at timestamptz not null,
  started_by_user_id uuid not null references public.users(id),
  ended_at timestamptz,
  ended_by_user_id uuid references public.users(id),
  end_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create unique index table_sessions_active_table_idx
  on public.table_sessions (event_table_id)
  where status in ('active', 'paused');

create index table_sessions_event_idx
  on public.table_sessions (event_id, event_table_id);

create table public.table_session_seats (
  id uuid primary key default gen_random_uuid(),
  table_session_id uuid not null references public.table_sessions(id) on delete cascade,
  seat_index integer not null check (seat_index between 0 and 3),
  initial_wind text not null
    check (initial_wind in ('east', 'south', 'west', 'north')),
  event_guest_id uuid not null references public.event_guests(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (table_session_id, seat_index),
  unique (table_session_id, event_guest_id)
);

create table public.hand_results (
  id uuid primary key default gen_random_uuid(),
  table_session_id uuid not null references public.table_sessions(id) on delete cascade,
  hand_number integer not null check (hand_number > 0),
  result_type text not null check (result_type in ('win', 'washout')),
  winner_seat_index integer check (winner_seat_index between 0 and 3),
  win_type text check (win_type in ('discard', 'self_draw')),
  discarder_seat_index integer check (discarder_seat_index between 0 and 3),
  fan_count integer check (fan_count >= 0),
  base_points integer check (base_points > 0),
  east_seat_index_before_hand integer not null check (east_seat_index_before_hand between 0 and 3),
  east_seat_index_after_hand integer not null check (east_seat_index_after_hand between 0 and 3),
  dealer_rotated boolean not null,
  session_completed_after_hand boolean not null,
  status text not null default 'recorded'
    check (status in ('recorded', 'voided')),
  entered_by_user_id uuid not null references public.users(id),
  entered_at timestamptz not null,
  correction_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0),
  unique (table_session_id, hand_number),
  check (
    (
      result_type = 'washout'
      and winner_seat_index is null
      and win_type is null
      and discarder_seat_index is null
      and fan_count is null
      and base_points is null
    )
    or
    (
      result_type = 'win'
      and winner_seat_index is not null
      and fan_count is not null
      and win_type is not null
      and (
        (win_type = 'discard' and discarder_seat_index is not null and discarder_seat_index <> winner_seat_index)
        or
        (win_type = 'self_draw' and discarder_seat_index is null)
      )
    )
  )
);

create table public.hand_settlements (
  id uuid primary key default gen_random_uuid(),
  hand_result_id uuid not null references public.hand_results(id) on delete cascade,
  payer_event_guest_id uuid not null references public.event_guests(id) on delete restrict,
  payee_event_guest_id uuid not null references public.event_guests(id) on delete restrict,
  amount_points integer not null check (amount_points > 0),
  multiplier_flags_json jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  check (payer_event_guest_id <> payee_event_guest_id)
);

create index hand_settlements_hand_result_idx
  on public.hand_settlements (hand_result_id);

create table public.event_score_totals (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  total_points integer not null default 0,
  hands_won integer not null default 0 check (hands_won >= 0),
  self_draw_wins integer not null default 0 check (self_draw_wins >= 0),
  discard_wins integer not null default 0 check (discard_wins >= 0),
  sessions_started integer not null default 0 check (sessions_started >= 0),
  sessions_completed integer not null default 0 check (sessions_completed >= 0),
  updated_at timestamptz not null default now(),
  unique (event_id, event_guest_id)
);

create table public.prize_plans (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null unique references public.events(id) on delete cascade,
  mode text not null check (mode in ('none', 'percentage', 'fixed')),
  status text not null check (status in ('draft', 'validated', 'locked')),
  reserve_fixed_cents integer not null default 0 check (reserve_fixed_cents >= 0),
  reserve_percentage_bps integer not null default 0
    check (reserve_percentage_bps between 0 and 10000),
  note text,
  created_by_user_id uuid not null references public.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  row_version integer not null default 1 check (row_version > 0)
);

create table public.prize_tiers (
  id uuid primary key default gen_random_uuid(),
  prize_plan_id uuid not null references public.prize_plans(id) on delete cascade,
  place integer not null check (place > 0),
  label text,
  percentage_bps integer check (percentage_bps between 0 and 10000),
  fixed_amount_cents integer check (fixed_amount_cents >= 0),
  created_at timestamptz not null default now(),
  unique (prize_plan_id, place),
  check ((percentage_bps is null) <> (fixed_amount_cents is null))
);

create table public.prize_awards (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  event_guest_id uuid not null references public.event_guests(id) on delete cascade,
  rank_start integer not null check (rank_start > 0),
  rank_end integer not null check (rank_end >= rank_start),
  display_rank text not null,
  award_amount_cents integer not null check (award_amount_cents >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index prize_awards_event_rank_idx
  on public.prize_awards (event_id, rank_start, rank_end);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  event_id uuid references public.events(id) on delete set null,
  actor_user_id uuid references public.users(id) on delete set null,
  entity_type text not null,
  entity_id text not null,
  action text not null,
  before_json jsonb,
  after_json jsonb,
  metadata_json jsonb not null default '{}'::jsonb,
  reason text,
  created_at timestamptz not null default now()
);

create index audit_logs_event_idx
  on public.audit_logs (event_id, created_at desc);
create index audit_logs_entity_idx
  on public.audit_logs (entity_type, entity_id, created_at desc);

create trigger users_touch_updated_at
before update on public.users
for each row execute function app_private.touch_updated_at();

create trigger events_touch_updated_at_and_row_version
before update on public.events
for each row execute function app_private.touch_updated_at_and_row_version();

create trigger event_guests_touch_updated_at_and_row_version
before update on public.event_guests
for each row execute function app_private.touch_updated_at_and_row_version();

create trigger nfc_tags_touch_updated_at
before update on public.nfc_tags
for each row execute function app_private.touch_updated_at();

create trigger event_tables_touch_updated_at
before update on public.event_tables
for each row execute function app_private.touch_updated_at();

create trigger table_sessions_touch_updated_at_and_row_version
before update on public.table_sessions
for each row execute function app_private.touch_updated_at_and_row_version();

create trigger hand_results_touch_updated_at_and_row_version
before update on public.hand_results
for each row execute function app_private.touch_updated_at_and_row_version();

create trigger event_score_totals_touch_updated_at
before update on public.event_score_totals
for each row execute function app_private.touch_updated_at();

create trigger prize_plans_touch_updated_at_and_row_version
before update on public.prize_plans
for each row execute function app_private.touch_updated_at_and_row_version();

create trigger prize_awards_touch_updated_at
before update on public.prize_awards
for each row execute function app_private.touch_updated_at();

insert into public.rulesets (
  id,
  name,
  version,
  status,
  definition_json
) values (
  'HK_STANDARD_V1',
  'Hong Kong Standard',
  1,
  'active',
  '{
    "id": "HK_STANDARD_V1",
    "name": "Hong Kong Standard",
    "version": 1,
    "winTypes": ["discard", "self_draw"],
    "washoutDealerBehavior": "retain_current_east",
    "rotationPolicyDefaults": ["dealer_cycle_return_to_initial_east"]
  }'::jsonb
)
on conflict (id) do update
set
  name = excluded.name,
  version = excluded.version,
  status = excluded.status,
  definition_json = excluded.definition_json;
