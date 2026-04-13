# Guest Roster Quick Actions Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce taps in the highest-frequency host flow by adding safe, inline guest-roster quick actions for common operations.

**Architecture:** Extend the existing guest roster screen and controller rather than creating a new subsystem. Reuse current guest repository methods and NFC/manual tag scan flows wherever possible, and add only the smallest missing repository/controller surface needed for fast `Mark Paid` / `Mark Comped` actions and in-place roster refresh.

**Tech Stack:** Flutter, existing guest repositories/controllers, widget tests, optional iOS simulator smoke verification

---

## File Map

- Modify: `lib/data/repositories/repository_interfaces.dart`
  - add minimal fast cover-status mutation surface if needed
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
  - support roster-safe `markPaid` / `markComped` path if not already cleanly available
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`
  - add quick-action handlers
  - track per-guest submission state
  - expose transient success/error feedback
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
  - render per-row quick actions conditionally
  - trigger NFC/manual tag scan flow inline from roster
  - show lightweight success feedback
- Create: `lib/features/guests/widgets/guest_quick_action_bar.dart`
  - compact row action strip for roster actions
- Modify: `lib/core/routing/app_router.dart`
  - only if roster quick actions need shared cover-entry or detail routing helpers
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
  - quick-action visibility and success feedback coverage
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`
  - only if shared guest-repository changes affect fakes/contracts
- Modify: `test/app/app_auth_gate_test.dart`
  - only if repository interface changes require updated fakes
- Modify: `integration_test/live_smoke_test.dart`
  - optional: use one roster quick action in the smoke flow if it materially exercises new behavior

## Chunk 1: Quick Action Contract And Fast Cover Status Updates

### Task 1: Add failing roster widget tests for quick-action visibility by guest state

**Files:**
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
- Create: `lib/features/guests/widgets/guest_quick_action_bar.dart`

- [ ] **Step 1: Write failing roster visibility tests**

Cover:
- unpaid guest shows `Mark Paid` and `Mark Comped`
- paid but unchecked-in guest shows `Check In & Tag`
- checked-in untagged guest shows `Assign Tag`
- checked-in tagged guest does not show play-unblocking quick actions
- row tap still opens guest detail

- [ ] **Step 2: Run the roster widget test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because no quick-action strip exists yet

- [ ] **Step 3: Add a compact `GuestQuickActionBar` widget**

Implement:
- compact row-level button layout
- supports 1-3 visible quick actions
- presentation only; callbacks come from the roster screen/controller

Keep it small and guest-roster-specific unless a clear reuse case appears immediately.

- [ ] **Step 4: Add conditional quick-action rendering to the roster**

Implement visibility rules from the spec:
- unpaid / partial / refunded -> `Mark Paid`, `Mark Comped`
- paid or comped and not checked in -> `Check In & Tag`
- checked in and untagged -> `Assign Tag`
- tagged -> no primary play-unblocking action

Do not wire the actions yet beyond placeholders if that helps keep the red/green cycle tight.

- [ ] **Step 5: Re-run the roster widget test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS for visibility/layout expectations

### Task 2: Add the minimal repository/controller contract for fast `Mark Paid` and `Mark Comped`

**Files:**
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`
- Modify: any fake guest repositories in touched tests

- [ ] **Step 1: Write the failing controller/repository expectations through widget tests**

Extend roster tests to assert that:
- tapping `Mark Paid` updates the roster row state
- tapping `Mark Comped` updates the roster row state

Drive this from the screen level so the contract stays user-visible.

- [ ] **Step 2: Run the roster widget test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because fast cover-status actions are not wired yet

- [ ] **Step 3: Add the smallest clean repository API**

If current `updateGuest` is too heavy for row actions, add a minimal method such as:
- `Future<EventGuestRecord> setGuestCoverStatus({required String guestId, required CoverStatus coverStatus})`

Implement it in `SupabaseGuestRepository` by:
- loading the target guest as needed
- reusing the existing update path
- refreshing the cached guest list data so the roster reflects the mutation

Do not create a broad new inline-edit layer.

- [ ] **Step 4: Wire controller helpers for fast cover-status actions**

Add to `GuestRosterController`:
- per-guest submission tracking
- `markPaid(guestId)`
- `markComped(guestId)`
- in-memory roster refresh after mutation

- [ ] **Step 5: Re-run the roster widget test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS

## Chunk 2: Inline Check-In And Tag Actions

### Task 3: Add failing roster tests for `Check In & Tag` and `Assign Tag`

**Files:**
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`

- [ ] **Step 1: Write failing widget tests for roster-level operational actions**

Cover:
- paid unchecked-in guest can complete `Check In & Tag`
- checked-in untagged guest can complete `Assign Tag`
- manual UID/NFC flow is triggered from the roster
- success feedback is shown without leaving the roster

- [ ] **Step 2: Run the roster widget test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because the row actions are not wired yet

- [ ] **Step 3: Reuse existing guest-repository and NFC/manual scan flows**

Implement:
- roster-level `checkInAndAssign`
- roster-level `assignTag`

Reuse:
- existing guest repository methods
- existing NFC/manual scan service behavior

Prefer calling the same business operations the detail screen already uses rather than re-implementing them in the roster.

- [ ] **Step 4: Keep the roster in place after success**

After action completion:
- refresh only what the roster needs
- keep the user on the roster
- show a short success message

- [ ] **Step 5: Re-run the roster widget test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS

## Chunk 3: Add Cover Entry Shortcut And Interaction Polish

### Task 4: Add failing tests for `Add Cover Entry` shortcut and snackbar feedback

**Files:**
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`
- Modify: routing/helpers only if needed

- [ ] **Step 1: Write failing tests for row-level cover-entry shortcut**

Cover:
- relevant guests expose `Add Cover Entry`
- tapping it launches the existing cover-entry flow
- successful save returns to the roster and shows confirmation

- [ ] **Step 2: Run the roster widget test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because the shortcut is not wired yet

- [ ] **Step 3: Reuse the current add-cover-entry flow**

Implement roster-level launch behavior by:
- reusing the existing cover-entry screen/form path
- avoiding a second cover-entry implementation just for the roster

Keep this action available only where it adds value and does not overcrowd the row.

- [ ] **Step 4: Add lightweight success feedback**

Use snackbars or an equivalent transient confirmation for:
- marked paid
- marked comped
- checked in
- assigned tag
- cover entry saved

Make the messages guest-specific and short.

- [ ] **Step 5: Re-run the roster widget test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS

## Chunk 4: Final Consistency Pass And Verification

### Task 5: Verify roster speed improvements without regressing detail behavior

**Files:**
- Modify only files needed from earlier tasks

- [ ] **Step 1: Review quick-action prioritization**

Check:
- no row shows too many actions
- action priority favors unblocking play first
- row tap still opens guest detail

- [ ] **Step 2: Run formatter**

Run:
```bash
dart format lib test integration_test
```

Expected: formatting completes cleanly

- [ ] **Step 3: Run focused guest-related widget suites**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/guests/screens/guest_roster_screen_test.dart test/features/checkin/screens/guest_detail_screen_test.dart test/features/guests/screens/guest_form_screen_test.dart
```

Expected: PASS

- [ ] **Step 4: Run full verification**

Run:
```bash
/opt/homebrew/bin/flutter analyze
/opt/homebrew/bin/flutter test
```

Expected:
- `flutter analyze` reports no issues
- `flutter test` passes fully

- [ ] **Step 5: Optional live smoke extension**

If the roster quick actions materially change the host flow, extend and run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL='brian.le1678@gmail.com' --dart-define=HOST_PASSWORD='12345678!'
```

Expected: PASS
