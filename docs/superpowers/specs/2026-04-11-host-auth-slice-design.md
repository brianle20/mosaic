# Host Auth Slice Design

## Summary

This design defines the next Mosaic implementation slice after the event and guest management vertical slice. The slice delivers the minimum host authentication flow needed to make the existing app path operate against Supabase in a production-shaped way:

`App Launch -> Restore Session -> Host Sign In -> Event List -> Sign Out`

The goal is to unlock a true authenticated app flow for the single-host MVP without introducing guest accounts, sign-up UI, password recovery UI, or future multi-user behavior.

## Goals

- Require a real authenticated host session before protected app flows run.
- Preserve the MVP rule that there is exactly one app user: the host.
- Keep the app UX narrow:
  - sign in
  - restore session
  - sign out
- Harden the backend so publishable-key access is scoped by authenticated ownership rather than open table access.
- Keep the architecture ready for future auth expansion:
  - player accounts
  - SMS OTP
  - multi-role staff access

## Out Of Scope

This slice does not implement:

- guest accounts
- player sign-in
- sign-up UI
- password reset UI
- profile editing
- multi-user collaboration
- staff or scorer roles
- SMS OTP
- web auth flows

## Product Scope

### Included behavior

- The app restores an existing Supabase session on launch.
- Signed-out users see a host sign-in screen.
- Signed-in users see the existing event and guest flow.
- The authenticated host can sign out from the app.

### Provisioning model

- The host account is created out of band in Supabase Auth.
- The app does not expose sign-up.
- A matching `public.users` row must exist for the authenticated host, created automatically by the backend.

## UX Direction

### Host sign-in screen

The sign-in screen should stay operational and minimal:

- app title
- email field
- password field
- primary sign-in button
- inline error state
- loading state while authentication is in progress

The screen should not present speculative paths such as:

- create account
- join as guest
- forgot password
- magic link

### Authenticated shell

Once signed in, the host should land directly in the existing event list flow. The authenticated area should expose a simple `Sign out` action so the full session lifecycle can be tested and operated.

## Architecture

The slice should add a focused auth feature and keep auth responsibilities separate from events and guests.

### Features

#### `features/auth/`

Owns:

- host sign-in screen
- sign-in form draft
- auth controller or coordinator for sign-in, sign-out, and session state

### Data layer

#### `AuthRepository`

Add an auth-specific repository abstraction with a Supabase implementation.

Responsibilities:

- sign in with email and password
- sign out
- expose current authenticated user
- expose session or auth-state changes
- support session restoration on app startup

This keeps auth behavior isolated from event and guest repositories so a later auth strategy change does not require rewiring product features.

### App shell

The app shell should become auth-aware and choose between three states:

- auth bootstrap/loading
- signed-out host sign-in screen
- signed-in application router

The existing event and guest router stays intact, but it should only be reachable from the signed-in state.

## Backend And Security Design

This slice requires a dedicated auth/security migration.

### Public user mirroring

Add a database function and trigger so inserts into `auth.users` create or sync a matching row in `public.users`.

Required outcomes:

- `public.users.id` matches `auth.users.id`
- email is copied into `public.users.email`
- `display_name` can default from email until profile editing exists

### Row-level security

Enable RLS on the public tables the client will touch now, and on closely related tables that should already be owner-scoped.

At minimum:

- `users`
- `events`
- `event_guests`

Recommended for forward consistency in the same migration:

- `guest_cover_entries`
- `event_guest_tag_assignments`
- `event_tables`
- `table_sessions`
- `table_session_seats`
- `hand_results`
- `hand_settlements`
- `event_score_totals`
- `prize_plans`
- `prize_tiers`
- `prize_awards`
- `audit_logs`

### Policy rules

#### `public.users`

- authenticated user can read their own row
- authenticated user can update their own row if needed later

#### `events`

- authenticated user can select events where `owner_user_id = auth.uid()`
- authenticated user can insert events only for `owner_user_id = auth.uid()`
- authenticated user can update events they own
- authenticated user can delete events they own if deletion remains allowed operationally

#### `event_guests`

- authenticated user can read and write guest rows only when the parent event belongs to `auth.uid()`

The same owner-scoped pattern should apply to the other event-owned tables.

### Trust boundary

The client may still send `owner_user_id` on insert if that keeps the repository simple, but the database must enforce that it matches the authenticated user. Security must not depend on honest client input.

## Data Flow

### App launch

1. Supabase initializes.
2. The auth repository determines whether a persisted session exists.
3. If a valid session exists, the app enters the authenticated shell.
4. If no valid session exists, the app enters the signed-out shell.

### Host sign-in

1. Host enters email and password.
2. Controller validates the draft locally.
3. Auth repository calls Supabase password sign-in.
4. On success, auth state updates and the app transitions into the authenticated shell.
5. Event list loads through the existing repositories.

### Host sign-out

1. Host taps `Sign out`.
2. Auth repository clears the session.
3. App returns to the signed-out shell.
4. Feature state depending on the authenticated user is discarded.

## Technical Design

### Repository integration

The existing event repository already depends on `client.auth.currentUser`. That behavior should remain. The auth slice should make that dependency safe by ensuring the event and guest UI is not reachable before authentication is established.

### Form model

Add a dedicated sign-in draft object for:

- email
- password
- validation state

Validation can stay simple:

- email required
- password required

Avoid more opinionated password rules in the client for now because this is a host-only sign-in form for an already provisioned account.

### Routing

The app should no longer immediately instantiate the authenticated router without considering auth state. The sign-in screen becomes the default entry when signed out.

### Error handling

Auth errors should be translated into practical host-facing messages:

- invalid credentials
- network failure
- unexpected backend failure

Do not expose raw stack traces in the sign-in screen.

## Testing Strategy

This slice should continue the small-surface TDD approach.

### Unit tests

- sign-in draft validation
- auth controller loading, success, and error transitions
- auth repository mapping around current user and sign-out behavior

### Widget tests

- app shell routes to sign-in when signed out
- app shell routes to the event list when signed in
- sign-in screen validation and submit behavior
- sign-out action returns the app to the signed-out shell

### Backend verification

After the migration is applied:

- verify RLS is enabled on the protected tables
- verify an authenticated host can read and write only their own events and guests
- verify unauthenticated or mismatched users cannot access another host's event data

## Assumptions

- The host account already exists in Supabase Auth for development and testing.
- The MVP continues to allow exactly one host user in product terms, even though the backend remains technically extensible.
- A mobile device or simulator will be used for the eventual true UI smoke test; desktop support is not required for this auth slice.
