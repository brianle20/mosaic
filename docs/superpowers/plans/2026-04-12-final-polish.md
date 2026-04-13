# Final Polish Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Mosaic feel finished across startup, auth, and the authenticated host experience by improving empty states, loading states, feedback messaging, and spacing consistency without changing business behavior.

**Architecture:** Keep this slice presentation-focused. Reuse existing screen and controller boundaries, introduce only small shared UI helpers where duplication is real, and standardize feedback copy so the app feels like one coherent product rather than a stack of completed slices.

**Tech Stack:** Flutter, widget tests, existing controllers/repositories, existing integration smoke harness

---

## File Map

- Create: `lib/widgets/empty_state_card.dart`
  - shared lightweight empty-state presentation
- Modify: `lib/core/widgets/async_body.dart`
  - consistent loading and error presentation
- Modify: `lib/app/app.dart`
  - bootstrap loading/error polish
- Modify: `lib/features/auth/screens/host_sign_in_screen.dart`
  - sign-in hierarchy and helper text polish
- Modify: `lib/features/events/screens/event_list_screen.dart`
  - better empty state and event-creation guidance
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - refined helper text and section rhythm if needed
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
  - stronger empty state and consistent feedback wording
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
  - tighten helper/feedback text only if needed
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`
  - stronger empty state and guidance
- Modify: `lib/features/scoring/screens/session_detail_screen.dart`
  - improve empty/history fallback or blocked messaging if needed
- Modify: `lib/features/leaderboard/screens/leaderboard_screen.dart`
  - intentional empty state for no scored results
- Modify: `lib/features/activity/screens/activity_screen.dart`
  - empty state and filter/loading polish
- Modify: `lib/features/prizes/screens/prize_plan_screen.dart`
  - empty/unconfigured prize state guidance
- Modify: `lib/features/prizes/screens/prize_awards_screen.dart`
  - empty locked-awards state and payout feedback polish
- Modify: `test/features/auth/screens/host_sign_in_screen_test.dart`
  - polished auth copy and error treatment assertions
- Modify: `test/features/events/screens/event_list_screen_test.dart`
  - empty-state and action-guidance assertions
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
  - empty-state and success-feedback assertions
- Modify: `test/features/tables/screens/tables_overview_screen_test.dart`
  - empty-state assertions
- Modify: `test/features/leaderboard/screens/leaderboard_screen_test.dart`
  - no-results empty-state assertions
- Modify: `test/features/activity/screens/activity_screen_test.dart`
  - empty-state/filter wording assertions
- Modify: `test/features/prizes/screens/prize_plan_screen_test.dart`
  - no-plan / no-eligible-player guidance assertions
- Modify: `test/features/prizes/screens/prize_awards_screen_test.dart`
  - empty locked-awards messaging assertions
- Modify: `integration_test/live_smoke_test.dart`
  - only if user-facing feedback copy becomes part of the smoke contract

## Chunk 1: Shared Polish Patterns And Startup/Auth

### Task 1: Add failing tests for startup and sign-in polish

**Files:**
- Modify: `test/features/auth/screens/host_sign_in_screen_test.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/core/widgets/async_body.dart`
- Modify: `lib/features/auth/screens/host_sign_in_screen.dart`
- Create: `lib/widgets/empty_state_card.dart`

- [ ] **Step 1: Write the failing auth/startup widget expectations**

Cover:
- bootstrap loading feels deliberate and readable
- startup error state is clearer and more intentional
- sign-in screen has stronger hierarchy and supporting copy
- sign-in errors remain concise and host-friendly

- [ ] **Step 2: Run the auth screen tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/auth/screens/host_sign_in_screen_test.dart test/app/app_auth_gate_test.dart
```

Expected: FAIL because the improved loading and sign-in presentation does not exist yet

- [ ] **Step 3: Add the minimal shared polish helpers**

Implement:
- `EmptyStateCard` as a small reusable UI block for empty states
- improved `AsyncBody` loading/error presentation without changing behavior
- a more intentional bootstrap loading screen in `app.dart`

Keep these helpers presentation-only.

- [ ] **Step 4: Update the sign-in screen**

Improve:
- title/subtitle hierarchy
- supporting copy
- spacing around form fields and error text
- keep authentication behavior unchanged

- [ ] **Step 5: Re-run the auth/startup tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/auth/screens/host_sign_in_screen_test.dart test/app/app_auth_gate_test.dart
```

Expected: PASS

## Chunk 2: High-Traffic Empty States And Feedback

### Task 2: Add failing event-list and guest-roster tests for empty states and host feedback

**Files:**
- Modify: `test/features/events/screens/event_list_screen_test.dart`
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/events/screens/event_list_screen.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`

- [ ] **Step 1: Write the failing empty-state and feedback assertions**

Cover:
- event list empty state explains what the host should do next
- guest roster empty state feels intentional and actionable
- success feedback wording on high-frequency guest actions is consistent and calm

- [ ] **Step 2: Run the event-list and guest-roster tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because the stronger empty-state and feedback treatment does not exist yet

- [ ] **Step 3: Update event list and guest roster UI**

Improve:
- replace bare empty text with intentional empty-state treatment
- point toward the next host action
- normalize success/error snackbars where wording still feels uneven

Do not add new guest or event functionality.

- [ ] **Step 4: Re-run the event-list and guest-roster tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_list_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS

### Task 3: Add failing tables and leaderboard tests for no-data states

**Files:**
- Modify: `test/features/tables/screens/tables_overview_screen_test.dart`
- Modify: `test/features/leaderboard/screens/leaderboard_screen_test.dart`
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`
- Modify: `lib/features/leaderboard/screens/leaderboard_screen.dart`

- [ ] **Step 1: Write the failing table and leaderboard empty-state assertions**

Cover:
- tables screen clearly explains the absence of tables
- leaderboard screen clearly explains that no scored results exist yet

- [ ] **Step 2: Run the table and leaderboard tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/tables/screens/tables_overview_screen_test.dart test/features/leaderboard/screens/leaderboard_screen_test.dart
```

Expected: FAIL because the stronger empty-state treatment does not exist yet

- [ ] **Step 3: Update the tables and leaderboard screens**

Improve:
- intentional empty-state blocks
- short operational guidance
- preserve the current data flow and loading behavior

- [ ] **Step 4: Re-run the table and leaderboard tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/tables/screens/tables_overview_screen_test.dart test/features/leaderboard/screens/leaderboard_screen_test.dart
```

Expected: PASS

## Chunk 3: Review Screens And Low-Frequency States

### Task 4: Add failing activity and prize-screen tests for empty and unconfigured states

**Files:**
- Modify: `test/features/activity/screens/activity_screen_test.dart`
- Modify: `test/features/prizes/screens/prize_plan_screen_test.dart`
- Modify: `test/features/prizes/screens/prize_awards_screen_test.dart`
- Modify: `lib/features/activity/screens/activity_screen.dart`
- Modify: `lib/features/prizes/screens/prize_plan_screen.dart`
- Modify: `lib/features/prizes/screens/prize_awards_screen.dart`

- [ ] **Step 1: Write the failing activity and prize UI assertions**

Cover:
- activity feed empty state feels intentional
- prize plan screen explains no plan / no eligible-player states clearly
- locked-awards screen explains when no awards exist yet

- [ ] **Step 2: Run the activity and prize tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/activity/screens/activity_screen_test.dart test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
```

Expected: FAIL because the stronger empty-state or helper treatment does not exist yet

- [ ] **Step 3: Update the activity and prize screens**

Improve:
- empty-state cards
- helper text and section rhythm
- keep prize behavior unchanged

- [ ] **Step 4: Re-run the activity and prize tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/activity/screens/activity_screen_test.dart test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
```

Expected: PASS

### Task 5: Tighten any remaining dashboard, session-detail, or guest-detail rough edges only where the tests or manual review show uneven polish

**Files:**
- Modify only as needed:
  - `lib/features/events/screens/event_dashboard_screen.dart`
  - `lib/features/scoring/screens/session_detail_screen.dart`
  - `lib/features/checkin/screens/guest_detail_screen.dart`
  - matching widget tests

- [ ] **Step 1: Review the touched host screens for inconsistent helper text, spacing, or feedback**

Check:
- section headers
- helper text placement
- feedback wording consistency with earlier polish slices

- [ ] **Step 2: Add or refine only the smallest necessary assertions**

Avoid speculative refactors. Add tests only for real presentation gaps found in the review.

- [ ] **Step 3: Make the minimal polish edits**

Keep these changes small and presentation-only.

- [ ] **Step 4: Re-run the focused screen tests you touched**

Run only the relevant widget suites for any screens updated in this task.

Expected: PASS

## Chunk 4: Final Consistency Pass

### Task 6: Run full polish verification and only touch the smoke harness if intentional copy changes require it

**Files:**
- Modify only files needed from earlier tasks

- [ ] **Step 1: Review copy consistency across the touched screens**

Check that repeated concepts use stable wording:
- loading
- empty-state prompts
- success feedback
- host guidance errors
- prize preview vs locked language

- [ ] **Step 2: Run formatter**

Run:
```bash
dart format lib test integration_test
```

Expected: formatting completes cleanly

- [ ] **Step 3: Run the focused polish suites together**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/auth/screens/host_sign_in_screen_test.dart test/app/app_auth_gate_test.dart test/features/events/screens/event_list_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart test/features/tables/screens/tables_overview_screen_test.dart test/features/leaderboard/screens/leaderboard_screen_test.dart test/features/activity/screens/activity_screen_test.dart test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
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

- [ ] **Step 5: Run the live smoke only if feedback or visible user-facing copy changed along the smoke path**

If needed, run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL='brian.le1678@gmail.com' --dart-define=HOST_PASSWORD='12345678!'
```

Expected: PASS
