# Events And Guests Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a real host workflow for creating events, opening an event dashboard, and adding/editing guests in a persisted guest roster.

**Architecture:** Add a feature-first Flutter slice for events and guests, backed by concrete Supabase repositories and a lightweight local JSON cache. Keep controllers simple with `ChangeNotifier`, route explicitly between the new screens, and preserve the Phase 1 typed model boundaries.

**Tech Stack:** Flutter, Dart, Supabase Flutter, Shared Preferences, Flutter test

---

## File Map

- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Modify: `lib/app/app.dart`
- Modify: `lib/data/models/event_models.dart`
- Modify: `lib/data/models/guest_models.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Create: `lib/core/routing/app_router.dart`
- Create: `lib/core/widgets/async_body.dart`
- Create: `lib/data/local/local_cache.dart`
- Create: `lib/data/repositories/supabase_event_repository.dart`
- Create: `lib/data/repositories/supabase_guest_repository.dart`
- Create: `lib/features/events/controllers/event_list_controller.dart`
- Create: `lib/features/events/controllers/event_form_controller.dart`
- Create: `lib/features/events/controllers/event_dashboard_controller.dart`
- Create: `lib/features/events/models/event_form_draft.dart`
- Create: `lib/features/events/screens/event_list_screen.dart`
- Create: `lib/features/events/screens/create_event_screen.dart`
- Create: `lib/features/events/screens/event_dashboard_screen.dart`
- Create: `lib/features/guests/controllers/guest_roster_controller.dart`
- Create: `lib/features/guests/controllers/guest_form_controller.dart`
- Create: `lib/features/guests/models/guest_form_draft.dart`
- Create: `lib/features/guests/screens/guest_roster_screen.dart`
- Create: `lib/features/guests/screens/guest_form_screen.dart`
- Create: `test/features/events/models/event_form_draft_test.dart`
- Create: `test/features/guests/models/guest_form_draft_test.dart`
- Create: `test/data/repositories/supabase_event_repository_test.dart`
- Create: `test/data/repositories/supabase_guest_repository_test.dart`
- Create: `test/features/events/screens/create_event_screen_test.dart`
- Create: `test/features/events/screens/event_list_screen_test.dart`
- Create: `test/features/guests/screens/guest_roster_screen_test.dart`
- Create: `test/features/guests/screens/guest_form_screen_test.dart`

## Chunk 1: Data And Routing Foundation

### Task 1: Add cache and repository dependencies

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`

- [ ] **Step 1: Add the failing repository/cache test imports**

Reference the planned repository test files so package resolution will fail until the dependency set is complete.

- [ ] **Step 2: Run a focused test command to verify red**

Run: `/opt/homebrew/bin/flutter test test/data/repositories/supabase_event_repository_test.dart`
Expected: FAIL because the test file and dependencies do not exist yet.

- [ ] **Step 3: Add the minimal new dependency**

Add `shared_preferences` to `pubspec.yaml` and refresh the lockfile with `flutter pub get`.

- [ ] **Step 4: Re-run package resolution verification**

Run: `/opt/homebrew/bin/flutter pub get`
Expected: completes successfully with updated lockfile.

### Task 2: Add app routing shell

**Files:**
- Modify: `lib/app/app.dart`
- Create: `lib/core/routing/app_router.dart`
- Create: `lib/core/widgets/async_body.dart`

- [ ] **Step 1: Write a failing widget test for the event list entry screen**

Create `test/features/events/screens/event_list_screen_test.dart` with a test that expects the app to show an events screen title and create-event action.

- [ ] **Step 2: Run the focused widget test to verify red**

Run: `/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart`
Expected: FAIL because routing and the screen do not exist yet.

- [ ] **Step 3: Implement the minimal routing shell**

Replace the Phase 1 placeholder home with a router that lands on the events list screen and includes helpers for event dashboard and guest routes.

- [ ] **Step 4: Re-run the widget test**

Run: `/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart`
Expected: still FAIL, but now only because the concrete event screen is missing.

## Chunk 2: Event Vertical Slice

### Task 3: Event form draft and validation

**Files:**
- Create: `lib/features/events/models/event_form_draft.dart`
- Create: `test/features/events/models/event_form_draft_test.dart`

- [ ] **Step 1: Write failing tests for event validation**

Cover required title, required timezone, non-negative cover charge, and non-negative prize budget.

- [ ] **Step 2: Run the focused test to verify red**

Run: `/opt/homebrew/bin/flutter test test/features/events/models/event_form_draft_test.dart`
Expected: FAIL because the draft model does not exist yet.

- [ ] **Step 3: Implement the minimal draft model**

Add immutable draft state plus validation helpers and a payload builder for repository writes.

- [ ] **Step 4: Re-run the focused test**

Run: `/opt/homebrew/bin/flutter test test/features/events/models/event_form_draft_test.dart`
Expected: PASS.

### Task 4: Event repository mapping and local cache

**Files:**
- Create: `lib/data/local/local_cache.dart`
- Create: `lib/data/repositories/supabase_event_repository.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/models/event_models.dart`
- Create: `test/data/repositories/supabase_event_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover event row parsing, create payload generation, and cache round-trip behavior for event summaries.

- [ ] **Step 2: Run the focused repository tests to verify red**

Run: `/opt/homebrew/bin/flutter test test/data/repositories/supabase_event_repository_test.dart`
Expected: FAIL because the repository and cache do not exist yet.

- [ ] **Step 3: Implement the minimal cache and event repository**

Add a shared-preferences-backed JSON cache, extend the event model if needed for summaries, and implement list/create/get methods in the concrete repository.

- [ ] **Step 4: Re-run the focused repository tests**

Run: `/opt/homebrew/bin/flutter test test/data/repositories/supabase_event_repository_test.dart`
Expected: PASS.

### Task 5: Event list, create event, and dashboard screens

**Files:**
- Create: `lib/features/events/controllers/event_list_controller.dart`
- Create: `lib/features/events/controllers/event_form_controller.dart`
- Create: `lib/features/events/controllers/event_dashboard_controller.dart`
- Create: `lib/features/events/screens/event_list_screen.dart`
- Create: `lib/features/events/screens/create_event_screen.dart`
- Create: `lib/features/events/screens/event_dashboard_screen.dart`
- Create: `test/features/events/screens/event_list_screen_test.dart`
- Create: `test/features/events/screens/create_event_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for the event flow**

Cover event list rendering, create-event form validation feedback, and successful navigation to dashboard after save.

- [ ] **Step 2: Run the focused widget tests to verify red**

Run: `/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart test/features/events/screens/create_event_screen_test.dart`
Expected: FAIL because controllers and screens are missing.

- [ ] **Step 3: Implement the minimal event screens and controllers**

Add the list, form, and dashboard UIs with repository-backed controllers and straightforward route navigation.

- [ ] **Step 4: Re-run the focused widget tests**

Run: `/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart test/features/events/screens/create_event_screen_test.dart`
Expected: PASS.

## Chunk 3: Guest Vertical Slice

### Task 6: Guest form draft and duplicate-name warning

**Files:**
- Create: `lib/features/guests/models/guest_form_draft.dart`
- Create: `test/features/guests/models/guest_form_draft_test.dart`

- [ ] **Step 1: Write failing tests for guest validation**

Cover required display name, non-negative cover amount, and duplicate-name warning helper behavior.

- [ ] **Step 2: Run the focused test to verify red**

Run: `/opt/homebrew/bin/flutter test test/features/guests/models/guest_form_draft_test.dart`
Expected: FAIL because the draft model does not exist yet.

- [ ] **Step 3: Implement the minimal guest draft model**

Add validation and duplicate-name warning helpers while preserving optional phone/email fields.

- [ ] **Step 4: Re-run the focused test**

Run: `/opt/homebrew/bin/flutter test test/features/guests/models/guest_form_draft_test.dart`
Expected: PASS.

### Task 7: Guest repository mapping and cache integration

**Files:**
- Create: `lib/data/repositories/supabase_guest_repository.dart`
- Modify: `lib/data/models/guest_models.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/local/local_cache.dart`
- Create: `test/data/repositories/supabase_guest_repository_test.dart`

- [ ] **Step 1: Write failing repository tests**

Cover guest row parsing, create/update payload generation, guest-list cache round-trip, and duplicate-name comparison inputs.

- [ ] **Step 2: Run the focused repository tests to verify red**

Run: `/opt/homebrew/bin/flutter test test/data/repositories/supabase_guest_repository_test.dart`
Expected: FAIL because the repository implementation does not exist yet.

- [ ] **Step 3: Implement the minimal guest repository**

Add list, create, and update operations plus cache reads/writes for guests by `event_id`.

- [ ] **Step 4: Re-run the focused repository tests**

Run: `/opt/homebrew/bin/flutter test test/data/repositories/supabase_guest_repository_test.dart`
Expected: PASS.

### Task 8: Guest roster and add/edit guest screens

**Files:**
- Create: `lib/features/guests/controllers/guest_roster_controller.dart`
- Create: `lib/features/guests/controllers/guest_form_controller.dart`
- Create: `lib/features/guests/screens/guest_roster_screen.dart`
- Create: `lib/features/guests/screens/guest_form_screen.dart`
- Create: `test/features/guests/screens/guest_roster_screen_test.dart`
- Create: `test/features/guests/screens/guest_form_screen_test.dart`

- [ ] **Step 1: Write failing widget tests for the guest flow**

Cover roster rendering, add-guest validation, and successful add/edit navigation back to roster.

- [ ] **Step 2: Run the focused widget tests to verify red**

Run: `/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart test/features/guests/screens/guest_form_screen_test.dart`
Expected: FAIL because the guest controllers and screens are missing.

- [ ] **Step 3: Implement the minimal guest screens and controllers**

Add the roster and shared add/edit form with event-scoped repository calls and duplicate-name warning display.

- [ ] **Step 4: Re-run the focused widget tests**

Run: `/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart test/features/guests/screens/guest_form_screen_test.dart`
Expected: PASS.

## Chunk 4: End-To-End Verification

### Task 9: Full slice verification

**Files:**
- Verify: routing, repositories, controllers, screens, and tests from previous chunks

- [ ] **Step 1: Run formatter**

Run: `/opt/homebrew/bin/dart format lib test`
Expected: all Dart files formatted successfully.

- [ ] **Step 2: Run static analysis**

Run: `/opt/homebrew/bin/flutter analyze`
Expected: no issues found.

- [ ] **Step 3: Run full test suite**

Run: `/opt/homebrew/bin/flutter test`
Expected: all tests pass.

- [ ] **Step 4: Verify the feature outcome**

Manually inspect the route structure and repository APIs to ensure the vertical slice supports:
- event list
- create event
- event dashboard
- guest roster
- add/edit guest

