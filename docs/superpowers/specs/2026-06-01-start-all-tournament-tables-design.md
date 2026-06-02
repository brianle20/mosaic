# Start All Tournament Tables Design

## Summary

Tournament seating already lets the host review all tables for a new round in one screen, but starting play still requires entering each table and starting that table session individually. Add an app-only action that starts every valid not-started table in the current tournament round at the same time.

The public website remains leaderboard/standings-only. No operational controls are added to the web app.

## Scope

- Add a `Start All Tables` action to the Flutter seating screen for tournament round seating.
- Start every current-round table that has valid active seating and no active or paused session.
- Support the existing assigned-table rules, including valid 2-, 3-, and 4-player tables.
- Use a Supabase RPC so all created table sessions share the same server timestamp for synchronized round timers.
- Refresh app seating/session state after the bulk start completes.

## Non-Goals

- Do not add operational controls to the public website.
- Do not remove the existing per-table `Enter Table` flow.
- Do not automatically start sessions when a new tournament round is generated; hosts still get the seating review step.
- Do not change qualification or public leaderboard behavior.

## User Experience

On `SeatingAssignmentScreen`, show a full-width `Start All Tables` button above the table cards when tournament seating exists and at least one table is eligible to start. The button is disabled while submitting.

After a successful bulk start:

- The app reloads seating and live session state.
- Tables that now have active sessions no longer need manual session start.
- The existing table entry path can still be used to open a specific table session.

If the backend rejects the request, show the existing inline error banner style. The host can still use the per-table flow to inspect or recover from a specific table issue.

## Backend

Add a Supabase migration defining a new authenticated RPC named `start_current_tournament_round_sessions(target_event_id uuid)`.

The RPC should:

- Require the caller to own or be allowed to score the event, matching existing assigned-table session permissions.
- Find the current tournament round for the event in `seating` or `active` status.
- Find current-round tables with active seating and no active or paused session.
- Validate each table with the same effective rules as `start_assigned_table_session`: contiguous seats from East, 2 to 4 assignments, one tournament round, checked-in players, no players already seated in live sessions, table default ruleset present.
- Insert table sessions and seats in one transaction.
- Use one captured server timestamp for every inserted `table_sessions.started_at`.
- Set the tournament round status to `active` and `started_at` when sessions are created.
- Return the created `table_sessions` rows ordered by table display order.

If no table is eligible because the round is already fully started, the RPC can return an empty list rather than creating duplicates.

## App Data Flow

Add a session repository method for the batch start, returning `List<TableSessionRecord>`.

`SeatingAssignmentController` gets a `startAllTables(eventId)` method that:

- Sets `isSubmitting`.
- Calls the batch start repository method.
- Reloads assignments and live-session state.
- Clears or sets `error` using existing controller patterns.

The seating screen uses controller state to show, disable, and refresh the button.

## Testing

Add tests at three levels:

- Supabase migration tests assert the RPC exists, grants execute to authenticated users, validates tournament-round seating, avoids duplicate live sessions, and uses a shared timestamp variable for inserted sessions.
- Repository/controller tests assert the app calls the new RPC, updates cached session state where appropriate, reloads seating state, and reports errors.
- Seating screen widget tests assert the `Start All Tables` button appears for eligible tournament seating, disables while submitting, invokes the controller path, and does not appear for empty seating.

## Risks

The main risk is duplicating validation logic between `start_assigned_table_session` and the new batch RPC. To reduce drift, the implementation should either reuse a private helper function or keep the new RPC's validation visibly aligned with the existing function and covered by migration tests.
