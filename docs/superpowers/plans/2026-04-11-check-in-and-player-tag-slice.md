# Check-In And Player Tag Slice Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add guest check-in and player tag assignment with a simulator-safe NFC fallback, backend-enforced assignment rules, and verified end-to-end host flow.

**Architecture:** Extend the existing guest flow with a dedicated guest detail/check-in surface, a small NFC service boundary, and server-authoritative RPC-backed tag operations. Keep the simulator path first-class by routing scans through a manual UID fallback service implementation, while preserving the same repository and backend write path that future real NFC hardware will use.

**Tech Stack:** Flutter, Supabase Postgres migrations/RPC, supabase_flutter, shared_preferences, Flutter widget tests, Flutter integration_test on iOS simulator

---

## File Map

- Create: `supabase/migrations/20260411180000_check_in_and_player_tags.sql`
  - RPCs for guest check-in and player tag registration/assignment/replacement
  - audit logging helpers for new operations if needed
- Modify: `lib/data/models/guest_models.dart`
  - add input/result types for check-in and active tag summary as needed
- Modify: `lib/data/models/tag_models.dart`
  - add assignment summary model and tag scan normalization helpers
- Modify: `lib/data/local/local_cache.dart`
  - cache guest detail/assignment information if needed for roster/detail refresh
- Modify: `lib/data/repositories/repository_interfaces.dart`
  - extend guest/tag repository contracts
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
  - implement check-in and tag assignment RPC calls
- Create: `lib/services/nfc/nfc_service.dart`
  - NFC abstraction and scan result types
- Create: `lib/services/nfc/manual_entry_nfc_service.dart`
  - simulator/dev UID fallback implementation
- Create: `lib/features/checkin/controllers/guest_check_in_controller.dart`
  - detail screen state, eligibility gating, assignment actions, friendly errors
- Create: `lib/features/checkin/models/manual_tag_scan_draft.dart`
  - manual UID validation and normalization
- Create: `lib/features/checkin/screens/guest_detail_screen.dart`
  - host-facing guest detail, check-in, assign/replace tag actions
- Modify: `lib/core/routing/app_router.dart`
  - route guest roster rows to guest detail and inject NFC service
- Modify: `lib/app/app.dart`
  - wire the default NFC service implementation
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
  - show tag badge and navigate to detail screen
- Test: `test/data/models/domain_model_serialization_test.dart`
  - guest/tag eligibility and assignment serialization coverage
- Create: `test/features/checkin/models/manual_tag_scan_draft_test.dart`
  - manual UID validation behavior
- Create: `test/features/checkin/screens/guest_detail_screen_test.dart`
  - detail UI states and blocked/eligible actions
- Create: `test/data/repositories/supabase_guest_repository_tag_ops_test.dart`
  - repository mapping for check-in/tag operations
- Modify: `integration_test/live_smoke_test.dart`
  - extend live flow to add paid guest, check in, assign player tag, verify cleanup

## Chunk 1: Backend And Domain Contracts

### Task 1: Add failing domain tests for check-in/tag state

**Files:**
- Modify: `test/data/models/domain_model_serialization_test.dart`
- Modify: `lib/data/models/guest_models.dart`
- Modify: `lib/data/models/tag_models.dart`

- [ ] **Step 1: Write failing tests for active assignment and guest eligibility helpers**

Add tests covering:
- active assignment summary JSON parsing
- checked-in/tagged status derivation
- replacement state serialization if modeled
- manual player-tag eligibility remains `paid`/`comped` only

- [ ] **Step 2: Run only the domain model tests to verify failure**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: FAIL for missing types/helpers

- [ ] **Step 3: Add minimal domain model code**

Implement only the types/helpers needed by the failing tests:
- active guest tag assignment summary record
- optional guest detail aggregate if required by repository response shape
- any small computed getters used by UI/tests

- [ ] **Step 4: Re-run the domain model tests**

Run: `flutter test test/data/models/domain_model_serialization_test.dart`
Expected: PASS

### Task 2: Add the backend migration for check-in and player tag RPCs

**Files:**
- Create: `supabase/migrations/20260411180000_check_in_and_player_tags.sql`

- [ ] **Step 1: Write the migration with server-authoritative functions**

Include:
- helper to normalize tag UID/fingerprint
- `public.check_in_guest`
- `public.register_nfc_tag`
- `public.assign_guest_tag`
- `public.replace_guest_tag`
- audit log entries for check-in and tag operations

- [ ] **Step 2: Re-read the migration against existing schema and RLS**

Check:
- functions use `auth.uid()`
- event ownership is verified through event joins
- active-assignment uniqueness relies on existing partial indexes
- replacement updates old row then inserts new row in one transaction

- [ ] **Step 3: Apply the migration to local config only in codebase**

No dashboard-only changes. The migration file must be ready for `supabase db push` / remote application later in execution.

## Chunk 2: Repository Layer And NFC Service

### Task 3: Add failing repository tests for check-in/tag operations

**Files:**
- Create: `test/data/repositories/supabase_guest_repository_tag_ops_test.dart`
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_guest_repository.dart`

- [ ] **Step 1: Write failing repository tests**

Cover:
- check-in maps RPC result to updated guest
- assign tag maps RPC result to updated guest/assignment summary
- replace tag maps RPC result correctly
- friendly conflict/error handling path if repository surfaces typed errors

- [ ] **Step 2: Run the new repository test file to verify failure**

Run: `flutter test test/data/repositories/supabase_guest_repository_tag_ops_test.dart`
Expected: FAIL for missing methods/types

- [ ] **Step 3: Extend repository contracts and implement minimal Supabase calls**

Add:
- repository methods for check-in, assign tag, replace tag
- RPC invocation code in `SupabaseGuestRepository`
- cache refresh/merge behavior after successful operations

- [ ] **Step 4: Re-run the repository tests**

Run: `flutter test test/data/repositories/supabase_guest_repository_tag_ops_test.dart`
Expected: PASS

### Task 4: Add failing tests for manual NFC UID entry

**Files:**
- Create: `test/features/checkin/models/manual_tag_scan_draft_test.dart`
- Create: `lib/features/checkin/models/manual_tag_scan_draft.dart`
- Create: `lib/services/nfc/nfc_service.dart`
- Create: `lib/services/nfc/manual_entry_nfc_service.dart`

- [ ] **Step 1: Write failing tests for manual UID validation**

Cover:
- trims whitespace
- normalizes case/spacing consistently
- rejects empty values
- preserves a stable normalized UID for assignment

- [ ] **Step 2: Run the draft test to verify failure**

Run: `flutter test test/features/checkin/models/manual_tag_scan_draft_test.dart`
Expected: FAIL for missing service/draft

- [ ] **Step 3: Implement the minimal draft and service abstraction**

Add:
- `NfcService`
- `TagScanResult`
- manual-entry implementation contract
- manual UID draft validation/normalization

- [ ] **Step 4: Re-run the draft test**

Run: `flutter test test/features/checkin/models/manual_tag_scan_draft_test.dart`
Expected: PASS

## Chunk 3: Guest Detail / Check-In UI

### Task 5: Add failing widget tests for guest detail states

**Files:**
- Create: `test/features/checkin/screens/guest_detail_screen_test.dart`
- Create: `lib/features/checkin/controllers/guest_check_in_controller.dart`
- Create: `lib/features/checkin/screens/guest_detail_screen.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: Write failing widget tests for guest detail**

Cover:
- paid/comped guest shows `Check In and Assign Tag`
- unpaid/partial guest shows blocked messaging
- checked-in guest with no tag shows `Assign Tag`
- checked-in tagged guest shows `Replace Tag`
- roster shows tag status badge and navigates to detail

- [ ] **Step 2: Run the guest detail widget tests to verify failure**

Run: `flutter test test/features/checkin/screens/guest_detail_screen_test.dart`
Expected: FAIL for missing route/screen/controller

- [ ] **Step 3: Implement the minimal guest detail screen and controller**

Add:
- detail screen UI
- controller methods for check-in and assignment actions
- route wiring
- roster badge updates and navigation to detail
- app-level injection of manual-entry NFC service

- [ ] **Step 4: Re-run the guest detail widget tests**

Run: `flutter test test/features/checkin/screens/guest_detail_screen_test.dart`
Expected: PASS

### Task 6: Hook manual UID assignment into the detail flow

**Files:**
- Modify: `lib/features/checkin/controllers/guest_check_in_controller.dart`
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
- Modify: `lib/services/nfc/manual_entry_nfc_service.dart`

- [ ] **Step 1: Add failing widget coverage for manual UID entry**

Extend `guest_detail_screen_test.dart` with:
- tapping assign action opens manual UID entry
- valid UID triggers repository action
- invalid UID shows validation

- [ ] **Step 2: Run only the guest detail widget test file to verify failure**

Run: `flutter test test/features/checkin/screens/guest_detail_screen_test.dart`
Expected: FAIL on missing modal flow

- [ ] **Step 3: Implement the minimal modal/manual assignment flow**

Include:
- entry sheet/dialog for manual UID
- call into `NfcService`
- surface friendly repository/controller errors

- [ ] **Step 4: Re-run the widget tests**

Run: `flutter test test/features/checkin/screens/guest_detail_screen_test.dart`
Expected: PASS

## Chunk 4: Integration, Migration Application, And Live Verification

### Task 7: Extend the live iOS smoke test for check-in and tag assignment

**Files:**
- Modify: `integration_test/live_smoke_test.dart`

- [ ] **Step 1: Add failing integration assertions**

Extend the smoke flow to:
- create a paid guest
- navigate to guest detail
- run check-in and manual tag assignment
- verify checked-in/tagged state in UI
- verify created tag/assignment through Supabase if practical

- [ ] **Step 2: Run the live smoke test to verify failure**

Run: `flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...`
Expected: FAIL on missing UI/backend support

- [ ] **Step 3: Apply the new migration to Supabase and complete the minimal implementation gap**

Apply:
- `supabase/migrations/20260411180000_check_in_and_player_tags.sql`

Then finish whatever minimal backend/client wiring is still required for the smoke flow to pass.

- [ ] **Step 4: Re-run analyzer, full test suite, and live smoke test**

Run:
- `flutter analyze`
- `flutter test`
- `flutter test integration_test/live_smoke_test.dart -d 5B28B87D-E80C-4E2C-B3CF-A89917E670D7 --dart-define=HOST_EMAIL=... --dart-define=HOST_PASSWORD=...`

Expected:
- analyzer clean
- all test files pass
- live smoke flow passes and cleans up smoke rows

- [ ] **Step 5: Verify live backend cleanup**

Query the live backend to confirm:
- no leftover `Smoke Event ...`
- no leftover `Smoke Guest ...`
- no leftover smoke test player tags if the test creates them

## Chunk 5: Review And Commit

### Task 8: Final review and commit

**Files:**
- Review all files changed in prior tasks

- [ ] **Step 1: Review the final diff for scope discipline**

Check that this slice does not accidentally add:
- table tags
- session scanning
- non-player NFC behavior beyond the abstraction boundary

- [ ] **Step 2: Commit the slice**

Suggested commit message:
- `feat: add guest check-in and player tag assignment`

- [ ] **Step 3: Push after verification**

Run:
- `git push origin main`

Expected:
- remote updated with verified check-in/tag slice
