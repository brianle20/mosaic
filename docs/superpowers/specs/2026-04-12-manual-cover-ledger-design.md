# Manual Cover Ledger Design

## Summary

This slice fills one of the last remaining MVP bookkeeping gaps: guest-level
cover ledger history in the app.

Mosaic already supports:

- guest cover status on the guest record
- cover amount on the guest record
- check-in gating based on `paid` or `comped`
- audit logging infrastructure

What is still missing is the host-facing ledger flow for recording and
reviewing manual payment history through `guest_cover_entries`.

This design adds a guest-level cover ledger UI without changing the product
principle that cover status is host-authored operational state.

## Goals

- Let the host record manual cover ledger entries from guest detail
- Show guest-level cover payment history in the app
- Support the MVP methods:
  - `cash`
  - `venmo`
  - `zelle`
  - `other`
  - `comp`
  - `refund`
- Keep `cover_status` separate from ledger history
- Keep the UI fast and host-oriented during live event operations
- Audit ledger writes

## Out Of Scope

- auto-deriving `cover_status` from ledger balances
- payment detection or memo matching
- payment processor integrations
- batch ledger import
- event-wide financial reporting
- exports
- guest self-service payment views

## Product Behavior

### Host mental model

The ledger is a payment history, not an automatic truth engine.

The host should continue to control:

- `cover_status`
- `cover_amount_cents`

Ledger rows provide supporting bookkeeping context:

- what happened
- how much
- by what method
- when it was recorded
- any host note

This preserves the original MVP principle:

- cover is manual bookkeeping
- cover status is not inferred money logic

### Guest detail

Guest detail should gain a `Cover Ledger` section showing:

- current cover status
- current cover amount
- a primary `Add Cover Entry` action
- newest-first ledger rows for that guest

Each ledger row should show:

- signed amount in cents
- method
- recorded timestamp
- optional note

### Add cover entry flow

The host should be able to add a ledger entry from guest detail with:

- amount in cents
- method
- optional note

Method options:

- `cash`
- `venmo`
- `zelle`
- `other`
- `comp`
- `refund`

Recommended behavior:

- positive amounts for normal intake methods and `comp`
- negative amounts for `refund`

The UI should not silently rewrite guest `cover_status`.

Instead, after saving an entry:

- ledger history refreshes
- guest detail remains on the same screen
- host may separately update cover status if needed

### Consistency guidance

The app may show lightweight nudges such as:

- `Ledger includes refund activity`
- `Guest status is unpaid but ledger has positive entries`
- `Guest is comped and has non-comp payment entries`

These should be advisory only. MVP should not block the host on strict
reconciliation rules.

## Backend Design

## New RPCs

Add:

- `record_cover_entry(...)`
- `list_guest_cover_entries(target_event_guest_id uuid)`

### `record_cover_entry`

Responsibilities:

- require current host ownership of the guest/event
- validate method
- validate amount is non-zero
- insert a row into `guest_cover_entries`
- write an audit log
- return the inserted ledger row

Recommended RPC shape:

- `target_event_guest_id uuid`
- `target_amount_cents integer`
- `target_method text`
- `target_note text default null`

The function should set:

- `event_id` from the guest
- `recorded_by_user_id = auth.uid()`
- `recorded_at = now()`

### `list_guest_cover_entries`

Responsibilities:

- require current host ownership of the guest/event
- return ledger rows for that guest ordered by:
  - `recorded_at desc`
  - `created_at desc`

This keeps the read path simple and host-focused.

## Validation Rules

- `amount_cents` must not be zero
- `method` must be one of:
  - `cash`
  - `venmo`
  - `zelle`
  - `other`
  - `comp`
  - `refund`
- `refund` entries should allow negative values
- other methods should allow either sign for MVP flexibility, but the UI should
  steer hosts toward the expected direction

The backend should stay permissive enough for manual correction workflows.

## Audit Logging

Ledger writes must create audit rows with:

- `entity_type = guest_cover_entry`
- `action = create`
- event id
- guest id in metadata
- amount/method metadata

This keeps payment-history changes visible once the audit activity slice lands.

## App Design

## Data layer

Add:

- typed `GuestCoverEntryRecord`
- guest repository methods for:
  - recording a cover entry
  - loading guest cover entries
  - reading cached guest cover entries

Local cache should store guest ledger rows keyed by guest id so the detail
screen can remain responsive after mutations.

## Feature structure

Extend the guest/check-in area rather than creating a new top-level feature.

Recommended additions:

- guest detail controller loads cover ledger rows
- cover entry form model for validation
- small `Add Cover Entry` screen or bottom sheet

I recommend a separate focused screen or modal form rather than inline row
editing in guest detail. It keeps the host flow quick and avoids crowding the
already operationally dense guest detail view.

## UI Flow

### Guest detail

Add a `Cover Ledger` card showing:

- `Add Cover Entry`
- current status/amount summary
- recent entry list

### Add Cover Entry screen

Fields:

- amount (required)
- method (required)
- note (optional)

Actions:

- `Save Entry`
- `Cancel`

After save:

- pop back to guest detail
- refresh ledger rows
- show the new entry immediately

## Error Handling

Show specific inline errors for:

- missing amount
- zero amount
- missing method
- backend validation failures

Show compact host-oriented failure copy such as:

- `Cover entry amount must be non-zero.`
- `Cover entry method is invalid.`
- `Could not record cover entry. Try again.`

## Testing

## Unit tests

- cover entry draft validation
- method enum parsing
- signed amount formatting if extracted into helpers

## Repository tests

- record cover entry request/response mapping
- list guest cover entries mapping and ordering
- cache refresh after write

## Widget tests

- guest detail renders cover ledger rows
- add cover entry form validation
- successful save returns to guest detail and shows the new row

## Live smoke extension

Extend the existing smoke harness to:

- create an event and guest
- start the event
- open guest detail
- add one positive cover entry
- add one refund entry
- verify guest ledger rows exist in Supabase
- verify cleanup leaves no ledger residue

## Acceptance Criteria

- Host can open guest detail and view cover ledger history
- Host can add a cover ledger entry with method, amount, and optional note
- Ledger writes persist to `guest_cover_entries`
- Ledger entry creation is audited
- Cover ledger does not silently change guest `cover_status`
- Guest detail refreshes immediately after a new entry is saved
- Tests cover validation, repository mapping, widget behavior, and live smoke
