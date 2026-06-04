# Check-In Play Mode Design

## Summary

Player NFC tag assignment should no longer be part of the required check-in path. Event staff should choose whether an arriving guest is checked in for open play or qualifying directly from the guest roster.

The current flow makes `Assign Tag` do too much: it can check in an expected guest, attach an NFC player tag, and promote an open-play guest to qualifying. That behavior is confusing now that player tags are not required for tournament table starts or seating identity. The new flow makes attendance and tournament intent explicit.

## Scope

- Replace tag-driven check-in actions with explicit roster actions:
  - `Check In: Open Play`
  - `Check In: Qualifying`
- `Check In: Qualifying` checks the guest in and sets `tournament_status` to `qualifying`.
- `Check In: Open Play` checks the guest in and sets `tournament_status` to `open_play_only`.
- Keep `qualified` as a separate later state. Check-in does not jump directly to `qualified`.
- Remove player tag assignment from primary roster status and action copy.
- Update tournament seating eligibility so player tags are not required.

## Non-Goals

- Do not remove the NFC infrastructure, database tables, or legacy tag assignment RPCs in this change.
- Do not remove optional player tag lookup/scanning from scoring or support flows in this change.
- Do not change table NFC tag requirements in this design.
- Do not change the meaning of `qualified`; it remains a deliberate tournament advancement/status.

## User Experience

For an expected guest who has paid or is comped, the roster shows two check-in choices: open play and qualifying. Staff can make the correct event-day choice without scanning an NFC tag.

For a checked-in open-play guest, staff can still move them to qualifying with the existing tournament status action. For a qualifying guest, staff can still later mark them qualified.

Roster summaries should describe play status, not missing player tags. A checked-in qualifying guest should read as ready for qualifying play even when no player tag exists.

## Data Flow

The guest roster controller should expose a check-in method that accepts the desired `EventTournamentStatus` for the check-in result. The method should call the existing `checkInGuest` path and, when needed, call `updateEventGuestTournamentStatus` to set `open_play_only` or `qualifying`.

Existing status mutation remains the source of truth for moving guests between open play, qualifying, qualified, and withdrawn after check-in.

Tournament seating generation should count eligible players from guest attendance and tournament status only. Active player tag assignments should not be joined or required.

## Error Handling

Check-in errors should continue to use the existing inline/snackbar roster error handling. If check-in succeeds but status update fails, the app should surface the failure and reload or merge the latest guest state so staff are not shown a false success.

Backend seating-generation errors should mention missing checked-in qualifying players or ready tables, not missing player tags.

## Testing

Add or update tests for:

- Open-play check-in does not scan NFC and leaves the guest in open play.
- Qualifying check-in does not scan NFC and sets the guest to qualifying.
- Assigning a player tag no longer promotes a guest to qualifying.
- Checked-in qualifying guests without player tags no longer show `Needs player tag`.
- Tournament seating generation no longer joins `event_guest_tag_assignments` or requires active player tags.
- Existing `qualified` and withdrawn status actions still work.
