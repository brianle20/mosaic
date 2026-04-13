# Live Supabase First Six Scenarios Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first six high-value live Supabase lifecycle scenarios so Mosaic has strong real-backend confidence across the most important cross-feature journeys, blockers, recalculation behavior, locked-award reopen behavior, and RLS boundaries.

**Architecture:** Refactor the existing single-file live smoke harness into a small reusable live-test support layer, then add focused scenario tests on top of it. Keep UI-driven assertions where they carry the most value, pair them with direct backend verification for persisted truth, and require deterministic cleanup for every scenario so the hosted Supabase project remains neutral after every run.

**Tech Stack:** Flutter `integration_test`, `flutter_test`, `supabase_flutter`, Supabase Auth/PostgREST/RPC, iOS simulator, direct Supabase row assertions

---

## File Map

- Modify: `integration_test/live_smoke_test.dart`
  - slim down the existing end-to-end smoke flow or convert it into the golden-path scenario using shared helpers
- Create: `integration_test/live_supabase_first_six_test.dart`
  - home for the first six scenario tests if the existing smoke file stays focused on one broad smoke path
- Create: `integration_test/support/live_test_config.dart`
  - centralize host credentials, simulator assumptions, and shared test constants
- Create: `integration_test/support/live_test_ids.dart`
  - generate unique names, tag UIDs, and run prefixes per scenario
- Create: `integration_test/support/live_fixture_state.dart`
  - track created IDs and raw names needed for cleanup
- Create: `integration_test/support/live_test_harness.dart`
  - sign-in helpers, app bootstrapping, navigation helpers, and common wait utilities
- Create: `integration_test/support/live_fixture_factory.dart`
  - helper methods to create or drive common setup paths such as event creation, guests, tables, sessions, and prizes
- Create: `integration_test/support/live_backend_assertions.dart`
  - direct Supabase verification helpers for rows, absence checks, leaderboard assertions, and cleanup verification
- Create: `integration_test/support/live_cleanup.dart`
  - deterministic teardown for events, guests, tags, tables, sessions, hands, settlements, and awards
- Modify: `pubspec.yaml`
  - only if new test-only helper package support is truly needed; otherwise avoid changes
- Create: `test/integration/live_fixture_factory_test.dart`
  - small pure-Dart tests for ID generation and cleanup ordering if the helper logic becomes non-trivial
- Modify: `docs/superpowers/specs/2026-04-12-live-supabase-test-strategy.md`
  - optionally add a short “implemented first six” note only after execution is complete

## Scenario Scope

This plan covers only these six scenarios from the strategy doc:

1. `live_golden_full_event_lifecycle`
2. `live_block_scoring_closed_blocks_session_start`
3. `live_block_finalize_with_active_session`
4. `live_mutation_edit_hand_recalculates_leaderboard`
5. `live_reopen_locked_prize_flow_preserves_awards_and_names`
6. `live_rls_host_can_only_access_own_event_data`

This plan explicitly does **not** add the full remaining blocker matrix or NFC device tests yet.

## Chunk 1: Extract A Reusable Live-Test Harness

### Task 1: Add failing harness-shape tests or helper assertions for deterministic fixtures

**Files:**
- Create: `test/integration/live_fixture_factory_test.dart`
- Create: `integration_test/support/live_test_ids.dart`
- Create: `integration_test/support/live_fixture_state.dart`
- Create: `integration_test/support/live_cleanup.dart`

- [ ] **Step 1: Write the failing helper tests**

Cover:
- generated run prefixes are unique and scenario-scoped
- generated player/table tag UIDs are normalized consistently
- cleanup ordering deletes dependent rows before parent rows

- [ ] **Step 2: Run the new helper tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/integration/live_fixture_factory_test.dart
```

Expected: FAIL because the helper files and functions do not exist yet

- [ ] **Step 3: Add the minimal helper models and utilities**

Implement:
- `LiveRunIds` or equivalent in `live_test_ids.dart`
- `LiveFixtureState` in `live_fixture_state.dart`
- cleanup helpers in `live_cleanup.dart` with explicit deletion order for:
  - `guest_cover_entries`
  - `prize_awards`
  - `event_guest_tag_assignments`
  - `table_sessions`
  - `event_tables`
  - `event_guests`
  - `events`
  - `nfc_tags`

- [ ] **Step 4: Re-run the helper tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/integration/live_fixture_factory_test.dart
```

Expected: PASS

### Task 2: Extract the shared live-test harness from the current smoke file

**Files:**
- Modify: `integration_test/live_smoke_test.dart`
- Create: `integration_test/support/live_test_config.dart`
- Create: `integration_test/support/live_test_harness.dart`
- Create: `integration_test/support/live_fixture_factory.dart`
- Create: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write down the support API shape before moving code**

Define focused helpers such as:
- `bootAndSignIn`
- `ensureSignedOut`
- `createEventViaUi`
- `addPaidGuestViaUi`
- `recordCoverEntryViaUi`
- `startEventViaUi`
- `openScoringViaUi`
- `createPointsTableViaUi`
- `bindTableTagViaUi`
- `startSessionViaUi`
- `recordDiscardHandViaUi`
- `recordSelfDrawHandViaUi`
- `recordWashoutViaUi`
- `lockPrizeAwardsViaRpc`
- `assertNoRowsExistForEvent`

- [ ] **Step 2: Move only stable, repeated code into support files**

Keep:
- `HOST_EMAIL` and `HOST_PASSWORD` handling centralized
- `pumpUntilVisible`, `pumpUntilAny`, and back-navigation helpers centralized
- direct Supabase row queries wrapped in backend assertion helpers where reuse is real

- [ ] **Step 3: Keep the existing smoke test green during refactor**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
```

Expected: PASS with no behavior change

- [ ] **Step 4: Run analyze after the extraction**

Run:
```bash
/opt/homebrew/bin/flutter analyze
```

Expected: PASS

## Chunk 2: Add The Golden Path And Edit-Hand Recalculation Scenario

### Task 3: Turn the current broad smoke path into the named golden-path scenario

**Files:**
- Modify or Create: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/live_smoke_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the scenario shell first**

Add a clearly named test:
- `live_golden_full_event_lifecycle`

It should cover:
1. sign in
2. create event
3. start event
4. open check-in
5. add four paid guests
6. add cover entries
7. check in and assign tags
8. create points table
9. bind table tag
10. open scoring
11. start session
12. record discard win, self-draw win, washout
13. verify leaderboard
14. configure prize plan
15. preview and lock awards
16. mark one award paid
17. complete event
18. finalize event
19. verify payout status still mutable post-finalize
20. cleanup

- [ ] **Step 2: Reuse the extracted harness rather than duplicating test steps**

Goal:
- scenario body reads like the business journey
- helper layer hides repetitive tapping and backend row lookup noise

- [ ] **Step 3: Add direct backend assertions for major handoffs**

Verify:
- event status transitions
- checked-in guest attendance state
- active tag assignments exist
- session rows and seat rows exist
- hand rows exist
- leaderboard values are non-trivial and match expected ordering
- prize award row is `paid`
- finalized event has `checkin_open = false` and `scoring_open = false`

- [ ] **Step 4: Run the golden-path scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_golden_full_event_lifecycle
```

Expected: PASS

### Task 4: Add the edit-hand recalculation scenario

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the scenario around an already-started session**

Add:
- `live_mutation_edit_hand_recalculates_leaderboard`

Flow:
- sign in
- create and start event
- prepare four eligible guests
- start a valid session
- record at least two hands
- capture leaderboard and/or session-derived state
- edit an earlier hand through the UI
- verify updated leaderboard and session state differ as expected

- [ ] **Step 2: Assert both visible and backend recalculation**

Verify:
- hand history reflects edited values
- leaderboard totals change after edit
- if current East or dealer progression changes, assert that too

- [ ] **Step 3: Keep this scenario narrower than the golden path**

Do not:
- repeat prize/finalization work
- overgrow the test beyond recalculation behavior

- [ ] **Step 4: Run the recalculation scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_mutation_edit_hand_recalculates_leaderboard
```

Expected: PASS

## Chunk 3: Add The Two Critical Blockers

### Task 5: Add the scoring-closed session-start blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the blocker scenario first**

Add:
- `live_block_scoring_closed_blocks_session_start`

Flow:
- sign in
- create event
- start event
- add four eligible tagged guests
- create points table and bind table tag
- leave `scoring_open = false`
- attempt to start a session

- [ ] **Step 2: Assert the host-facing block and backend absence**

Verify:
- UI surfaces the expected blocked guidance
- no `table_sessions` row exists
- no `table_session_seats` rows exist

- [ ] **Step 3: Re-run only this scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_scoring_closed_blocks_session_start
```

Expected: PASS

### Task 6: Add the active-session finalization blocker

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the finalization-blocker scenario**

Add:
- `live_block_finalize_with_active_session`

Flow:
- sign in
- create and start event
- prepare a valid active session
- move far enough to allow completion attempt
- attempt to complete/finalize while the session is still active

- [ ] **Step 2: Assert the block precisely**

Verify:
- UI explains why finalization is blocked
- event status remains unchanged
- active session row remains present and unchanged

- [ ] **Step 3: Re-run only this scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_block_finalize_with_active_session
```

Expected: PASS

## Chunk 4: Add Locked-Award Reopen And RLS Ownership Coverage

### Task 7: Add the locked-award reopen persistence scenario

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`

- [ ] **Step 1: Write the reopen scenario around a locked prize plan**

Add:
- `live_reopen_locked_prize_flow_preserves_awards_and_names`

Flow:
- sign in
- create event and enough scored state for prize eligibility
- configure and lock prizes
- leave the screen
- reopen the prize flow from the dashboard

- [ ] **Step 2: Assert the exact regression boundaries**

Verify:
- locked awards are shown after reopen
- guest names are shown, not raw IDs
- payout actions remain attached to the correct award rows
- standings order is preserved in the awards list

- [ ] **Step 3: Re-run only this scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_reopen_locked_prize_flow_preserves_awards_and_names
```

Expected: PASS

### Task 8: Add the RLS ownership scenario

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`
- Modify: `integration_test/support/live_test_harness.dart`

- [ ] **Step 1: Decide the safest real-backend path**

Use one of these:
- a second pre-provisioned auth user if available
- or a direct auth-context/backend assertion path that verifies non-owned rows are inaccessible without requiring a second UI account

Prefer the second user if available because it proves RLS more directly.

- [ ] **Step 2: Write the ownership scenario**

Add:
- `live_rls_host_can_only_access_own_event_data`

Verify one of:
- a second host cannot read or mutate the first host’s event data
- or direct row access under the active session cannot reach non-owned seeded rows

Also verify:
- owned rows are still readable to the signed-in host

- [ ] **Step 3: Keep cleanup airtight**

Because this scenario may use multiple auth contexts, ensure:
- sign-out/sign-in transitions are explicit
- created rows are deleted under the correct owner context

- [ ] **Step 4: Re-run only the RLS scenario**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=... --plain-name live_rls_host_can_only_access_own_event_data
```

Expected: PASS

## Chunk 5: Verification, Stabilization, And Handoff

### Task 9: Run the full first-six suite and stabilize flaky helpers

**Files:**
- Modify: `integration_test/live_supabase_first_six_test.dart`
- Modify: `integration_test/support/live_test_harness.dart`
- Modify: `integration_test/support/live_fixture_factory.dart`
- Modify: `integration_test/support/live_backend_assertions.dart`
- Modify: `integration_test/support/live_cleanup.dart`

- [ ] **Step 1: Run all first-six scenarios together**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
```

Expected: all six scenarios PASS

- [ ] **Step 2: Run the broad regression suite**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
```

Expected:
- analyze PASS
- full test suite PASS

- [ ] **Step 3: Verify Supabase residue is zero after the full suite**

Directly verify no leftover rows exist for the generated run prefix across:
- `events`
- `event_guests`
- `guest_cover_entries`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`
- `prize_awards`

Expected: zero residue

- [ ] **Step 4: Update the strategy doc only if the implementation meaningfully changes**

If helpful, add a short note to:
- `docs/superpowers/specs/2026-04-12-live-supabase-test-strategy.md`

Keep it minimal:
- note that the first six scenarios are now implemented or tracked in code

- [ ] **Step 5: Commit**

```bash
git add integration_test test/integration docs/superpowers/plans/2026-04-12-live-supabase-first-six.md
git commit -m "test: add first six live Supabase lifecycle scenarios"
```

## Notes For Execution

- Keep scenario names stable and descriptive because they are now part of the testing strategy vocabulary.
- Prefer extracting helpers only after a second use case appears; avoid building a mini test framework.
- Where a scenario can verify the backend more directly than the UI, pair the UI assertion with a direct Supabase check instead of adding extra taps.
- Do not weaken cleanup discipline for speed. The hosted project must remain clean after every run.
- If the RLS scenario cannot be proven cleanly with only one host account, stop and document the need for a second dedicated test host before proceeding.

## Ready-To-Run Verification Commands

```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
/opt/homebrew/bin/flutter test integration_test/live_supabase_first_six_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
```
