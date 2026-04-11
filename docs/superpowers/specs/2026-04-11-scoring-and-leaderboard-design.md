# Scoring And Leaderboard Slice Design

## Summary

This slice adds the first complete scored-play loop after session start:

`Session Detail -> Record Hand -> Recalculate Session -> Refresh Leaderboard`

The design keeps the MVP narrow while making scoring architecture correct from day one:

- only `HK_STANDARD_V1` is exposed
- hand writes are server-authoritative
- every hand create, edit, or void triggers full-session recalculation
- standings are derived from persisted hand settlements, not client math
- the UI stays host-oriented and simple: session detail, hand entry, hand history, and leaderboard

This slice includes hand correction because deterministic recalculation is one of the core MVP product principles. It does not include prizes, finalization, or alternate rulesets.

## Goals

- Let the host record scored hands for an active session
- Let the host edit or void historical hands
- Recalculate dealer progression, settlements, session state, and standings deterministically after every hand mutation
- Expose a real leaderboard backed by `event_score_totals`
- Keep the scoring engine authoritative in Postgres
- Add test coverage for the highest-risk HK rules logic

## Non-goals

- No prize plan or payout flow
- No event finalization logic
- No pause, resume, or end-session controls in this slice
- No tile recognition
- No fan auto-calculation
- No multiple winners
- No alternate rulesets in production UI
- No alternate rotation policies in production UI

## User Flow

### Session Detail

The host opens an active session and sees:

- table label
- session status
- current East highlight
- seat map in East, South, West, North order
- hand history
- `Record Hand`

Each hand history row should be quick to scan during live play and show:

- hand number
- outcome summary
- points summary
- whether East rotated

Tapping a historical hand opens a lightweight edit/void path.

### Record Hand

The host taps `Record Hand` and uses a dedicated hand-entry screen.

Inputs:

- result type: `win` or `washout`
- if `win`:
  - winner seat
  - fan count
  - win type: `discard` or `self_draw`
  - discarder seat if discard

The screen should show a scoring preview before save so the host can confirm payer-by-payer points.

### Edit Or Void Hand

The host can open a recorded hand and either:

- edit the hand inputs and save, or
- void the hand with an audit note if the UI includes it now, or a simple correction note if not

The host does not manually adjust downstream hands. The app recalculates the entire session from hand 1 forward after any historical change.

### Leaderboard

The leaderboard screen becomes a real derived standings screen backed by server totals.

For MVP it should show:

- rank
- guest
- total points
- hands won
- self-draw wins

Sorting is by `total_points DESC`.

## Domain Rules

### Hand Inputs

Allowed result types:

- `win`
- `washout`

For `win`:

- `winner_seat_index` is required
- `fan_count` is required
- `fan_count >= 0`
- `win_type` is required

For `discard`:

- `discarder_seat_index` is required
- `discarder_seat_index != winner_seat_index`

For `self_draw`:

- `discarder_seat_index` must be null

For `washout`:

- no winner
- no discarder
- no fan count

### HK Fan Mapping

Fan-to-base points must match the MVP spec exactly:

- `0 -> 1`
- `1 -> 2`
- `2 -> 4`
- `3 -> 8`
- `4..6 -> 16`
- `7..9 -> 32`
- `10..12 -> 64`
- `13+ -> 128`

### Multiplier Rules

Multipliers are applied per payer, not once per hand:

1. discarder pays double on discard win
2. all losers pay double on self-draw
3. all losers pay double if East wins
4. East pays double if East loses

These multipliers stack multiplicatively.

### Dealer Progression

Seat order remains:

- `0 = East`
- `1 = South`
- `2 = West`
- `3 = North`

Dealer progression rules:

- washout: East retains
- East win: East retains
- non-East win: dealer rotates counterclockwise

Session completion rule for MVP:

- session completes when dealer returns to initial East and `dealer_pass_count >= 4`

### Recalculation Rule

Whenever a hand is created, edited, or voided:

1. recalculate the entire session from hand 1 onward
2. recompute East before and after every hand
3. rebuild settlements for every affected hand
4. update session aggregate state
5. refresh `event_score_totals`
6. mark participating guests as `has_scored_play = true`
7. refresh leaderboard reads automatically from the derived totals

## Backend Design

## New RPCs

This slice should add server-authoritative functions for:

- `record_hand_result`
- `edit_hand_result`
- `void_hand_result`
- `recalculate_session`
- `get_event_leaderboard`

All three hand mutation operations should funnel into one recalculation path.

## `record_hand_result`

Responsibilities:

- verify session ownership through the event
- verify session is `active`
- validate hand input shape
- assign the next `hand_number`
- insert the new `hand_results` row
- trigger full-session recalculation
- audit the creation

## `edit_hand_result`

Responsibilities:

- verify ownership
- validate edited input shape
- update the target `hand_results` row in place
- preserve auditability with before/after snapshots
- trigger full-session recalculation
- audit the edit

## `void_hand_result`

Responsibilities:

- verify ownership
- mark the row `status = 'voided'`
- preserve correction metadata
- trigger full-session recalculation
- audit the void

## `recalculate_session`

Responsibilities:

- lock the target `table_sessions` row
- load all non-voided hands for the session ordered by `hand_number`
- begin from:
  - `initial_east_seat_index`
  - `current dealer = initial East`
  - `dealer_pass_count = 0`
- for each hand:
  - validate data shape
  - derive base points from fan count
  - compute payer-specific settlements
  - write:
    - `base_points`
    - `east_seat_index_before_hand`
    - `east_seat_index_after_hand`
    - `dealer_rotated`
    - `session_completed_after_hand`
  - rebuild `hand_settlements`
  - advance dealer state
- after the final hand:
  - update session `current_dealer_seat_index`
  - update `dealer_pass_count`
  - update `hand_count`
  - set session `status = completed` if the completion rule is met, otherwise keep `active`
- rebuild `event_score_totals` for the event or at minimum all guests participating in the event

This function is the single correctness core of the scoring system.

## `get_event_leaderboard`

Responsibilities:

- verify event ownership
- return ordered standings from `event_score_totals`
- include guest identity fields needed by the UI
- support simple ranking display without introducing prize logic

## Persistence Rules

This slice relies on the existing tables:

- `hand_results`
- `hand_settlements`
- `event_score_totals`

It should add or complete Dart-side models for:

- `HandResultRecord`
- `HandSettlementRecord`
- `EventScoreTotalRecord`
- `LeaderboardEntry`
- `HandResultDraft`

Session detail reads should combine:

- the session row
- ordered seats
- ordered hand history
- optionally current derived standings preview for participants

## Flutter Architecture

### Features

Add a new `features/scoring/` area with:

- session detail screen
- hand entry screen
- hand detail or edit screen
- controllers for session detail and hand submission

Add a real `features/leaderboard/` area if it is not already live:

- leaderboard screen
- controller that loads standings from the repository

### Repositories

Expand the repository layer to support:

- loading session detail and hand history
- recording a hand
- editing a hand
- voiding a hand
- loading event leaderboard

The repository should treat the server as the authority for scoring outputs and should not duplicate scoring math in Dart beyond optional preview helpers.

### Preview Logic

The app may include a lightweight scoring preview to improve host confidence before saving.

That preview should:

- mirror the same HK mapping and multiplier rules
- be clearly treated as a preview
- not become the source of truth

If keeping preview math in sync becomes awkward, prefer a server-backed preview RPC over duplicating too much client scoring logic.

## UI Design

### Session Detail

The session detail screen should show:

- table label
- session status
- current East guest
- seat map
- hand history list
- `Record Hand`

The seat map should make East visually distinct because dealer state matters operationally.

### Hand Entry

The hand-entry screen should be form-driven and fast:

- segmented or radio-style choice for `Win` vs `Washout`
- conditional inputs for win details
- scoring preview section
- `Save Hand`

For MVP, use guest names plus seat labels in selection controls so the host does not need to mentally translate seat indices.

### Hand History

Each hand row should show concise summaries such as:

- `Hand 4`
- `West wins by discard, 3 fan`
- `E pays 16, S pays 8, N pays 8`

Tapping a row opens edit/void controls.

### Leaderboard

The leaderboard should read cleanly during live events:

- rank
- player
- total points
- hands won
- self-draw wins

This slice should prefer readability over dense analytics.

## Error Handling

The scoring path should surface clear host-facing errors for:

- invalid hand shape
- discarder equals winner
- washout with leftover win fields
- session not active
- session already completed
- unknown historical hand
- recalculation failure

If recalculation fails after a write attempt, the transaction should roll back so the session never lands in a partially updated scoring state.

## Testing Strategy

### SQL And Engine Tests

Add authoritative tests for:

- fan bucket mapping
- discard multiplier logic
- self-draw multiplier logic
- East wins double-all behavior
- East loses double-East behavior
- washout retains East
- non-East win rotates East
- session completion when dealer returns with `dealer_pass_count >= 4`
- historical hand edit recalculates later hands
- voided hand removal recalculates standings correctly

### Repository Tests

Add repository tests for:

- session detail mapping
- record hand response mapping
- edit hand response mapping
- void hand response mapping
- leaderboard mapping and ordering

### Widget Tests

Add widget tests for:

- hand entry validation
- win vs washout conditional UI
- session detail rendering with seat map and hand history
- edit/void actions from hand history
- leaderboard rendering

### Live Smoke Extension

Extend the existing iOS simulator smoke harness to cover:

1. sign in
2. create event
3. add, check in, and tag four guests
4. create table and start session
5. record:
   - one discard win
   - one self-draw win
   - one washout
6. verify leaderboard updates
7. edit or void one historical hand
8. verify totals change after recalculation
9. clean up all live rows

## Risks And Trade-offs

### Duplicate Scoring Logic

If the app computes a preview locally, there is a risk of drift from the server engine.

Mitigation:

- keep the preview small and explicit
- prefer server truth after save
- move preview server-side later if needed

### Historical Edit Complexity

Historical edits are the highest-risk correctness path because they affect later dealer state and settlements.

Mitigation:

- funnel all mutations into the same recalculation function
- test historical edit and void paths early

### Session Detail Density

Scoring adds a lot of operational detail to one screen.

Mitigation:

- keep hand entry on a separate screen
- keep history rows concise
- avoid overloading session detail with non-essential controls
