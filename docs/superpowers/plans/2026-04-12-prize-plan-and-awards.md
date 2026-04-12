# Prize Plan And Awards Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the MVP prize workflow for Mosaic: configure a prize plan, preview derived awards from live standings, lock official prize awards, and track payout status.

**Architecture:** Keep prize logic server-authoritative in Supabase RPCs layered on top of the existing leaderboard and event schema. On the Flutter side, add a focused `prizes` feature with a compact plan editor, preview/locked-awards screens, and a `SupabasePrizeRepository` that reads preview data and mutates locked awards through RPCs rather than client-side math.

**Tech Stack:** Flutter, supabase_flutter, Supabase Postgres SQL migrations/RPC, widget tests, repository tests, iOS simulator integration_test

---

## File Map

- Create: `supabase/migrations/20260412120000_prize_plan_and_awards.sql`
  - prize RPCs
  - allocation helpers
  - lock/payout mutations
- Modify: `lib/data/models/prize_models.dart`
  - extend existing prize plan model set
- Create: `lib/features/prizes/models/prize_plan_draft.dart`
  - plan form validation
- Create: `lib/data/repositories/supabase_prize_repository.dart`
  - prize plan load/upsert
  - preview load
  - lock awards
  - payout status updates
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - expand `PrizeRepository`
- Modify: `lib/data/local/local_cache.dart`
  - cache prize plan, preview, and locked awards snapshots
- Create: `lib/features/prizes/controllers/prize_plan_controller.dart`
  - plan editing, preview, and lock flow
- Create: `lib/features/prizes/controllers/prize_awards_controller.dart`
  - locked awards list and payout tracking actions
- Create: `lib/features/prizes/screens/prize_plan_screen.dart`
  - mode, reserve, tiers, preview, lock action
- Create: `lib/features/prizes/screens/prize_awards_screen.dart`
  - locked awards list with mark paid / void actions
- Modify: `lib/core/routing/app_router.dart`
  - prize routes and arguments
- Modify: `lib/app/app.dart`
  - inject `PrizeRepository`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - real `Prizes` quick action
- Modify: `test/data/models/domain_model_serialization_test.dart`
  - prize tier / award / preview parsing coverage
- Create: `test/data/repositories/supabase_prize_repository_test.dart`
  - repository mapping and mutation coverage
- Create: `test/features/prizes/models/prize_plan_draft_test.dart`
  - draft validation coverage
- Create: `test/features/prizes/screens/prize_plan_screen_test.dart`
  - plan validation, preview, lock UI
- Create: `test/features/prizes/screens/prize_awards_screen_test.dart`
  - payout status actions UI
- Modify: `integration_test/live_smoke_test.dart`
  - extend through prize plan, lock, and mark paid

## Chunk 1: Prize Domain Models And Server Contract

### Task 1: Add failing model tests for tiers, preview rows, and awards

**Files:**
- Modify: `test/data/models/domain_model_serialization_test.dart`
- Modify: `lib/data/models/prize_models.dart`

- [ ] **Step 1: Write failing model tests**

Cover:
- `PrizeTierRecord` JSON parsing
- `PrizeAwardRecord` JSON parsing
- `PrizeAwardPreviewRow` JSON parsing
- distributable budget still clamps at zero
- shared-rank display fields are preserved

- [ ] **Step 2: Run the model tests to verify failure**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL for missing prize record types / parsing

- [ ] **Step 3: Implement the minimal model extensions**

Add:
- `PrizeTierRecord`
- `PrizeAwardRecord`
- `PrizeAwardPreviewRow`
- payout status enum if not already represented

Keep the existing `PrizePlanRecord` as the root event-level plan record instead of introducing a parallel plan type.

- [ ] **Step 4: Re-run the model tests**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS

### Task 2: Add the backend prize migration and award-allocation RPCs

**Files:**
- Create: `supabase/migrations/20260412120000_prize_plan_and_awards.sql`

- [ ] **Step 1: Write the migration**

Include:
- allocation helper(s) for:
  - fixed mode
  - percentage mode
  - reserve math
  - tie splitting
  - deterministic leftover-cent ordering
- `upsert_prize_plan`
- `preview_prize_awards`
- `lock_prize_awards`
- `mark_prize_award_paid`
- `void_prize_award`
- audit logging for:
  - plan update
  - award lock
  - paid/void status change

- [ ] **Step 2: Re-read the migration against the approved spec**

Check:
- ranking comes from server-derived standings
- only scored guests are eligible
- no secondary tiebreak is added
- lock persists `prize_awards`
- payout tracking only operates on locked awards
- awards are blocked when total exceeds distributable budget

- [ ] **Step 3: Apply the migration to the remote Supabase project**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260412120000_prize_plan_and_awards.sql
```

Expected: `CREATE FUNCTION` / `CREATE OR REPLACE FUNCTION` output and exit code `0`

- [ ] **Step 4: Sanity-check the new RPCs exist**

Run a `psql` query against `pg_proc`.
Expected: all prize functions are present

## Chunk 2: Prize Repository Layer And Authoritative Allocation Verification

### Task 3: Add failing repository tests for prize plan load/upsert and preview

**Files:**
- Create: `test/data/repositories/supabase_prize_repository_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Create: `lib/data/repositories/supabase_prize_repository.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write failing repository tests**

Cover:
- load existing prize plan with event prize budget context
- upsert plan returns the saved plan and ordered tiers
- preview maps ordered award rows
- cached plan and preview refresh after repository calls

- [ ] **Step 2: Run the repository tests to verify failure**

Run: `flutter test test/data/repositories/supabase_prize_repository_test.dart`
Expected: FAIL for missing repository methods / mappings

- [ ] **Step 3: Implement minimal repository changes**

Expand `PrizeRepository` to include:
- `loadPrizePlan`
- `upsertPrizePlan`
- `readCachedPrizePreview`
- `loadPrizePreview`
- `lockPrizeAwards`
- `readCachedPrizeAwards`
- `loadPrizeAwards`
- `markPrizeAwardPaid`
- `voidPrizeAward`

Implement `SupabasePrizeRepository` using the new RPCs and local cache helpers.

- [ ] **Step 4: Re-run the repository tests**

Run: `flutter test test/data/repositories/supabase_prize_repository_test.dart`
Expected: PASS

### Task 4: Add authoritative SQL verification cases for prize allocation

**Files:**
- Modify: `supabase/migrations/20260412120000_prize_plan_and_awards.sql`

- [ ] **Step 1: Write explicit verification cases from the spec**

Cover:
- distributable budget with fixed reserve
- distributable budget with percentage reserve
- fixed tiers within budget
- fixed tiers exceeding budget
- percentage allocation sums correctly
- tie split across affected ranks
- leftover cents go to best rank then alphabetical name order
- only guests with scored play receive awards

- [ ] **Step 2: Run direct SQL verification against the helper functions / preview RPC**

Use temporary event and score fixtures in `psql`.
Expected: outputs match the product spec exactly

- [ ] **Step 3: Fix any mismatches before UI work**

Do not start screens until preview and lock math is correct server-side.

## Chunk 3: Prize Draft, Controllers, And Screen Flows

### Task 5: Add failing draft-validation tests for prize plan editing

**Files:**
- Create: `test/features/prizes/models/prize_plan_draft_test.dart`
- Create: `lib/features/prizes/models/prize_plan_draft.dart`

- [ ] **Step 1: Write failing draft tests**

Cover:
- valid `none` mode
- fixed mode requires fixed tiers
- percentage mode requires percentage tiers
- duplicate places are invalid
- negative reserve values are invalid
- reserve percentage outside `0..10000` is invalid
- malformed tiers are rejected before preview/lock

- [ ] **Step 2: Run the draft tests to verify failure**

Run: `flutter test test/features/prizes/models/prize_plan_draft_test.dart`
Expected: FAIL for missing draft model / validation

- [ ] **Step 3: Implement the minimal draft model**

Add:
- prize plan draft object
- draft tier model
- validation getters
- conversion to repository input

- [ ] **Step 4: Re-run the draft tests**

Run: `flutter test test/features/prizes/models/prize_plan_draft_test.dart`
Expected: PASS

### Task 6: Add failing widget tests for the prize plan screen

**Files:**
- Create: `test/features/prizes/screens/prize_plan_screen_test.dart`
- Create: `lib/features/prizes/controllers/prize_plan_controller.dart`
- Create: `lib/features/prizes/screens/prize_plan_screen.dart`

- [ ] **Step 1: Write failing widget tests**

Cover:
- renders current event budget and mode selector
- validates malformed tiers
- shows preview rows after preview load
- blocks `Lock Prize Awards` when configuration is invalid
- allows lock when preview validates

- [ ] **Step 2: Run the widget tests to verify failure**

Run: `flutter test test/features/prizes/screens/prize_plan_screen_test.dart`
Expected: FAIL for missing controller/screen

- [ ] **Step 3: Implement the minimal plan controller and screen**

UI should include:
- mode selector
- reserve inputs
- tier editor
- preview section
- `Lock Prize Awards` action

Keep layout operational and compact rather than decorative.

- [ ] **Step 4: Re-run the widget tests**

Run: `flutter test test/features/prizes/screens/prize_plan_screen_test.dart`
Expected: PASS

### Task 7: Add failing widget tests for the locked prize awards screen

**Files:**
- Create: `test/features/prizes/screens/prize_awards_screen_test.dart`
- Create: `lib/features/prizes/controllers/prize_awards_controller.dart`
- Create: `lib/features/prizes/screens/prize_awards_screen.dart`

- [ ] **Step 1: Write failing widget tests**

Cover:
- renders locked awards list with ranks, names, amounts, and statuses
- shows `paid` and `void` actions for planned awards
- updates UI after mark paid
- updates UI after void

- [ ] **Step 2: Run the widget tests to verify failure**

Run: `flutter test test/features/prizes/screens/prize_awards_screen_test.dart`
Expected: FAIL for missing controller/screen

- [ ] **Step 3: Implement the minimal awards controller and screen**

Keep actions simple:
- `Mark Paid`
- `Void`

Surface status and payout metadata without building a heavy admin panel.

- [ ] **Step 4: Re-run the widget tests**

Run: `flutter test test/features/prizes/screens/prize_awards_screen_test.dart`
Expected: PASS

## Chunk 4: App Integration, Routing, And Dashboard Entry Point

### Task 8: Wire prize routes and repository injection

**Files:**
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write or extend failing UI tests where routing changes matter**

Cover:
- dashboard exposes a real `Prizes` action
- routing into prize plan screen works

- [ ] **Step 2: Run focused tests to verify failure**

Run:
```bash
flutter test test/app/app_auth_gate_test.dart test/features/events/screens/event_list_screen_test.dart
```

Expected: FAIL if constructor wiring / navigation contracts are incomplete

- [ ] **Step 3: Implement routing and dependency wiring**

Add:
- prize plan route
- prize awards route
- prize repository injection through `MosaicApp`
- event dashboard quick action to open prizes

- [ ] **Step 4: Re-run the focused tests**

Run:
```bash
flutter test test/app/app_auth_gate_test.dart test/features/events/screens/event_list_screen_test.dart
```

Expected: PASS

### Task 9: Run the full local verification set before live smoke

**Files:**
- All prize-related files above

- [ ] **Step 1: Format changed files**

Run: `dart format lib test`
Expected: format completes cleanly

- [ ] **Step 2: Run analyze**

Run: `/opt/homebrew/bin/flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the full Flutter test suite**

Run: `/opt/homebrew/bin/flutter test`
Expected: all tests pass

## Chunk 5: Live Prize Smoke Test And Cleanup Verification

### Task 10: Extend the live smoke test through prizes

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Add failing live-smoke assertions**

Extend the existing flow to:
- create event
- score hands for non-trivial standings
- open prizes
- configure prize plan
- preview awards
- lock awards
- mark one award paid
- verify backend rows

- [ ] **Step 2: Run the live smoke test to capture the first failure**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD='12345678!'
```

Expected: FAIL at the first unimplemented prize step

- [ ] **Step 3: Implement the minimal integration changes**

Update the smoke harness to use the new prize UI and verify:
- preview totals
- locked `prize_awards`
- payout status update

- [ ] **Step 4: Re-run the live smoke test**

Run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=brian.le1678@gmail.com --dart-define=HOST_PASSWORD='12345678!'
```

Expected: PASS

### Task 11: Verify remote cleanup leaves no smoke residue

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

Keep cleanup surgical and limited to smoke data.

### Task 12: Final verification before completion

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

Re-run the residue check from Task 11.
Expected: zero smoke residue

- [ ] **Step 3: Hand off for completion workflow**

After all verification passes, use `superpowers:finishing-a-development-branch` before claiming completion or committing.
