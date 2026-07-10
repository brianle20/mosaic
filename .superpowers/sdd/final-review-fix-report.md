# Final review fix wave

Base: `7bc4509` on `main`.

## Disposition

1. **Photo ownership after queue commit — fixed.** `PhotoQueueCommitStatus` records the durable offline queue boundary before projection/read-back. `HandEntryController` and `HandEntryScreen` transfer ownership even when the post-commit call returns an error, so dispose cannot delete a queue-owned photo.
2. **Session sync snapshot loss — fixed.** Recovery reattaches the current-generation subscription before rereading the complete snapshot and merges that snapshot after remote detail/guest refresh.
3. **Async disposal and stale reads — fixed.** Silent-read controllers now use request generations/disposed guards and active-only notifications. Guest detail, roster, bonus round, seating, tables, leaderboard, prize awards, ledger, activity, event list/dashboard, and related actions use host-safe error formatting.
4. **Nested-route auth and return refresh — fixed.** The auth listener is route-independent; route-aware listeners retain a hidden generation and drain it when the route becomes current again.
5. **Authoritative null/empty results — fixed.** Guest detail and dashboard event assign successful null; seating assigns successful empty responses (while preserving route-provided initial seating for its first frame, then clearing on later recovery).
6. **Guest detail cache-first loading — fixed.** Usable cached detail clears loading immediately while remote revalidation remains silent.
7. **Initial/recovery overlap — fixed.** Generation checks cover high-risk read controllers and prevent late initial loads from restoring stale state.
8. **Raw IDs/backend errors — fixed.** Added `userFacingError`, host-friendly seat/guest fallbacks, and fixed-copy filtering for backend/RPC/UUID diagnostics across touched paths.
9. **Background queued recovery — fixed.** Queued work and store-change recovery defer while backgrounded and drain on resume; production callback uses the queued-work trigger.
10. **Photo queue progress — fixed.** Non-retryable blocked photo uploads are marked blocked and the queue continues to later independent uploads.
11. **Boundary strength — fixed.** Recovery surface boundary test now requires an `onRefresh:` callback in addition to listener presence.
12. **Overlapping recovery loads — fixed.** Leaderboard, prize awards, and hand-ledger stale completions now guard cache/remote assignments and `finally` loading state by request generation; delayed overlap regressions cover each controller.
13. **Initial session sync handoff — fixed.** Session detail rereads the complete sync snapshot immediately after attaching its subscription, and queues sync events that arrive during a refresh rather than dropping them.
14. **In-flight photo ownership — fixed.** Hand-entry disposal and result-type changes retain a captured photo while a durable submit is still pending; the controller also suppresses late notifications after disposal.
15. **Prize-plan lifecycle — fixed.** Load, preview, lock, and recovery paths have disposal and independent submission-generation guards so stale actions cannot leave the saving indicator stuck.

## TDD evidence

- Photo ownership RED: `flutter test test/features/scoring/controllers/hand_entry_controller_test.dart --plain-name 'retains photo ownership when projection fails after queue commit'` (expected `true`, actual `false`). GREEN: same command, `All tests passed!`; screen regression also passes with `flutter test test/features/scoring/screens/hand_entry_screen_test.dart --plain-name 'post-commit projection failure keeps queued photo on dispose'`.
- Snapshot RED: `flutter test test/features/scoring/controllers/session_detail_controller_test.dart --plain-name 'recovery rereads the complete sync snapshot after subscription handoff'` (stale pending hand remained). GREEN: same command, `All tests passed!`.
- Nested auth RED: `flutter test test/data/offline/offline_recovery_scope_test.dart --plain-name 'auth listener refreshes while a nested route is visible'` initially failed to compile without `routeAware`; GREEN after wiring: `All tests passed!`. Return-to-route regression passes with the matching focused command.
- Background queue RED: `flutter test test/data/offline/sync_coordinator_test.dart --plain-name 'queued work while backgrounded waits for resume'` observed a record while backgrounded. GREEN: same command, `All tests passed!`.
- Photo queue RED: `flutter test test/data/offline/sync_coordinator_test.dart --plain-name 'business upload failures block one photo and continue later uploads'` left the second upload pending. GREEN: same command, `All tests passed!`.
- Cache/disposal regressions: `flutter test test/features/checkin/controllers/guest_check_in_controller_lifecycle_test.dart` — 2 tests passed (cached detail usable during slow remote; late result ignored after dispose).
- Null/empty regressions: dashboard null event and seating empty assignments focused tests both pass. Error/privacy regression `flutter test test/core/user_facing_error_test.dart` passes.
- Overlap regressions: `flutter test test/features/leaderboard/controllers/leaderboard_controller_test.dart --plain-name 'stale leaderboard load cannot overwrite a newer recovery load'`, the matching prize-awards and hand-ledger commands, and `flutter test test/features/scoring/controllers/session_detail_controller_test.dart --plain-name 'queues a sync event that arrives during snapshot refresh'` all pass.
- In-flight photo regression: `flutter test test/features/scoring/screens/hand_entry_screen_test.dart --plain-name 'photo survives route disposal while hand commit is pending'` passed after reproducing the pre-fix deletion and late-disposed-controller notification failure.

## Full verification

- `flutter test` — **All tests passed (1406)**.
- `flutter test --concurrency=1` — **All tests passed (1406)**.
- `flutter analyze --no-pub` — **No issues found**.
- `git diff --check` — clean.
- Graphify update from `/Users/brian/Documents/repos` completed AST extraction for 4,109 files.
- Simulator smoke: `MOSAIC_SIMULATOR_SCREENSHOT_PATH=/tmp/mosaic-simulator.png tool/run_ios_simulator_debug.sh` built, installed, launched `com.mosaicmahjong.mosaic`, and wrote the screenshot successfully.

## Concerns

- Route-provided seating passed from the just-created seating flow is retained through the first empty remote response to preserve the existing first-frame UX; a subsequent silent/recovery load clears it authoritatively.
- The full test suite is long (~1 minute) but completed with 1,406 passing tests and no failures.
