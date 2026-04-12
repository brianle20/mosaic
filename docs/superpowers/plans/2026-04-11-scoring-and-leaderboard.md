# Scoring And Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add HK hand recording, deterministic session recalculation, and a real leaderboard for active Mosaic events.

**Architecture:** Keep scoring server-authoritative in Supabase RPCs and treat session state and standings as derived from ordered hand history. On the Flutter side, add focused scoring and leaderboard features that read the recalculated server truth, with only a lightweight preview in the hand-entry flow.

**Tech Stack:** Flutter, Supabase Postgres migrations/RPC, supabase_flutter, widget tests, repository tests, SQL verification via `psql`, iOS simulator `integration_test`

---

## File Map

- Create: `supabase/migrations/20260411213000_scoring_and_leaderboard.sql`
  - scoring RPCs
  - HK helper functions
  - recalculation path
  - leaderboard query function
- Modify: `lib/data/models/session_models.dart`
  - add hand result and settlement record types if kept session-adjacent
- Create: `lib/data/models/scoring_models.dart`
  - `HandResultRecord`
  - `HandSettlementRecord`
  - `HandResultDraft`
  - `ScoringPreview`
- Create: `lib/data/models/leaderboard_models.dart`
  - `LeaderboardEntry`
  - `EventScoreTotalRecord`
- Modify: `lib/data/local/local_cache.dart`
  - cache session detail and leaderboard snapshots
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - expand session repository
  - add leaderboard repository methods if split
- Modify: `lib/data/repositories/supabase_session_repository.dart`
  - session detail/history load
  - record/edit/void hand RPC wiring
- Create: `lib/data/repositories/supabase_leaderboard_repository.dart`
  - leaderboard query mapping
- Create: `lib/features/scoring/models/hand_result_draft.dart`
  - hand form validation and preview inputs
- Create: `lib/features/scoring/controllers/session_detail_controller.dart`
  - load session detail and hand history
- Create: `lib/features/scoring/controllers/hand_entry_controller.dart`
  - create/edit/void hand flows
- Create: `lib/features/scoring/screens/session_detail_screen.dart`
  - seat map, current East, hand history, record-hand entry point
- Create: `lib/features/scoring/screens/hand_entry_screen.dart`
  - win/washout form and scoring preview
- Create: `lib/features/leaderboard/controllers/leaderboard_controller.dart`
  - fetch standings
- Create: `lib/features/leaderboard/screens/leaderboard_screen.dart`
  - real standings screen
- Modify: `lib/core/routing/app_router.dart`
  - routes/args for session detail, hand entry, leaderboard
- Modify: `lib/app/app.dart`
  - inject scoring/leaderboard repositories
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - add leaderboard quick action if not already real
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`
  - active session card opens session detail
- Modify: `lib/features/tables/screens/start_session_screen.dart`
  - navigate to session detail after start if appropriate
- Test: `test/data/models/domain_model_serialization_test.dart`
  - hand result / leaderboard serialization
- Create: `test/data/repositories/supabase_session_repository_scoring_test.dart`
  - session detail and hand mutation mapping
- Create: `test/data/repositories/supabase_leaderboard_repository_test.dart`
  - leaderboard mapping/order
- Create: `test/features/scoring/models/hand_result_draft_test.dart`
  - validation cases
- Create: `test/features/scoring/screens/session_detail_screen_test.dart`
  - seat map, hand history, record-hand action
- Create: `test/features/scoring/screens/hand_entry_screen_test.dart`
  - conditional fields, preview, save/edit/void UI
- Create: `test/features/leaderboard/screens/leaderboard_screen_test.dart`
  - standings rendering
- Modify: `integration_test/live_smoke_test.dart`
  - extend through hand recording, recalculation, and leaderboard verification

## Chunk 1: Scoring Domain Models And Engine Contract

### Task 1: Add failing model tests for hand results and leaderboard entries

**Files:**
- Modify: `test/data/models/domain_model_serialization_test.dart`
- Create: `lib/data/models/scoring_models.dart`
- Create: `lib/data/models/leaderboard_models.dart`
- Modify: `lib/data/models/session_models.dart`

- [ ] **Step 1: Write failing model tests**

Cover:
- `HandResultRecord` JSON parsing
- `HandSettlementRecord` JSON parsing
- `LeaderboardEntry` parsing from server response
- hand result preserves:
  - `base_points`
  - `east_seat_index_before_hand`
  - `east_seat_index_after_hand`
  - `dealer_rotated`
  - `session_completed_after_hand`

- [ ] **Step 2: Run the model tests to verify failure**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL for missing scoring/leaderboard types

- [ ] **Step 3: Implement the minimal scoring and leaderboard models**

Add:
- `HandResultRecord`
- `HandSettlementRecord`
- `EventScoreTotalRecord`
- `LeaderboardEntry`

Keep them narrowly typed to current RPC/query needs.

- [ ] **Step 4: Re-run the model tests**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS

### Task 2: Add the backend scoring migration and shared recalculation path

**Files:**
- Create: `supabase/migrations/20260411213000_scoring_and_leaderboard.sql`

- [ ] **Step 1: Write the migration**

Include:
- helper function for fan bucket mapping
- helper function(s) for per-payer multiplier calculation
- shared `recalculate_session`
- `record_hand_result`
- `edit_hand_result`
- `void_hand_result`
- `get_event_leaderboard`
- audit logging for hand create/edit/void

- [ ] **Step 2: Re-read the migration against existing schema**

Check:
- ownership flows through event/session ownership and `auth.uid()`
- all hand writes run inside transactions
- `hand_settlements` are rebuilt during recalculation
- `event_score_totals` are refreshed from server-side truth
- session completion uses `dealer_pass_count >= 4`

- [ ] **Step 3: Apply the migration to the remote Supabase project**

Run:
```bash
PGPASSWORD='...' /opt/homebrew/opt/libpq/bin/psql 'postgresql://postgres.<project-ref>@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require' -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260411213000_scoring_and_leaderboard.sql
```

Expected: `CREATE FUNCTION` output and exit code `0`

- [ ] **Step 4: Sanity-check the new RPCs exist**

Run a `psql` query against `pg_proc` or a lightweight authenticated smoke query.
Expected: the new scoring/leaderboard functions are present

## Chunk 2: Repository Layer And HK Engine Test Coverage

### Task 3: Add failing repository tests for session scoring methods

**Files:**
- Create: `test/data/repositories/supabase_session_repository_scoring_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_session_repository.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write failing repository tests**

Cover:
- session detail loads session row, seats, and ordered hands
- record hand maps returned detail correctly
- edit hand maps updated detail correctly
- void hand maps updated detail correctly
- session cache refreshes after scoring mutations

- [ ] **Step 2: Run the repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_session_repository_scoring_test.dart`
Expected: FAIL for missing repository methods / mappings

- [ ] **Step 3: Implement minimal repository changes**

Add:
- `loadSessionDetail`
- `recordHand`
- `editHand`
- `voidHand`
- cache helpers for session detail/history

Prefer a compact session-detail aggregate type instead of scattering several parallel loads through the UI.

- [ ] **Step 4: Re-run the repository tests**

Run: `flutter test test/data/repositories/supabase_session_repository_scoring_test.dart`
Expected: PASS

### Task 4: Add failing repository tests for leaderboard loading

**Files:**
- Create: `test/data/repositories/supabase_leaderboard_repository_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Create: `lib/data/repositories/supabase_leaderboard_repository.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write failing leaderboard repository tests**

Cover:
- `get_event_leaderboard` mapping
- ranking order by total points descending
- leaderboard cache refresh after fetch

- [ ] **Step 2: Run the leaderboard repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_leaderboard_repository_test.dart`
Expected: FAIL for missing repository/contracts

- [ ] **Step 3: Implement minimal leaderboard repository code**

Add:
- interface method(s) for leaderboard load
- `SupabaseLeaderboardRepository`
- lightweight cached standings read path

- [ ] **Step 4: Re-run the leaderboard repository tests**

Run: `flutter test test/data/repositories/supabase_leaderboard_repository_test.dart`
Expected: PASS

### Task 5: Add authoritative HK engine verification cases

**Files:**
- Modify: `supabase/migrations/20260411213000_scoring_and_leaderboard.sql`
- Optionally create: `docs/superpowers/tmp/scoring-verification-notes.md` only if needed during development

- [ ] **Step 1: Write explicit verification cases from the spec**

Cover these scenarios with concrete expected outputs:
- fan bucket mapping for `0, 1, 2, 3, 4, 7, 10, 13`
- discard win where East loses
- self-draw with East as winner
- washout retains East
- non-East win rotates East
- session completion when dealer returns after four passes

- [ ] **Step 2: Run direct SQL verification against the new helper functions / RPC path**

Use `psql` with simple `select` statements or temporary event/session fixtures.
Expected: outputs match the product spec exactly

- [ ] **Step 3: Fix any mismatches in the SQL before moving on**

Do not start UI work until these authoritative server-side cases are correct.

## Chunk 3: Session Detail And Hand Entry UI

### Task 6: Add failing tests for hand form validation and preview state

**Files:**
- Create: `test/features/scoring/models/hand_result_draft_test.dart`
- Create: `lib/features/scoring/models/hand_result_draft.dart`

- [ ] **Step 1: Write failing draft-model tests**

Cover:
- win requires winner, fan count, and win type
- discard requires discarder and discarder != winner
- self-draw requires null discarder
- washout rejects winner/discarder/fan fields
- preview input shape is only valid when the form is valid

- [ ] **Step 2: Run the draft-model tests to verify failure**

Run: `flutter test test/features/scoring/models/hand_result_draft_test.dart`
Expected: FAIL for missing model

- [ ] **Step 3: Implement the minimal draft model**

Add:
- validation getters
- normalized payload builders for create/edit
- preview-friendly seat labels if helpful

- [ ] **Step 4: Re-run the draft-model tests**

Run: `flutter test test/features/scoring/models/hand_result_draft_test.dart`
Expected: PASS

### Task 7: Add failing widget tests for session detail and hand entry

**Files:**
- Create: `test/features/scoring/screens/session_detail_screen_test.dart`
- Create: `test/features/scoring/screens/hand_entry_screen_test.dart`
- Create: `lib/features/scoring/controllers/session_detail_controller.dart`
- Create: `lib/features/scoring/controllers/hand_entry_controller.dart`
- Create: `lib/features/scoring/screens/session_detail_screen.dart`
- Create: `lib/features/scoring/screens/hand_entry_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`
- Modify: `lib/features/tables/screens/start_session_screen.dart`

- [ ] **Step 1: Write failing session-detail and hand-entry widget tests**

Cover:
- session detail renders seat map and current East
- hand history renders ordered hands
- `Record Hand` navigates to hand entry
- hand entry toggles win/washout fields correctly
- scoring preview appears for valid input
- save submits through controller
- historical hand opens edit/void path

- [ ] **Step 2: Run the widget tests to verify failure**

Run:
```bash
flutter test test/features/scoring/screens/session_detail_screen_test.dart test/features/scoring/screens/hand_entry_screen_test.dart
```
Expected: FAIL for missing controllers/screens/routes

- [ ] **Step 3: Implement minimal session detail and hand entry**

Add:
- session detail controller that loads server detail
- hand entry controller for create/edit/void
- separate hand-entry screen, not inline form
- lightweight preview section driven by validated draft input

- [ ] **Step 4: Re-run the widget tests**

Run:
```bash
flutter test test/features/scoring/screens/session_detail_screen_test.dart test/features/scoring/screens/hand_entry_screen_test.dart
```
Expected: PASS

## Chunk 4: Leaderboard UI And Navigation Integration

### Task 8: Add failing widget tests for the real leaderboard screen

**Files:**
- Create: `test/features/leaderboard/screens/leaderboard_screen_test.dart`
- Create: `lib/features/leaderboard/controllers/leaderboard_controller.dart`
- Create: `lib/features/leaderboard/screens/leaderboard_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write failing leaderboard widget tests**

Cover:
- leaderboard renders ordered standings
- rank, player, total points, hands won, and self-draw wins appear
- retry path reloads after error

- [ ] **Step 2: Run the leaderboard widget tests to verify failure**

Run: `flutter test test/features/leaderboard/screens/leaderboard_screen_test.dart`
Expected: FAIL for missing controller/screen/route

- [ ] **Step 3: Implement minimal leaderboard UI**

Add:
- leaderboard controller
- real leaderboard screen
- dashboard route/action to open it

- [ ] **Step 4: Re-run the leaderboard widget tests**

Run: `flutter test test/features/leaderboard/screens/leaderboard_screen_test.dart`
Expected: PASS

### Task 9: Run a focused integration of the new UI surfaces

**Files:**
- Modify only files already touched in this slice

- [ ] **Step 1: Run focused scoring and leaderboard widget tests together**

Run:
```bash
flutter test test/features/scoring/models/hand_result_draft_test.dart test/features/scoring/screens/session_detail_screen_test.dart test/features/scoring/screens/hand_entry_screen_test.dart test/features/leaderboard/screens/leaderboard_screen_test.dart
```
Expected: PASS

- [ ] **Step 2: Run related repository tests together**

Run:
```bash
flutter test test/data/repositories/supabase_session_repository_scoring_test.dart test/data/repositories/supabase_leaderboard_repository_test.dart
```
Expected: PASS

## Chunk 5: Live Smoke Extension And Final Verification

### Task 10: Extend the live iOS simulator smoke test through scoring and recalculation

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Write the failing smoke-test extension**

Extend the flow to:
- sign in
- create event
- add/check in/tag four guests
- create table and start session
- record:
  - one discard win
  - one self-draw win
  - one washout
- verify leaderboard totals change
- edit or void one historical hand
- verify recalculated totals change again
- clean up all created rows

- [ ] **Step 2: Run the live smoke to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD='...'
```
Expected: FAIL until the scoring slice is fully wired

- [ ] **Step 3: Implement the minimal smoke harness updates**

Keep the harness robust:
- use `hitTestable()` finders where route transitions can leave offstage widgets behind
- scope dialog text fields to visible overlays
- query Supabase directly for post-action assertions

- [ ] **Step 4: Re-run the live smoke test**

Run the same simulator command.
Expected: PASS

- [ ] **Step 5: Verify backend cleanup residue is zero**

Run a `psql` query against:
- `events`
- `event_guests`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`

Expected: zero smoke-test residue

### Task 11: Final verification and handoff

**Files:**
- Modify only files already touched in this slice

- [ ] **Step 1: Run formatter**

Run:
```bash
dart format lib test integration_test
```
Expected: formatting completes cleanly

- [ ] **Step 2: Run full static analysis**

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

- [ ] **Step 4: Re-run the live iOS smoke test one final time**

Run the same simulator command from Task 10.
Expected: PASS

- [ ] **Step 5: Summarize residual risks before commit**

Explicitly call out any remaining limitations, especially:
- preview math duplication risk if local preview exists
- lack of prize/finalization locking in this slice
- any intentionally deferred session-end controls
