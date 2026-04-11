# Events And Guests Vertical Slice Design

## Summary

This design defines the next Mosaic implementation slice after Phase 1 foundation work. The slice delivers one real host workflow end to end:

`Event List -> Create Event -> Event Dashboard -> Guest Roster -> Add/Edit Guest`

The goal is to validate the real app boundaries early without pulling in check-in, NFC, sessions, scoring, or prizes UI.

## Goals

- Deliver one production-shaped host workflow with real persistence.
- Keep the change small enough to review and test comfortably.
- Exercise the core data boundaries already introduced in Phase 1:
  - typed models
  - repository interfaces
  - Supabase as source of truth
  - local cache as a supporting layer
- Preserve product language from the spec:
  - `event`
  - `guest`
  - `session` as the internal gameplay term, even though this slice does not build session flows yet

## Out Of Scope

This slice does not implement:

- auth polish beyond the existing single-host assumption
- guest cover ledger entry workflows
- check-in and check-out flows
- NFC tag registration or assignment
- table CRUD
- session creation
- scoring
- leaderboard
- prizes UI
- offline mutation queues

## Product Scope

### Included screens

- Event list
- Create event
- Event dashboard
- Guest roster
- Add guest
- Edit guest

### Included event fields

- title
- starts at
- timezone
- venue name
- venue address
- cover charge cents
- prize budget cents
- default ruleset fixed to `HK_STANDARD_V1`

### Included guest fields

- display name
- phone E.164 optional
- email optional
- cover status
- cover amount cents
- note

## UX Direction

### Event list

Operational and lightweight. Each item should show the event title, start time, timezone, and basic context if available. The list should make it obvious how to create a new event.

### Create event

Focused on the smallest useful event setup. The form should not expose speculative future configuration. `default_ruleset_id` stays fixed to `HK_STANDARD_V1` in this slice, even though the schema already supports more.

### Event dashboard

A simple host operations hub for a single event. The dashboard should prioritize quick movement into the next action, not dense analytics. It should include:

- event title and status
- guest count summary
- quick actions for `Guests` and `Add Guest`
- clear placeholders or stubs for future sections, without pretending they are implemented

### Guest roster

A searchable or scan-friendly list is not required yet, but the structure should prepare for it. Each row should show:

- display name
- cover status badge
- attendance status badge

Duplicate names remain allowed. If the host adds a guest whose normalized name matches another guest in the same event, the form should warn but not block.

### Guest form

Add and edit should share one form model and one screen where practical. Validation should stay operational and forgiving:

- name required
- phone optional
- email optional
- cover amount non-negative
- cover status required

## Architecture

The slice should stay feature-first and keep responsibilities narrow.

### Features

#### `features/events/`

Owns:

- event list screen
- create event screen
- event dashboard screen
- event form state/controller
- event list/dashboard state/controller

#### `features/guests/`

Owns:

- guest roster screen
- add/edit guest screen
- guest form state/controller
- guest roster state/controller

### Data layer

#### Repository implementations

Concrete implementations should now be added behind the Phase 1 interfaces:

- `SupabaseEventRepository`
- `SupabaseGuestRepository`

Responsibilities:

- query and write Supabase rows
- map rows into typed models
- update local cache after successful writes

#### Local cache

This slice should introduce the first lightweight local persistence layer for:

- event summaries
- single event records
- guest lists by `event_id`

The cache does not need mutation queue behavior yet. It only needs enough functionality to support fast reloads and clean repository boundaries.

### Routing

Add explicit app routes for the vertical slice:

- event list
- create event
- event dashboard
- guest roster
- add/edit guest

Navigation should be linear and unsurprising.

## Data Flow

### Event list load

1. controller asks repository for events
2. repository may return cached events first
3. repository refreshes from Supabase
4. controller updates UI when refreshed data arrives

### Event creation

1. host submits create event form
2. controller validates input
3. repository inserts event in Supabase
4. repository updates cache
5. app navigates to the new event dashboard

### Guest roster load

1. dashboard opens guest roster for a specific `event_id`
2. controller requests guests for that event
3. repository returns cached list if available
4. repository refreshes from Supabase
5. controller updates the roster

### Guest create/edit

1. host submits guest form
2. controller validates input
3. controller computes duplicate-name warning if applicable
4. repository inserts or updates guest row in Supabase
5. repository updates cached guest list
6. app returns to roster

## Technical Design

### State management

Use simple built-in Flutter patterns first. `ChangeNotifier` or `ValueNotifier` based controllers are sufficient for this slice. Avoid bringing in a heavier state package before the app proves it needs one.

### Form models

Introduce separate draft/form objects for events and guests rather than mutating record models directly. This keeps validation and UI concerns out of persistence models.

### Validation

Keep validation explicit and local to the form/controller layer:

- required event title
- valid event datetime
- required timezone
- non-negative cover charge
- non-negative prize budget
- required guest display name
- non-negative guest cover amount

### Mapping rules

Repository mapping must preserve the Phase 1 schema conventions exactly:

- snake_case Supabase fields
- explicit enum conversion
- optional nullable contact fields
- explicit `default_ruleset_id`

## Testing Strategy

This slice should continue the TDD pattern.

### Unit tests

- event form validation
- guest form validation
- event repository row mapping
- guest repository row mapping
- duplicate-name warning helper behavior

### Widget tests

- event list renders loaded events
- create event form shows validation feedback
- guest roster renders guests for an event
- add guest form submits valid data through controller/repository boundary

### Non-goals for tests in this slice

- no scoring tests here
- no NFC tests here
- no end-to-end integration environment required yet

## Risks And Mitigations

### Risk: overbuilding the app shell

Mitigation:

- keep this slice tightly focused on the vertical workflow only
- do not build placeholder abstractions for future roles or features unless this slice truly depends on them

### Risk: local cache complexity grows too early

Mitigation:

- cache read-through and write-through only
- no offline mutation queue
- no generalized sync engine in this slice

### Risk: form logic leaks into repositories

Mitigation:

- repository accepts already-validated payloads or typed records
- keep duplicate-name warnings and field validation in feature-level controllers or helpers

## Recommended Commit Goal

The implementation plan for this design should aim at a single thin vertical slice that results in:

- a host can create an event
- a host can open that event
- a host can add and edit guests
- the roster persists through the repository layer

## Open Notes

- This design assumes the current single-host MVP auth posture remains unchanged.
- This design does not require applying the Supabase migration during the same code change, but the implementation plan should call out when the migration must be run against the real project.
- Future check-in, cover ledger, and scoring flows should build on these repositories rather than bypassing them.
