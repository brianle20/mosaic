# Host Auth Slice Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add single-host Supabase authentication with secure row-level access so the existing event and guest flow only runs for an authenticated host.

**Architecture:** Add a small auth feature layer in Flutter, an auth repository around Supabase Auth, and an auth-aware app shell that gates the existing router behind session state. Pair that with a Supabase migration that mirrors `auth.users` into `public.users` and enables owner-scoped RLS policies for the current and near-future event tables.

**Tech Stack:** Flutter, Dart, `supabase_flutter`, Supabase Postgres SQL migrations, Flutter widget tests

---

## File Structure

### Create

- `docs/superpowers/plans/2026-04-11-host-auth-slice.md`
- `lib/data/models/auth_models.dart`
- `lib/data/repositories/supabase_auth_repository.dart`
- `lib/features/auth/controllers/auth_controller.dart`
- `lib/features/auth/models/host_sign_in_draft.dart`
- `lib/features/auth/screens/host_sign_in_screen.dart`
- `supabase/migrations/20260411130000_host_auth_and_rls.sql`
- `test/data/repositories/supabase_auth_repository_test.dart`
- `test/features/auth/controllers/auth_controller_test.dart`
- `test/features/auth/models/host_sign_in_draft_test.dart`
- `test/features/auth/screens/host_sign_in_screen_test.dart`
- `test/app/app_auth_gate_test.dart`

### Modify

- `lib/app/app.dart`
- `lib/core/routing/app_router.dart`
- `lib/data/repositories/repository_interfaces.dart`
- `lib/data/repositories/supabase_event_repository.dart`
- `lib/features/events/screens/event_list_screen.dart`
- `test/features/events/screens/event_list_screen_test.dart`

## Chunk 1: Backend Security And Auth Data Shape

### Task 1: Add auth/domain interfaces before wiring UI

**Files:**
- Create: `lib/data/models/auth_models.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Test: `test/data/repositories/supabase_auth_repository_test.dart`

- [ ] **Step 1: Write the failing auth model and repository contract test**

Add a small test that expects:
- a host auth record model with `id` and `email`
- an `AuthRepository` interface with:
  - `currentHost`
  - `signInWithPassword`
  - `signOut`
  - `authStateChanges`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/supabase_auth_repository_test.dart`
Expected: FAIL because auth model and repository contract do not exist yet

- [ ] **Step 3: Add the minimal auth model and repository interface**

Implement:
- `HostAuthUser` in `lib/data/models/auth_models.dart`
- `AuthRepository` in `lib/data/repositories/repository_interfaces.dart`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/supabase_auth_repository_test.dart`
Expected: PASS

### Task 2: Add the auth and RLS migration

**Files:**
- Create: `supabase/migrations/20260411130000_host_auth_and_rls.sql`

- [ ] **Step 1: Write the migration checklist in comments**

Document these required outcomes:
- mirror `auth.users` into `public.users`
- enable RLS on protected tables
- add owner-scoped policies

- [ ] **Step 2: Implement the auth mirror function and trigger**

Add SQL for:
- `app_private.handle_auth_user_sync()`
- trigger on `auth.users`

Behavior:
- insert or update `public.users`
- copy `id` and `email`
- derive `display_name` from email when missing

- [ ] **Step 3: Enable RLS on current and near-future event tables**

Enable RLS on:
- `public.users`
- `public.events`
- `public.event_guests`
- `public.guest_cover_entries`
- `public.event_guest_tag_assignments`
- `public.event_tables`
- `public.table_sessions`
- `public.table_session_seats`
- `public.hand_results`
- `public.hand_settlements`
- `public.event_score_totals`
- `public.prize_plans`
- `public.prize_tiers`
- `public.prize_awards`
- `public.audit_logs`

- [ ] **Step 4: Add owner-scoped policies**

Add policies that enforce:
- `public.users`: user may select/update only their own row
- `public.events`: owner may select/insert/update/delete only their own events
- child tables: access allowed only through ownership of the parent event

- [ ] **Step 5: Apply the migration to Supabase**

Run the same verified pooler pattern:

```bash
PGPASSWORD='***' /opt/homebrew/opt/libpq/bin/psql "sslmode=require host=aws-1-us-east-1.pooler.supabase.com port=5432 dbname=postgres user=postgres.uznzxjjdzjcqremvfqnp connect_timeout=10" -v ON_ERROR_STOP=1 -f supabase/migrations/20260411130000_host_auth_and_rls.sql
```

Expected: SQL executes without errors

## Chunk 2: Auth Repository And App Shell

### Task 3: Implement the Supabase auth repository with tests

**Files:**
- Create: `lib/data/repositories/supabase_auth_repository.dart`
- Test: `test/data/repositories/supabase_auth_repository_test.dart`

- [ ] **Step 1: Expand the test to cover repository behavior**

Cover:
- `currentHost` maps Supabase current user
- `signInWithPassword` returns mapped host user
- `signOut` delegates to Supabase auth

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/supabase_auth_repository_test.dart`
Expected: FAIL because implementation does not exist yet

- [ ] **Step 3: Implement the minimal Supabase auth repository**

Use `SupabaseClient.auth` methods:
- `currentUser`
- `signInWithPassword`
- `signOut`
- `onAuthStateChange`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/supabase_auth_repository_test.dart`
Expected: PASS

### Task 4: Add sign-in draft validation

**Files:**
- Create: `lib/features/auth/models/host_sign_in_draft.dart`
- Test: `test/features/auth/models/host_sign_in_draft_test.dart`

- [ ] **Step 1: Write the failing draft validation test**

Cover:
- empty email invalid
- empty password invalid
- populated email/password valid

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/models/host_sign_in_draft_test.dart`
Expected: FAIL because draft model does not exist

- [ ] **Step 3: Implement the minimal draft model**

Add:
- fields for `email` and `password`
- `copyWith`
- validation getters

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/models/host_sign_in_draft_test.dart`
Expected: PASS

### Task 5: Add auth controller state

**Files:**
- Create: `lib/features/auth/controllers/auth_controller.dart`
- Test: `test/features/auth/controllers/auth_controller_test.dart`

- [ ] **Step 1: Write the failing auth controller test**

Cover:
- starts in loading or bootstrapping state
- resolves to signed out when no host exists
- resolves to signed in when host exists
- reports error on invalid sign-in
- returns to signed out on sign-out

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/controllers/auth_controller_test.dart`
Expected: FAIL because controller does not exist

- [ ] **Step 3: Implement the minimal auth controller**

Use a focused state model, for example:
- `bootstrapping`
- `signedOut`
- `signingIn`
- `signedIn`
- `error`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/controllers/auth_controller_test.dart`
Expected: PASS

### Task 6: Gate the app shell behind auth

**Files:**
- Modify: `lib/app/app.dart`
- Test: `test/app/app_auth_gate_test.dart`

- [ ] **Step 1: Write the failing app-shell auth gate test**

Cover:
- signed-out state renders host sign-in screen
- signed-in state renders existing event list flow

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/app/app_auth_gate_test.dart`
Expected: FAIL because app shell is not auth-aware yet

- [ ] **Step 3: Update app bootstrap and shell**

Add:
- `AuthRepository` loading alongside event and guest repositories
- auth-aware shell that chooses sign-in vs authenticated router

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/app/app_auth_gate_test.dart`
Expected: PASS

## Chunk 3: Host Sign-In Screen And Sign-Out Path

### Task 7: Add the host sign-in screen

**Files:**
- Create: `lib/features/auth/screens/host_sign_in_screen.dart`
- Test: `test/features/auth/screens/host_sign_in_screen_test.dart`

- [ ] **Step 1: Write the failing sign-in screen widget test**

Cover:
- renders email and password fields
- validates missing fields
- shows loading state
- invokes controller sign-in on submit
- displays friendly error text

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/screens/host_sign_in_screen_test.dart`
Expected: FAIL because screen does not exist

- [ ] **Step 3: Implement the minimal sign-in screen**

Include:
- title
- email field
- password field
- submit button
- validation and error message area

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/screens/host_sign_in_screen_test.dart`
Expected: PASS

### Task 8: Add sign-out access from the authenticated event flow

**Files:**
- Modify: `lib/features/events/screens/event_list_screen.dart`
- Modify: `test/features/events/screens/event_list_screen_test.dart`

- [ ] **Step 1: Write the failing sign-out affordance test**

Cover:
- authenticated event list exposes `Sign out`
- tapping it delegates to auth controller

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/events/screens/event_list_screen_test.dart`
Expected: FAIL because sign-out action is not present

- [ ] **Step 3: Add the minimal UI affordance**

Add a simple action in the event list app bar that triggers auth controller sign-out.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/events/screens/event_list_screen_test.dart`
Expected: PASS

## Chunk 4: Integration Cleanup And Verification

### Task 9: Keep routing and repositories coherent after auth gating

**Files:**
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/data/repositories/supabase_event_repository.dart`

- [ ] **Step 1: Review the current event router assumptions**

Check for any route or screen entry that assumes the app is always authenticated.

- [ ] **Step 2: Make the minimal code changes**

Keep router behavior the same inside the authenticated shell and keep `currentUser` enforcement in `SupabaseEventRepository.createEvent`.

- [ ] **Step 3: Run targeted auth and event tests**

Run:

```bash
flutter test test/app/app_auth_gate_test.dart
flutter test test/features/events/screens/event_list_screen_test.dart
flutter test test/features/auth
```

Expected: PASS

### Task 10: Run full verification and backend smoke checks

**Files:**
- Modify: none

- [ ] **Step 1: Run formatter**

Run: `dart format lib test`
Expected: formatting completes cleanly

- [ ] **Step 2: Run analysis**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all tests pass

- [ ] **Step 4: Verify RLS migration behavior**

Using the existing Supabase project:
- confirm the host account has a mirrored `public.users` row
- confirm the authenticated host can still create and list their own events
- confirm publishable-key access without a proper user session no longer has open write behavior for protected tables

- [ ] **Step 5: Summarize results and remaining blockers**

Report:
- what shipped
- exact verification commands run
- whether mobile simulator or device smoke testing is still pending
