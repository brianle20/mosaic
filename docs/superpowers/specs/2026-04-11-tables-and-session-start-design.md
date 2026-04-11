# Tables And Session Start Slice Design

## Summary

This slice adds the operational bridge between tagged players and scored play:

`Tables overview -> configure points table -> bind table tag -> start session by scanning table + four player tags`

The design keeps the MVP narrow:

- only points tables can start scored sessions
- the only exposed ruleset remains `HK_STANDARD_V1`
- the only exposed rotation policy remains `dealer_cycle_return_to_initial_east`
- scan order defines seats as East, South, West, North
- the host uses the same scan-first flow on device and simulator, with manual UID entry as the simulator fallback

This slice stops at session creation. It does not include hand entry, scoring, pause/resume, or end-session operations.

## Goals

- Let the host configure event tables inside the app
- Let the host bind reusable NFC table tags to event tables
- Let the host start a scored session from already checked-in, tagged guests
- Enforce all MVP session-start eligibility rules authoritatively
- Store `ruleset_id` and `rotation_policy_type` explicitly on every session from day one
- Keep the flow testable on the iOS simulator with the existing manual UID fallback

## Non-goals

- No hand recording
- No dealer progression or session completion UI
- No pause, resume, end early, or abort controls
- No mixed rulesets in production UI
- No alternate rotation policy selection in production UI
- No manual guest-pick fallback during session start
- No table-side casual seating management

## User Flow

### Tables Overview

The event dashboard gets a `Tables` entry point. The tables overview shows every table for the event and a fast action to add a new one.

Each table card should show:

- label
- mode
- whether a table tag is bound
- whether a session is active
- if active, a brief state summary such as `Session active`

### Table Config

The host can create or edit a table with a minimal form:

- label
- mode: `points`, `casual`, `inactive`
- default ruleset fixed to `HK_STANDARD_V1`
- default rotation policy fixed to `dealer_cycle_return_to_initial_east`
- optional bind or replace table tag action

Binding a table tag is an explicit host action. Unknown table tags may be registered only through this explicit bind flow, not during session start.

### Start Session

The host starts a session from a points-enabled table card.

Flow:

1. Open `Start Session`
2. Scan the table tag
3. Scan East player tag
4. Scan South player tag
5. Scan West player tag
6. Scan North player tag
7. Review resolved guests and seat order
8. Confirm session start

The scan prompts are explicit and sequential. The simulator path uses the existing manual UID entry dialog at each step.

Seat assignment is defined only by scan order:

- first player tag = East
- second = South
- third = West
- fourth = North

## Domain Rules

### Table Rules

- only `points` tables may start scored sessions
- one event table may have at most one bound table tag
- one table tag may be bound to at most one event table in the event
- table tags are event-scoped operational bindings, not global table identities

### Session Start Rules

A session can be created only when:

- the target table belongs to the current host's event
- the table mode is `points`
- the table has no active or paused session
- exactly four unique guests are resolved from the scanned player tags
- all four guests are checked in
- all four guests have active player-tag assignments in the event
- none of the guests are already in another active or paused session for the event

### Tag Rules

- the scanned table tag must already be known and bound to the selected event table
- unknown table tags are blocked during session start
- unknown player tags are blocked during session start
- duplicate player tags in the same setup are rejected immediately
- player/table type mismatches are rejected immediately

## Backend Design

## New RPCs

This slice should add server-authoritative functions for:

- `create_event_table`
- `update_event_table`
- `bind_table_tag`
- `start_table_session`

The app may perform lightweight pre-validation for UX, but the RPCs remain authoritative.

## `create_event_table`

Responsibilities:

- verify the event belongs to `auth.uid()`
- insert an `event_tables` row
- default ruleset to `HK_STANDARD_V1`
- default rotation policy to `dealer_cycle_return_to_initial_east`
- audit the creation

## `update_event_table`

Responsibilities:

- verify ownership
- update label, mode, and display order as needed
- preserve existing session rows
- audit before/after

## `bind_table_tag`

Responsibilities:

- verify event ownership
- normalize scanned UID
- create or update `nfc_tags` as a `table` tag
- reject assignment if the tag is actively bound to another table in the event
- bind or replace the table's `nfc_tag_id`
- audit the bind or replacement

## `start_table_session`

Responsibilities:

- verify ownership
- lock the target table row
- verify `points` mode
- verify no active or paused session already exists for the table
- resolve the table from the scanned table tag and verify it matches the selected table
- resolve four player tags to four active guest assignments
- verify guest eligibility
- verify none of the guests are already in another active or paused session
- compute `session_number_for_table`
- load the ruleset version for `HK_STANDARD_V1`
- insert the `table_sessions` row with explicit:
  - `ruleset_id`
  - `ruleset_version`
  - `rotation_policy_type`
  - `rotation_policy_config_json`
- set:
  - `initial_east_seat_index = 0`
  - `current_dealer_seat_index = 0`
  - `dealer_pass_count = 0`
  - `completed_games_count = 0`
  - `hand_count = 0`
  - `status = active`
- insert four `table_session_seats` rows
- audit session creation

The session start RPC should take the selected table id plus the scanned UIDs. The selected table remains the user's intent; the scanned table tag is an operational confirmation.

## Data Model Additions

The base schema already contains:

- `event_tables`
- `table_sessions`
- `table_session_seats`

This slice should add or complete the Dart-side typed models for:

- `EventTableRecord`
- `CreateEventTableInput`
- `UpdateEventTableInput`
- `TableSessionSeatRecord`
- `StartSessionInput`
- optional resolved preview types used only by the app layer

These models should preserve explicit `ruleset_id` and `rotation_policy_type` on sessions even though the MVP exposes only one choice.

## Flutter Architecture

### Features

Add a new `features/tables/` area with:

- tables overview screen
- table form screen
- start session screen
- table/session controllers

### Repositories

Add concrete repositories and interfaces for:

- table CRUD
- table tag binding
- session start
- listing active sessions for an event

### NFC Service

Extend the existing NFC abstraction with scan intents for:

- `scanTableTag`
- `scanPlayerTagForSessionSeat`

The simulator implementation should reuse the manual UID dialog and keep the prompts explicit by step.

## UI Design

### Event Dashboard

Add a `Tables` action beside the existing host actions.

### Tables Overview

Each table card should show:

- label
- mode badge
- `Table Tag Bound` or `Table Tag Unbound`
- `Session Active` when relevant

Primary actions:

- `Add Table`
- `Edit`
- `Bind Table Tag`
- `Start Session` for eligible points tables

### Table Form

The form should be intentionally compact:

- `Label`
- `Mode`

The ruleset and rotation policy should be presented as read-only defaults for this MVP slice instead of editable fields.

### Start Session Screen

Use a step-based layout with one clear action at a time:

- selected table summary
- current scan prompt
- resolved seat list as progress builds
- final review state before confirmation

At the review step, the UI should show:

- East guest
- South guest
- West guest
- North guest
- ruleset
- rotation policy

This is the host’s last chance to catch a seating mistake before session creation.

## Error Handling

The app should show specific messages for:

- unknown table tag
- table tag belongs to a different table
- player tag unknown
- duplicate player tag scanned in the same setup
- guest is not checked in
- guest has no active player tag
- guest already active in another session
- selected table is not a points table
- selected table already has an active session

Errors should keep the host on the current scan step when possible rather than dumping them back to the start.

## Testing Strategy

### Unit Tests

- seat order maps scan order to East, South, West, North
- session-start eligibility helpers reject ineligible guests
- table form validation covers required label and mode transitions

### Repository Tests

- `bind_table_tag` maps server results correctly
- `start_table_session` maps session and seat rows correctly
- server conflict errors surface useful app-level messages

### Widget Tests

- tables overview renders table cards and statuses
- points tables show `Start Session`
- non-points tables do not show `Start Session`
- start-session step flow advances through table and seat scans
- review screen shows the resolved seat map

### Integration Test

Extend the live iOS smoke test to:

1. sign in
2. create an event
3. add four paid guests
4. check in and assign player tags to all four
5. create a points table
6. bind a table tag
7. start a session with scanned table/player tags
8. verify `table_sessions` and `table_session_seats`
9. clean up all created rows

## Risks And Trade-offs

### Scan-first fidelity vs simulator speed

Keeping scan-first behavior now avoids a later rewrite of the host workflow, but it makes the simulator path more verbose. This is acceptable because operational correctness matters more than brevity in this part of the app.

### Explicit table selection plus table-tag scan

This may feel redundant, but it reduces host mistakes. The host intentionally starts from a table card, then confirms physical-table identity by scan.

### No hand entry in this slice

That is intentional. Session creation has enough eligibility, tagging, and operational complexity to stand on its own as a reviewable increment.

## Acceptance Criteria For This Slice

- Host can create and edit event tables
- Host can bind a table tag to an event table
- Host can start a scored session only from a points table
- Session start requires a bound matching table tag
- Session start requires four unique, checked-in, player-tagged guests
- Session start blocks guests already seated in another active or paused session
- Session stores explicit `ruleset_id`, `ruleset_version`, and `rotation_policy_type`
- Session inserts ordered seat rows for East, South, West, North
- Simulator flow can complete the entire start-session path through manual UID entry
