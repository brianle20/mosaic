# Live Operations Controls Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add host-facing live operations controls so draft events can be started, check-in/scoring can be opened or closed, and active sessions can be paused, resumed, or ended early.

**Architecture:** Keep all lifecycle and operational state transitions server-authoritative in Supabase RPCs, then expose them in Flutter through small repository extensions and existing event/session screens. Reuse centralized event/session guard helpers so check-in, session start, and hand recording all obey the same operational flag rules.

**Tech Stack:** Flutter, supabase_flutter, Supabase Postgres SQL migrations/RPC, widget tests, repository tests, direct SQL verification, iOS simulator integration_test

---

## File Map

- Create: `supabase/migrations/20260412210000_live_operations_controls.sql`
  - `start_event`
  - `set_event_operational_flags`
  - `pause_table_session`
  - `resume_table_session`
  - `end_table_session`
  - shared event operational guard helpers
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - add event start/flag methods
  - add session pause/resume/end methods
- Modify: `lib/data/repositories/supabase_event_repository.dart`
  - call `start_event`
  - call `set_event_operational_flags`
  - refresh event cache rows after mutations
- Modify: `lib/data/repositories/supabase_session_repository.dart`
  - call pause/resume/end RPCs
  - refresh session detail and session list cache after mutations
- Modify: `lib/features/events/controllers/event_dashboard_controller.dart`
  - expose start/flag actions and submission state
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - add `Start Event`
  - add check-in/scoring operational controls
  - render lifecycle-aware blocked messages
- Modify: `lib/features/scoring/controllers/session_detail_controller.dart`
  - expose pause/resume/end-early actions
  - track action loading/error state
- Modify: `lib/features/scoring/screens/session_detail_screen.dart`
  - add pause/resume/end-early controls
  - require end-early reason
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
  - remove fallback behavior for check-in/tag ops when real operational guards should be authoritative
  - ensure guest operations surface server errors clearly
- Modify: `integration_test/live_smoke_test.dart`
  - use real `Start Event`
  - verify scoring gate before session start
  - pause/resume/end session
  - complete/finalize still succeed
- Create: `test/data/repositories/supabase_event_repository_operations_test.dart`
  - repository mapping for `startEvent` and `setOperationalFlags`
- Create: `test/data/repositories/supabase_session_repository_operations_test.dart`
  - repository mapping for `pauseSession`, `resumeSession`, and `endSession`
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
  - dashboard start/flag control behavior
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
  - session control visibility and reason prompt
- Modify: `test/app/app_auth_gate_test.dart`
  - update fake repository interfaces
- Modify: `test/features/events/screens/create_event_screen_test.dart`
  - update fake repository interfaces
- Modify: `test/features/events/screens/event_list_screen_test.dart`
  - update fake repository interfaces

## Chunk 1: Event Operation RPCs And Repository Contract

### Task 1: Add failing repository tests for event start and operational flags

**Files:**
- Create: `test/data/repositories/supabase_event_repository_operations_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_event_repository.dart`

- [ ] **Step 1: Write the failing repository tests**

Cover:
- `startEvent` returns an `EventRecord` with:
  - `lifecycleStatus = active`
  - `checkinOpen = true`
  - `scoringOpen = false`
- `setOperationalFlags` returns an updated `EventRecord`
- both methods refresh cached event rows

- [ ] **Step 2: Run the repository tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_event_repository_operations_test.dart
```

Expected: FAIL for missing repository methods/constructor hooks

- [ ] **Step 3: Implement the minimal event repository contract**

Add to `EventRepository`:
- `Future<EventRecord> startEvent(String eventId)`
- `Future<EventRecord> setOperationalFlags({required String eventId, required bool checkinOpen, required bool scoringOpen})`

Implement in `SupabaseEventRepository` using:
- `start_event`
- `set_event_operational_flags`

Reuse the existing event cache merge path so event list and dashboard update from the same source of truth.

- [ ] **Step 4: Re-run the repository tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_event_repository_operations_test.dart
```

Expected: PASS

### Task 2: Add the live-operations migration and event guard helpers

**Files:**
- Create: `supabase/migrations/20260412210000_live_operations_controls.sql`

- [ ] **Step 1: Write the migration**

Include:
- `app_private.require_event_for_checkin(target_event_id uuid)`
- `app_private.require_event_for_scoring(target_event_id uuid)`
- `public.start_event(target_event_id uuid)`
- `public.set_event_operational_flags(target_event_id uuid, target_checkin_open boolean, target_scoring_open boolean)`

Also update existing RPCs to use the right guards:
- `check_in_guest`
- `assign_guest_tag`
- `replace_guest_tag`
- `start_table_session`
- `record_hand_result`
- `edit_hand_result`
- `void_hand_result`

- [ ] **Step 2: Re-read the migration against the spec**

Check:
- `start_event` only allows `draft -> active`
- start event sets:
  - `checkin_open = true`
  - `scoring_open = false`
- operational flags can change only while event is `active`
- check-in/tagging are blocked when `checkin_open = false`
- session start and hand writes are blocked when `scoring_open = false`

- [ ] **Step 3: Apply the migration to the remote Supabase project**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260412210000_live_operations_controls.sql
```

Expected: `CREATE FUNCTION` output and exit code `0`

- [ ] **Step 4: Sanity-check the new event RPCs exist**

Run a `pg_proc` query for:
- `start_event`
- `set_event_operational_flags`
- `require_event_for_checkin`
- `require_event_for_scoring`

Expected: all present

## Chunk 2: Session Operation RPCs And SQL Verification

### Task 3: Add failing repository tests for pause/resume/end session

**Files:**
- Create: `test/data/repositories/supabase_session_repository_operations_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_session_repository.dart`

- [ ] **Step 1: Write the failing session operation repository tests**

Cover:
- `pauseSession` returns refreshed `SessionDetailRecord` with session status `paused`
- `resumeSession` returns refreshed `SessionDetailRecord` with session status `active`
- `endSession` returns refreshed `SessionDetailRecord` with session status `endedEarly`

- [ ] **Step 2: Run the repository tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_session_repository_operations_test.dart
```

Expected: FAIL for missing repository methods

- [ ] **Step 3: Implement the minimal session repository contract**

Add to `SessionRepository`:
- `Future<SessionDetailRecord> pauseSession(String sessionId)`
- `Future<SessionDetailRecord> resumeSession(String sessionId)`
- `Future<SessionDetailRecord> endSession({required String sessionId, required String reason})`

Implement in `SupabaseSessionRepository` by:
- calling the new session RPCs
- reloading session detail
- merging the updated session into the cached session list

- [ ] **Step 4: Re-run the repository tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_session_repository_operations_test.dart
```

Expected: PASS

### Task 4: Add session operation RPCs and verify backend rules directly in SQL

**Files:**
- Modify: `supabase/migrations/20260412210000_live_operations_controls.sql`

- [ ] **Step 1: Extend the migration with session RPCs**

Add:
- `public.pause_table_session(target_table_session_id uuid)`
- `public.resume_table_session(target_table_session_id uuid)`
- `public.end_table_session(target_table_session_id uuid, target_end_reason text)`

Make them:
- ownership-safe
- event-aware
- audit-logged
- state-transition validated

- [ ] **Step 2: Run direct SQL verification for live operation rules**

Use temporary fixtures with:
- host auth context via `request.jwt.claim.sub`
- draft and active events
- active and paused sessions

Verify:
- cannot start event unless `draft`
- cannot toggle flags unless `active`
- cannot check in when `checkin_open = false`
- cannot start a session when `scoring_open = false`
- cannot record hands when `scoring_open = false`
- can pause only from `active`
- can resume only from `paused`
- cannot resume while scoring is closed
- can end early from both `active` and `paused`

- [ ] **Step 3: Fix any backend mismatches before UI work**

Do not move into screen/controller changes until the SQL behavior matches the product rules exactly.

## Chunk 3: Event Dashboard Live Controls

### Task 5: Add failing widget tests for event start and operational flag controls

**Files:**
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
- Modify: `lib/features/events/controllers/event_dashboard_controller.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write failing dashboard tests**

Cover:
- draft event shows `Start Event`
- active event shows check-in/scoring controls
- completed/finalized events hide flag controls
- blocked operational error message renders when repository throws a known error

- [ ] **Step 2: Run the dashboard tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: FAIL for missing start/flag UI and controller methods

- [ ] **Step 3: Implement minimal controller changes**

Add:
- submission state for operations
- `startEvent()`
- `setOperationalFlags({required bool checkinOpen, required bool scoringOpen})`
- shared host-facing error formatting

- [ ] **Step 4: Implement minimal dashboard UI changes**

Add:
- primary `Start Event` button for draft events
- operational status card for active events
- explicit actions for:
  - open/close check-in
  - open/close scoring

Keep the controls compact and host-operational, not settings-heavy.

- [ ] **Step 5: Re-run the dashboard tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: PASS

## Chunk 4: Session Detail Controls

### Task 6: Add failing widget tests for pause/resume/end-early controls

**Files:**
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
- Modify: `lib/features/scoring/controllers/session_detail_controller.dart`
- Modify: `lib/features/scoring/screens/session_detail_screen.dart`

- [ ] **Step 1: Write failing session detail tests**

Cover:
- active session shows `Pause Session` and `End Early`
- paused session shows `Resume Session` and `End Early`
- completed/ended-early sessions do not show live controls
- ending early requires a reason before submission

- [ ] **Step 2: Run the session detail tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/scoring/screens/session_detail_screen_test.dart
```

Expected: FAIL for missing controls and reason prompt

- [ ] **Step 3: Implement minimal session detail controller changes**

Add:
- action loading/error state
- `pauseSession()`
- `resumeSession()`
- `endSession(String reason)`
- detail refresh after mutation

- [ ] **Step 4: Implement minimal session detail UI changes**

Add:
- lifecycle-aware live control row
- reason prompt dialog or bottom sheet for `End Early`
- disable `Record Hand` when session is not `active`

- [ ] **Step 5: Re-run the session detail tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/scoring/screens/session_detail_screen_test.dart
```

Expected: PASS

## Chunk 5: Supporting Fakes, Full Local Verification, And Live Smoke

### Task 7: Update fake repositories for the expanded interfaces

**Files:**
- Modify: `test/app/app_auth_gate_test.dart`
- Modify: `test/features/events/screens/create_event_screen_test.dart`
- Modify: `test/features/events/screens/event_list_screen_test.dart`

- [ ] **Step 1: Update fake repositories to satisfy new methods**

Add stubs for:
- `startEvent`
- `setOperationalFlags`
- `pauseSession`
- `resumeSession`
- `endSession`

- [ ] **Step 2: Run the focused app/event/scoring tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/app/app_auth_gate_test.dart test/features/events/screens/create_event_screen_test.dart test/features/events/screens/event_list_screen_test.dart test/features/events/screens/event_dashboard_screen_test.dart test/features/scoring/screens/session_detail_screen_test.dart
```

Expected: PASS

### Task 8: Run the full local verification set

**Files:**
- All live-operations files above

- [ ] **Step 1: Format changed files**

Run:
```bash
/opt/homebrew/bin/dart format lib test integration_test
```

Expected: formatter completes cleanly

- [ ] **Step 2: Run static analysis**

Run:
```bash
/opt/homebrew/bin/flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run:
```bash
/opt/homebrew/bin/flutter test
```

Expected: all tests pass

### Task 9: Extend the live iOS simulator smoke test

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Extend the smoke flow through live operations**

Cover:
- create draft event
- tap `Start Event`
- verify backend row becomes:
  - `active`
  - `checkin_open = true`
  - `scoring_open = false`
- verify session start is blocked until scoring opens
- open scoring
- continue through check-in and session start
- pause session
- resume session
- end session early with a reason
- lock prizes if needed
- complete and finalize event

- [ ] **Step 2: Run the live smoke on the booted iOS simulator**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD=12345678!
```

Expected: PASS

- [ ] **Step 3: Verify backend residue is cleaned up**

Run the same direct SQL cleanup check pattern used in earlier slices for:
- `events`
- `event_guests`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`
- `prize_awards`

Expected:
```text
events=0
guests=0
tags=0
tables=0
sessions=0
hands=0
settlements=0
awards=0
```
