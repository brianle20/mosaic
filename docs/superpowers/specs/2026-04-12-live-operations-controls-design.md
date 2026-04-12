# Live Operations Controls Design

## Summary

This slice closes the remaining host-side operational gap between event setup and event closure.

Mosaic already supports:

- draft event creation
- guest roster and cover status
- check-in and player tag assignment
- table setup and session start
- scoring and leaderboard
- prize planning and awards
- event completion and finalization

What is still missing is a clean host-facing control layer for running the event live:

- moving an event from `draft` to `active`
- opening and closing check-in
- opening and closing scoring
- pausing, resuming, and ending sessions early

This design adds those controls without changing the existing lifecycle model:

- lifecycle status remains the event phase
- operational flags remain the live-operational switches
- session status remains the per-table operational state

## Goals

- Give the host an explicit `Start Event` action for `draft -> active`
- Make `checkin_open` and `scoring_open` real operational controls in the UI
- Add server-authoritative session controls:
  - `pause`
  - `resume`
  - `end early`
- Keep transitions validated and audited in Supabase
- Preserve the existing lifecycle semantics:
  - `draft`
  - `active`
  - `completed`
  - `finalized`
  - `cancelled`

## Out Of Scope

- auto-starting events by time
- auto-closing scoring when sessions still exist
- guest check-out
- cover ledger UI
- exports
- redesigning restart/abort flows
- any new scoring or prize logic

## Product Behavior

### Event start

Draft events should show a primary `Start Event` action on the event dashboard.

`Start Event`:

- is allowed only when `lifecycle_status = draft`
- updates the event to:
  - `lifecycle_status = active`
  - `checkin_open = true`
  - `scoring_open = false`

This matches the intended host flow:

1. configure the event in `draft`
2. start the event
3. begin check-in
4. open scoring when tables are ready

### Operational flags

Active events should expose explicit controls for:

- opening and closing check-in
- opening and closing scoring

These controls do not change lifecycle state. They only change operational readiness.

Rules:

- only `active` events may change operational flags
- completed/finalized/cancelled events cannot change flags
- draft events cannot toggle live operations before start

### Session controls

Active or paused sessions should expose operational controls in session detail.

For `active` sessions:

- `Pause Session`
- `End Early`

For `paused` sessions:

- `Resume Session`
- `End Early`

For `completed`, `ended_early`, or `aborted` sessions:

- live controls are hidden

`End Early` requires a host reason and should preserve the session record in history.

### Operational gating

The new controls should become real guardrails in backend behavior:

- guest check-in and tag assignment require:
  - event is `active`
  - `checkin_open = true`
- scored session start requires:
  - event is `active`
  - `scoring_open = true`
- hand entry and hand mutation require:
  - event is `active`
  - `scoring_open = true`
  - session status allows it
- paused sessions cannot record or edit hands
- paused sessions can resume only when `scoring_open = true`

## Backend Design

## Event RPCs

Add:

- `start_event(target_event_id uuid)`
- `set_event_operational_flags(target_event_id uuid, target_checkin_open boolean, target_scoring_open boolean)`

### `start_event`

Responsibilities:

- require current host ownership
- require event status is `draft`
- update:
  - `lifecycle_status = active`
  - `checkin_open = true`
  - `scoring_open = false`
- increment `row_version`
- write an audit log
- return the updated `events` row

### `set_event_operational_flags`

Responsibilities:

- require current host ownership
- require event status is `active`
- update:
  - `checkin_open`
  - `scoring_open`
- increment `row_version`
- write an audit log
- return the updated `events` row

## Session RPCs

Add:

- `pause_table_session(target_table_session_id uuid)`
- `resume_table_session(target_table_session_id uuid)`
- `end_table_session(target_table_session_id uuid, target_end_reason text)`

### `pause_table_session`

Responsibilities:

- require current host ownership
- require session status is `active`
- require event is still operationally scorable
- update session to:
  - `status = paused`
- audit the transition
- return updated row

### `resume_table_session`

Responsibilities:

- require current host ownership
- require session status is `paused`
- require:
  - event is `active`
  - `scoring_open = true`
- update session to:
  - `status = active`
- audit the transition
- return updated row

### `end_table_session`

Responsibilities:

- require current host ownership
- require session status is `active` or `paused`
- require non-empty reason
- update session to:
  - `status = ended_early`
  - `ended_at = now()`
  - `ended_by_user_id = auth.uid()`
  - `end_reason = target_end_reason`
- audit the transition
- return updated row

Ended-early sessions remain part of standings history but no longer block event completion/finalization.

## Guard Helpers

Add helper functions for:

- requiring event ownership and status
- requiring event is open for check-in
- requiring event is open for scoring
- requiring session transition validity

These helpers should be reused by:

- `check_in_guest`
- tag assignment flows
- `start_table_session`
- `record_hand_result`
- `edit_hand_result`
- `void_hand_result`
- `pause_table_session`
- `resume_table_session`

This keeps operational policy centralized instead of duplicated in each RPC.

## App Architecture

### Repository changes

Extend `EventRepository` with:

- `Future<EventRecord> startEvent(String eventId)`
- `Future<EventRecord> setOperationalFlags({required String eventId, required bool checkinOpen, required bool scoringOpen})`

Extend `SessionRepository` with:

- `Future<SessionDetailRecord> pauseSession(String sessionId)`
- `Future<SessionDetailRecord> resumeSession(String sessionId)`
- `Future<SessionDetailRecord> endSession({required String sessionId, required String reason})`

Supabase implementations should:

- call authoritative RPCs
- refresh local cache
- return typed records

### Event dashboard

The event dashboard becomes the host’s top-level live control surface.

#### Draft dashboard

Show:

- event summary
- `Start Event`
- no live check-in/scoring controls yet

#### Active dashboard

Show:

- event summary
- operational controls section
  - `Check-In Open` / `Check-In Closed`
  - `Scoring Open` / `Scoring Closed`
- action buttons to change each flag

#### Completed/finalized dashboard

Show lifecycle and review state, but the operational controls should be hidden or read-only.

### Session detail

Session detail already shows seat map and hand history.

Add a small operational controls section:

- if session is `active`
  - `Pause Session`
  - `End Early`
- if session is `paused`
  - `Resume Session`
  - `End Early`
- if session is not live
  - no operational controls

`End Early` should use a simple reason prompt rather than a large workflow.

## UX Notes

- `Start Event` should be clearly primary on draft events
- operational flags should read like live state, not raw booleans
- blocked actions should show direct host-facing explanations
  - example: `Scoring must be open before starting a session.`
  - example: `Check-in is closed for this event.`
- `End Early` should make it obvious that the session history is preserved

## Testing Strategy

### Repository tests

Add coverage for:

- `startEvent`
- `setOperationalFlags`
- `pauseSession`
- `resumeSession`
- `endSession`

### Widget tests

Add coverage for:

- draft dashboard shows `Start Event`
- active dashboard shows operational flag controls
- completed/finalized dashboards hide live controls
- session detail action set changes by session status
- end-early requires a reason

### SQL verification

Direct SQL verification should cover:

- cannot start event unless status is `draft`
- cannot toggle flags unless status is `active`
- cannot check in when `checkin_open = false`
- cannot start session when `scoring_open = false`
- cannot record/edit/void hands when scoring is closed
- cannot resume a session while scoring is closed
- can end early from both `active` and `paused`

### Live smoke

Extend the existing simulator smoke test to cover:

1. create draft event
2. start event
3. verify `checkin_open = true` and `scoring_open = false`
4. open scoring
5. complete check-in and session start
6. pause session
7. resume session
8. end session early
9. complete/finalize still succeed afterward
10. verify cleanup leaves no residue

## Recommendation

Implement this as one thin live-operations slice:

- event start
- operational flags
- session pause/resume/end early

That is the highest-value remaining operational gap because it turns the current system into a host-run live workflow without relying on backend-only state changes or smoke-test shortcuts for normal event control.
