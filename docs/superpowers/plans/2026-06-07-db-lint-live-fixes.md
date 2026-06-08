# DB Lint Live Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the live Supabase lint errors that can affect hand scoring and tournament round session starts, while leaving deprecated player-tag legacy code service-role-only.

**Architecture:** Add one forward-only Supabase migration that replaces the current broken functions with corrected definitions. Keep behavior unchanged except for fixing missing helper references, removing writes to removed columns, and disambiguating PL/pgSQL variables. Add migration tests that lock the fixes in place.

**Tech Stack:** Supabase Postgres migrations, PL/pgSQL, Flutter/Dart migration tests, Supabase CLI.

---

## Files

- Create: `supabase/migrations/20260607140000_fix_live_db_lint_errors.sql`
  - Recreates `app_private.validate_hand_result_input(...)`.
  - Recreates `app_private.refresh_event_score_totals(uuid)`.
  - Recreates `public.start_current_tournament_round_sessions(uuid)`.
  - Reloads PostgREST schema.
- Create: `test/supabase/fix_live_db_lint_errors_migration_test.dart`
  - Guards the new migration content.
  - Ensures the old broken references are absent.
- Modify only if needed: existing migration tests that assert exact old `assignment_index` snippets.
- Keep separate from current uncommitted player-tag RPC cleanup:
  - `supabase/migrations/20260607130000_deprecate_remaining_player_tag_rpcs.sql`
  - `lib/data/repositories/supabase_guest_repository.dart`
  - related tests

---

### Task 0: Commit Current Player-Tag RPC Cleanup First

**Files:**
- Existing uncommitted files from the previous cleanup.

- [ ] **Step 1: Verify current cleanup**

Run:

```bash
flutter test test/deprecations/player_tag_app_api_deprecation_test.dart test/supabase/deprecate_remaining_player_tag_rpcs_migration_test.dart test/data/repositories/supabase_guest_repository_cover_ledger_test.dart test/data/repositories/supabase_guest_repository_tournament_test.dart
flutter analyze
git diff --check
```

Expected:

```text
All tests passed
No issues found
```

- [ ] **Step 2: Stage and commit current cleanup**

Run:

```bash
git add lib/data/repositories/supabase_guest_repository.dart \
  test/data/repositories/supabase_guest_repository_cover_ledger_test.dart \
  test/deprecations/player_tag_app_api_deprecation_test.dart \
  supabase/migrations/20260607130000_deprecate_remaining_player_tag_rpcs.sql \
  test/supabase/deprecate_remaining_player_tag_rpcs_migration_test.dart
git commit -m "Deprecate remaining player tag helper RPCs"
```

Expected:

```text
[main <sha>] Deprecate remaining player tag helper RPCs
```

---

### Task 1: Add Failing Migration Test For Live Lint Fixes

**Files:**
- Create: `test/supabase/fix_live_db_lint_errors_migration_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/supabase/fix_live_db_lint_errors_migration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live db lint fix migration repairs scoring and bulk start functions', () {
    final migrationFile = File(
      'supabase/migrations/20260607140000_fix_live_db_lint_errors.sql',
    );

    expect(migrationFile.existsSync(), isTrue);
    final sql = migrationFile.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function app_private.validate_hand_result_input',
      ),
    );
    expect(sql, contains('app_private.ruleset_minimum_winning_fan'));
    expect(sql, isNot(contains('app_private.ruleset_minimum_fan')));

    expect(
      sql,
      contains('create or replace function app_private.refresh_event_score_totals'),
    );
    expect(sql, isNot(contains('score_total_points = totals.total_points')));
    expect(sql, isNot(contains('score_rank = ranked.rank')));
    expect(sql, contains('perform app_private.refresh_public_event_standings_snapshot(target_event_id);'));

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, contains('subscript_index integer;'));
    expect(sql, contains('from generate_subscripts(assignment_rows, 1) as generated_index'));
    expect(sql, contains('assignment_rows[generated_index].seat_index <> generated_index - 1'));
    expect(sql, contains('for subscript_index in 1..array_length(assignment_rows, 1) loop'));
    expect(sql, isNot(contains('from generate_subscripts(assignment_rows, 1) as assignment_index')));

    expect(
      sql,
      contains(
        'grant execute on function public.start_current_tournament_round_sessions(uuid)',
      ),
    );
    expect(sql, contains("select pg_notify('pgrst', 'reload schema');"));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/supabase/fix_live_db_lint_errors_migration_test.dart
```

Expected:

```text
Expected: true
Actual: <false>
```

---

### Task 2: Create Migration To Fix Hand Validation

**Files:**
- Create/modify: `supabase/migrations/20260607140000_fix_live_db_lint_errors.sql`

- [ ] **Step 1: Add `validate_hand_result_input` replacement**

Start the migration with:

```sql
-- Fix live DB lint errors in current scoring and tournament round session RPCs.

create or replace function app_private.validate_hand_result_input(
  target_ruleset_id text,
  target_result_type text,
  target_winner_seat_index integer,
  target_win_type text,
  target_discarder_seat_index integer,
  target_fan_count integer,
  target_dealer_was_waiting_at_draw boolean default null,
  target_penalty_seat_index integer default null
)
returns void
language plpgsql
stable
as $$
declare
  minimum_fan integer;
begin
  if target_result_type not in ('win', 'washout', 'false_win_penalty') then
    raise exception 'Hand result type must be win, washout, or false_win_penalty.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'washout' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null
      or target_penalty_seat_index is not null
      or target_fan_count is not null then
      raise exception 'Draw hands cannot include winner, win type, discarder, penalty caller, or fan count.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_dealer_was_waiting_at_draw is not null then
    raise exception 'Only draw hands can include dealer waiting state.'
      using errcode = 'P0001';
  end if;

  if target_result_type = 'false_win_penalty' then
    if target_winner_seat_index is not null
      or target_win_type is not null
      or target_discarder_seat_index is not null then
      raise exception 'False win penalties cannot include winner, win type, or discarder.'
        using errcode = 'P0001';
    end if;

    if target_penalty_seat_index is null
      or target_penalty_seat_index not between 0 and 3 then
      raise exception 'False win penalties require a valid caller seat.'
        using errcode = 'P0001';
    end if;

    if target_fan_count is not null and target_fan_count <> 6 then
      raise exception 'False win penalties are fixed at 6 fan.'
        using errcode = 'P0001';
    end if;

    return;
  end if;

  if target_penalty_seat_index is not null then
    raise exception 'Win hands cannot include a false win caller.'
      using errcode = 'P0001';
  end if;

  if target_winner_seat_index is null
    or target_winner_seat_index not between 0 and 3 then
    raise exception 'Win hands require a valid winner seat.'
      using errcode = 'P0001';
  end if;

  if target_win_type not in ('discard', 'self_draw') then
    raise exception 'Win hands require a win type of discard or self_draw.'
      using errcode = 'P0001';
  end if;

  if target_win_type = 'discard' then
    if target_discarder_seat_index is null
      or target_discarder_seat_index not between 0 and 3 then
      raise exception 'Discard wins require a valid discarder seat.'
        using errcode = 'P0001';
    end if;

    if target_discarder_seat_index = target_winner_seat_index then
      raise exception 'Discarder must be different from winner.'
        using errcode = 'P0001';
    end if;
  else
    if target_discarder_seat_index is not null then
      raise exception 'Self-draw wins cannot include a discarder.'
        using errcode = 'P0001';
    end if;
  end if;

  minimum_fan := app_private.ruleset_minimum_winning_fan(target_ruleset_id);
  if target_fan_count is null or target_fan_count < minimum_fan then
    raise exception 'Fan count must be at least %.', minimum_fan
      using errcode = 'P0001';
  end if;
end;
$$;
```

- [ ] **Step 2: Run migration test**

Run:

```bash
flutter test test/supabase/fix_live_db_lint_errors_migration_test.dart
```

Expected: still fails because refresh totals and bulk start code are not yet in the migration.

---

### Task 3: Replace Score Total Refresh Without Removed Columns

**Files:**
- Modify: `supabase/migrations/20260607140000_fix_live_db_lint_errors.sql`

- [ ] **Step 1: Copy current `refresh_event_score_totals` body and remove stale guest-column update**

Append a `create or replace function app_private.refresh_event_score_totals(target_event_id uuid)` definition based on the latest definition in `supabase/migrations/20260524150000_public_standings_snapshot_stream.sql`.

In the copied function:

1. Keep the `delete from public.event_score_totals`.
2. Keep the `insert into public.event_score_totals (...) with ...` calculation.
3. Remove the block that checks `information_schema.columns` for `score_total_points` / `score_rank`.
4. Remove the `update public.event_guests set score_total_points = ..., score_rank = ...` statement.
5. End the function with:

```sql
  perform app_private.refresh_public_event_standings_snapshot(target_event_id);
end;
$$;
```

- [ ] **Step 2: Run migration test**

Run:

```bash
flutter test test/supabase/fix_live_db_lint_errors_migration_test.dart
```

Expected: still fails until the bulk-start function is added.

---

### Task 4: Replace Bulk Tournament Round Start With Disambiguated Loop Names

**Files:**
- Modify: `supabase/migrations/20260607140000_fix_live_db_lint_errors.sql`
- Possibly modify: `test/supabase/start_current_tournament_round_sessions_migration_test.dart`

- [ ] **Step 1: Copy current `start_current_tournament_round_sessions` function**

Append the current function from `supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql`.

In the copied function:

1. Change declaration:

```sql
  subscript_index integer;
```

2. Replace the contiguous seat check with:

```sql
    if exists (
      select 1
      from generate_subscripts(assignment_rows, 1) as generated_index
      where assignment_rows[generated_index].seat_index <> generated_index - 1
    ) then
      raise exception 'Assigned seating must fill seats contiguously from East.'
        using errcode = 'P0001';
    end if;
```

3. Replace the insert loop with:

```sql
    for subscript_index in 1..array_length(assignment_rows, 1) loop
      insert into public.table_session_seats (
        table_session_id,
        seat_index,
        initial_wind,
        event_guest_id
      )
      values (
        session_row.id,
        assignment_rows[subscript_index].seat_index,
        initial_winds[assignment_rows[subscript_index].seat_index + 1],
        assignment_rows[subscript_index].event_guest_id
      );
    end loop;
```

4. Keep:

```sql
grant execute on function public.start_current_tournament_round_sessions(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
```

- [ ] **Step 2: Run migration tests**

Run:

```bash
flutter test test/supabase/fix_live_db_lint_errors_migration_test.dart test/supabase/start_current_tournament_round_sessions_migration_test.dart
```

Expected:

```text
All tests passed
```

If `start_current_tournament_round_sessions_migration_test.dart` fails because it asserts the old `assignment_index` snippet, update it to assert the new `generated_index` / `subscript_index` snippets.

---

### Task 5: Apply Migration And Verify Remote Lint Errors Are Gone

**Files:**
- No code changes unless verification reveals a typo.

- [ ] **Step 1: Apply migration**

Run:

```bash
DBPASS=$(awk -F= '$1=="SUPABASE_DB_PASSWORD" {print substr($0, index($0,"=")+1)}' .env)
SUPABASE_DB_PASSWORD="$DBPASS" npx supabase db push
```

Expected:

```text
Applying migration 20260607140000_fix_live_db_lint_errors.sql...
Finished supabase db push.
```

- [ ] **Step 2: Verify remote lint**

Run:

```bash
DBPASS=$(awk -F= '$1=="SUPABASE_DB_PASSWORD" {print substr($0, index($0,"=")+1)}' .env)
SUPABASE_DB_PASSWORD="$DBPASS" npx supabase db lint --linked
```

Expected:

- No `level: "error"` entries for:
  - `app_private.validate_hand_result_input`
  - `app_private.refresh_event_score_totals`
  - `public.start_current_tournament_round_sessions`
- Existing warnings may remain.
- `public.replace_guest_tag` may still report an error unless intentionally handled in Task 6.

- [ ] **Step 3: Verify the live RPCs remain executable for intended roles**

Run:

```bash
npx supabase db query --linked -o json "select n.nspname as schema, p.proname as function_name, pg_get_function_identity_arguments(p.oid) as arguments, has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_execute from pg_proc p join pg_namespace n on n.oid = p.pronamespace where p.proname in ('record_hand_result','start_current_tournament_round_sessions') order by n.nspname, p.proname;"
```

Expected:

```json
"authenticated_execute": true
```

for `public.record_hand_result` and `public.start_current_tournament_round_sessions`.

---

### Task 6: Decide Whether To Silence Deprecated `replace_guest_tag`

**Files:**
- Optional modify: `supabase/migrations/20260607140000_fix_live_db_lint_errors.sql`

- [ ] **Step 1: Decide scope**

Default recommendation: do not repair `replace_guest_tag` business logic. It is deprecated and client-revoked. If we want DB lint to have zero `error` entries, replace it with a service-role-only stub in a separate migration:

```sql
create or replace function public.replace_guest_tag(
  target_event_guest_id uuid,
  scanned_uid text,
  scanned_display_label text
)
returns public.event_guest_tag_assignments
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'Player tag replacement is deprecated.'
    using errcode = 'P0001';
end;
$$;

revoke all on function public.replace_guest_tag(uuid, text, text) from public;
revoke all on function public.replace_guest_tag(uuid, text, text) from anon;
revoke all on function public.replace_guest_tag(uuid, text, text) from authenticated;
grant execute on function public.replace_guest_tag(uuid, text, text) to service_role;
```

Expected product decision:

- If the goal is only live safety: skip this task.
- If the goal is clean Supabase lint errors: add the stub in a follow-up migration.

---

### Task 7: Final Local Verification And Commit

**Files:**
- All files changed by this plan.

- [ ] **Step 1: Run focused tests**

Run:

```bash
flutter test test/supabase/fix_live_db_lint_errors_migration_test.dart test/supabase/start_current_tournament_round_sessions_migration_test.dart test/supabase/draws_always_rotate_dealer_migration_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 2: Run broader verification**

Run:

```bash
flutter analyze
git diff --check
```

Expected:

```text
No issues found
```

- [ ] **Step 3: Commit**

Run:

```bash
git add supabase/migrations/20260607140000_fix_live_db_lint_errors.sql \
  test/supabase/fix_live_db_lint_errors_migration_test.dart \
  test/supabase/start_current_tournament_round_sessions_migration_test.dart
git commit -m "Fix live Supabase lint errors"
```

Expected:

```text
[main <sha>] Fix live Supabase lint errors
```

---

## Self-Review

- Spec coverage: the plan fixes the three live lint errors: missing minimum-fan helper, removed score columns, and ambiguous bulk-start index. It explicitly defers or separately scopes the deprecated `replace_guest_tag` error.
- Placeholder scan: no placeholders remain; each task has exact file paths, commands, and expected outcomes.
- Type consistency: function signatures match current remote/local definitions:
  - `app_private.validate_hand_result_input(text, text, integer, text, integer, integer, boolean, integer)`
  - `app_private.refresh_event_score_totals(uuid)`
  - `public.start_current_tournament_round_sessions(uuid)`
