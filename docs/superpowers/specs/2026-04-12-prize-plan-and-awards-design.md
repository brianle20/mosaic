# Prize Plan And Awards Slice Design

## Goal

Add the MVP prize workflow for Mosaic:

`Prize Plan -> Award Preview -> Lock Prize Awards -> Mark Awards Paid`

This slice builds on the existing scoring and leaderboard flow and keeps prize logic separate from gameplay scoring, cover bookkeeping, and final event finalization.

## Product Scope

### In scope

- prize plan configuration
- prize plan modes:
  - `none`
  - `fixed`
  - `percentage`
- reserve handling:
  - fixed reserve
  - percentage reserve
- derived award preview based on current standings
- prize eligibility based on scored participation only
- tie splitting across affected prize ranks
- deterministic leftover-cent allocation
- locking awards into persisted `prize_awards` rows
- payout status tracking on locked awards:
  - `planned`
  - `paid`
  - `void`

### Out of scope

- event finalization
- payment processing or disbursement
- prize funding derived automatically from cover
- manual override editing of locked award amounts
- exports and advanced payout reporting

## Why Prize Locking Exists

Prize preview is derived from live standings and the editable prize plan. It can change while scoring or plan edits continue.

Prize locking turns that preview into the host's official payout list by persisting concrete `prize_awards` rows. After lock:

- the recipients and amounts stop changing silently
- payout tracking can operate against stable rows
- the host has an operational checklist for who should be paid

This is distinct from event finalization:

- prize lock freezes the payout list
- event finalization later freezes the event's overall final state

## Host Workflow

1. Host opens `Prizes` from the event dashboard.
2. Host configures plan mode, reserves, and prize tiers.
3. App previews derived awards from current standings.
4. App validates that the preview fits within the distributable budget.
5. Host taps `Lock Prize Awards`.
6. App persists official `prize_awards` rows.
7. Host marks individual awards `paid` or `void` as real-world payouts occur.

## Architecture

### Backend responsibility

Prize behavior should be server-authoritative in Supabase RPCs, mirroring the scoring architecture already in use.

Recommended RPCs:

- `upsert_prize_plan`
- `preview_prize_awards`
- `lock_prize_awards`
- `mark_prize_award_paid`
- `void_prize_award`

### Core rule boundaries

- scoring produces standings
- prize preview derives awards from standings
- award lock persists the payout list
- payout tracking only updates locked awards

Prize logic must not:

- change gameplay score totals
- depend on cover collected
- auto-send payments

## Data Model Expectations

### Existing tables used

- `events`
- `event_guests`
- `event_score_totals`
- `prize_plans`
- `prize_tiers`
- `prize_awards`
- `audit_logs`

### Existing event data dependency

Prize budget remains event-scoped through `events.prize_budget_cents`.

`prize_plans` stores:

- mode
- status
- reserve fixed amount
- reserve percentage
- note

`prize_tiers` stores either:

- fixed amount tiers, or
- percentage tiers

`prize_awards` stores the official locked payout rows and their payout-tracking fields.

## Prize Budget Rules

### Distributable budget

Distributable budget is:

`event.prize_budget_cents - reserve_fixed_cents - reserve_percentage_share`

Where:

- `reserve_percentage_share = prize_budget_cents * reserve_percentage_bps / 10000`
- final distributable value is clamped at zero

### Validation

- locked awards must not exceed the distributable budget
- preview can surface invalid configurations, but lock must be blocked when invalid
- `none` mode should produce zero awards cleanly

## Ranking And Eligibility

### Ranking basis

Awards rank by:

`total_points DESC`

using current server-derived leaderboard data.

### Eligibility

A guest is prize-eligible only if they have scored participation in the event.

That means:

- guests with `has_scored_play = true` are eligible
- comped guests are eligible if they played scored hands
- spectators and non-playing attendees are not eligible

There is no secondary tiebreak in MVP.

## Tie Handling

When guests tie across prize-paying ranks:

1. combine the prize amounts across the affected ranks
2. split equally among the tied eligible guests
3. assign leftover cents deterministically using:
   1. best affected rank first
   2. alphabetical `display_name` order for remainder allocation

The app should display tied ranks clearly in preview and locked awards using rank ranges such as `T-2` or an equivalent readable shared-rank label.

## Locking Behavior

### Before lock

- prize plan can remain editable
- preview can be recalculated from live standings
- no official payout list exists yet

### On lock

`lock_prize_awards` should:

1. validate the current plan and distributable budget
2. compute the current preview from current standings
3. replace any previous unlocked award state as needed by policy
4. persist new `prize_awards` rows
5. mark the plan as locked
6. write an audit record

### After lock

- payout tracking becomes available
- award rows are stable
- later standings changes should not silently rewrite locked awards
- final event finalization will later lock the broader event state

## Payout Tracking

Payout tracking is bookkeeping, not payment processing.

Supported statuses:

- `planned`
- `paid`
- `void`

Recommended tracked metadata:

- `paid_method`
- `paid_at`
- `paid_note`

This gives the host an operational record of what actually happened without Mosaic ever sending money.

## Flutter App Structure

### Feature area

Create `features/prizes/` with:

- `prize_plan_screen.dart`
- `prize_awards_screen.dart`
- plan controller
- awards controller

### Data layer

Add or extend models for:

- `PrizeTierRecord`
- `PrizeAwardRecord`
- preview row model

Add `SupabasePrizeRepository` to own:

- plan CRUD/upsert
- preview fetch
- award lock
- payout status updates

### Routing

Add a `Prizes` path from the event dashboard into the prize feature flow.

## UX Design

### Prize Plan screen

Show:

- current event prize budget, read-only
- mode selector:
  - `none`
  - `fixed`
  - `percentage`
- reserve fixed input
- reserve percentage input
- tier editor

The tier editor should stay operationally simple:

- one row per place
- amount field for fixed mode
- percentage field for percentage mode

### Preview section

Preview should show:

- rank
- guest name
- award amount
- shared-rank/tie indication when applicable

Validation warnings should appear inline when:

- awards exceed distributable budget
- tiers are malformed for the selected mode

### Locked awards screen

After lock, show:

- rank
- guest
- amount
- current payout status
- actions to mark `paid` or `void`

The list should function as a payout checklist rather than a spreadsheet.

## Error Handling

The system should handle these cases explicitly:

- zero prize budget with `none` mode
- zero prize budget with non-zero tiers
- invalid or duplicate tier places
- fixed awards exceeding distributable budget
- percentage tiers that exceed 100%
- no eligible scored players
- ties spanning prize and non-prize boundaries
- payout update attempted before awards are locked

Server-side RPC validation should remain authoritative even if the app pre-validates.

## Testing Strategy

### Unit tests

Cover:

- distributable budget math
- fixed-mode allocation
- percentage-mode allocation
- eligibility filtering
- tie splitting
- leftover-cent ordering

### Repository tests

Cover:

- prize plan mapping
- preview mapping
- lock mapping
- mark-paid mapping
- void mapping

### Widget tests

Cover:

- prize plan validation states
- over-budget lock blocking
- preview rendering
- locked awards status actions

### Live smoke test extension

Extend the existing iOS simulator smoke test to:

1. create event and score enough hands for non-trivial standings
2. open prizes
3. configure a prize plan
4. preview awards
5. lock awards
6. mark one award paid
7. verify `prize_awards` server rows
8. clean up all created rows

## Recommendation

Implement the full operational slice now:

`Prize Plan -> Preview Awards -> Lock Prize Awards -> Mark Paid`

This is the smallest slice that feels complete for a host running a live event. A preview-only prize tool would still leave the host without a stable payout checklist, which is the main operational reason this feature exists.
