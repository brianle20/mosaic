# Tables And Session Start Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add event table management, table-tag binding, and scan-first scored session start with explicit East/South/West/North seating.

**Architecture:** Extend the current event/guest/check-in flow with a focused `tables` feature area, concrete table/session repositories, and server-authoritative RPCs for table binding and session creation. Reuse the existing NFC abstraction and simulator-safe manual UID entry, but add explicit scan intents for table confirmation and seat-by-seat player scanning.

**Tech Stack:** Flutter, Supabase Postgres migrations/RPC, supabase_flutter, shared_preferences, widget tests, repository tests, iOS simulator integration_test

---

## File Map

- Create: `supabase/migrations/20260411193000_tables_and_session_start.sql`
  - table/session RPCs
  - audit hooks for table and session operations
- Create: `lib/data/models/table_models.dart`
  - `EventTableRecord`, form inputs, binding result helpers
- Modify: `lib/data/models/session_models.dart`
  - add `TableSessionSeatRecord`, `StartTableSessionInput`, `StartedTableSessionRecord`
- Modify: `lib/data/models/tag_models.dart`
  - add table-tag binding summary helpers if needed
- Modify: `lib/data/local/local_cache.dart`
  - cache table lists and active sessions per event
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - add `TableRepository` and flesh out `SessionRepository`
- Create: `lib/data/repositories/supabase_table_repository.dart`
  - event-table CRUD and table-tag binding
- Create: `lib/data/repositories/supabase_session_repository.dart`
  - session listing and session start RPC wiring
- Modify: `lib/services/nfc/nfc_service.dart`
  - add scan intents for table tag and session-seat player tags
- Modify: `lib/services/nfc/manual_entry_nfc_service.dart`
  - parameterize prompt labels for table vs seat scans
- Create: `lib/features/tables/models/table_form_draft.dart`
  - table form validation
- Create: `lib/features/tables/models/start_session_scan_state.dart`
  - step state and seat-order helpers
- Create: `lib/features/tables/controllers/table_list_controller.dart`
  - load tables and active sessions
- Create: `lib/features/tables/controllers/table_form_controller.dart`
  - create/update tables and bind table tags
- Create: `lib/features/tables/controllers/start_session_controller.dart`
  - scan-step flow, prevalidation, confirm start
- Create: `lib/features/tables/screens/tables_overview_screen.dart`
  - list cards and host actions
- Create: `lib/features/tables/screens/table_form_screen.dart`
  - add/edit table UI
- Create: `lib/features/tables/screens/start_session_screen.dart`
  - scan-first start-session flow
- Modify: `lib/core/routing/app_router.dart`
  - routes/args for tables, table form, session start
- Modify: `lib/app/app.dart`
  - inject table/session repositories into router
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - add `Tables` action
- Test: `test/data/models/domain_model_serialization_test.dart`
  - table/session seat serialization coverage
- Create: `test/features/tables/models/table_form_draft_test.dart`
  - table form validation
- Create: `test/features/tables/models/start_session_scan_state_test.dart`
  - seat-order mapping and duplicate scan protection
- Create: `test/data/repositories/supabase_table_repository_test.dart`
  - table CRUD and bind mapping
- Create: `test/data/repositories/supabase_session_repository_test.dart`
  - session start mapping
- Create: `test/features/tables/screens/tables_overview_screen_test.dart`
  - table cards, actions, statuses
- Create: `test/features/tables/screens/table_form_screen_test.dart`
  - table form flow
- Create: `test/features/tables/screens/start_session_screen_test.dart`
  - scan steps, errors, review, confirm
- Modify: `integration_test/live_smoke_test.dart`
  - extend live flow through table creation, table-tag binding, and session start

## Chunk 1: Domain Models And Backend Contracts

### Task 1: Add failing model tests for tables and session seats

**Files:**
- Modify: `test/data/models/domain_model_serialization_test.dart`
- Create: `lib/data/models/table_models.dart`
- Modify: `lib/data/models/session_models.dart`

- [ ] **Step 1: Write failing model tests**

Cover:
- `EventTableRecord` JSON parsing
- `TableSessionSeatRecord` JSON parsing
- started-session aggregate shape preserves explicit `ruleset_id` and `rotation_policy_type`
- seat helper maps `0..3` to east/south/west/north

- [ ] **Step 2: Run model tests to verify failure**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL for missing models/types

- [ ] **Step 3: Implement minimal table/session model code**

Add only the types and helpers needed by the tests:
- `EventTableRecord`
- create/update input payloads
- `TableSessionSeatRecord`
- `StartedTableSessionRecord`

- [ ] **Step 4: Re-run the model tests**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS

### Task 2: Add the backend migration for tables and session start RPCs

**Files:**
- Create: `supabase/migrations/20260411193000_tables_and_session_start.sql`

- [ ] **Step 1: Write the migration**

Include:
- ownership helpers for tables
- `create_event_table`
- `update_event_table`
- `bind_table_tag`
- `start_table_session`
- any helper views/functions needed to resolve tags and validate eligibility
- audit inserts for table create/update, tag bind, and session start

- [ ] **Step 2: Re-read the migration against existing schema**

Check:
- it uses `auth.uid()`
- it respects existing RLS/policies
- active session blocking relies on the existing partial index and explicit checks
- table tags become `default_tag_type = 'table'`
- session rows store explicit ruleset/rotation values copied from table defaults

- [ ] **Step 3: Keep the migration ready for remote apply**

No dashboard-only edits. The SQL file should be ready for `psql`/pooler application later in execution.

## Chunk 2: Repository Layer And NFC Extension

### Task 3: Add failing repository tests for table CRUD and binding

**Files:**
- Create: `test/data/repositories/supabase_table_repository_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Create: `lib/data/repositories/supabase_table_repository.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write failing table repository tests**

Cover:
- create table maps RPC result to `EventTableRecord`
- update table maps correctly
- bind table tag maps correctly
- cached table list refreshes after writes

- [ ] **Step 2: Run the table repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_table_repository_test.dart`
Expected: FAIL for missing repository/contracts

- [ ] **Step 3: Implement minimal table repository code**

Add:
- `TableRepository` interface
- `SupabaseTableRepository`
- table cache keys in `LocalCache`

- [ ] **Step 4: Re-run the table repository tests**

Run: `flutter test test/data/repositories/supabase_table_repository_test.dart`
Expected: PASS

### Task 4: Add failing repository tests for session start

**Files:**
- Create: `test/data/repositories/supabase_session_repository_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Create: `lib/data/repositories/supabase_session_repository.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write failing session repository tests**

Cover:
- session list mapping
- `start_table_session` maps session row and ordered seats
- session list refresh after start

- [ ] **Step 2: Run the session repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_session_repository_test.dart`
Expected: FAIL for missing repository/contracts

- [ ] **Step 3: Implement minimal session repository code**

Add:
- `SessionRepository` methods for list/start
- `SupabaseSessionRepository`
- cache support for active sessions if needed for the overview screen

- [ ] **Step 4: Re-run the session repository tests**

Run: `flutter test test/data/repositories/supabase_session_repository_test.dart`
Expected: PASS

### Task 5: Extend the NFC service with table and seat scan intents

**Files:**
- Modify: `lib/services/nfc/nfc_service.dart`
- Modify: `lib/services/nfc/manual_entry_nfc_service.dart`
- Create: `test/features/tables/models/start_session_scan_state_test.dart`
- Create: `lib/features/tables/models/start_session_scan_state.dart`

- [ ] **Step 1: Write failing tests for scan-state helpers**

Cover:
- seat prompts advance East -> South -> West -> North
- duplicate player-tag scans are rejected in app-state helper logic
- review state is produced only after all four seats are resolved

- [ ] **Step 2: Run the scan-state tests to verify failure**

Run: `flutter test test/features/tables/models/start_session_scan_state_test.dart`
Expected: FAIL for missing model/service updates

- [ ] **Step 3: Implement minimal scan-state and NFC service changes**

Add:
- explicit scan intents for table and seat-player scans
- manual dialog prompt labels for each step
- scan-state helper for seat order and duplicate protection

- [ ] **Step 4: Re-run the scan-state tests**

Run: `flutter test test/features/tables/models/start_session_scan_state_test.dart`
Expected: PASS

## Chunk 3: Tables UI

### Task 6: Add failing widget tests for tables overview and table form

**Files:**
- Create: `test/features/tables/models/table_form_draft_test.dart`
- Create: `lib/features/tables/models/table_form_draft.dart`
- Create: `test/features/tables/screens/tables_overview_screen_test.dart`
- Create: `test/features/tables/screens/table_form_screen_test.dart`
- Create: `lib/features/tables/controllers/table_list_controller.dart`
- Create: `lib/features/tables/controllers/table_form_controller.dart`
- Create: `lib/features/tables/screens/tables_overview_screen.dart`
- Create: `lib/features/tables/screens/table_form_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write failing table-form and overview tests**

Cover:
- dashboard shows `Tables` action
- tables overview renders points/casual/inactive cards
- points tables can show `Start Session`
- form validates required label
- bind table tag action is visible on table form

- [ ] **Step 2: Run the table UI tests to verify failure**

Run: `flutter test test/features/tables/models/table_form_draft_test.dart test/features/tables/screens/tables_overview_screen_test.dart test/features/tables/screens/table_form_screen_test.dart`
Expected: FAIL for missing screens/routes/controllers

- [ ] **Step 3: Implement the minimal tables UI**

Add:
- `TableFormDraft`
- tables overview screen
- table form screen
- controller wiring
- dashboard route/action into tables
- router/app injection for table/session repositories

- [ ] **Step 4: Re-run the table UI tests**

Run: `flutter test test/features/tables/models/table_form_draft_test.dart test/features/tables/screens/tables_overview_screen_test.dart test/features/tables/screens/table_form_screen_test.dart`
Expected: PASS

## Chunk 4: Start Session UI And End-To-End Wiring

### Task 7: Add failing widget tests for the start-session flow

**Files:**
- Create: `test/features/tables/screens/start_session_screen_test.dart`
- Create: `lib/features/tables/controllers/start_session_controller.dart`
- Create: `lib/features/tables/screens/start_session_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`

- [ ] **Step 1: Write failing start-session widget tests**

Cover:
- flow prompts for table tag first
- flow then prompts East/South/West/North in order
- duplicate player scan shows an error
- review screen shows resolved guest names and seat order
- confirming start calls repository and exits successfully

- [ ] **Step 2: Run the start-session widget tests to verify failure**

Run: `flutter test test/features/tables/screens/start_session_screen_test.dart`
Expected: FAIL for missing screen/controller

- [ ] **Step 3: Implement the minimal start-session UI**

Add:
- scan-step controller
- start-session screen
- route from points table cards into start flow
- friendly inline errors for unknown/mismatched/duplicate scans

- [ ] **Step 4: Re-run the start-session widget tests**

Run: `flutter test test/features/tables/screens/start_session_screen_test.dart`
Expected: PASS

### Task 8: Apply the migration and extend the live simulator smoke test

**Files:**
- Create or modify local SQL apply command usage only during execution
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Apply the migration to the live Supabase project**

Use the pooler-backed `psql` flow already proven in this repo.

- [ ] **Step 2: Extend the live smoke test with table/session start**

Add steps to:
- create four paid guests
- check in and tag all four
- create a points table
- bind a table tag
- start a session with table + seat scans
- verify `table_sessions` and `table_session_seats`
- clean up created rows

- [ ] **Step 3: Run the live smoke test to verify the full slice**

Run: `/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...`
Expected: PASS

## Chunk 5: Final Verification

### Task 9: Run the full verification suite

**Files:**
- No new files

- [ ] **Step 1: Run formatter on touched Dart files**

Run: `dart format lib test integration_test`
Expected: all touched files formatted

- [ ] **Step 2: Run static analysis**

Run: `flutter analyze`
Expected: PASS with no issues

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS

- [ ] **Step 4: Re-run the live smoke test after all changes**

Run: `/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...`
Expected: PASS

- [ ] **Step 5: Summarize residual risks**

Call out:
- real hardware NFC for table tags still needs on-device validation
- hand entry/scoring remains a separate next slice
