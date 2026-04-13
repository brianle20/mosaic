# Guest Roster Quick Actions Design

## Summary

This slice improves the speed of repeated host actions by turning the guest roster into the fastest path for common operational tasks.

The goal is not to replace guest detail. The goal is to let the host handle the most frequent, lowest-risk actions without leaving the roster.

The roster should become the host’s fast lane for:

- marking a guest paid
- marking a guest comped
- checking in and assigning a player tag
- assigning a player tag for an already checked-in guest
- adding a cover entry when useful

Guest detail remains the full-control screen for complete review and deeper management.

## Product goals

1. Reduce taps for the most common guest operations during live events.
2. Keep the roster visually readable and operationally safe.
3. Preserve guest detail as the complete record-management screen.
4. Reuse existing business rules and NFC/manual-tag flows rather than inventing new logic paths.

## Non-goals

1. No bulk edit mode in this slice.
2. No swipe-only hidden actions.
3. No inline editing of all guest fields.
4. No change to the underlying guest eligibility rules.
5. No replacement of guest detail or check-in logic.

## Recommended approach

Use safe inline quick actions on each guest row.

Why this is the right approach:

- it improves the highest-frequency host flow immediately
- it stays explicit and discoverable under live-event pressure
- it avoids the training cost and hiddenness of swipe actions
- it avoids the complexity of bulk workflows before the MVP really needs them

## Screen behavior

### Guest roster

Each guest row remains tappable and still opens guest detail.

In addition, each row may render a compact quick-action strip below the state chips and summary text.

The row should show only the actions that are most relevant for that guest’s current state.

The visible quick actions should stay capped at two or three so rows remain scannable.

### Guest detail

Guest detail remains unchanged in role:

- full status view
- tag replacement
- cover ledger review
- deeper management

This slice makes roster faster, not detail weaker.

## Quick action rules

### Unpaid, partial, or refunded guests

Preferred quick actions:

- `Mark Paid`
- `Mark Comped`
- optionally `Add Cover Entry`

Purpose:

- unblock eligibility as fast as possible

### Paid or comped guests who are not checked in

Preferred quick action:

- `Check In & Tag`

Purpose:

- combine the operationally natural next step into one roster-level action

### Checked-in guests who are eligible but do not have a player tag

Preferred quick action:

- `Assign Tag`

Purpose:

- remove an unnecessary trip into guest detail

### Checked-in guests who already have a player tag

Preferred quick action:

- no primary play-unblocking action
- optionally `Add Cover Entry` if it still adds value

Purpose:

- avoid showing actions that are no longer the likely next step

## Interaction model

### Quick actions

Quick actions should be compact buttons or chips rendered inline with the row.

They should:

- be easy to hit
- not dominate the row
- clearly indicate the intended operation

### Success feedback

Quick actions should provide lightweight in-place feedback after success.

Examples:

- `Marked Alice Wong paid`
- `Checked in Bob Lee`
- `Assigned player tag to Carol Ng`
- `Saved cover entry for Dee Wu`

Snackbars are acceptable here because the host stays on the same screen and needs immediate confirmation.

### Error feedback

Errors should stay concise and actionable.

Examples:

- `This guest must be paid or comped first.`
- `That player tag is already assigned.`
- `Check-in is currently closed.`

## Architecture

## Reuse first

This slice should extend the existing guest roster feature instead of adding a new subsystem.

Primary files likely involved:

- `lib/features/guests/screens/guest_roster_screen.dart`
- `lib/features/guests/controllers/guest_roster_controller.dart`

Potential supporting additions:

- a small reusable row quick-action widget if row layout becomes crowded

## Data and service boundaries

Reuse existing repository and service methods whenever possible:

- `checkInGuest`
- `assignGuestTag`
- existing NFC/manual tag scan flow
- cover-entry recording flow where appropriate

If the roster needs fast `Mark Paid` or `Mark Comped` actions and the current guest repository does not expose a clean update path for that, add the smallest possible repository/controller surface to support it.

Do not add a broad inline-edit API just for this slice.

## UX constraints

1. Keep rows readable.
2. Prefer the action that unblocks play first.
3. Do not expose more than two or three visible quick actions per row.
4. Preserve row tap to open detail.
5. Do not duplicate every guest-detail capability on the roster.

## Testing

### Widget tests

Add coverage for:

- quick-action visibility by guest state
- unpaid guest showing `Mark Paid` / `Mark Comped`
- eligible unchecked-in guest showing `Check In & Tag`
- checked-in untagged guest showing `Assign Tag`
- row still opening guest detail on tap
- success feedback after quick actions

### Integration scope

This slice is mostly workflow-speed polish, so widget tests should carry most of the risk.

Only extend the live smoke if the implementation introduces a meaningful new roster-level flow that is not already covered indirectly elsewhere.

## Success criteria

This slice is successful if the host can stay on the roster and complete the most common guest operations without repeatedly bouncing into guest detail.

Concretely, the roster should let a host quickly:

- unblock guest eligibility
- check guests in
- assign player tags
- confirm the action succeeded

while still preserving guest detail as the authoritative full guest screen.
