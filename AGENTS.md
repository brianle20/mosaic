# AGENTS.md - Mosaic

## Project Context

Mosaic is a Flutter mobile app for running live Mahjong events. The app is used under real event pressure, so clarity, data correctness, safe production operations, and fast verification matter more than clever abstractions.

Default repo path: `/Users/brian/Documents/repos/mosaic`.

## Working Agreements

- Inspect the current repo, tests, routes, schema, logs, or live data before answering implementation questions.
- If the user says "no code changes yet", do analysis only.
- If the user asks for implementation, debugging, cleanup, verification, device push, migration, or commit, carry the work through instead of stopping at a proposal.
- Ask questions only when the answer is necessary, cannot be discovered from local context, and a wrong assumption would be risky.
- Keep patches focused. Do not refactor unrelated areas.
- Preserve dirty worktree changes you did not make.
- When the user asks "what's going on", treat it as debugging: establish observed behavior, root cause, and the smallest safe fix.

## Product Rules

- Optimize for a host running a live Mahjong event from a phone.
- Use host-friendly labels in UI and reports: event title, table label, guest display name, wind, hand number, winner, fan count, status, and timestamp.
- Do not expose database IDs, UUIDs, RPC names, storage paths, or implementation details in normal user-facing UI.
- Raw IDs are acceptable only in explicit diagnostic/admin/debug contexts.
- Be careful with overloaded terms:
  - `session` is the internal scored table-session concept.
  - `round` may be user-facing tournament language.
  - `wind` can mean seat wind, dealer wind, round wind, or event prevailing wind.
  - `tag` may mean NFC player tag or table tag, not QR code unless code confirms it.
- Scoring, prize awards, cover bookkeeping, public profiles, and cached public snapshots are separate domains. Do not patch one domain's derived state to hide a source-of-truth problem in another.

## UI And Mobile Rules

- Never use raw UUIDs as normal user-facing labels.
- User-facing fallback labels should be graceful, for example:
  - `Hand 7`
  - `Ava's winning hand`
  - `Table 3 winning hand`
  - `Captured winning hand`
  - `Captured Jun 25, 2026 at 6:30 PM`
- Screens should make the next action obvious through existing UI structure. Do not rely on hidden workflow knowledge.
- If a user asks how to access a screen, inspect the current route/action labels and screen code before answering.
- For UI changes, run focused widget tests and `flutter analyze`.
- For confusing mobile screens or visual bugs, verify on an iOS simulator when practical.
- If a screen is technically correct but confusing under live-event pressure, treat that as a product bug.

## Scoring And Live Event Data

- Treat live scoring corrections as high risk.
- Never manually edit derived standings, settlements, score totals, prize previews, public projections, or public snapshots as the primary fix.
- Prefer existing hand/session mutation and recalculation paths.
- For late or missed hands, insert or correct the source hand data with strict guards, then run the existing recalculation path.
- Before any live scoring write:
  1. Confirm event, table, session, seats, hand number, and current state with read-only queries.
  2. Confirm the target record is absent or wrong.
  3. Add duplicate guards.
  4. Use a transaction when possible.
  5. Run existing recalculation functions.
  6. Verify hand rows, settlements, session counters, score totals, and audit logs.
- Report exact changed records and exact verification results.

## Supabase And Production Database

- Never print secrets, passwords, service-role keys, or full connection strings.
- Assume Supabase writes may touch production unless proven otherwise.
- Distinguish clearly between:
  - local repo migrations
  - remote Supabase migration history
  - direct production SQL/data repair
  - app/RPC behavior
  - cached public snapshot behavior
- Do not guess the database access path.
- Known access lessons from prior work:
  - Do not assume the first pooler host/port is correct.
  - If a direct connection fails, check whether the saved/local pooler URL works before inventing a new route.
  - Supabase Management/API or linked-query paths may hang; do not keep retrying them blindly.
  - Supabase JS client can be useful for app-level reads/RPCs, but SQL-level repair may need a real Postgres connection.
  - If `SUPABASE_DB_PASSWORD` is missing from the command environment, load it from local env without printing it.
  - If local `psql` or `pg` is unavailable, do not install dependencies into the repo for a one-off production repair. Use temporary tooling outside the repo if absolutely needed, and start with `select 1`.

### Production Data Changes

Before any production DB write:

1. Identify the target project/environment.
2. Run read-only confirmation queries.
3. State the intended rows/entities.
4. Write with guards or a transaction.
5. Prefer existing RPCs/recalculation functions over manual table edits.
6. Verify with follow-up queries.
7. Report exact changed records.

### Migrations

- Schema changes must be migrations in `supabase/migrations`, not dashboard-only edits.
- Add or update migration tests under `test/supabase`.
- To check applied state, use `npx supabase migration list` and compare Local vs Remote.
- If auth fails because the DB password is not in the shell environment, load it from local `.env` without printing it.
- Apply locally first when practical.
- Push remote migrations only when explicitly asked.
- After a remote migration push, verify remote migration history.

### Public Snapshot Data

- Public pages may prefer cached snapshot tables over live RPC results.
- When public website data looks stale, check both:
  - cached public snapshot row/payload and `updated_at`
  - live RPC/source data
- If RPC/source data is correct but snapshot is stale, fix the snapshot invalidation path with a migration, then refresh existing snapshots.

## iOS Simulator And Device Pushes

Mosaic often needs to be pushed to a simulator during UI work. Do not stop at "build succeeded"; verify launch.

### Simulator Push

1. Run `flutter devices`.
2. Identify the booted simulator and target id.
3. Confirm the bundle id from Xcode project if needed. Expected: `com.mosaicmahjong.mosaic`.
4. Build: `flutter build ios --simulator --debug`.
5. Install: `xcrun simctl install booted build/ios/iphonesimulator/Runner.app`.
6. Launch: `xcrun simctl launch booted com.mosaicmahjong.mosaic`.
7. If startup behavior matters, capture a screenshot: `xcrun simctl io booted screenshot /tmp/mosaic-simulator.png`.

### Known Simulator Failure: Native Framework Wrong Platform

If the app opens to an error mentioning:

- `Couldn't resolve native function 'DOBJC_initializeApi'`
- `objective_c.framework`
- `incompatible platform (have 'iOS', need 'iOS-sim')`

Then the simulator bundle likely contains stale native assets built for physical iOS.

Fix path:

1. Run `flutter clean`.
2. Run `flutter pub get`.
3. Run `flutter build ios --simulator --debug`.
4. Verify framework platform:
   `xcrun vtool -show-build build/ios/iphonesimulator/Runner.app/Frameworks/objective_c.framework/objective_c`
5. Confirm it says `platform IOSSIMULATOR`.
6. Uninstall stale app: `xcrun simctl uninstall booted com.mosaicmahjong.mosaic`.
7. Reinstall and launch.
8. Capture a screenshot if the prior failure was visual/startup related.

Do not claim the simulator is fixed until launch output or a screenshot confirms the app starts.

### Physical iPhone

- Start with `flutter devices`.
- Do not assume wireless devices are reachable.
- If wireless connection fails, tell the user the likely requirements:
  - phone unlocked
  - same network
  - Developer Mode enabled
  - cable connection may be required
- Confirm the target device id before running/installing.
- Do not install a debug build when the user wants to open the app normally from the phone Home Screen.
  - Debug iOS builds can launch only when started by Flutter tooling or Xcode.
  - If opened directly, they may crash with `Cannot create a FlutterEngine instance in debug mode without Flutter tooling or Xcode`.
- For a physical phone push intended for normal use, install a profile or release build:
  - Preferred quick deploy: `flutter run -d <device_id> --profile --no-pub`.
  - After it installs, stop the attached run if needed, then verify standalone launch:
    `xcrun devicectl device process launch --device <device_id> --terminate-existing com.mosaicmahjong.mosaic`.
  - To verify it does not immediately crash, use:
    `xcrun devicectl device process launch --device <device_id> --terminate-existing --console --timeout 20 com.mosaicmahjong.mosaic`.
    A timeout while waiting for termination means the app stayed running; a signal or FlutterEngine debug-mode error means the push is not valid.

## Testing And Verification

- For bug fixes, add a regression test first when practical.
- Use focused tests for the touched area, then broader checks based on risk.
- Common checks:
  - `flutter analyze`
  - focused `flutter test ...`
  - relevant `test/supabase/...` migration tests
  - simulator screenshot/launch verification for startup or visual issues
- Do not say tests pass unless the command was run in the current session and the result was observed.
- If a check cannot be run, say exactly which check was skipped and why.

## Git

- When asked to commit, commit on `main` by default.
- Stage only files related to the task.
- Check the staged diff before committing.
- Use Conventional Commit messages.
- Do not push unless explicitly asked.
- Always report remaining dirty or unrelated files.
- If generated files change during build/test, identify them and restore only generated churn you created.

## Graphify

- For codebase questions under `/Users/brian/Documents/repos`, prefer the central Graphify graph when practical.
- After modifying Mosaic code, attempt a Graphify update from `/Users/brian/Documents/repos` when practical.
- If Graphify cannot update because semantic extraction needs an API key, report that clearly.
