# Tournament Qualification and Player Tag Deprecation Design

## Summary

Mosaic should keep guest tournament states but stop treating qualification as a scored game stage. Staff should decide a guest's tournament qualification intent when adding or editing the guest, then check-in should render the correct action from that saved intent.

Player tags are deprecated for the active product workflow. The app should hide player tag scanning, assignment, replacement, prompts, and tag-based check-in behavior from current and future event operations. Historical tag data can remain in the database for safety, but it should no longer be part of the visible event workflow.

## Scope

- Add a `Tournament Qualification` section to the add/edit guest form.
- Use the existing `event_guests.tournament_status` values as the source of truth:
  - `Prequalified` maps to `qualified`.
  - `Considered` maps to `qualifying`.
  - `Not Playing Tournament` maps to `open_play_only`.
- Make check-in actions derive from the guest's saved tournament status:
  - `Check In: Prequalified`
  - `Check In: Considered`
  - `Check In: Not Playing Tournament`
- Remove individual primary `Mark Qualified` / `Mark Qualifying` progression from the checked-in guest card workflow.
- Add a bulk action for hosts to qualify all checked-in considered guests.
- Keep per-guest exception actions for moving a guest to `Not Playing Tournament` or `Withdrawn`.
- Hide player tag UX from roster and guest detail screens.
- Remove tag-driven tournament status promotion from check-in and assignment controllers.

## Non-Goals

- Do not delete player tag tables, historical tag assignment rows, or old migrations in this change.
- Do not rewrite archived event history.
- Do not reintroduce qualification scoring, qualification rounds, or qualification leaderboards.
- Do not remove table tags or any table-level NFC behavior unless separately approved.
- Do not change the meaning of `withdrawn`; it remains the state for a guest removed from tournament play after being part of the event.

## User Experience

### Add/Edit Guest

The guest form gains a `Tournament Qualification` section near event-specific fields such as cover status. It offers three choices:

- `Prequalified`: the guest is expected to play the tournament and should be treated as qualified at check-in.
- `Considered`: the guest may play the tournament, but the host will make a later decision.
- `Not Playing Tournament`: the guest is attending but should not be included in tournament seating.

For new guests, the default should be `Prequalified`, because most guests are expected to play the tournament. Editing a guest should show and preserve their current tournament status.

### Roster Check-In

Pending guest cards show one check-in button based on the saved tournament status:

- A `Prequalified` guest shows `Check In: Prequalified` and remains `qualified`.
- A `Considered` guest shows `Check In: Considered` and remains `qualifying`.
- A `Not Playing Tournament` guest shows `Check In: Not Playing Tournament` and remains `open_play_only`.

This keeps check-in fast and prevents staff from making the same qualification decision twice.

### Checked-In Guests

Checked-in guest cards show status chips and exception actions, not individual advancement buttons. A checked-in considered guest remains visibly considered until the host uses the bulk qualification action or an exception action.

The roster should offer a host-only bulk action, `Qualify Checked-In Considered`, when at least one checked-in considered guest exists. The action promotes checked-in guests with `tournament_status = qualifying` to `qualified`. It should not affect expected, not-playing, withdrawn, or already qualified guests.

### Player Tags

The active UI should no longer show:

- `Scan Player Tag`
- `Assign Tag`
- `Replace Tag`
- `Check In & Tag`
- player tag status prompts
- tag identification sheets or tag-not-found sheets

Any old active tag assignment data should stay hidden unless a future administrative or historical support screen explicitly needs it.

## Data Model

No new database enum is required. The existing `event_guests.tournament_status` values are enough:

- `qualified` represents the user-facing `Prequalified` state before check-in and `Qualified` state after check-in.
- `qualifying` represents the user-facing `Considered` state.
- `open_play_only` represents `Not Playing Tournament`.
- `withdrawn` remains `Withdrawn`.

The app should centralize display labels so labels can depend on context:

- On the guest form and pending roster, `qualified` displays as `Prequalified`.
- On checked-in roster rows and leaderboard/tournament contexts, `qualified` can display as `Qualified`.
- `qualifying` displays as `Considered`, not `Qualifying`, in the guest management workflow.
- `open_play_only` displays as `Not Playing Tournament`, not `Open Play Only`, in the guest management workflow.

## App Flow

`GuestFormDraft`, `CreateGuestInput`, and `UpdateGuestInput` should carry an `EventTournamentStatus`.

Creating a guest should insert the selected tournament status instead of always inserting `open_play_only`.

Updating a guest should update the tournament status as part of the same save path, or immediately after the guest update through the existing tournament status RPC if that better matches repository boundaries. The UI should treat the save as one operation either way.

Roster check-in should call the existing attendance check-in path and then preserve or set the selected tournament status. It should not scan for tags, assign tags, or infer tournament status from tag assignment.

Guest detail check-in should follow the same rules as roster check-in. If guest detail keeps a check-in button, its label should also come from the guest's saved tournament status.

## Player Tag Deprecation

The first implementation should be a soft deprecation:

- Remove player tag actions and prompts from active screens.
- Stop calling player tag scan, assign, replace, and identify flows from roster and guest detail UI.
- Keep repository methods, models, and Supabase objects in place when removing them would create avoidable risk.
- Remove tests that assert visible player tag workflows, or rewrite them to assert the workflows are hidden.

Deep deletion can be a later cleanup once active scoring, archived event views, and support needs are confirmed not to depend on tag records.

## Error Handling

Guest save errors should continue using the existing guest form submit error surface.

Check-in errors should continue using the roster snackbar and guest detail error surfaces. If attendance check-in succeeds but tournament status update fails, the app should surface the failure and reload the guest list/detail so staff see the actual server state.

The bulk `Qualify Checked-In Considered` action should report how many guests were promoted. If any update fails, the app should show an error and reload the roster.

## Testing

Add or update tests for:

- Guest form defaults new guests to `Prequalified`.
- Guest form can save `Prequalified`, `Considered`, and `Not Playing Tournament`.
- Editing a guest preserves and updates tournament qualification.
- `CreateGuestInput` inserts the selected tournament status.
- `UpdateGuestInput` or the repository update path persists tournament status changes.
- Pending roster cards render `Check In: Prequalified`, `Check In: Considered`, or `Check In: Not Playing Tournament`.
- Check-in preserves the selected tournament status.
- Individual primary `Mark Qualified` / `Mark Qualifying` buttons are not shown.
- Bulk `Qualify Checked-In Considered` promotes only checked-in considered guests.
- `Scan Player Tag`, `Assign Tag`, `Replace Tag`, and tag prompt text are hidden from active roster and guest detail screens.
- Guest detail no longer promotes `open_play_only` guests to `qualifying` through tag assignment.

## Risks

The main risk is label confusion because the persisted statuses keep legacy names. Centralized display helpers should make the user-facing language explicit and context-aware.

The second risk is hidden tag dependencies. Soft-deprecating visible tag workflows first avoids breaking historical data or backend functions while still removing tags from staff operations.
