# Public Events Directory Design

## Summary

Add a central public events page at `/events` on `www.mosaicmahjong.com`. The page lists all unarchived public Mosaic events automatically and gives visitors direct links to each event's live standings and points race.

The existing public event routes remain the detail surfaces:

- `/events/<event_slug>/standings`
- `/events/<event_slug>/standings/graph`

The landing page header should also gain an `Events` link so visitors can discover the directory from `www.mosaicmahjong.com`.

## Scope

- Add a public `/events` page to the Next.js web app.
- Add an `Events` link to the landing page header.
- List all unarchived public events automatically.
- For each event, show its title and links to:
  - Standings
  - Points Race
- Keep the existing event standings and points-race URLs unchanged.
- Use public-safe event fields only.

## Non-Goals

- Do not add staff controls, event management, check-in, or scoring operations to the website.
- Do not replace existing per-event share URLs.
- Do not build a curated or manually maintained event list.
- Do not expose private guest, staff, owner, or operational event fields.
- Do not change archived event behavior for existing public standings pages beyond using the current visibility rule.

## Recommended Architecture

Add a public database function, `public.get_public_events()`, as the explicit list boundary for the website. The function should return one row per unarchived public event with only fields needed by the directory:

- `event_id`
- `public_slug`
- `title`
- `standings_updated_at`, if available from `public_event_standings_snapshots`

The function should filter to `events.archived_at is null`. The web app should call this RPC through the public Supabase client instead of reading from `events` directly.

This is preferred over using `public_event_standings_snapshots` as the directory source because snapshots are a cache for standings, while `get_public_events()` states the product intent: which events are publicly listable.

## User Experience

The `/events` page should be a quiet public directory, not a second marketing page. Use the existing Mosaic visual language from the landing page: brand header, restrained colors, compact rows or cards, and clear links.

The page should include:

- Header with Mosaic brand and the same public navigation pattern as the landing page.
- Page title: `Events`.
- A short supporting line that frames the page as public live event results.
- Event entries sorted by most recent `standings_updated_at` first, with events that have no timestamp after dated events, then by title.
- For each event:
  - Event title
  - Optional last-updated text
  - `Standings` link
  - `Points Race` link

If no public unarchived events are available, show a simple empty state that says no public events are available.

On mobile, the `Events` header link should remain visible. The sales email may stay hidden as it is today.

## Data Flow

1. A visitor opens `/events`.
2. The Next.js server page creates the public Supabase client.
3. The page calls `get_public_events()`.
4. Rows map into event link models using `public_slug`.
5. The rendered links route to the existing standings and points-race pages.

The per-event standings and points race pages continue to fetch their own snapshots with `fetchPublicStandings`.

## Error Handling

If the event directory RPC fails, render an inline alert using the existing public-site error style and show an otherwise empty events list.

If a row is missing a usable `public_slug`, skip it rather than rendering a broken public link.

If there are no visible events, render the empty state. This should not be treated as an error.

## Testing

Add or update tests for:

- Landing page header renders an `Events` link to `/events`.
- `/events` renders public event rows with `Standings` and `Points Race` links built from `public_slug`.
- `/events` skips rows without a usable `public_slug`.
- `/events` renders an empty state when no events are returned.
- Web data mapping handles optional `standings_updated_at`.
- The migration defines `get_public_events()` with the unarchived-event filter and public grants.

## Verification

Run the web checks before shipping:

```sh
cd web
npm run lint
npm run test
npm run build
```

Run the relevant Supabase migration tests from the repository root after adding the RPC migration.
