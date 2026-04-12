# Event Completion And Finalization Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the MVP event-closure flow so hosts can complete active events, review completed events, and finalize them into a locked state.

**Architecture:** Keep lifecycle transitions server-authoritative in Supabase RPCs layered on top of existing event, session, and prize tables. On Flutter, extend the event repository and dashboard so completion/finalization are driven from one operational screen with clear blocked-state messaging and status-aware actions.

**Tech Stack:** Flutter, supabase_flutter, Supabase Postgres SQL migrations/RPC, widget tests, repository tests, iOS simulator integration_test

---

## File Map

- Create: `supabase/migrations/20260412170000_event_completion_and_finalization.sql`
  - `complete_event`
  - `finalize_event`
  - lifecycle validation helpers
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - add event completion/finalization methods
- Modify: `lib/data/repositories/supabase_event_repository.dart`
  - call lifecycle RPCs
  - refresh cached event rows after mutations
- Modify: `lib/features/events/controllers/event_dashboard_controller.dart`
  - expose completion/finalization state and actions
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - add `Complete Event` / `Finalize Event`
  - show blocked messages and lifecycle-aware UI
- Modify: `lib/data/models/event_models.dart`
  - confirm lifecycle parsing/serialization coverage only if needed
- Modify: `test/data/models/domain_model_serialization_test.dart`
  - add lifecycle serialization assertions if behavior changes
- Create: `test/data/repositories/supabase_event_repository_lifecycle_test.dart`
  - repository mapping for complete/finalize
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
  - dashboard actions by event lifecycle
- Modify: `test/app/app_auth_gate_test.dart`
  - update fake event repository interface if needed
- Modify: `integration_test/live_smoke_test.dart`
  - extend through complete and finalize

## Chunk 1: Lifecycle RPCs And Repository Contract

### Task 1: Add failing repository tests for event completion and finalization

**Files:**
- Create: `test/data/repositories/supabase_event_repository_lifecycle_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_event_repository.dart`

- [ ] **Step 1: Write the failing repository tests**

Cover:
- `completeEvent` returns an `EventRecord` with `lifecycleStatus = completed`
- `finalizeEvent` returns an `EventRecord` with `lifecycleStatus = finalized`
- both methods refresh cached event rows

- [ ] **Step 2: Run the repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_event_repository_lifecycle_test.dart`

Expected: FAIL for missing repository methods

- [ ] **Step 3: Implement the minimal repository contract**

Add to `EventRepository`:
- `Future<EventRecord> completeEvent(String eventId)`
- `Future<EventRecord> finalizeEvent(String eventId)`

Implement in `SupabaseEventRepository` using RPC calls and cache refresh logic that matches the existing event list/get flows.

- [ ] **Step 4: Re-run the repository tests**

Run: `flutter test test/data/repositories/supabase_event_repository_lifecycle_test.dart`

Expected: PASS

### Task 2: Add the lifecycle migration and RPCs

**Files:**
- Create: `supabase/migrations/20260412170000_event_completion_and_finalization.sql`

- [ ] **Step 1: Write the migration**

Include:
- helper to assert no `active` or `paused` sessions exist for the event
- helper to assert prizes are locked when applicable
- `complete_event(target_event_id uuid)`
- `finalize_event(target_event_id uuid)`
- audit logs for both transitions

- [ ] **Step 2: Re-read the migration against the spec**

Check:
- `complete_event` only allows `active -> completed`
- `finalize_event` only allows `completed -> finalized`
- completion/finalization block on active or paused sessions
- finalization blocks on unlocked prize plan when `mode != none`
- `scoring_open` closes on completion
- `checkin_open` and `scoring_open` close on finalization
- no reopening finalized events is introduced

- [ ] **Step 3: Apply the migration to the remote Supabase project**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260412170000_event_completion_and_finalization.sql
```

Expected: `CREATE FUNCTION` / `CREATE OR REPLACE FUNCTION` output and exit code `0`

- [ ] **Step 4: Sanity-check the new RPCs exist**

Run a `psql` query against `pg_proc`.

Expected: `complete_event` and `finalize_event` are present

## Chunk 2: SQL Verification And Dashboard State

### Task 3: Add direct SQL verification for lifecycle blocking rules

**Files:**
- Modify: `supabase/migrations/20260412170000_event_completion_and_finalization.sql`

- [ ] **Step 1: Write explicit verification cases from the spec**

Cover:
- cannot complete while session is `active`
- cannot complete while session is `paused`
- can complete when no active/paused sessions remain
- cannot finalize when prize plan exists but is not locked
- can finalize when prizes are locked
- finalized event cannot finalize again

- [ ] **Step 2: Run direct SQL verification against the new RPCs**

Use temporary fixtures in `psql` with host auth context set via `request.jwt.claim.sub`.

Expected: blocking errors and success paths match the product rules exactly

- [ ] **Step 3: Fix any mismatches before UI work**

Do not move into dashboard implementation until lifecycle rules are correct server-side.

### Task 4: Add failing widget tests for dashboard lifecycle actions

**Files:**
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
- Modify: `lib/features/events/controllers/event_dashboard_controller.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write failing dashboard tests**

Cover:
- active event shows `Complete Event`
- completed event shows `Finalize Event`
- finalized event does not show live-operation actions
- blocked lifecycle error message renders when repository throws a known error

- [ ] **Step 2: Run the dashboard tests to verify failure**

Run: `flutter test test/features/events/screens/event_dashboard_screen_test.dart`

Expected: FAIL for missing actions/state handling

- [ ] **Step 3: Implement the minimal dashboard controller changes**

Add:
- submit state for completion/finalization
- controller methods:
  - `completeEvent()`
  - `finalizeEvent()`
- local refresh of event state after lifecycle mutation

- [ ] **Step 4: Implement the minimal dashboard UI changes**

Add:
- lifecycle-aware action buttons
- blocked-state messaging area
- finalized-state messaging

Keep the dashboard operational and compact rather than building a separate wizard.

- [ ] **Step 5: Re-run the dashboard tests**

Run: `flutter test test/features/events/screens/event_dashboard_screen_test.dart`

Expected: PASS

## Chunk 3: App Integration And Full Local Verification

### Task 5: Update fakes and focused app tests for the expanded event repository

**Files:**
- Modify: `test/app/app_auth_gate_test.dart`
- Modify: `test/features/events/screens/create_event_screen_test.dart`
- Modify: `test/features/events/screens/event_list_screen_test.dart`

- [ ] **Step 1: Update fake event repositories to satisfy the new interface**

Add stub implementations for:
- `completeEvent`
- `finalizeEvent`

- [ ] **Step 2: Run the focused app/event tests**

Run:
```bash
flutter test test/app/app_auth_gate_test.dart test/features/events/screens/create_event_screen_test.dart test/features/events/screens/event_list_screen_test.dart test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: PASS

### Task 6: Run the full local verification set before live smoke

**Files:**
- All event-finalization files above

- [ ] **Step 1: Format changed files**

Run: `dart format lib test integration_test`

Expected: formatter completes cleanly

- [ ] **Step 2: Run analyze**

Run: `/opt/homebrew/bin/flutter analyze`

Expected: `No issues found!`

- [ ] **Step 3: Run the full Flutter suite**

Run: `/opt/homebrew/bin/flutter test`

Expected: all tests pass

## Chunk 4: Live Finalization Smoke And Cleanup

### Task 7: Extend the live smoke test through completion and finalization

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Add failing live-smoke assertions**

Extend the existing live flow to:
- score the event
- ensure prize awards are locked
- complete the event
- finalize the event
- verify the event row becomes `finalized`

- [ ] **Step 2: Run the live smoke test to capture the first failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD='12345678!'
```

Expected: FAIL at the first unimplemented finalization step

- [ ] **Step 3: Implement the minimal integration changes**

Update the smoke harness to:
- reach the completed dashboard state
- finalize the event
- verify `events.lifecycle_status = finalized`
- keep cleanup surgical

- [ ] **Step 4: Re-run the live smoke test**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD='12345678!'
```

Expected: PASS

### Task 8: Verify remote cleanup leaves no smoke residue

**Files:**
- None

- [ ] **Step 1: Run the residue check**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -Atc "select 'events='||count(*) from events where title like 'Smoke Event %'; select 'guests='||count(*) from event_guests where display_name like 'Smoke %'; select 'tags='||count(*) from nfc_tags where uid_hex like 'SMOKE%'; select 'tables='||count(*) from event_tables where label like 'Table %'; select 'sessions='||count(*) from table_sessions where started_at > now() - interval '1 day'; select 'hands='||count(*) from hand_results where entered_at > now() - interval '1 day'; select 'settlements='||count(*) from hand_settlements where created_at > now() - interval '1 day'; select 'awards='||count(*) from prize_awards where created_at > now() - interval '1 day';"
```

Expected:
- `events=0`
- `guests=0`
- `tags=0`
- `tables=0`
- `sessions=0`
- `hands=0`
- `settlements=0`
- `awards=0`

- [ ] **Step 2: If residue exists, remove only the smoke rows and re-run the check**

Keep cleanup limited to smoke data.

### Task 9: Final verification before completion

**Files:**
- All changed files

- [ ] **Step 1: Run the final full verification set fresh**

Run:
```bash
dart format lib test integration_test
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD='12345678!'
```

Expected:
- formatter completes
- analyze reports no issues
- full test suite passes
- live smoke test passes

- [ ] **Step 2: Confirm remote residue is still zero**

Re-run the residue check from Task 8.

Expected: zero smoke residue

- [ ] **Step 3: Hand off for completion workflow**

After all verification passes, use `superpowers:finishing-a-development-branch` before claiming completion or committing.
