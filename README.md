# Mosaic

Mosaic is mahjong event software built around a native Flutter host app, a
Supabase backend, and a Next.js public web companion. It supports the event-day
flow for clubs, pop-ups, leagues, and private Hong Kong mahjong tournaments:
guest intake, check-in, seating, table sessions, hand scoring, live standings,
finals, prizes, and event closeout.

## Product Surface

- Supabase-backed host authentication with owner and event scorer access
- Event creation, metadata editing, lifecycle controls, archive/copy-for-testing,
  and check-in/scoring gates
- Guest profiles, duplicate matching, public display names, tournament status,
  cover ledger entries, comps, check-in, and withdrawal handling
- NFC table and guest identification with native UID reads and manual-entry
  override for development
- Random/manual seating, tournament round orchestration, assigned table entry,
  start-all-current-round sessions, and finals seating
- Hong Kong scoring with wins, self-draws, washouts, false-win penalties, dealer
  rotation, round timers, hand corrections, voiding, and event hand ledger views
- Offline-first session hand entry using SQLite mutation queues and background
  sync back to Supabase
- Leaderboards, public standings snapshots, points timeline, finals leaderboards,
  and public event slugs
- Bonus/finals flows for Table of Champions, Table of Redemption, sudden death,
  and play-in cases
- Prize plan setup, award preview, locked awards, and event activity history

Qualification scoring is deprecated for new events. Historical data remains
readable, but current tournament operation is centered on the tournament and
bonus scoring phases.

## Repository Layout

- `lib/` - Flutter mobile app source
- `lib/app/` - app bootstrap and repository wiring
- `lib/core/` - routing, theme, config, shared widgets, and time helpers
- `lib/data/models/` - typed domain records and RPC payload models
- `lib/data/repositories/` - Supabase and offline-aware repository implementations
- `lib/data/offline/` - SQLite store, mutation records, projections, reachability,
  and sync coordinator
- `lib/features/` - feature controllers, screens, models, and widgets
- `lib/services/nfc/` - NFC abstractions, native reader integration, and manual
  entry service
- `supabase/config.toml` - linked Supabase auth and project configuration
- `supabase/migrations/` - authoritative schema, RLS policies, RPCs, triggers,
  and backend behavior
- `supabase/templates/` - Supabase auth email templates
- `web/` - Next.js landing page and public live standings app
- `test/` - Flutter unit/widget/repository/model/offline/migration tests
- `integration_test/` - live Supabase smoke and lifecycle tests
- `docs/superpowers/` - local specs and implementation plans that are tracked in
  this repo

## Prerequisites

- Flutter with Dart SDK compatible with `pubspec.yaml` (`^3.6.0`)
- Xcode/iOS tooling for native iOS builds and NFC testing
- Node.js and npm for the `web` workspace
- Supabase CLI for applying and linting migrations
- A linked Supabase project with the latest migrations applied

## Setup

Install mobile dependencies:

```sh
flutter pub get
```

Install web dependencies from the repository root:

```sh
npm install
```

Configure the Flutter app with a `.env.mobile` file containing:

```text
SUPABASE_URL=<supabase-project-url>
SUPABASE_PUBLISHABLE_KEY=<supabase-publishable-key>
```

`.env.mobile` is bundled as a Flutter asset, so keep it limited to publishable
client configuration. Do not put database passwords, host credentials, or service
role keys in it.

Configure the web app with `web/.env.local`:

```sh
cp web/.env.example web/.env.local
```

Then fill in:

```text
NEXT_PUBLIC_SUPABASE_URL=<supabase-project-url>
NEXT_PUBLIC_SUPABASE_ANON_KEY=<supabase-anon-or-publishable-key>
NEXT_PUBLIC_POSTHOG_PROJECT_TOKEN=<optional-posthog-token>
NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com
```

Root `.env` files are ignored and may be used for local-only Supabase CLI secrets
or shell helpers. Keep real live-test credentials in a password manager or local
shell environment only.

## Run The Mobile App

```sh
flutter run
```

For iOS NFC work, use a real device with the Runner NFC entitlement configured.
Mosaic reads NFC tag UIDs directly; tags do not need to be written or formatted.
Common phone-readable tags such as NTAG213, NTAG215, and NTAG216 are suitable.

Use manual NFC entry during development with:

```sh
flutter run --dart-define=MOSAIC_USE_MANUAL_NFC=true
```

For iOS simulator pushes, use the helper so manual NFC entry is always baked
into the simulator build:

```sh
tool/run_ios_simulator_debug.sh
```

## Run The Web App

```sh
npm run dev
```

The root npm scripts proxy into the `web` workspace:

```sh
npm run lint
npm run test
npm run build
```

The web app includes the marketing landing page, a public events directory at
`/events`, dynamic public standings at `/events/[eventSlug]/standings`, and a
points-race graph at `/events/[eventSlug]/standings/graph`.

## Database

Backend behavior is source-controlled in `supabase/migrations/`. Apply
migrations to the linked Supabase project with:

```sh
supabase db push
```

The mobile and web clients expect the latest migrations before live testing.
Client-side compatibility fallbacks are intentionally limited; Supabase RPCs,
RLS, triggers, and snapshot refresh logic own lifecycle gates, scoring,
finalization, prize locking, public standings, staff access, and tag assignment
rules.

## Verification

Run the Flutter formatter, analyzer, and local test suite before shipping mobile
or backend changes:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Run the web checks before shipping public site or standings changes:

```sh
npm run lint
npm run test
npm run build
```

Live integration tests require a real Supabase project, a host account, and a
device or simulator target:

```sh
flutter test integration_test/live_smoke_test.dart \
  -d <device-id> \
  --dart-define=HOST_EMAIL=<host-email> \
  --dart-define=HOST_PASSWORD=<host-password>
```

## Development Notes

- Treat Supabase migrations as the backend contract. Update migration tests when
  adding or changing tables, RLS policies, RPCs, triggers, or auth templates.
- Keep client models and repository tests in sync with RPC payload shapes.
- Preserve offline hand logging idempotency when touching scoring or sync code.
- Keep NFC tags owner-scoped; shared/global tag mutation is not acceptable for
  multi-host use.
- Keep prize awards locked and read-only after calculation unless the product
  scope changes.
- Use placeholder values in docs, commit messages, and test examples. Rotate any
  credential immediately if it appears in tracked files, shell history,
  screenshots, or shared branches.
