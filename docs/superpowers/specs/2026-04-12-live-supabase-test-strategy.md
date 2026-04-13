# Live Supabase Test Strategy

Date: 2026-04-12
Product: Mosaic
Slice: Live Backend Lifecycle Validation

## Purpose

This document defines the strategy for validating Mosaic against the real Supabase backend across the highest-value end-to-end host workflows.

The goal is not exhaustive permutation coverage. The goal is confidence that:

- real auth works
- real RLS works
- real RPCs enforce lifecycle and scoring rules
- persisted state transitions remain coherent across feature boundaries
- cached reopen behavior does not drift from backend truth

This strategy complements:

- unit tests
- widget tests
- repository mapping tests
- the existing live smoke harness

It does not replace them.

## Scope

These tests should run against:

- real Supabase Auth
- real PostgREST / RPC endpoints
- real RLS policies
- real persisted rows in the hosted project

These tests should primarily be exercised through:

- iOS simulator for app-driven flows
- direct backend assertions where app UI is not the best verification surface

Later, once physical tags are available, this strategy expands to:

- real iPhone NFC validation

## Non-Goals

This strategy does not attempt to:

- test every mathematical permutation of state
- replace fine-grained unit coverage
- validate visual polish
- brute-force every possible UI combination

The phrase "every feature combination" in this context means every important cross-feature handoff, where one feature's persisted state becomes another feature's precondition.

## Test Design Principles

### 1. Prefer lifecycle chains over isolated clicks

The highest-value live tests are not isolated screen checks. They are stateful journeys where:

- a host action writes backend state
- later steps depend on that state
- blocking rules are enforced by the server

### 2. Keep the matrix intentionally small

The live suite should be compact and high signal.

Recommended balance:

- one full golden-path lifecycle test
- a focused blocker suite
- a focused mutation / recalculation suite
- a focused persistence / reopen suite
- a later real-device NFC suite

### 3. Verify both UI truth and backend truth

When possible, each scenario should validate:

- the user-visible outcome
- the persisted backend outcome

For example:

- a blocked action shows the right host-facing message
- and no invalid row was created

### 4. Every live test must clean up

Each test must:

- use unique run-scoped identifiers
- clean up all created rows
- leave the hosted project in a neutral state

Recommended naming convention:

- `live_<scenario>_<timestamp>`
- or a short prefix like `smoke_<timestamp>_*`

## Coverage Layers

### Layer 1: Golden Path

This is the single most important live test.

#### `live_golden_full_event_lifecycle`

Flow:

1. Sign in
2. Create event
3. Start event
4. Open check-in
5. Add four paid guests
6. Add cover entries
7. Check in and assign player tags
8. Create a points table
9. Bind a table tag
10. Open scoring
11. Start a session
12. Record:
   - one discard win
   - one self-draw win
   - one washout
13. Verify leaderboard updates
14. Configure prize plan
15. Preview awards
16. Lock awards
17. Mark one award paid
18. Complete event
19. Finalize event
20. Verify payout state remains editable after finalization
21. Clean up

Success criteria:

- one real host event can be run start to finish
- every major persisted handoff works on the real backend

## Layer 2: Blocker Scenarios

These tests prove that server-side lifecycle and eligibility guards are real.

### Recommended blocker scenarios

#### `live_block_checkin_closed_blocks_guest_checkin`

Verify:

- guest check-in is blocked when `checkin_open = false`
- no accidental attendance mutation is written

#### `live_block_unpaid_guest_cannot_receive_player_tag`

Verify:

- unpaid or partial guests cannot receive player tags
- no assignment row is created

#### `live_block_scoring_closed_blocks_session_start`

Verify:

- session start is blocked while scoring is closed
- no session or seat rows are created

#### `live_block_non_points_table_cannot_start_session`

Verify:

- casual or inactive tables cannot start scored sessions

#### `live_block_guest_without_tag_cannot_start_session`

Verify:

- a checked-in but untagged guest cannot join a scored session

#### `live_block_guest_already_in_active_session_cannot_start_second_session`

Verify:

- one player cannot be double-booked across active sessions

#### `live_block_finalize_with_active_session`

Verify:

- finalization is blocked while any session remains active or paused

#### `live_block_finalize_without_locked_prizes_when_plan_exists`

Verify:

- event finalization is blocked if prizes are required but not locked

#### `live_block_resume_paused_session_when_scoring_closed`

Verify:

- paused sessions cannot resume while scoring is closed

## Layer 3: Mutation and Recalculation

These tests prove that historical edits, reassignment, and lock boundaries behave correctly.

### Recommended mutation scenarios

#### `live_mutation_edit_hand_recalculates_leaderboard`

Verify:

- editing an earlier hand changes derived session state
- leaderboard totals refresh correctly

#### `live_mutation_void_hand_recalculates_session_and_leaderboard`

Verify:

- voiding a hand rebuilds settlements and totals deterministically

#### `live_mutation_replace_guest_tag_preserves_single_active_assignment`

Verify:

- old player-tag assignment is no longer active
- replacement history is preserved correctly

#### `live_mutation_end_session_early_allows_event_completion`

Verify:

- ended-early sessions remain historical
- they do not block completion/finalization like active sessions do

#### `live_mutation_prize_lock_freezes_awards_despite_later_score_changes`

Verify:

- locked awards do not silently mutate after standings change
- preview and locked-award semantics remain separated

## Layer 4: Persistence and Reopen

These tests prove that reopening screens or restoring app state does not lose operational truth.

### Recommended persistence scenarios

#### `live_reopen_event_dashboard_after_refresh`

Verify:

- lifecycle status
- operational flags
- guest counts

remain coherent after reload

#### `live_reopen_locked_prize_flow_preserves_awards_and_names`

Verify:

- locked awards still appear after reopen
- guest names remain available
- payout actions remain attached to the correct award rows

#### `live_reopen_session_detail_preserves_hand_history_and_current_east`

Verify:

- session detail reloads the correct hand history
- current East / dealer state is still correct

#### `live_reopen_activity_feed_shows_recent_actions`

Verify:

- audit feed remains readable and complete after real mutations and reloads

## Layer 5: Auth and RLS

These tests prove ownership and session restoration behavior.

### Recommended auth / RLS scenarios

#### `live_rls_host_can_only_access_own_event_data`

Verify:

- a host can read only owned event data
- non-owned rows are blocked by RLS

#### `live_auth_session_restore_returns_to_event_list`

Verify:

- an existing session restores correctly
- authenticated host routing resumes in the expected area

#### `live_auth_sign_out_blocks_event_access`

Verify:

- post-sign-out access to authenticated event flows is blocked

## Layer 6: Real-Device NFC

These should wait until physical tags are available.

### Recommended device scenarios

#### `device_nfc_assign_player_tag_happy_path`

#### `device_nfc_bind_table_tag_happy_path`

#### `device_nfc_start_session_with_real_scans`

#### `device_nfc_wrong_tag_type_blocking`

#### `device_nfc_duplicate_tag_assignment_blocking`

The goal here is not just correctness, but operational reliability:

- scan success rate
- scan timing
- failure recovery
- host comprehension of mismatch and retry states

## Initial Recommended Implementation Set

The first live backend expansion should prioritize these six scenarios:

1. `live_golden_full_event_lifecycle`
2. `live_block_scoring_closed_blocks_session_start`
3. `live_block_finalize_with_active_session`
4. `live_mutation_edit_hand_recalculates_leaderboard`
5. `live_reopen_locked_prize_flow_preserves_awards_and_names`
6. `live_rls_host_can_only_access_own_event_data`

Why these first:

- they cover the full operating loop
- they validate the most important blockers
- they test recalculation
- they test locked-award persistence
- they test the security boundary

## Execution Guidance

### Test harness expectations

Each live scenario should:

- generate unique fixture names
- record created IDs for cleanup
- perform cleanup in `tearDown` or equivalent guarded cleanup paths
- fail loudly if cleanup is incomplete

### Assertion style

Prefer assertions in this order:

1. user-visible UI behavior
2. repository / RPC response behavior
3. direct backend row verification

### Failure handling

Blocker tests should confirm both:

- the failure message / host guidance
- the absence of invalid side effects

### CI expectations

This suite should eventually be split by cost:

- lightweight live smoke in normal CI
- deeper live-backend lifecycle suite in scheduled or gated CI
- NFC real-device suite outside normal simulator CI

## Success Criteria

This strategy is successful when the live suite gives confidence that:

- lifecycle gates are real
- scoring gates are real
- recalculation is real
- lock semantics are real
- cache and reopen behavior are real
- RLS boundaries are real
- later NFC behavior is verified on real hardware

## Summary

The correct target is not "test everything."

The correct target is:

- one trustworthy golden path
- focused blocker coverage
- focused mutation coverage
- focused reopen coverage
- focused auth / RLS coverage
- later, focused real-device NFC coverage

That gives Mosaic strong live-backend confidence without turning the test suite into an unmaintainable permutation matrix.
