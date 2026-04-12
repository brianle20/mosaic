# Event Completion And Finalization Design

## Goal

Add the MVP event-closure flow for Mosaic so the host can move an event from live play into review and then into a locked final state.

The flow is intentionally two-step:

1. `active -> completed`
2. `completed -> finalized`

This preserves a review checkpoint after live play ends and before the event becomes immutable for scoring and prize configuration.

## Scope

This slice includes:

- `Complete Event` action
- `Finalize Event` action
- server-authoritative lifecycle RPCs
- dashboard status and action updates by event state
- blocking rules for active sessions and unlocked prize plans
- audit logging for completion and finalization

This slice does not include:

- reopening finalized events
- export/report generation
- payout disbursement
- post-finalization scoring edits

## Product Workflow

### Complete Event

Host intent:

- live scoring is over
- no more sessions should start
- standings and prizes can still be reviewed

Behavior:

- available only when `events.lifecycle_status = active`
- blocked if any `table_sessions` are `active` or `paused`
- sets:
  - `events.lifecycle_status = completed`
  - `events.scoring_open = false`
- leaves prize review and prize award payout tracking available

### Finalize Event

Host intent:

- standings and prize awards are final
- the event should be locked as the authoritative record

Behavior:

- available only when `events.lifecycle_status = completed`
- blocked if any sessions are `active` or `paused`
- blocked if a prize plan exists with `mode != none` and `status != locked`
- sets:
  - `events.lifecycle_status = finalized`
  - `events.checkin_open = false`
  - `events.scoring_open = false`

## Locking Rules

### After completion

Disallow:

- starting new sessions
- recording/editing/voiding hands
- reopening live scoring in the UI

Allow:

- leaderboard review
- prize review
- locking prize awards
- payout status updates on locked awards

### After finalization

Disallow:

- event edits that would change standings or operational state
- prize plan edits
- re-locking or regenerating awards
- any scoring/session mutations

Allow:

- viewing leaderboard
- viewing locked prize awards
- marking locked awards `paid` or `void` for bookkeeping

## Backend Design

## RPCs

### `complete_event(target_event_id uuid)`

Responsibilities:

- verify current host owns the event
- verify `events.lifecycle_status = active`
- verify no sessions for the event are `active` or `paused`
- update event to `completed`
- set `scoring_open = false`
- audit the change

### `finalize_event(target_event_id uuid)`

Responsibilities:

- verify current host owns the event
- verify `events.lifecycle_status = completed`
- verify no sessions for the event are `active` or `paused`
- if prize plan exists and `mode != none`, verify `status = locked`
- update event to `finalized`
- set `checkin_open = false`
- set `scoring_open = false`
- audit the change

## Database Rules

These server checks should remain authoritative even if the client pre-validates:

- no completion with active or paused sessions
- no finalization with active or paused sessions
- no finalization with unlocked applicable prize plan
- no repeated invalid lifecycle transition

## Client Architecture

## Repository

Extend `EventRepository` with:

- `Future<EventRecord> completeEvent(String eventId)`
- `Future<EventRecord> finalizeEvent(String eventId)`

The Supabase repository should:

- call the new RPCs
- refresh cached event data
- return the updated `EventRecord`

## Event Dashboard

The dashboard becomes the primary closure UI.

### Active event dashboard

Show:

- event status
- existing actions
- `Complete Event`

### Completed event dashboard

Show:

- event status as `completed`
- review-oriented framing
- `Leaderboard`
- `Prizes`
- `Finalize Event`

### Finalized event dashboard

Show:

- event status as `finalized`
- locked/final messaging
- read-only review actions
- `Prizes` remains accessible for payout tracking

## Error Handling

Host-facing errors should be explicit and operational:

- “This event still has active sessions.”
- “Prize awards must be locked before finalization.”
- “Only active events can be completed.”
- “Only completed events can be finalized.”

Avoid generic failure text when a specific lifecycle block is known.

## Testing

### Repository tests

- `completeEvent` returns updated lifecycle status
- `finalizeEvent` returns updated lifecycle status

### Widget tests

- active dashboard shows `Complete Event`
- completed dashboard shows `Finalize Event`
- finalized dashboard hides live-operation actions

### SQL / RPC verification

- cannot complete with active session
- cannot finalize with unlocked prize plan
- can finalize when sessions are closed and prizes are locked

### Live smoke

Extend the existing live flow to:

- score event
- lock prize awards
- complete event
- finalize event
- verify `events.lifecycle_status = finalized`
- cleanup all smoke rows

## Acceptance Criteria

- Host can complete an active event only when no active or paused sessions remain.
- Completing an event sets it into a review state and closes scoring.
- Host can finalize a completed event only when no active or paused sessions remain.
- If a non-`none` prize plan exists, finalization requires locked prize awards.
- Finalization locks the event from further scoring and prize-plan edits.
- Locked prize awards remain available for payout status updates after finalization.
- Completion and finalization actions are audited.
