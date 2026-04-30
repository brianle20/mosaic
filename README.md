# Mosaic

Mosaic is a native Flutter app for hosting casual Hong Kong mahjong events. The MVP covers the event-day workflow: host sign-in, event setup, guest check-in, NFC tag assignment, table/session start, hand entry, leaderboard review, locked prize awards, activity history, and event finalization.

## Current MVP

- Email/password host authentication through Supabase Auth
- Host-owned events with RLS-backed data isolation
- Guest roster, duplicate-name confirmation, Instagram handles, cover tracking, comping, and check-in
- NFC-backed player tags and table tags, scoped to the signed-in host
- Table overview, table tag binding, session start, pause/resume/end, and hand entry
- Standard Hong Kong scoring with server-side settlement and leaderboard RPCs
- Event hand ledger and per-session hand history
- Prize plan preview and locked awards; payout tracking is intentionally out of scope
- Event activity feed and operational controls for check-in/scoring/finalization

## Repository Layout

- `lib/` - Flutter app source
- `lib/data/models/` - typed records and RPC payload models
- `lib/data/repositories/` - Supabase-backed repository implementations
- `lib/features/` - feature controllers, screens, and view models
- `supabase/migrations/` - authoritative database schema, RLS, functions, and seed data
- `test/` - unit, widget, repository, and migration text tests
- `integration_test/` - live Supabase smoke and lifecycle tests

Planning docs, specs, mockups, and local superpowers artifacts intentionally live outside this repo at:

```text
/Users/brian/Documents/repos/docs/mosaic
```

## Setup

Install Flutter and the Supabase CLI, then fetch packages:

```sh
flutter pub get
```

Create a local `.env` from `.env.example`:

```sh
cp .env.example .env
```

`.env` is gitignored. Do not commit database passwords, host test credentials, or one-off live-test command lines with real secrets.

## Run The App

```sh
flutter run
```

For iOS NFC work, use a real device with the project’s iOS bundle/NFC entitlements configured.

## NFC Tags

Mosaic reads the factory UID from blank NFC tags. Tags do not need to be written or formatted for the MVP. Use common phone-readable tags such as NTAG213, NTAG215, or NTAG216.

Manual UID entry is still available in tests and development overrides, but production app startup uses the native NFC reader.

## Database

Database behavior is source-controlled in `supabase/migrations/`. Apply migrations with the Supabase CLI for the linked project:

```sh
supabase db push
```

The app expects the latest migrations before live testing. Client compatibility fallbacks are intentionally limited; server RPCs own lifecycle gates, scoring, finalization, prize locking, and tag assignment rules.

## Verification

Run formatting, analyzer, and the full local suite before pushing:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Live tests require a real Supabase project, a signed-in host account, and a device/simulator target:

```sh
flutter test integration_test/live_smoke_test.dart \
  -d <device-id> \
  --dart-define=HOST_EMAIL=<host-email> \
  --dart-define=HOST_PASSWORD=<host-password>
```

Use placeholder examples in docs and commit messages. Keep real live-test credentials in a password manager or local shell environment only.

## Production Notes

- Treat Supabase migrations as the backend contract; update migration tests when adding or changing RPCs/RLS.
- Keep prize awards locked and read-only after calculation unless the product scope changes.
- Keep NFC tags owner-scoped; shared/global tag mutation is not acceptable for multi-host use.
- Rotate credentials immediately if they appear in tracked files, command logs, screenshots, or shared branches.
