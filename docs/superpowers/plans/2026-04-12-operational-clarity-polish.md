# Operational Clarity Polish Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve host-facing operational clarity across live-event screens by making status, allowed actions, and blocked reasons easier to understand at a glance.

**Architecture:** Keep this slice UI-focused and avoid changing product behavior. Reuse existing screen/controller boundaries, introduce only small shared presentation helpers where duplication is real, and strengthen the wording and hierarchy around lifecycle state, operational flags, guest eligibility, session state, table status, and prize lock state.

**Tech Stack:** Flutter, widget tests, existing repositories/controllers, iOS simulator smoke verification where needed

---

## File Map

- Create: `lib/widgets/status_chip.dart`
  - small shared host-facing status chip presentation
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`
  - stronger lifecycle summary
  - clearer operational controls grouping
  - better blocked-state guidance
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
  - clearer cover/attendance/tag summaries
  - clearer blocked guidance for tag assignment
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
  - stronger guest row state readability
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`
  - clearer per-table live state summaries
- Modify: `lib/features/scoring/screens/session_detail_screen.dart`
  - stronger session state and East emphasis
  - clearer live-control guidance
- Modify: `lib/features/prizes/screens/prize_plan_screen.dart`
  - clearer preview-vs-locked language
- Modify: `lib/features/prizes/screens/prize_awards_screen.dart`
  - stronger locked/payout state wording
- Modify: `lib/features/activity/screens/activity_screen.dart`
  - stronger empty/filter guidance if needed
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
  - lifecycle/flag clarity assertions
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`
  - blocked tag guidance assertions
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
  - guest row state readability assertions
- Modify: `test/features/tables/screens/tables_overview_screen_test.dart`
  - table state wording assertions
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
  - session state and blocked guidance assertions
- Modify: `test/features/prizes/screens/prize_plan_screen_test.dart`
  - preview-vs-locked wording assertions
- Modify: `test/features/prizes/screens/prize_awards_screen_test.dart`
  - payout status wording assertions

## Chunk 1: Shared Presentation Pattern And Dashboard Clarity

### Task 1: Add failing dashboard tests for stronger lifecycle and operational state language

**Files:**
- Modify: `test/features/events/screens/event_dashboard_screen_test.dart`
- Create: `lib/widgets/status_chip.dart`
- Modify: `lib/features/events/screens/event_dashboard_screen.dart`

- [ ] **Step 1: Write the failing dashboard widget expectations**

Cover:
- draft events show a clear lifecycle summary, not just action buttons
- active events show stronger `Check-In` and `Scoring` state labels
- completed/finalized states show review/locked messaging that reads like host guidance
- blocked finalization wording is understandable without backend knowledge

- [ ] **Step 2: Run the dashboard tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: FAIL because the stronger wording/chip treatment does not exist yet

- [ ] **Step 3: Add a minimal shared `StatusChip` widget**

Implement:
- text label only
- semantic color variants for:
  - neutral
  - success
  - warning
  - danger
- compact layout that can be reused on dashboard, guest, table, and session screens

Keep it intentionally small and presentation-only.

- [ ] **Step 4: Update the event dashboard UI**

Improve:
- explicit event lifecycle summary near the top
- clearer grouping for:
  - event lifecycle
  - live operations
  - review/results
- more host-readable operational labels
- helper text for blocked completion/finalization conditions where the current UI is too terse

Do not change repository or controller behavior unless the screen truly needs a small derived helper.

- [ ] **Step 5: Re-run the dashboard tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart
```

Expected: PASS

## Chunk 2: Guest And Table Operational Readability

### Task 2: Add failing guest-detail and guest-roster tests for eligibility/blocked guidance

**Files:**
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`

- [ ] **Step 1: Write failing guest UI assertions**

Cover:
- guest detail clearly shows cover, attendance, and tag state
- unpaid/partial/refunded guests see actionable tag-block guidance
- paid/comped guests have clearer next-step language
- guest roster rows are easier to scan for operational state

- [ ] **Step 2: Run the guest widget tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/screens/guest_detail_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because the new copy/chips/readability treatment does not exist yet

- [ ] **Step 3: Update guest detail and roster screens**

Improve:
- state summaries using consistent chip language
- helper text near blocked tag/check-in actions
- roster row summaries so hosts can quickly identify who is eligible to play

Avoid changing the guest operation flow itself.

- [ ] **Step 4: Re-run the guest widget tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/checkin/screens/guest_detail_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS

### Task 3: Add failing tables-overview tests for scan-friendly table state

**Files:**
- Modify: `test/features/tables/screens/tables_overview_screen_test.dart`
- Modify: `lib/features/tables/screens/tables_overview_screen.dart`

- [ ] **Step 1: Write failing table overview assertions**

Cover:
- table cards clearly show mode
- bound/unbound table-tag state reads clearly
- active/paused/completed/ended-early session state is obvious

- [ ] **Step 2: Run the table overview test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/tables/screens/tables_overview_screen_test.dart
```

Expected: FAIL because the clearer wording and chip treatment are not present yet

- [ ] **Step 3: Update the tables overview screen**

Improve:
- status hierarchy on each card
- concise operational wording
- stronger emphasis on whether the table is ready, live, or unavailable for new session start

- [ ] **Step 4: Re-run the table overview test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/tables/screens/tables_overview_screen_test.dart
```

Expected: PASS

## Chunk 3: Session And Prize Clarity

### Task 4: Add failing session-detail tests for live-state guidance

**Files:**
- Modify: `test/features/scoring/screens/session_detail_screen_test.dart`
- Modify: `lib/features/scoring/screens/session_detail_screen.dart`

- [ ] **Step 1: Write failing session-detail assertions**

Cover:
- session state is visually and textually obvious
- current East is easier to identify
- paused and ended-early sessions show clearer hand-entry/action guidance
- live controls read like host operations, not generic buttons

- [ ] **Step 2: Run the session-detail test to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/scoring/screens/session_detail_screen_test.dart
```

Expected: FAIL because the stronger state/guidance treatment does not exist yet

- [ ] **Step 3: Update the session-detail screen**

Improve:
- state chips and section hierarchy
- East emphasis
- explanatory text for when hand entry is unavailable
- pause/resume/end-early guidance wording

- [ ] **Step 4: Re-run the session-detail test**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/scoring/screens/session_detail_screen_test.dart
```

Expected: PASS

### Task 5: Add failing prize-screen tests for preview-vs-locked clarity

**Files:**
- Modify: `test/features/prizes/screens/prize_plan_screen_test.dart`
- Modify: `test/features/prizes/screens/prize_awards_screen_test.dart`
- Modify: `lib/features/prizes/screens/prize_plan_screen.dart`
- Modify: `lib/features/prizes/screens/prize_awards_screen.dart`

- [ ] **Step 1: Write failing prize UI assertions**

Cover:
- prize plan screen clearly distinguishes editable preview from locked awards state
- locked awards screen clearly communicates payout statuses and official-award semantics

- [ ] **Step 2: Run the prize widget tests to verify failure**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
```

Expected: FAIL because the stronger explanatory language is not present yet

- [ ] **Step 3: Update the prize screens**

Improve:
- preview-vs-lock messaging
- locked award section headings
- payout status wording for `planned`, `paid`, and `void`

- [ ] **Step 4: Re-run the prize widget tests**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
```

Expected: PASS

## Chunk 4: Final Consistency Pass

### Task 6: Run targeted consistency checks and full verification

**Files:**
- Modify only files needed from earlier tasks

- [ ] **Step 1: Review copy consistency across the touched screens**

Check that the same state always uses the same language:
- `Draft`, `Live`, `Completed`, `Finalized`
- `Check-In Open/Closed`
- `Scoring Open/Closed`
- `Tag Assigned/Unassigned`
- `Active`, `Paused`, `Completed`, `Ended Early`
- `Preview`, `Locked`, `Paid`, `Void`

- [ ] **Step 2: Run formatter**

Run:
```bash
dart format lib test
```

Expected: formatting completes cleanly

- [ ] **Step 3: Run focused widget suites together**

Run:
```bash
/opt/homebrew/bin/flutter test test/features/events/screens/event_dashboard_screen_test.dart test/features/checkin/screens/guest_detail_screen_test.dart test/features/guests/screens/guest_roster_screen_test.dart test/features/tables/screens/tables_overview_screen_test.dart test/features/scoring/screens/session_detail_screen_test.dart test/features/prizes/screens/prize_plan_screen_test.dart test/features/prizes/screens/prize_awards_screen_test.dart
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

- [ ] **Step 5: Optional simulator confidence check**

If wording or visibility changes touched the smoke path materially, run:
```bash
/opt/homebrew/bin/flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL='brian.le1678@gmail.com' --dart-define=HOST_PASSWORD='12345678!'
```

Expected: PASS
