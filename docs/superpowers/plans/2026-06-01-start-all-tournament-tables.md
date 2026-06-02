# Start All Tournament Tables Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an app-only `Start All Tables` action that starts every eligible table in the current tournament round with one synchronized server timestamp.

**Architecture:** A new Supabase RPC creates all current-round table sessions in one transaction and returns the created `table_sessions` rows. The Flutter session repository exposes that RPC, the seating controller invokes it and refreshes state, and the seating screen renders the button above the table seating cards. The public web app remains untouched.

**Tech Stack:** Flutter/Dart, Supabase PostgreSQL migrations, `flutter_test`, repository fakes in `test/helpers/repository_fakes.dart`.

---

## File Map

- Create `supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql`: define `public.start_current_tournament_round_sessions(target_event_id uuid)`.
- Create `test/supabase/start_current_tournament_round_sessions_migration_test.dart`: migration string tests for the new RPC contract.
- Modify `lib/data/repositories/repository_interfaces.dart`: add `SessionRepository.startCurrentTournamentRoundSessions(String eventId)`.
- Modify `lib/data/repositories/supabase_session_repository.dart`: add list RPC runner support and implement the new repository method.
- Modify `test/helpers/repository_fakes.dart`: add the throwing override for the new session repository method.
- Modify `test/data/repositories/supabase_session_repository_test.dart`: test RPC params, parsing, and cache merge for bulk-started sessions.
- Modify `lib/features/tables/controllers/seating_assignment_controller.dart`: add `canStartAllTables` and `startAllTables(eventId)`.
- Modify `test/features/tables/controllers/seating_assignment_controller_test.dart`: cover controller success and error behavior.
- Modify `lib/features/tables/screens/seating_assignment_screen.dart`: render `Start All Tables` above table cards and wire it to the controller.
- Modify `test/features/tables/screens/seating_assignment_screen_test.dart`: cover button visibility, action, error display, and hidden empty state.

---

### Task 1: Supabase Bulk Start RPC

**Files:**
- Create: `supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql`
- Test: `test/supabase/start_current_tournament_round_sessions_migration_test.dart`

- [ ] **Step 1: Write the failing migration test**

Create `test/supabase/start_current_tournament_round_sessions_migration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bulk tournament table start migration defines synchronized RPC', () {
    final migration = File(
      'supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql',
    );

    expect(migration.existsSync(), isTrue);
    final sql = migration.readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function public.start_current_tournament_round_sessions',
      ),
    );
    expect(sql, contains('target_event_id uuid'));
    expect(sql, contains('returns setof public.table_sessions'));
    expect(sql, contains('security definer'));
    expect(sql, contains('perform app_private.require_event_for_scoring'));
    expect(sql, contains('bulk_started_at timestamptz := now();'));
    expect(sql, contains('current_round public.event_tournament_rounds%rowtype;'));
    expect(sql, contains("current_round.status in ('seating', 'active')"));
    expect(sql, contains("assignment.status = 'active'"));
    expect(sql, contains('array_length(assignment_rows, 1) between 2 and 4'));
    expect(
      sql,
      contains(
        'assignment_rows[assignment_index].seat_index <> assignment_index - 1',
      ),
    );
    expect(sql, contains('guest.attendance_status <> \'checked_in\''));
    expect(sql, contains("existing_session.status in ('active', 'paused')"));
    expect(sql, contains('existing_session.event_table_id = table_row.id'));
    expect(sql, contains('seat.event_guest_id = assignment.event_guest_id'));
    expect(sql, contains('table_row.default_ruleset_id'));
    expect(sql, contains('session_number_for_table'));
    expect(sql, contains('tournament_round_id'));
    expect(sql, contains('assignment_round'));
    expect(sql, contains('started_at'));
    expect(sql, contains('bulk_started_at'));
    expect(sql, contains("status = 'active'"));
    expect(sql, contains('started_at = coalesce(started_at, bulk_started_at)'));
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

- [ ] **Step 2: Run the migration test to verify it fails**

Run:

```bash
flutter test test/supabase/start_current_tournament_round_sessions_migration_test.dart
```

Expected: FAIL because `supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql` does not exist.

- [ ] **Step 3: Add the migration**

Create `supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql`:

```sql
create or replace function public.start_current_tournament_round_sessions(
  target_event_id uuid
)
returns setof public.table_sessions
language plpgsql
security definer
set search_path = public
as $$
declare
  event_row public.events%rowtype;
  current_round public.event_tournament_rounds%rowtype;
  table_row public.event_tables%rowtype;
  ruleset_row public.rulesets%rowtype;
  assignment_rows public.event_seating_assignments[];
  session_row public.table_sessions%rowtype;
  next_session_number integer;
  assignment_index integer;
  bulk_started_at timestamptz := now();
  initial_winds text[] := array['east', 'south', 'west', 'north'];
begin
  perform app_private.require_event_for_scoring(target_event_id);

  select *
  into event_row
  from public.events
  where id = target_event_id;

  if event_row.id is null
    or coalesce(event_row.current_scoring_phase, 'qualification') <> 'tournament'
  then
    raise exception 'Tournament round is not available for this event.'
      using errcode = 'P0001';
  end if;

  select *
  into current_round
  from public.event_tournament_rounds as tournament_round
  where tournament_round.event_id = target_event_id
    and tournament_round.scoring_phase = 'tournament'
    and tournament_round.status in ('seating', 'active')
  order by tournament_round.round_number desc
  limit 1;

  if current_round.id is null then
    raise exception 'No current tournament round seating is available.'
      using errcode = 'P0001';
  end if;

  for table_row in
    select event_table.*
    from public.event_tables as event_table
    where event_table.event_id = target_event_id
      and exists (
        select 1
        from public.event_seating_assignments as assignment
        where assignment.event_id = target_event_id
          and assignment.event_table_id = event_table.id
          and assignment.tournament_round_id = current_round.id
          and assignment.status = 'active'
      )
      and not exists (
        select 1
        from public.table_sessions as existing_session
        where existing_session.event_table_id = event_table.id
          and existing_session.status in ('active', 'paused')
      )
    order by event_table.display_order asc, event_table.label asc, event_table.id asc
  loop
    select array_agg(assignment order by assignment.seat_index asc)
    into assignment_rows
    from public.event_seating_assignments as assignment
    where assignment.event_id = target_event_id
      and assignment.event_table_id = table_row.id
      and assignment.tournament_round_id = current_round.id
      and assignment.status = 'active';

    if assignment_rows is null
      or not (array_length(assignment_rows, 1) between 2 and 4)
    then
      raise exception 'Two to four active seating assignments are required to start all tables.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from generate_subscripts(assignment_rows, 1) as assignment_index
      where assignment_rows[assignment_index].seat_index <> assignment_index - 1
    ) then
      raise exception 'Assigned seating must fill seats contiguously from East.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      where assignment.assignment_type <> 'random'
        or assignment.tournament_round_id is distinct from current_round.id
        or assignment.assignment_round is distinct from current_round.assignment_round
    ) then
      raise exception 'All active tournament assignments must belong to the current tournament round.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from public.event_guests as guest
      where guest.id = any (
          select assignment.event_guest_id
          from unnest(assignment_rows) as assignment
        )
        and guest.attendance_status <> 'checked_in'
    ) then
      raise exception 'All assigned session players must be checked in.'
        using errcode = 'P0001';
    end if;

    if exists (
      select 1
      from unnest(assignment_rows) as assignment
      join public.table_session_seats as seat
        on seat.event_guest_id = assignment.event_guest_id
      join public.table_sessions as existing_session
        on existing_session.id = seat.table_session_id
      where existing_session.event_id = target_event_id
        and existing_session.status in ('active', 'paused')
    ) then
      raise exception 'An assigned guest is already seated in another active session.'
        using errcode = 'P0001';
    end if;

    select *
    into ruleset_row
    from public.rulesets
    where id = table_row.default_ruleset_id;

    if not found then
      raise exception 'Default ruleset not found for a selected table.'
        using errcode = 'P0001';
    end if;

    select coalesce(max(existing_session.session_number_for_table), 0) + 1
    into next_session_number
    from public.table_sessions as existing_session
    where existing_session.event_table_id = table_row.id;

    insert into public.table_sessions (
      event_id,
      event_table_id,
      session_number_for_table,
      ruleset_id,
      rotation_policy_type,
      rotation_policy_config_json,
      status,
      initial_east_seat_index,
      current_dealer_seat_index,
      dealer_pass_count,
      completed_games_count,
      hand_count,
      scoring_phase,
      tournament_round_id,
      assignment_round,
      started_at,
      started_by_user_id
    )
    values (
      target_event_id,
      table_row.id,
      next_session_number,
      table_row.default_ruleset_id,
      table_row.default_rotation_policy_type,
      table_row.default_rotation_policy_config_json,
      'active',
      0,
      0,
      0,
      0,
      0,
      'tournament',
      current_round.id,
      current_round.assignment_round,
      bulk_started_at,
      auth.uid()
    )
    returning *
    into session_row;

    for assignment_index in 1..array_length(assignment_rows, 1) loop
      insert into public.table_session_seats (
        table_session_id,
        seat_index,
        initial_wind,
        event_guest_id
      )
      values (
        session_row.id,
        assignment_rows[assignment_index].seat_index,
        initial_winds[assignment_rows[assignment_index].seat_index + 1],
        assignment_rows[assignment_index].event_guest_id
      );
    end loop;

    return next session_row;
  end loop;

  update public.event_tournament_rounds
  set
    status = 'active',
    started_at = coalesce(started_at, bulk_started_at)
  where id = current_round.id
    and exists (
      select 1
      from public.table_sessions as started_session
      where started_session.event_id = target_event_id
        and started_session.tournament_round_id = current_round.id
        and started_session.status in ('active', 'paused')
    );

  return;
end;
$$;

grant execute on function public.start_current_tournament_round_sessions(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
```

- [ ] **Step 4: Run the migration test to verify it passes**

Run:

```bash
flutter test test/supabase/start_current_tournament_round_sessions_migration_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql test/supabase/start_current_tournament_round_sessions_migration_test.dart
git commit -m "feat: add bulk tournament table start rpc"
```

---

### Task 2: Session Repository Bulk Start Method

**Files:**
- Modify: `lib/data/repositories/repository_interfaces.dart`
- Modify: `lib/data/repositories/supabase_session_repository.dart`
- Modify: `test/helpers/repository_fakes.dart`
- Test: `test/data/repositories/supabase_session_repository_test.dart`

- [ ] **Step 1: Write the failing repository test**

Add this test inside `group('SupabaseSessionRepository', () { ... })` in `test/data/repositories/supabase_session_repository_test.dart`:

```dart
    test('starts current tournament round sessions and caches returned rows',
        () async {
      final cache = await LocalCache.create();
      final repository = SupabaseSessionRepository(
        client: SupabaseClient('https://example.com', 'publishable-key'),
        cache: cache,
        rpcListRunner: (functionName, params) async {
          expect(functionName, 'start_current_tournament_round_sessions');
          expect(params, {'target_event_id': 'evt_01'});
          return [
            _sessionJson(
              id: 'ses_01',
              tableId: 'tbl_01',
              startedAt: '2026-06-01T19:00:00Z',
            ),
            _sessionJson(
              id: 'ses_02',
              tableId: 'tbl_02',
              startedAt: '2026-06-01T19:00:00Z',
            ),
          ];
        },
      );

      final sessions =
          await repository.startCurrentTournamentRoundSessions('evt_01');
      final cached = await repository.readCachedSessions('evt_01');

      expect(sessions.map((session) => session.id), ['ses_01', 'ses_02']);
      expect(
        sessions.map((session) => session.startedAt.toUtc()).toSet(),
        {DateTime.parse('2026-06-01T19:00:00Z')},
      );
      expect(cached.map((session) => session.id), ['ses_01', 'ses_02']);
      expect(cached.first.scoringPhase, EventScoringPhase.tournament);
      expect(cached.first.tournamentRoundId, 'rnd_01');
      expect(cached.first.assignmentRound, 2);
    });
```

Add this helper near the other private helpers in the same file:

```dart
Map<String, dynamic> _sessionJson({
  required String id,
  required String tableId,
  required String startedAt,
}) {
  return {
    'id': id,
    'event_id': 'evt_01',
    'event_table_id': tableId,
    'session_number_for_table': 1,
    'ruleset_id': 'HK_STANDARD',
    'rotation_policy_type': 'dealer_cycle_return_to_initial_east',
    'rotation_policy_config_json': {},
    'status': 'active',
    'scoring_phase': 'tournament',
    'initial_east_seat_index': 0,
    'current_dealer_seat_index': 0,
    'dealer_pass_count': 0,
    'completed_games_count': 0,
    'hand_count': 0,
    'started_at': startedAt,
    'started_by_user_id': 'usr_01',
    'tournament_round_id': 'rnd_01',
    'assignment_round': 2,
  };
}
```

- [ ] **Step 2: Run the repository test to verify it fails**

Run:

```bash
flutter test test/data/repositories/supabase_session_repository_test.dart
```

Expected: FAIL with compile errors for missing `rpcListRunner` and missing `startCurrentTournamentRoundSessions`.

- [ ] **Step 3: Add the repository interface method and fake override**

In `lib/data/repositories/repository_interfaces.dart`, add this method after `startAssignedSession`:

```dart
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  );
```

In `test/helpers/repository_fakes.dart`, add this override to `ThrowingSessionRepository` after `startAssignedSession`:

```dart
  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) =>
      throw UnimplementedError();
```

- [ ] **Step 4: Implement the repository list RPC runner**

In `lib/data/repositories/supabase_session_repository.dart`, add this typedef after `SessionRpcSingleRunner`:

```dart
typedef SessionRpcListRunner = Future<List<Map<String, dynamic>>> Function(
  String functionName,
  Map<String, dynamic> params,
);
```

Update the constructor:

```dart
    SessionRpcSingleRunner? rpcSingleRunner,
    SessionRpcListRunner? rpcListRunner,
    SessionDetailLoader? sessionDetailLoader,
```

Update the initializer list:

```dart
        _rpcSingleRunner = rpcSingleRunner,
        _rpcListRunner = rpcListRunner,
```

Add the field after `_rpcSingleRunner`:

```dart
  final SessionRpcListRunner? _rpcListRunner;
```

Add the repository method after `startAssignedSession`:

```dart
  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    final rows = await _runRpcList(
      'start_current_tournament_round_sessions',
      {'target_event_id': eventId},
    );
    final startedSessions = rows
        .map((row) => TableSessionRecord.fromJson(row))
        .toList(growable: false);

    final currentSessions = await readCachedSessions(eventId);
    final startedIds = {
      for (final session in startedSessions) session.id,
    };
    final mergedSessions = [
      ...currentSessions.where(
        (session) => !startedIds.contains(session.id),
      ),
      ...startedSessions,
    ]..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    await cache.saveSessions(eventId, mergedSessions);

    return startedSessions;
  }
```

Add this private helper near `_runRpcSingle`:

```dart
  Future<List<Map<String, dynamic>>> _runRpcList(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final runner = _rpcListRunner;
    if (runner != null) {
      return runner(functionName, params);
    }

    final response = await client.rpc(functionName, params: params);
    if (response is List) {
      return response
          .map((row) => (row as Map).cast<String, dynamic>())
          .toList(growable: false);
    }

    throw StateError(
      'Expected a row list from $functionName but received ${response.runtimeType}.',
    );
  }
```

- [ ] **Step 5: Add overrides to local fake session repositories**

Search:

```bash
rg -n "class _FakeSessionRepository" test lib
```

For each test-local `_FakeSessionRepository extends ThrowingSessionRepository` that now fails to compile because it implements `SessionRepository`, add:

```dart
  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) {
    throw UnimplementedError();
  }
```

For fake repositories where `const _FakeSessionRepository` is used, keep the method non-mutating so the constructor can remain `const`.

- [ ] **Step 6: Run the repository test to verify it passes**

Run:

```bash
flutter test test/data/repositories/supabase_session_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/data/repositories/repository_interfaces.dart lib/data/repositories/supabase_session_repository.dart test/helpers/repository_fakes.dart test/data/repositories/supabase_session_repository_test.dart
git commit -m "feat: expose bulk tournament session start"
```

---

### Task 3: Seating Controller Bulk Start Behavior

**Files:**
- Modify: `lib/features/tables/controllers/seating_assignment_controller.dart`
- Test: `test/features/tables/controllers/seating_assignment_controller_test.dart`

- [ ] **Step 1: Write failing controller tests**

In `test/features/tables/controllers/seating_assignment_controller_test.dart`, update `_FakeSessionRepository`:

```dart
class _FakeSessionRepository extends ThrowingSessionRepository {
  _FakeSessionRepository({
    this.sessions = const [],
    this.sessionsAfterBulkStart = const [],
    this.bulkStartError,
  });

  final List<TableSessionRecord> sessions;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  final Object? bulkStartError;
  final calls = <String>[];
```

Replace its `listSessions` override:

```dart
  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async {
    calls.add('list:$eventId');
    return calls.contains('bulkStart:$eventId')
        ? sessionsAfterBulkStart
        : sessions;
  }
```

Add this override:

```dart
  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    calls.add('bulkStart:$eventId');
    final error = bulkStartError;
    if (error != null) {
      throw error;
    }
    return sessionsAfterBulkStart;
  }
```

Add these tests before the existing live-session blocking test:

```dart
  test('startAllTables bulk starts sessions and reloads seating state',
      () async {
    final seatingRepository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
    );
    final sessionRepository = _FakeSessionRepository(
      sessionsAfterBulkStart: [_session(SessionStatus.active)],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: sessionRepository,
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(sessionRepository.calls, [
      'list:evt_01',
      'bulkStart:evt_01',
      'list:evt_01',
    ]);
    expect(seatingRepository.calls, [
      'cache:evt_01',
      'load:evt_01',
      'load:evt_01',
    ]);
    expect(controller.hasLiveSessions, isTrue);
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, isNull);
  });

  test('startAllTables reports backend errors and keeps assignments',
      () async {
    final seatingRepository = _FakeSeatingRepository(
      loadedAssignments: [
        _assignment(displayName: 'Ava East'),
      ],
    );
    final controller = SeatingAssignmentController(
      seatingRepository: seatingRepository,
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(
        bulkStartError: Exception('No current tournament round seating'),
      ),
    );

    await controller.load('evt_01');
    await controller.startAllTables('evt_01');

    expect(controller.assignments.single.displayName, 'Ava East');
    expect(controller.isSubmitting, isFalse);
    expect(controller.error, contains('No current tournament round seating'));
  });

  test('canStartAllTables requires assignments and no live sessions', () async {
    final controller = SeatingAssignmentController(
      seatingRepository: _FakeSeatingRepository(
        loadedAssignments: [_assignment()],
      ),
      guestRepository: _FakeGuestRepository(),
      sessionRepository: _FakeSessionRepository(),
    );

    expect(controller.canStartAllTables, isFalse);

    await controller.load('evt_01');
    expect(controller.canStartAllTables, isTrue);

    controller.hasLiveSessions = true;
    expect(controller.canStartAllTables, isFalse);
  });
```

- [ ] **Step 2: Run the controller tests to verify they fail**

Run:

```bash
flutter test test/features/tables/controllers/seating_assignment_controller_test.dart
```

Expected: FAIL because `canStartAllTables` and `startAllTables` do not exist.

- [ ] **Step 3: Implement controller behavior**

In `lib/features/tables/controllers/seating_assignment_controller.dart`, add this getter after `canChangeSeating`:

```dart
  bool get canStartAllTables => assignments.isNotEmpty && !hasLiveSessions;
```

Add this method after `clear`:

```dart
  Future<void> startAllTables(String eventId) async {
    if (!canStartAllTables) {
      return;
    }

    isSubmitting = true;
    error = null;
    notifyListeners();

    try {
      await _sessionRepository.startCurrentTournamentRoundSessions(eventId);
      final loadedAssignments = _filterAssignments(
        await _seatingRepository.loadAssignments(eventId),
        bonusTableRoleFilter,
      );
      if (loadedAssignments.isNotEmpty || assignments.isEmpty) {
        assignments = loadedAssignments;
      }
      await _refreshLiveSessions(eventId);
      error = null;
    } catch (exception) {
      error = exception.toString();
    }

    isSubmitting = false;
    notifyListeners();
  }
```

- [ ] **Step 4: Run the controller tests to verify they pass**

Run:

```bash
flutter test test/features/tables/controllers/seating_assignment_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/features/tables/controllers/seating_assignment_controller.dart test/features/tables/controllers/seating_assignment_controller_test.dart
git commit -m "feat: add seating bulk start controller"
```

---

### Task 4: Seating Screen Start All Tables Button

**Files:**
- Modify: `lib/features/tables/screens/seating_assignment_screen.dart`
- Test: `test/features/tables/screens/seating_assignment_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

In `test/features/tables/screens/seating_assignment_screen_test.dart`, update `_FakeSessionRepository`:

```dart
class _FakeSessionRepository extends ThrowingSessionRepository {
  const _FakeSessionRepository({
    this.sessions = const [],
    this.sessionsAfterBulkStart = const [],
    this.bulkStartError,
  });

  final List<TableSessionRecord> sessions;
  final List<TableSessionRecord> sessionsAfterBulkStart;
  final Object? bulkStartError;
  static int bulkStartCallCount = 0;
```

Replace its `listSessions` override:

```dart
  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      bulkStartCallCount > 0 ? sessionsAfterBulkStart : sessions;
```

Add this override:

```dart
  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) async {
    bulkStartCallCount += 1;
    final error = bulkStartError;
    if (error != null) {
      throw error;
    }
    return sessionsAfterBulkStart;
  }
```

Add this reset at the top of `main()`:

```dart
  setUp(() {
    _FakeSessionRepository.bulkStartCallCount = 0;
  });
```

Add these widget tests after `displays seating by table and wind`:

```dart
  testWidgets('start all tables appears for tournament seating and starts bulk sessions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(displayName: 'Ava East', seatIndex: 0),
              _assignment(
                id: 'a2',
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            sessionsAfterBulkStart: [_session(SessionStatus.active)],
          ),
          minimumTableSize: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start All Tables'), findsOneWidget);

    await tester.tap(find.text('Start All Tables'));
    await tester.pumpAndSettle();

    expect(_FakeSessionRepository.bulkStartCallCount, 1);
    expect(find.text(seatingChangeBlockedMessage), findsOneWidget);
  });

  testWidgets('start all tables stays hidden without seating', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: const _FakeSessionRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start All Tables'), findsNothing);
  });

  testWidgets('start all tables shows inline error after backend rejection',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeatingAssignmentScreen(
          eventId: 'evt_01',
          seatingRepository: _FakeSeatingRepository(
            loadedAssignments: [
              _assignment(displayName: 'Ava East', seatIndex: 0),
              _assignment(
                id: 'a2',
                guestId: 'gst_02',
                displayName: 'Ben South',
                seatIndex: 1,
              ),
            ],
          ),
          guestRepository: _FakeGuestRepository(),
          sessionRepository: _FakeSessionRepository(
            bulkStartError: Exception('No current tournament round seating'),
          ),
          minimumTableSize: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start All Tables'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No current tournament round seating'),
        findsOneWidget);
    expect(find.text('Table 1'), findsOneWidget);
  });
```

- [ ] **Step 2: Run widget tests to verify they fail**

Run:

```bash
flutter test test/features/tables/screens/seating_assignment_screen_test.dart
```

Expected: FAIL because the button is not rendered.

- [ ] **Step 3: Add the screen action**

In `lib/features/tables/screens/seating_assignment_screen.dart`, add this method after `_enterTable`:

```dart
  Future<void> _startAllTables() async {
    await _controller.startAllTables(widget.eventId);
  }
```

In the `ListView` children, place this block after the live-session info panel and before the empty-state/table-card branch:

```dart
            if (hasAssignments && !_controller.hasLiveSessions) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _controller.isSubmitting ? null : _startAllTables,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(
                    _controller.isSubmitting
                        ? 'Starting Tables...'
                        : 'Start All Tables',
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
```

- [ ] **Step 4: Run widget tests to verify they pass**

Run:

```bash
flutter test test/features/tables/screens/seating_assignment_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

Run:

```bash
git add lib/features/tables/screens/seating_assignment_screen.dart test/features/tables/screens/seating_assignment_screen_test.dart
git commit -m "feat: add start all tables seating action"
```

---

### Task 5: Focused Verification

**Files:**
- Verify only; no planned file changes.

- [ ] **Step 1: Run focused tests**

Run:

```bash
flutter test test/supabase/start_current_tournament_round_sessions_migration_test.dart test/data/repositories/supabase_session_repository_test.dart test/features/tables/controllers/seating_assignment_controller_test.dart test/features/tables/screens/seating_assignment_screen_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run static analysis**

Run:

```bash
flutter analyze
```

Expected: PASS or only pre-existing warnings unrelated to the changed files.

- [ ] **Step 3: Inspect changed files**

Run:

```bash
git status --short
git diff --stat
git diff --check
```

Expected: changed files match this plan, and `git diff --check` reports no whitespace errors.

- [ ] **Step 4: Commit verification-only cleanup if needed**

If Step 2 or Step 3 requires formatting-only fixes, run:

```bash
dart format lib/data/repositories/repository_interfaces.dart lib/data/repositories/supabase_session_repository.dart lib/features/tables/controllers/seating_assignment_controller.dart lib/features/tables/screens/seating_assignment_screen.dart test/helpers/repository_fakes.dart test/data/repositories/supabase_session_repository_test.dart test/features/tables/controllers/seating_assignment_controller_test.dart test/features/tables/screens/seating_assignment_screen_test.dart test/supabase/start_current_tournament_round_sessions_migration_test.dart
git add lib/data/repositories/repository_interfaces.dart lib/data/repositories/supabase_session_repository.dart lib/features/tables/controllers/seating_assignment_controller.dart lib/features/tables/screens/seating_assignment_screen.dart test/helpers/repository_fakes.dart test/data/repositories/supabase_session_repository_test.dart test/features/tables/controllers/seating_assignment_controller_test.dart test/features/tables/screens/seating_assignment_screen_test.dart test/supabase/start_current_tournament_round_sessions_migration_test.dart supabase/migrations/20260601130000_start_current_tournament_round_sessions.sql
git commit -m "chore: format bulk table start changes"
```

Expected: a commit is created only when formatting or small verification cleanup changed files.

---

## Self-Review Notes

- Spec coverage: Task 1 covers synchronized backend start, validation, duplicate avoidance, and round activation. Task 2 covers repository method and cache refresh. Task 3 covers controller state and errors. Task 4 covers the app-only UI button and keeps per-table entry. Task 5 covers focused verification.
- Public website scope: no `web/` files are created or modified.
- TDD order: every implementation task starts with a failing test and an explicit expected failure before code changes.
