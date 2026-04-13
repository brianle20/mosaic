# Final Polish Design

Date: 2026-04-12
Product: Mosaic
Slice: Visual, Empty, Loading, and Feedback Polish

## Goal

Make Mosaic feel complete and calm across the full host experience by improving:

- empty states
- loading states
- success and error feedback
- spacing and hierarchy consistency

This is not a redesign. It is a finishing pass on the existing MVP so every important state feels intentional.

## Scope

### In scope

- bootstrap loading screen
- host sign-in screen
- authenticated host screens with rough empty, loading, or feedback states:
  - event list
  - event dashboard
  - guest roster
  - guest detail
  - tables overview
  - session detail
  - leaderboard
  - prizes
  - activity
- success feedback for key host actions
- clearer, friendlier error messages where current messaging still feels system-oriented
- more consistent spacing, section headers, and helper text

### Out of scope

- new product functionality
- major visual redesign
- heavy animations
- branding overhaul
- navigation restructuring

## Design principles

1. Calm over flashy
   - Loading and empty states should feel purposeful, not decorative.
2. Operational confidence
   - Success and error feedback should reassure the host quickly.
3. Consistency over novelty
   - Shared patterns should feel the same across screens.
4. Host-oriented wording
   - Feedback should read like guidance, not raw system output.

## Primary UX targets

### 1. Startup and auth

Polish:

- bootstrap loading screen should feel like a deliberate app startup state
- sign-in screen should have clearer hierarchy and friendlier supporting copy
- sign-in errors should remain concise and actionable

Success criteria:

- the app feels intentional before data has loaded
- the host understands what the app is doing during startup

### 2. Empty states

Target screens:

- event list
- guest roster
- tables overview
- activity
- leaderboard
- prize screens

Polish:

- empty states should explain what is missing
- where appropriate, empty states should point to the next host action
- phrasing should stay short and operational

Examples:

- no events yet
- no guests yet
- no tables yet
- no activity yet for this event
- no scored results yet
- no locked awards yet

### 3. Async states and feedback

Polish:

- loading treatments should be visually consistent
- key mutations should confirm success with short, stable messaging
- error messages should prefer host guidance over exception-shaped text

Candidate success feedback:

- event started
- check-in opened or closed
- scoring opened or closed
- guest updated
- cover entry saved
- tag assigned
- table saved
- session paused, resumed, or ended
- prize awards locked
- event finalized

### 4. Layout rhythm and hierarchy

Polish:

- normalize section spacing
- strengthen section headers where screens still feel uneven
- make helper text placement more consistent
- keep cards and status treatments aligned with the existing operational-clarity pass

## Implementation approach

Use a small set of shared UI patterns where that reduces duplication:

- lightweight empty-state presentation
- consistent loading presentation
- consistent snackbar or inline feedback phrasing

Apply the shared patterns first to startup/auth and high-traffic host screens, then to lower-frequency review screens.

## Screen-by-screen priorities

### Highest priority

- sign-in
- event list
- guest roster
- event dashboard
- tables overview

### Medium priority

- session detail
- leaderboard
- prize plan
- prize awards

### Lower priority

- activity
- guest detail, where much of the operational clarity work is already in place

## Testing strategy

### Widget tests

Add or refine widget coverage for:

- bootstrap or auth screen loading/error presentation
- event list empty state
- guest roster empty state and feedback
- tables overview empty state
- leaderboard empty state
- activity empty state
- prize screens empty or unlocked states

### Regression focus

- ensure new feedback text does not break existing widget or integration tests
- avoid changing business logic while polishing presentation

### Live smoke

- keep the existing integration smoke mostly unchanged
- only update assertions if intentional feedback copy changes are now part of the user-facing contract

## Acceptance criteria

- startup feels deliberate rather than placeholder-like
- sign-in feels consistent with the rest of the app
- every major screen has an intentional empty state
- loading states feel consistent across screens
- important actions produce clear success or error feedback
- spacing and hierarchy feel consistent across the authenticated host experience
- no business behavior changes are introduced as part of the polish pass
