# Check-In And Player Tag Slice Design

## Summary

This slice adds the first live operational event intake flow after guest creation:

`Guest roster -> guest detail/check-in -> assign player tag -> checked in + tagged`

The slice is intentionally narrow. It focuses on player check-in and player tag assignment only. It does not include table tags, session start scanning, or full hardware NFC polish.

The main product goal is to let the host quickly admit an eligible guest and bind a reusable player identity token to that guest for later scored session use.

## Product Scope

### In scope

- guest detail / check-in screen
- roster badges for attendance and tag status
- `Check In and Assign Tag`
- `Assign Tag`
- `Replace Tag`
- player tag registration during assignment for unknown tags
- simulator/dev fallback for manual tag UID entry
- repository and backend support for check-in and tag assignment
- backend-enforced uniqueness and eligibility rules
- tests for eligibility, conflicts, and the simulator/dev assignment flow

### Out of scope

- table tags
- session-start seat scanning
- passive/background NFC scanning
- full check-out and tag release flows, unless required for replacement correctness
- non-player tag operations
- camera/tile recognition

## Product Rules

### Guest eligibility

A guest may receive a player tag only if:

- `cover_status = paid`, or
- `cover_status = comped`

`partial`, `unpaid`, and `refunded` are not eligible.

### Check-in behavior

The host may check in and tag a guest in one operation.

This slice should support:

- assigning a tag while checking in an eligible guest
- assigning or replacing a tag for a guest who is already checked in

### Player tag rules

- one guest may have only one active player tag assignment per event
- one player tag may be actively assigned to only one guest per event
- unknown player tags may be registered during assignment
- tag assignment history must be preserved

### Replacement behavior

Replacing a tag must:

- mark the old assignment as no longer active
- preserve the old assignment row for audit/history
- create a new active assignment row

## Recommended UX

### Guest roster

The roster should continue to be the main operational list. Each row should show:

- display name
- cover badge
- attendance badge
- tag badge

Recommended tag badge states:

- `Tag Unassigned`
- `Tag Assigned`

### Guest detail / check-in screen

Selecting a guest should open a detail screen that shows:

- display name
- phone/email if present
- cover status
- attendance status
- current tag status
- current active tag label or UID if assigned

Primary actions:

- `Check In and Assign Tag`
- `Assign Tag`
- `Replace Tag`
- `Edit Guest`

### Ineligible guest UX

If the guest is not `paid` or `comped`:

- block tag assignment
- explain the eligibility rule clearly
- offer a fast path back to edit cover status

### Simulator / dev scan UX

Because the iOS simulator cannot provide real NFC reads, the app should expose a dev fallback through the NFC abstraction:

- start “scan”
- show a modal or entry sheet
- host enters a UID manually
- app treats that UID as the scanned tag

This keeps the flow testable in the simulator without distorting the production architecture.

## Architecture

### Service boundary

Introduce an explicit NFC abstraction:

- `services/nfc/nfc_service.dart`

Recommended interface shape:

- `scanPlayerTagForAssignment()`

Return value should include at least:

- raw UID / normalized UID
- whether the read came from fallback/manual entry

Implementations:

- simulator/dev manual-entry implementation
- device NFC implementation boundary for future iOS hardware support

The rest of the app should depend on the interface, not platform details.

### Repository boundary

The current repositories should be extended so app features do not talk directly to Supabase tables.

Recommended additions:

- `GuestRepository.checkInGuest(...)`
- `GuestRepository.assignGuestTag(...)`
- `GuestRepository.replaceGuestTag(...)`
- `TagRepository` or equivalent tag-focused methods if the surface becomes too broad

The repository result should include enough persisted data for the UI to refresh immediately:

- updated guest record
- active assignment summary, or enough identifiers to reload it

### Models

Current typed models already include tag records, but this slice likely needs read models for active assignment state.

Recommended additions:

- active guest tag assignment summary
- guest detail view model or repository aggregate for:
  - guest
  - active tag assignment

Avoid over-modeling. Only add new types where the screen would otherwise have to stitch unrelated JSON together manually.

## Backend Design

### Authoritative operations

Tag operations should be server-authoritative. Use SQL functions / RPCs rather than raw multi-step client writes.

Recommended functions:

- `check_in_guest`
- `register_nfc_tag`
- `assign_guest_tag`
- `replace_guest_tag`

### Function responsibilities

#### `check_in_guest`

- verify the guest belongs to an event owned by the current host
- update attendance status to `checked_in`
- set `checked_in_at` if appropriate
- write audit log entry

#### `register_nfc_tag`

- normalize and store UID / fingerprint
- create tag row when unknown
- require explicit tag type
- reuse existing row if the tag already exists

#### `assign_guest_tag`

- verify host ownership through event scope
- verify guest is `paid` or `comped`
- verify guest is checked in, or reject if the caller did not check in first
- verify tag type is `player`
- block assignment if:
  - guest already has an active player tag
  - tag is already actively assigned to another guest in the event
- create active assignment row
- write audit log entry

#### `replace_guest_tag`

- verify host ownership through event scope
- verify guest is eligible
- find current active assignment
- mark old assignment inactive using allowed status transition
- create replacement active assignment row
- write audit log entry

### Database constraints

The existing unique partial indexes on `event_guest_tag_assignments` should remain the primary safety rails:

- one active guest assignment per event guest
- one active assignment per tag within an event

This slice should build on those constraints rather than re-implementing them only in Dart.

### RLS

Existing owner-scoped RLS should extend naturally to:

- `nfc_tags`
- `event_guest_tag_assignments`

If the current policies are too broad or incomplete for these write paths, add the minimal policy changes required by the RPC/functions.

## Data Flow

### Happy path

1. Host opens guest detail.
2. App shows current attendance / cover / tag state.
3. Host taps `Check In and Assign Tag`.
4. App asks the NFC service to scan.
5. On simulator/dev, host enters a UID.
6. App calls backend:
   - register tag if needed
   - check in guest if needed
   - assign active player tag
7. App reloads guest detail and roster state.
8. Guest now appears checked in with assigned tag.

### Unknown tag

If the scanned UID is not known:

- the app registers it as a `player` tag
- then proceeds with assignment

### Conflict path

If the scanned tag is already assigned to another guest in the event:

- the backend rejects the operation
- the UI shows a specific message
- no partial client-side state should remain

### Ineligible guest path

If the guest is not `paid` or `comped`:

- block the check-in/tag assignment operation
- show the eligibility reason
- route the host to edit the guest if needed

## Error Handling

Friendly UI errors should map from backend/domain errors, not from raw database messages.

Recommended user-facing cases:

- `Guest must be paid or comped before receiving a player tag.`
- `This guest already has an active player tag.`
- `This tag is already assigned to another guest in this event.`
- `Only player tags can be assigned to guests.`
- `Unable to read the tag. Please try again.`

Keep raw SQL / PostgREST error text out of the host UI.

## Testing

### Unit tests

- guest eligibility for player tag assignment
- friendly error mapping for tag conflicts and ineligible guests
- dev/manual UID parsing behavior

### Repository tests

- check-in mapping
- assign tag mapping
- replace tag mapping
- active assignment summary mapping

### Widget tests

- guest detail shows correct action states by cover status
- ineligible guests are blocked from tag assignment
- manual UID entry flow appears in simulator/dev mode

### Integration test

Extend the existing simulator smoke approach with a new live path:

1. sign in
2. create event
3. add paid guest
4. check in and assign player tag through the manual UID fallback
5. verify the guest appears checked in and tagged
6. verify cleanup leaves no smoke rows behind

## Implementation Notes

- keep the internal domain term `session`; do not introduce “round” in internal APIs
- do not add table-tag behavior in this slice
- do not require real NFC hardware to validate the flow
- prefer server-authoritative writes over multi-step client mutation sequences
- preserve auditability and assignment history from the first release of this flow

## Recommended Next Step After This Slice

Once check-in and player tag assignment exist, the next natural slice becomes:

`points tables -> table tag binding -> start session with four tagged guests`
