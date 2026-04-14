# Live Supabase Remaining Blockers Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the next wave of high-value live Supabase blocker scenarios so Mosaic proves the remaining event lifecycle, seating eligibility, and pause/resume guardrails against the real backend.

**Architecture:** Extend the existing live Supabase harness rather than creating a second framework. Keep each blocker narrow: use UI actions where the host-facing behavior matters, use direct backend setup only for preconditions the current MVP UI does not expose cleanly, and always pair the visible block with a persisted-state assertion that no invalid rows or mutations were written.

**Tech Stack:** Flutter `integration_test`, `flutter_test`, Supabase Auth/PostgREST/RPC, iOS simulator, direct Supabase assertions

---

## File Map

- Modify: `integration_test/live_supabase_first_six_test.dart`
  - add the next blocker scenarios so all live-backend coverage stays in one suite
- Modify: `integration_test/support/live_fixture_factory.dart`
  - add targeted helpers for unpaid guests, direct check-in setup, pause/resume setup, and prize-plan setup
- Modify: `integration_test/support/live_backend_assertions.dart`
  - add focused assertions for tag assignments, session counts, and lifecycle state
- Modify: `integration_test/support/live_cleanup.dart`
  - only if new setup paths reveal missing cleanup edges
- Modify: `test/integration/live_fixture_factory_test.dart`
  - add small helper tests only if fixture-generation or cleanup logic changes materially
- Modify: `docs/superpowers/specs/2026-04-12-live-supabase-test-strategy.md`
  - optional note after implementation if needed

## Scenario Scope

This plan covers these remaining blocker scenarios:

1. `live_block_finalize_without_locked_prizes_when_plan_exists`
2. `live_block_resume_paused_session_when_scoring_closed`
3. `live_block_unpaid_guest_cannot_receive_player_tag`
4. `live_block_guest_without_tag_cannot_start_session`
5. `live_block_guest_already_in_active_session_cannot_start_second_session`

This plan does **not** add the persistence/auth scenarios from the later strategy layers, since those are already partly covered and are not blockers.

## Chunk 1: Add Small Harness Extensions For Blocker Setup

### Task 1: Add failing helper coverage only where setup logic becomes non-trivial

**Files:**
- Modify: `test/integration/live_fixture_factory_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write failing helper tests only if needed**

Cover only logic worth unit coverage, such as:
- unpaid guest fixture generation
- direct check-in setup that intentionally leaves tags unassigned
- helper-generated seat/tag data for split setups

- [ ] **Step 2: Run targeted helper tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/integration/live_fixture_factory_test.dart
```

Expected: FAIL only if new helper behavior is under test

- [ ] **Step 3: Add minimal harness helpers**

Add only the helpers actually needed for these blockers, such as:
- `addGuestViaUi(..., coverStatus: unpaid|paid|comped)`
- `closeCheckInIfOpen`
- `closeScoringIfOpen`
- `pauseCurrentSessionViaUi`
- direct Supabase setup helper for `check_in_guest` without tag assignment
- direct prize-plan setup helper that leaves the plan unlocked

- [ ] **Step 4: Re-run the helper tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/integration/live_fixture_factory_test.dart
```

Expected: PASS

## Chunk 2: Lifecycle And Session-Operation Blockers

### Task 2: Add the unlocked-prizes finalization blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the failing scenario first**

Add:
- `live_block_finalize_without_locked_prizes_when_plan_exists`

Flow:
- sign in
- create/start event
- create enough scored state for prize eligibility
- create a prize plan through RPC or UI
- do **not** lock awards
- complete the event if needed
- attempt finalization

- [ ] **Step 2: Run only this scenario to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_finalize_without_locked_prizes_when_plan_exists
```

Expected: FAIL before the scenario/setup is correct

- [ ] **Step 3: Implement the minimal setup and assertions**

Verify:
- finalization is blocked
- event lifecycle stays `completed`
- prize plan remains unlocked
- no prize-award lock side effects appear

- [ ] **Step 4: Re-run the scenario**

Expected: PASS

### Task 3: Add the paused-session resume blocker when scoring is closed

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`

- [ ] **Step 1: Write the failing scenario first**

Add:
- `live_block_resume_paused_session_when_scoring_closed`

Flow:
- sign in
- create/start event
- prepare a valid active session
- pause the session
- close scoring
- attempt resume

- [ ] **Step 2: Run only this scenario to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_resume_paused_session_when_scoring_closed
```

Expected: FAIL before the exact assertion/setup is correct

- [ ] **Step 3: Implement the minimal scenario logic**

Verify:
- resume action is blocked
- session status stays `paused`
- scoring stays closed

- [ ] **Step 4: Re-run the scenario**

Expected: PASS

## Chunk 3: Guest Eligibility Blockers

### Task 4: Add the unpaid-guest player-tag blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the failing scenario first**

Add:
- `live_block_unpaid_guest_cannot_receive_player_tag`

Flow:
- sign in
- create/start event
- add one unpaid guest
- open guest detail
- attempt tag assignment path

- [ ] **Step 2: Run only this scenario to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_unpaid_guest_cannot_receive_player_tag
```

Expected: FAIL before the scenario/setup is correct

- [ ] **Step 3: Implement the minimal scenario logic**

Verify:
- the blocking guidance is visible
- no assignment row is created
- attendance status does not move forward unintentionally

- [ ] **Step 4: Re-run the scenario**

Expected: PASS

### Task 5: Add the untagged-guest session-start blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`

- [ ] **Step 1: Write the failing scenario first**

Add:
- `live_block_guest_without_tag_cannot_start_session`

Flow:
- sign in
- create/start event
- prepare four eligible guests
- directly check in one guest without assigning a tag
- create points table and open scoring
- attempt session start including that guest

- [ ] **Step 2: Run only this scenario to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_guest_without_tag_cannot_start_session
```

Expected: FAIL before the setup/assertions are correct

- [ ] **Step 3: Implement the minimal scenario logic**

Verify:
- UI blocks the seat scan or final confirmation path
- no session row is created
- no seat rows are created

- [ ] **Step 4: Re-run the scenario**

Expected: PASS

## Chunk 4: Active-Session Double-Booking Blocker

### Task 6: Add the second-active-session double-booking blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the failing scenario first**

Add:
- `live_block_guest_already_in_active_session_cannot_start_second_session`

Flow:
- sign in
- create/start event
- prepare enough eligible guests for two tables
- start one active session using guest A
- prepare a second points table
- attempt to start a second active session that also includes guest A

- [ ] **Step 2: Run only this scenario to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_guest_already_in_active_session_cannot_start_second_session
```

Expected: FAIL before the exact setup/assertions are correct

- [ ] **Step 3: Implement the minimal scenario logic**

Verify:
- the second session start is blocked
- only one active session exists for the event/guest combination
- no second seat set is written

- [ ] **Step 4: Re-run the scenario**

Expected: PASS

## Chunk 5: Full Verification And Cleanup

### Task 7: Run the remaining-blockers suite and broad verification

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`
- Modify: `integration_test/support/live_cleanup.dart`

- [ ] **Step 1: Run the full live blocker suite**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
```

Expected: PASS

- [ ] **Step 2: Re-run the golden-path live smoke**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
```

Expected: PASS

- [ ] **Step 3: Run the broad local regression suite**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
```

Expected:
- analyze PASS
- test PASS

- [ ] **Step 4: Confirm backend residue is zero**

Verify no leftover rows remain for live test fixtures across:
- `events`
- `event_guests`
- `guest_cover_entries`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`
- `prize_awards`

- [ ] **Step 5: Commit**

```bash
git add integration_test test docs/superpowers/plans/2026-04-13-live-supabase-remaining-blockers.md
git commit -m "test: add remaining live Supabase blocker scenarios"
```
