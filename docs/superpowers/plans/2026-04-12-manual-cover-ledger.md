# Manual Cover Ledger Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add guest-level manual cover ledger entry creation and history viewing without changing the existing host-authored `cover_status` model.

**Architecture:** Keep cover ledger writes server-authoritative in Supabase RPCs, then expose them through the existing guest-detail flow via small repository, cache, and controller extensions. Reuse the current guest detail screen as the host’s operational entry point, and add a focused cover-entry form so payment history stays separate from check-in and tag actions.

**Tech Stack:** Flutter, supabase_flutter, Supabase Postgres SQL migrations/RPC, SharedPreferences local cache, widget tests, repository tests, iOS simulator integration_test

---

## File Map

- Create: `supabase/migrations/20260412230000_manual_cover_ledger.sql`
  - `record_cover_entry`
  - `list_guest_cover_entries`
  - audit logging for ledger rows
- Modify: `lib/data/models/guest_models.dart`
  - add cover entry model(s)
  - extend guest detail shape to carry ledger rows
  - add cover-entry method enum/value helpers
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - extend `GuestRepository` with cover-ledger methods
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
  - load ledger rows into guest detail
  - record entries through RPC
  - cache and reload guest detail consistently
- Modify: `lib/data/local/local_cache.dart`
  - store guest-level cover ledger rows
- Modify: `lib/features/checkin/controllers/guest_check_in_controller.dart`
  - load cover ledger with guest detail
  - submit cover entry
  - surface advisory consistency messages if implemented
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
  - render `Cover Ledger` section
  - open cover-entry form
  - show history rows
- Create: `lib/features/checkin/models/cover_entry_form_draft.dart`
  - validate amount/method/note
- Create: `lib/features/checkin/screens/add_cover_entry_screen.dart`
  - focused entry form
- Create: `test/data/repositories/supabase_guest_repository_cover_ledger_test.dart`
  - repository mapping for load and record cover entry
- Create: `test/features/checkin/models/cover_entry_form_draft_test.dart`
  - validation coverage
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`
  - ledger section rendering
  - add-cover-entry flow
- Modify: `test/app/app_auth_gate_test.dart`
  - update fake guest repository contract
- Modify: `test/features/guests/screens/guest_form_screen_test.dart`
  - update fake guest repository contract
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
  - update fake guest repository contract
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
  - update fake guest repository contract
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
  - update fake guest repository contract
- Modify: `test/features/tables/screens/start_session_screen_test.dart`
  - update fake guest repository contract
- Create or Modify: `integration_test/live_smoke_test.dart`
  - cover ledger creation and cleanup verification

## Chunk 1: Models, Cache, And Repository Contract

### Task 1: Add failing model and repository tests for cover-ledger data

**Files:**
- Create: `test/features/checkin/models/cover_entry_form_draft_test.dart`
- Create: `test/data/repositories/supabase_guest_repository_cover_ledger_test.dart`
- Modify: `lib/data/models/guest_models.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write the failing draft validation tests**

Cover:
- amount is required
- amount cannot be zero
- method is required
- refund can use a negative amount
- non-refund methods still allow signed values but the draft exposes helper text/state for expected direction

- [ ] **Step 2: Write the failing repository tests**

Cover:
- `getGuestDetail` returns guest detail with ordered `coverEntries`
- `recordCoverEntry` calls the RPC and returns refreshed detail
- guest cover-entry cache refreshes after mutation

- [ ] **Step 3: Run the new tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/models/cover_entry_form_draft_test.dart test/data/repositories/supabase_guest_repository_cover_ledger_test.dart
```

Expected: FAIL for missing models/repository methods/cache support

- [ ] **Step 4: Add the minimal typed model support**

Implement in `lib/data/models/guest_models.dart`:
- `CoverEntryMethod` enum
- `GuestCoverEntryRecord`
- extend `GuestDetailRecord` with `coverEntries`

Add JSON helpers for:
- `cash`
- `venmo`
- `zelle`
- `other`
- `comp`
- `refund`

- [ ] **Step 5: Add the repository and cache contract**

Extend `GuestRepository` with:
- `Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId)`
- `Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(String guestId)`
- `Future<GuestDetailRecord> recordCoverEntry({required String guestId, required int amountCents, required CoverEntryMethod method, String? note})`

Extend `LocalCache` with:
- `saveGuestCoverEntries(String guestId, List<GuestCoverEntryRecord> entries)`
- `readGuestCoverEntries(String guestId)`

- [ ] **Step 6: Re-run the targeted tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/models/cover_entry_form_draft_test.dart test/data/repositories/supabase_guest_repository_cover_ledger_test.dart
```

Expected: still FAIL, but now at the concrete repository implementation or form logic boundary

## Chunk 2: Supabase RPCs And Guest Repository Implementation

### Task 2: Add the cover-ledger migration and backend validation

**Files:**
- Create: `supabase/migrations/20260412230000_manual_cover_ledger.sql`

- [ ] **Step 1: Write the migration**

Add:
- `public.record_cover_entry(target_event_guest_id uuid, target_amount_cents integer, target_method text, target_note text default null)`
- `public.list_guest_cover_entries(target_event_guest_id uuid)`

Implement:
- guest ownership validation via existing guest ownership helper
- method validation against the allowed methods
- non-zero amount validation
- insert into `public.guest_cover_entries`
- `recorded_by_user_id = auth.uid()`
- `recorded_at = now()`
- audit log insert with amount/method metadata

- [ ] **Step 2: Re-read the migration against the spec**

Check:
- no automatic guest cover-status mutation
- no event-wide balance logic
- newest-first list ordering
- audit action/entity naming is consistent

- [ ] **Step 3: Apply the migration to Supabase**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260412230000_manual_cover_ledger.sql
```

Expected: `CREATE FUNCTION` output and exit code `0`

- [ ] **Step 4: Directly verify RPC behavior in SQL**

Use a transaction and host auth context to verify:
- valid entry inserts correctly
- zero amount is blocked
- invalid method is blocked
- list RPC returns newest-first rows for the target guest only

Expected: all checks pass and transaction rolls back cleanly

### Task 3: Implement the guest repository cover-ledger path

**Files:**
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
- Modify: `lib/data/local/local_cache.dart`
- Modify: `lib/data/models/guest_models.dart`

- [ ] **Step 1: Implement `loadGuestCoverEntries`**

Use:
- `list_guest_cover_entries` RPC when available
- ordered mapping into `GuestCoverEntryRecord`
- cache save by guest id

- [ ] **Step 2: Extend `getGuestDetail` to include cover entries**

Load:
- guest row
- active tag assignment
- cover entry rows

Return a single `GuestDetailRecord` with all three pieces.

- [ ] **Step 3: Implement `recordCoverEntry`**

Call:
- `record_cover_entry`

Then:
- refresh cached ledger rows
- refresh and return full guest detail

- [ ] **Step 4: Re-run the repository tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_guest_repository_cover_ledger_test.dart
```

Expected: PASS

## Chunk 3: Guest Detail UI And Form Flow

### Task 4: Add failing widget tests for guest detail cover ledger behavior

**Files:**
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`
- Create: `lib/features/checkin/models/cover_entry_form_draft.dart`
- Create: `lib/features/checkin/screens/add_cover_entry_screen.dart`
- Modify: `lib/features/checkin/controllers/guest_check_in_controller.dart`
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`

- [ ] **Step 1: Write failing guest-detail widget tests**

Cover:
- guest detail shows a `Cover Ledger` section
- existing ledger rows render newest-first
- `Add Cover Entry` opens the form
- saving a valid entry returns to guest detail and shows the new row
- invalid form input shows inline validation

- [ ] **Step 2: Run the widget test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/screens/guest_detail_screen_test.dart
```

Expected: FAIL because the cover-ledger UI and form do not exist yet

- [ ] **Step 3: Implement the cover-entry draft**

In `cover_entry_form_draft.dart` add:
- amount string parsing
- selected method
- note
- validation helpers
- `toRepositoryInput()` or equivalent compact mapping

- [ ] **Step 4: Extend the guest detail controller**

Add:
- cover-entry submission method
- optional advisory consistency message generation
- reuse existing submit/error state instead of introducing a separate controller unless the screen becomes too dense

- [ ] **Step 5: Implement the add-cover-entry screen**

Build a focused form with:
- amount field
- method selector
- note field
- save/cancel

On save:
- call controller/repository path
- pop on success

- [ ] **Step 6: Render the ledger section in guest detail**

Add:
- current cover summary
- `Add Cover Entry` action
- newest-first ledger rows
- optional advisory nudge text

- [ ] **Step 7: Re-run the widget tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/screens/guest_detail_screen_test.dart test/features/checkin/models/cover_entry_form_draft_test.dart
```

Expected: PASS

## Chunk 4: Test Double Cleanup, End-To-End Smoke, And Final Verification

### Task 5: Update test doubles to match the expanded guest repository

**Files:**
- Modify: `test/app/app_auth_gate_test.dart`
- Modify: `test/features/guests/screens/guest_form_screen_test.dart`
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
- Modify: `test/features/tables/screens/start_session_screen_test.dart`

- [ ] **Step 1: Add the new guest-repository method stubs to affected fakes**

Add implementations or `throw UnimplementedError()` for:
- `loadGuestCoverEntries`
- `readCachedGuestCoverEntries`
- `recordCoverEntry`

- [ ] **Step 2: Run a broad widget/analyze pass**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
```

Expected: all tests pass and no interface errors remain

### Task 6: Extend the live smoke test with cover-ledger verification

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Add a cover-ledger smoke path**

Extend the flow to:
- create an event and at least one guest
- start the event
- open guest detail
- add a positive ledger entry
- add a refund entry
- verify `guest_cover_entries` rows exist for that guest

- [ ] **Step 2: Ensure cleanup removes ledger rows**

Add cleanup for:
- `guest_cover_entries`

- [ ] **Step 3: Run the live smoke on the iOS simulator**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD=12345678!
```

Expected: PASS end to end

- [ ] **Step 4: Verify Supabase residue is zero**

Run a cleanup query for:
- `events`
- `event_guests`
- `guest_cover_entries`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`
- `prize_awards`

Expected:
- all counts return `0`

### Task 7: Final project verification

**Files:**
- No new files; verification only

- [ ] **Step 1: Run final formatting**

Run:
```bash
dart format lib test integration_test
```

Expected: clean formatting

- [ ] **Step 2: Run final verification suite**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD=12345678!
```

Expected:
- analyze passes
- test suite passes
- live smoke passes

- [ ] **Step 3: Prepare commit**

Use a conventional commit once implementation is complete, for example:

```bash
git add lib test integration_test supabase/migrations docs/superpowers/plans/2026-04-12-manual-cover-ledger.md
git commit -m "feat: add guest cover ledger flow"
```
