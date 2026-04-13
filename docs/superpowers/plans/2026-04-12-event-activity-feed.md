# Event Activity Feed Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a host-facing event activity feed that shows newest-first audit history with simple category filtering.

**Architecture:** Keep the feed read-only and server-authoritative by querying `audit_logs` through one event-scoped Supabase RPC that returns normalized category and summary fields. On the Flutter side, add a small activity feature with a focused repository, controller, and screen, then wire it into the existing event dashboard as a simple operational logbook.

**Tech Stack:** Flutter, supabase_flutter, Supabase Postgres SQL migrations/RPC, SharedPreferences local cache, widget tests, repository tests, iOS simulator `integration_test`

---

## File Map

- Create: `supabase/migrations/20260413000000_event_activity_feed.sql`
  - `list_event_activity`
  - summary/category mapping helpers if needed
- Create: `lib/data/models/activity_models.dart`
  - `EventActivityCategory`
  - `EventActivityEntry`
- Modify: `lib/data/local/local_cache.dart`
  - cache event activity lists by event/category
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - add `ActivityRepository`
- Create: `lib/data/repositories/supabase_activity_repository.dart`
  - RPC mapping
  - cache read/write
- Modify: `lib/app/app.dart`
  - inject activity repository
- Modify: `lib/core/routing/app_router.dart`
  - add activity route and args
- Create: `lib/features/activity/controllers/activity_controller.dart`
  - load/filter state
- Create: `lib/features/activity/screens/activity_screen.dart`
  - activity feed UI and filter chips
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - add `Activity` action
- Modify: `test/app/app_auth_gate_test.dart`
  - update injected repository set
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
  - activity action presence/routing
- Create: `test/data/repositories/supabase_activity_repository_test.dart`
  - repository mapping and cache behavior
- Create: `test/features/activity/screens/activity_screen_test.dart`
  - feed rendering, filters, empty state
- Modify: `integration_test/live_smoke_test.dart`
  - verify activity feed shows recent actions

## Chunk 1: Activity Data Contract And Backend RPC

### Task 1: Add failing repository/model tests for activity entries

**Files:**
- Create: `test/data/repositories/supabase_activity_repository_test.dart`
- Create: `lib/data/models/activity_models.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/local/local_cache.dart`

- [ ] **Step 1: Write the failing activity repository tests**

Cover:
- rows map into typed `EventActivityEntry`
- default list order is newest-first
- category filter is included in the repository call
- cache is refreshed after a successful fetch

- [ ] **Step 2: Run the new repository test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_activity_repository_test.dart
```

Expected: FAIL for missing models/repository/cache support

- [ ] **Step 3: Add minimal activity model types**

Implement in `lib/data/models/activity_models.dart`:
- `EventActivityCategory` enum with:
  - `all`
  - `guests`
  - `payments`
  - `sessions`
  - `prizes`
  - `event`
  - `other`
- `EventActivityEntry`
  - `id`
  - `eventId`
  - `entityType`
  - `entityId`
  - `action`
  - `category`
  - `summaryText`
  - `reason`
  - `metadataJson`
  - `createdAt`

- [ ] **Step 4: Add repository and cache contracts**

Extend `repository_interfaces.dart` with:
- `abstract interface class ActivityRepository`
- `Future<List<EventActivityEntry>> readCachedActivity(String eventId, EventActivityCategory category)`
- `Future<List<EventActivityEntry>> loadActivity(String eventId, EventActivityCategory category)`

Extend `LocalCache` with:
- event/category-scoped activity keys
- `saveActivity`
- `readActivity`

- [ ] **Step 5: Re-run the repository test**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_activity_repository_test.dart
```

Expected: still FAIL, but now at the concrete repository implementation boundary

### Task 2: Add the activity-feed migration and SQL verification

**Files:**
- Create: `supabase/migrations/20260413000000_event_activity_feed.sql`

- [ ] **Step 1: Write the migration**

Add:
- `public.list_event_activity(target_event_id uuid, target_category text default 'all')`

Implement:
- event ownership validation through existing owner helper
- newest-first ordering by `created_at desc, id desc`
- broad category mapping from `entity_type` / `action`
- stable `summary_text` generation for current audited actions

Suggested category mapping:
- `event_guest`, `event_guest_tag_assignment` -> `guests`
- `guest_cover_entry` -> `payments`
- `event_table`, `table_session`, `hand_result` -> `sessions`
- `prize_plan`, `prize_award` -> `prizes`
- `event` -> `event`
- fallback -> `other`

- [ ] **Step 2: Re-read the SQL against the product boundary**

Check:
- no writes
- no raw admin-only exposure
- summaries are short and stable, not overly clever
- `all` returns every event-scoped row
- specific categories only return matching rows

- [ ] **Step 3: Apply the migration to Supabase**

Run:
```bash
env PGPASSWORD='ovhQW^Nu6#Ta0OuDY0z&rfmvC' /opt/homebrew/opt/libpq/bin/psql "postgresql://postgres.uznzxjjdzjcqremvfqnp@aws-1-us-east-1.pooler.supabase.com:5432/postgres?sslmode=require" -v ON_ERROR_STOP=1 -f /Users/brian/Documents/repos/mosaic/supabase/migrations/20260413000000_event_activity_feed.sql
```

Expected: `CREATE FUNCTION` output and exit code `0`

- [ ] **Step 4: Directly verify the RPC**

Use a temporary event and one or two audited actions, then verify:
- `all` returns rows newest-first
- `payments` includes cover-entry rows
- `event` includes lifecycle rows
- summary text is non-empty

Expected: SQL/RPC check passes and temporary data is cleaned up

## Chunk 2: Repository Implementation And Dashboard Wiring

### Task 3: Implement the Supabase activity repository

**Files:**
- Create: `lib/data/repositories/supabase_activity_repository.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/data/local/local_cache.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`

- [ ] **Step 1: Write the minimal repository implementation**

Implement:
- `loadActivity`
  - calls `list_event_activity`
  - maps rows to `EventActivityEntry`
  - saves category-scoped cache
- `readCachedActivity`
  - reads cached entries only

- [ ] **Step 2: Wire the repository into app startup**

Update:
- `_loadRepositories()` in `lib/app/app.dart`
- `_AppWithRepositories`
- `AppRouter` constructor call sites

- [ ] **Step 3: Re-run the repository tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/data/repositories/supabase_activity_repository_test.dart
```

Expected: PASS

### Task 4: Add dashboard route and failing dashboard/widget tests

**Files:**
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
- Modify: `test/app/app_auth_gate_test.dart`

- [ ] **Step 1: Write the failing dashboard tests**

Cover:
- dashboard shows an `Activity` action
- tapping it navigates to the activity screen route

- [ ] **Step 2: Run the dashboard tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: FAIL because the route/action do not exist yet

- [ ] **Step 3: Add route args and dashboard action**

Implement:
- `AppRouter.activityRoute`
- `ActivityArgs`
- dashboard `FilledButton` or `OutlinedButton` for `Activity`

- [ ] **Step 4: Update test fakes for the new repository dependency**

Touch:
- `test/app/app_auth_gate_test.dart`
- any other test harness that builds `MosaicApp` or `AppRouter`

- [ ] **Step 5: Re-run the dashboard tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: PASS

## Chunk 3: Activity Screen And Filter UX

### Task 5: Add failing widget tests for the activity screen

**Files:**
- Create: `lib/features/activity/controllers/activity_controller.dart`
- Create: `lib/features/activity/screens/activity_screen.dart`
- Create: `test/features/activity/screens/activity_screen_test.dart`

- [ ] **Step 1: Write the failing activity-screen widget tests**

Cover:
- initial feed renders newest-first rows
- filter chips switch categories
- empty state renders for no rows
- optional reason line shows when present

- [ ] **Step 2: Run the widget tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/activity/screens/activity_screen_test.dart
```

Expected: FAIL because the feature does not exist yet

- [ ] **Step 3: Implement the controller**

Add:
- `isLoading`
- `error`
- `selectedCategory`
- `entries`
- `load(eventId)`
- `selectCategory(category)`

Behavior:
- show cached rows first if available
- refresh from repository
- refetch on category change

- [ ] **Step 4: Implement the screen**

Render:
- app bar title `Activity`
- category filter chips
- activity list rows with:
  - summary
  - timestamp
  - optional reason/secondary line
- empty state:
  - `No activity yet for this event.`

- [ ] **Step 5: Re-run the activity widget tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/activity/screens/activity_screen_test.dart
```

Expected: PASS

## Chunk 4: Live Smoke, Full Verification, And Cleanup

### Task 6: Extend the live smoke test for the activity feed

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Extend the live host flow**

After existing audited actions occur:
- open `Activity` from the dashboard
- verify at least a few real rows are visible, such as:
  - event started
  - cover entry recorded
  - guest checked in
- switch to `Payments` and confirm the cover-entry row appears

- [ ] **Step 2: Keep cleanup complete**

Ensure any temporary rows already created by the smoke flow continue to be deleted.

- [ ] **Step 3: Run focused verification**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test test/data/repositories/supabase_activity_repository_test.dart test/features/activity/screens/activity_screen_test.dart test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: all PASS

- [ ] **Step 4: Run full verification**

Run:
```bash
/opt/homebrew/bin/flutter test
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL='brian.le1678@gmail.com' --dart-define=HOST_PASSWORD='12345678!'
```

Expected: all PASS

- [ ] **Step 5: Run final Supabase residue check**

Verify these remain `0` after cleanup:
- `events`
- `event_guests`
- `guest_cover_entries`
- `nfc_tags`
- `event_tables`
- `table_sessions`
- `hand_results`
- `hand_settlements`
- `prize_awards`

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/2026-04-12-event-activity-feed.md \
  supabase/migrations/20260413000000_event_activity_feed.sql \
  lib/data/models/activity_models.dart \
  lib/data/local/local_cache.dart \
  lib/data/repositories/repository_interfaces.dart \
  lib/data/repositories/supabase_activity_repository.dart \
  lib/app/app.dart \
  lib/core/routing/app_router.dart \
  lib/features/activity/controllers/activity_controller.dart \
  lib/features/activity/screens/activity_screen.dart \
  lib/features/events/screens/event_dashboard_screen.dart \
  test/data/repositories/supabase_activity_repository_test.dart \
  test/features/activity/screens/activity_screen_test.dart \
  test/features/events/screens/event_dashboard_screen_test.dart \
  test/app/app_auth_gate_test.dart \
  integration_test/live_smoke_test.dart
git commit -m "feat: add event activity feed"
```

