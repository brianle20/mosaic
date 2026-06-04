# Check-In Play Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace player-tag-driven check-in with explicit open-play and qualifying check-in choices, while removing player tag requirements from tournament seating eligibility.

**Architecture:** Keep existing guest attendance and tournament status models. Add a roster controller check-in method that accepts the desired play mode, update the roster UI to call it from two explicit actions, and leave optional NFC tag lookup infrastructure intact. Remove player tag joins from app-side eligible-player filtering and from the latest `generate_tournament_round` SQL via a forward migration.

**Tech Stack:** Flutter/Dart, `flutter_test`, Supabase PostgreSQL migrations, existing repository fakes in `test/helpers/repository_fakes.dart`.

---

## File Map

- Modify `lib/features/guests/controllers/guest_roster_controller.dart`: replace tag-promoting check-in behavior with explicit play-mode check-in.
- Modify `test/features/guests/controllers/guest_roster_controller_test.dart`: add controller tests for open-play and qualifying check-in.
- Modify `lib/features/guests/screens/guest_roster_screen.dart`: replace primary `Assign Tag` check-in actions and tag-centric summaries with play-mode actions/copy.
- Modify `test/features/guests/screens/guest_roster_screen_test.dart`: update roster widget expectations and add NFC-free check-in coverage.
- Modify `lib/features/tables/controllers/seating_assignment_controller.dart`: compute eligible tournament players from attendance and tournament status, not active player tags.
- Modify `test/features/tables/controllers/seating_assignment_controller_test.dart`: update eligibility tests so untagged qualified checked-in players remain eligible.
- Create `supabase/migrations/20260604130000_remove_player_tag_seating_requirement.sql`: redefine `public.generate_tournament_round` without player tag joins.
- Create `test/supabase/check_in_play_mode_migration_test.dart`: assert the latest `generate_tournament_round` definition no longer requires player tags.
- Modify `test/supabase/tournament_round_orchestration_migration_test.dart`: remove or update old assertion that expects "tagged players" in the historical orchestration migration.

---

### Task 1: Controller Play-Mode Check-In

**Files:**
- Modify: `test/features/guests/controllers/guest_roster_controller_test.dart`
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`

- [ ] **Step 1: Write failing controller tests**

Add these tests before the closing `}` of `main()` in `test/features/guests/controllers/guest_roster_controller_test.dart`:

```dart
  test('checkInForPlayMode checks in an open-play guest without tags',
      () async {
    final repository = _FakeGuestRepository([
      _guest(id: 'gst_01', name: 'Alice Wong'),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    await controller.checkInForPlayMode(
      guestId: 'gst_01',
      status: EventTournamentStatus.openPlayOnly,
    );

    expect(repository.checkInCalls, 1);
    expect(repository.statusUpdates['gst_01'], EventTournamentStatus.openPlayOnly);
    expect(repository.assignTagCalls, 0);
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.openPlayOnly,
    );
  });

  test('checkInForPlayMode checks in a qualifying guest without tags',
      () async {
    final repository = _FakeGuestRepository([
      _guest(id: 'gst_01', name: 'Alice Wong'),
    ]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('event-1');
    await controller.checkInForPlayMode(
      guestId: 'gst_01',
      status: EventTournamentStatus.qualifying,
    );

    expect(repository.checkInCalls, 1);
    expect(repository.statusUpdates['gst_01'], EventTournamentStatus.qualifying);
    expect(repository.assignTagCalls, 0);
    expect(controller.guests.single.isCheckedIn, isTrue);
    expect(
      controller.guests.single.tournamentStatus,
      EventTournamentStatus.qualifying,
    );
  });
```

Update `_FakeGuestRepository` in the same file so these tests can pass. Add this field:

```dart
  final statusUpdates = <String, EventTournamentStatus>{};
```

Replace `checkInGuest` with:

```dart
  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    checkInCalls += 1;
    final guest = _guests.firstWhere((entry) => entry.id == guestId);
    final updated = EventGuestRecord(
      id: guest.id,
      eventId: guest.eventId,
      guestProfileId: guest.guestProfileId,
      displayName: guest.displayName,
      normalizedName: guest.normalizedName,
      publicDisplayName: guest.publicDisplayName,
      phoneE164: guest.phoneE164,
      emailLower: guest.emailLower,
      instagramHandle: guest.instagramHandle,
      attendanceStatus: AttendanceStatus.checkedIn,
      tournamentStatus: guest.tournamentStatus,
      coverStatus: guest.coverStatus,
      coverAmountCents: guest.coverAmountCents,
      isComped: guest.isComped,
      hasScoredPlay: guest.hasScoredPlay,
      note: guest.note,
      checkedInAt: DateTime.parse('2026-06-04T12:00:00-07:00'),
      rowVersion: guest.rowVersion,
    );
    final index = _guests.indexWhere((entry) => entry.id == guestId);
    _guests[index] = updated;
    return GuestDetailRecord(guest: updated);
  }
```

Replace `updateEventGuestTournamentStatus` with:

```dart
  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) async {
    tournamentMutationCalls += 1;
    statusUpdates[eventGuestId] = status;
    final guest = _guests.firstWhere((entry) => entry.id == eventGuestId);
    final updated = EventGuestRecord(
      id: guest.id,
      eventId: guest.eventId,
      guestProfileId: guest.guestProfileId,
      displayName: guest.displayName,
      normalizedName: guest.normalizedName,
      publicDisplayName: guest.publicDisplayName,
      phoneE164: guest.phoneE164,
      emailLower: guest.emailLower,
      instagramHandle: guest.instagramHandle,
      attendanceStatus: guest.attendanceStatus,
      tournamentStatus: status,
      coverStatus: guest.coverStatus,
      coverAmountCents: guest.coverAmountCents,
      isComped: guest.isComped,
      hasScoredPlay: guest.hasScoredPlay,
      note: guest.note,
      checkedInAt: guest.checkedInAt,
      rowVersion: guest.rowVersion,
    );
    final index = _guests.indexWhere((entry) => entry.id == eventGuestId);
    _guests[index] = updated;
    return updated;
  }
```

- [ ] **Step 2: Run controller tests and verify failure**

Run:

```bash
flutter test test/features/guests/controllers/guest_roster_controller_test.dart
```

Expected: FAIL because `GuestRosterController.checkInForPlayMode` does not exist.

- [ ] **Step 3: Implement controller method**

In `lib/features/guests/controllers/guest_roster_controller.dart`, replace the existing `checkIn` method with:

```dart
  Future<bool> checkIn(String guestId) {
    return checkInForPlayMode(
      guestId: guestId,
      status: _guestById(guestId).tournamentStatus,
    );
  }

  Future<bool> checkInForPlayMode({
    required String guestId,
    required EventTournamentStatus status,
  }) async {
    await _runGuestAction(guestId, () async {
      final checkedInDetail = await _guestRepository.checkInGuest(guestId);
      _mergeGuest(checkedInDetail.guest);
      _mergeAssignment(guestId, checkedInDetail.activeTagAssignment);

      final updated = await _guestRepository.updateEventGuestTournamentStatus(
        eventGuestId: guestId,
        status: status,
      );
      _mergeGuest(updated);
    });
    return true;
  }
```

Then remove the automatic open-play-to-qualifying promotion from `assignTag`. Delete this block:

```dart
      if (guest.tournamentStatus == EventTournamentStatus.openPlayOnly) {
        final updated = await _guestRepository.updateEventGuestTournamentStatus(
          eventGuestId: guestId,
          status: EventTournamentStatus.qualifying,
        );
        _mergeGuest(updated);
      }
```

Leave `assignTag` itself available for optional/legacy tag assignment.

- [ ] **Step 4: Run controller tests and verify pass**

Run:

```bash
flutter test test/features/guests/controllers/guest_roster_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit controller slice**

```bash
git add lib/features/guests/controllers/guest_roster_controller.dart test/features/guests/controllers/guest_roster_controller_test.dart
git commit -m "Update guest check-in controller for play modes"
```

---

### Task 2: Roster Play-Mode Actions and Copy

**Files:**
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`

- [ ] **Step 1: Write/update failing roster widget tests**

In `test/features/guests/screens/guest_roster_screen_test.dart`, update `renders an intentional empty state when no guests exist` to expect:

```dart
    expect(
      find.text('Add guests to start check-in and live seating.'),
      findsOneWidget,
    );
```

In `renders guests and row-specific quick actions`, replace the action/copy expectations around check-in/tagging with:

```dart
    expect(find.text('Check In: Open Play'), findsOneWidget);
    expect(find.text('Check In: Qualifying'), findsOneWidget);
    expect(find.text('Check In'), findsNothing);
    expect(find.text('Check In & Tag'), findsNothing);
    expect(find.text('Assign Tag'), findsNothing);
    expect(find.text('Add Cover Entry'), findsOneWidget);
    expect(find.text('Open Play Only'), findsAtLeastNWidgets(1));
    expect(find.text('Mark Qualifying', skipOffstage: false), findsOneWidget);
    expect(find.text('Mark Qualified'), findsNothing);
    expect(find.text('Withdraw'), findsNothing);
    expect(find.text('Tag Assigned'), findsNothing);
    expect(
      find.text('Ready for qualifying play', skipOffstage: false),
      findsOneWidget,
    );
```

In the same test, make `gst_tag` a qualifying checked-in guest so the summary expectation covers qualifying-without-tag:

```dart
        _guest(
          id: 'gst_tag',
          name: 'Tao',
          attendanceStatus: AttendanceStatus.checkedIn,
          coverStatus: CoverStatus.paid,
          tournamentStatus: EventTournamentStatus.qualifying,
        ),
```

In the same test, replace the summary lookup:

```dart
    final summaryRect = tester.getRect(find.text('Needs payment or comp'));
```

Replace the existing `checks in open-play-only guests without scanning a tag` and `eligible expected guests can check in without scanning a tag` tests with:

```dart
  testWidgets('open-play check-in does not scan NFC and keeps open play',
      (tester) async {
    final nfcService = _CountingNfcService();
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.paid,
      ),
    ]);

    await tester.pumpWidget(
      _buildRosterApp(
        guestRepository: repository,
        nfcService: nfcService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In: Open Play'));
    await tester.pumpAndSettle();

    expect(nfcService.assignmentScanCount, 0);
    expect(
      repository.statusUpdates['gst_01'],
      EventTournamentStatus.openPlayOnly,
    );
    expect(find.text('Checked in for open play'), findsOneWidget);
    expect(find.text('Assign Tag'), findsNothing);
    expect(
      find.text('Alice Wong is checked in for open play.'),
      findsOneWidget,
    );
  });

  testWidgets('qualifying check-in does not scan NFC and marks qualifying',
      (tester) async {
    final nfcService = _CountingNfcService();
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.paid,
      ),
    ]);

    await tester.pumpWidget(
      _buildRosterApp(
        guestRepository: repository,
        nfcService: nfcService,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In: Qualifying'));
    await tester.pumpAndSettle();

    expect(nfcService.assignmentScanCount, 0);
    expect(
      repository.statusUpdates['gst_01'],
      EventTournamentStatus.qualifying,
    );
    expect(find.text('Ready for qualifying play'), findsOneWidget);
    expect(find.text('Assign Tag'), findsNothing);
    expect(find.text('Alice Wong is checked in for qualifying.'), findsOneWidget);
  });
```

Replace `open-play-only guests need a tag before qualification actions` with:

```dart
  testWidgets('open-play-only checked-in guests can mark qualifying without a tag',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.checkedIn,
        coverStatus: CoverStatus.paid,
      ),
    ]);

    await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Assign Tag'), findsNothing);
    expect(find.text('Mark Qualifying'), findsOneWidget);

    await tester.tap(find.text('Mark Qualifying'));
    await tester.pumpAndSettle();

    expect(
      repository.statusUpdates['gst_01'],
      EventTournamentStatus.qualifying,
    );
  });
```

Delete the widget test named `assigning a tag promotes open-play-only guests to qualifying`. Keep the tests that cover optional tag identification/assignment if they still call controller methods directly or are moved out of primary roster actions.

- [ ] **Step 2: Run roster widget tests and verify failure**

Run:

```bash
flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because the UI still renders `Check In` / `Assign Tag` and tag-centric summaries.

- [ ] **Step 3: Implement roster UI changes**

In `lib/features/guests/screens/guest_roster_screen.dart`, replace `_checkInGuest` with:

```dart
  Future<void> _checkInGuest(
    EventGuestRecord guest,
    EventTournamentStatus status,
  ) async {
    if (!widget.canCheckIn) {
      return;
    }
    final isQualifying = status == EventTournamentStatus.qualifying;
    await _runQuickAction(
      () => _controller.checkInForPlayMode(
        guestId: guest.id,
        status: status,
      ),
      successMessage: isQualifying
          ? '${guest.displayName} is checked in for qualifying.'
          : '${guest.displayName} is checked in for open play.',
    );
  }
```

Keep `_assignTag` available, but stop calling it from the primary roster row.

In the empty state copy, replace:

```dart
'Add guests to start check-in, tag assignment, and live seating.'
```

with:

```dart
'Add guests to start check-in and live seating.'
```

Replace `_primaryActionForGuest` with:

```dart
  Widget? _primaryActionForGuest(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);

    if (!guest.isCheckedIn) {
      return null;
    }

    if (!widget.canManageTournamentStatus) {
      return null;
    }

    return switch (guest.tournamentStatus) {
      EventTournamentStatus.openPlayOnly => FilledButton(
          onPressed: isSubmitting
              ? null
              : () => _updateTournamentStatus(
                    guest,
                    EventTournamentStatus.qualifying,
                  ),
          child: const Text('Mark Qualifying'),
        ),
      EventTournamentStatus.qualifying => FilledButton(
          onPressed: isSubmitting
              ? null
              : () => _updateTournamentStatus(
                    guest,
                    EventTournamentStatus.qualified,
                  ),
          child: const Text('Mark Qualified'),
        ),
      EventTournamentStatus.qualified => null,
      EventTournamentStatus.withdrawn => null,
    };
  }
```

In `_overflowActionsForGuest`, remove `hasTag` and allow status actions without tags. Replace the `switch` with:

```dart
    switch (guest.tournamentStatus) {
      case EventTournamentStatus.openPlayOnly:
        actions.addAll(const [
          _GuestRosterOverflowAction.markQualified,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.qualifying:
        actions.addAll(const [
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.qualified:
        actions.addAll(const [
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
          _GuestRosterOverflowAction.withdraw,
        ]);
      case EventTournamentStatus.withdrawn:
        actions.addAll(const [
          _GuestRosterOverflowAction.markQualifying,
          _GuestRosterOverflowAction.markQualified,
          _GuestRosterOverflowAction.moveToOpenPlayOnly,
        ]);
    }
```

Replace the `!guest.isCheckedIn` branch in `_buildQuickActionsForGuest` with:

```dart
    if (!guest.isCheckedIn) {
      if (!widget.canCheckIn) {
        return const SizedBox.shrink();
      }
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting
                  ? null
                  : () => _checkInGuest(
                        guest,
                        EventTournamentStatus.openPlayOnly,
                      ),
              child: _singleLineButtonLabel('Check In: Open Play'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting
                  ? null
                  : () => _checkInGuest(
                        guest,
                        EventTournamentStatus.qualifying,
                      ),
              child: _singleLineButtonLabel('Check In: Qualifying'),
            ),
          ),
        ],
      );
    }
```

Update `_rowSummary` to remove tag-gated status:

```dart
  String _rowSummary(EventGuestRecord guest) {
    if (!guest.isEligibleForPlayerTagAssignment) {
      return 'Needs payment or comp';
    }
    if (!guest.isCheckedIn) {
      return 'Ready for check-in';
    }
    return switch (guest.tournamentStatus) {
      EventTournamentStatus.openPlayOnly => 'Checked in for open play',
      EventTournamentStatus.qualifying => 'Ready for qualifying play',
      EventTournamentStatus.qualified => 'Qualified for tournament play',
      EventTournamentStatus.withdrawn => 'Withdrawn from tournament play',
    };
  }
```

After this, run `rg -n "_tagSummary\\(" lib/features/guests/screens/guest_roster_screen.dart`. If the only remaining match is the function declaration, delete `_tagSummary`.

- [ ] **Step 4: Run roster widget tests and verify pass**

Run:

```bash
flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit roster UI slice**

```bash
git add lib/features/guests/screens/guest_roster_screen.dart test/features/guests/screens/guest_roster_screen_test.dart
git commit -m "Replace roster tag check-in with play modes"
```

---

### Task 3: App-Side Seating Eligibility Without Player Tags

**Files:**
- Modify: `test/features/tables/controllers/seating_assignment_controller_test.dart`
- Modify: `lib/features/tables/controllers/seating_assignment_controller.dart`

- [ ] **Step 1: Update failing seating controller test**

In `test/features/tables/controllers/seating_assignment_controller_test.dart`, rename the test:

```dart
  test('eligible tournament players are qualified checked-in guests', () async {
```

In that test, keep the untagged guest in the expected eligible list:

```dart
    expect(
      controller.eligibleGuests.map((guest) => guest.displayName),
      ['No Active Tag', 'Qualified Player'],
    );
```

The alphabetical order is expected because `No Active Tag` sorts before `Qualified Player`.

- [ ] **Step 2: Run seating controller test and verify failure**

Run:

```bash
flutter test test/features/tables/controllers/seating_assignment_controller_test.dart
```

Expected: FAIL because `_loadEligibleGuests` still requires an active player tag assignment.

- [ ] **Step 3: Remove tag requirements from app eligibility**

In `lib/features/tables/controllers/seating_assignment_controller.dart`, remove this import:

```dart
import 'package:mosaic/data/models/tag_models.dart';
```

Replace `_loadEligibleGuests` with:

```dart
  Future<List<EventGuestRecord>> _loadEligibleGuests(String eventId) async {
    final guests = await _guestRepository.listGuests(eventId);

    return guests.where((guest) {
      return guest.isCheckedIn &&
          guest.tournamentStatus == EventTournamentStatus.qualified;
    }).toList(growable: false)
      ..sort((left, right) => left.displayName.compareTo(right.displayName));
  }
```

- [ ] **Step 4: Run seating controller test and verify pass**

Run:

```bash
flutter test test/features/tables/controllers/seating_assignment_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit app eligibility slice**

```bash
git add lib/features/tables/controllers/seating_assignment_controller.dart test/features/tables/controllers/seating_assignment_controller_test.dart
git commit -m "Remove player tag gate from seating eligibility"
```

---

### Task 4: Backend Tournament Seating Without Player Tags

**Files:**
- Create: `test/supabase/check_in_play_mode_migration_test.dart`
- Create: `supabase/migrations/20260604130000_remove_player_tag_seating_requirement.sql`
- Modify: `test/supabase/tournament_round_orchestration_migration_test.dart`

- [ ] **Step 1: Write failing migration test**

Create `test/supabase/check_in_play_mode_migration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migrationsSql;

  setUpAll(() {
    migrationsSql = _readAllMigrationSql();
  });

  test('latest tournament seating generation does not require player tags', () {
    final generateRoundSql = _extractLatestFunction(
      migrationsSql,
      'public.generate_tournament_round',
    );

    expect(generateRoundSql, contains('create or replace function public.generate_tournament_round'));
    expect(generateRoundSql, contains('guest.tournament_status = \'qualified\''));
    expect(generateRoundSql, contains('guest.attendance_status = \'checked_in\''));
    expect(
      generateRoundSql,
      contains('At least 2 qualified, checked-in players are required.'),
    );
    expect(generateRoundSql, isNot(contains('event_guest_tag_assignments')));
    expect(generateRoundSql, isNot(contains('tag_assignment')));
    expect(generateRoundSql, isNot(contains("tag.default_tag_type = 'player'")));
    expect(generateRoundSql, isNot(contains("tag.status = 'active'")));
    expect(generateRoundSql, isNot(contains('tagged players')));
  });
}

String _readAllMigrationSql() {
  final migrationFiles = Directory('supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  return migrationFiles
      .map((file) => '-- ${file.path}\n${file.readAsStringSync()}')
      .join('\n\n');
}

String _extractLatestFunction(String sql, String functionName) {
  final escapedName = RegExp.escape(functionName);
  final matches = RegExp(
    'create or replace function $escapedName[\\s\\S]*?\\n\\\$\\\$;',
    caseSensitive: false,
  ).allMatches(sql).toList();

  return matches.isEmpty ? '' : matches.last.group(0)!;
}
```

In `test/supabase/tournament_round_orchestration_migration_test.dart`, update the old text assertion so it no longer requires "tagged":

```dart
    expect(
      sql,
      contains(
        'At least 2 qualified, checked-in, tagged players are required.',
      ),
    );
```

becomes:

```dart
    expect(sql, contains('generate_tournament_round'));
```

This keeps the historical migration smoke test broad while the new test owns the latest behavior.

- [ ] **Step 2: Run migration tests and verify failure**

Run:

```bash
flutter test test/supabase/check_in_play_mode_migration_test.dart test/supabase/tournament_round_orchestration_migration_test.dart
```

Expected: FAIL because the latest `generate_tournament_round` definition still joins `event_guest_tag_assignments`.

- [ ] **Step 3: Add forward migration**

Create `supabase/migrations/20260604130000_remove_player_tag_seating_requirement.sql` by copying the full contents of `supabase/migrations/20260526090000_balanced_tournament_round_seating.sql`, then make exactly these replacements in the copied file.

Replace the first eligible-player CTE:

```sql
  with eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  )
```

with:

```sql
  with eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  )
```

Replace the error:

```sql
    raise exception 'At least 2 qualified, checked-in, tagged players are required.'
```

with:

```sql
    raise exception 'At least 2 qualified, checked-in players are required.'
```

Replace the second eligible-player CTE:

```sql
  eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    join public.event_guest_tag_assignments as tag_assignment
      on tag_assignment.event_guest_id = guest.id
      and tag_assignment.event_id = guest.event_id
      and tag_assignment.status = 'assigned'
    join public.nfc_tags as tag
      on tag.id = tag_assignment.nfc_tag_id
      and tag.default_tag_type = 'player'
      and tag.status = 'active'
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  ),
```

with:

```sql
  eligible_players as (
    select distinct guest.id as event_guest_id
    from public.event_guests as guest
    where guest.event_id = target_event_id
      and guest.tournament_status = 'qualified'
      and guest.attendance_status = 'checked_in'
  ),
```

Keep these lines at the bottom of the copied migration:

```sql
grant execute on function public.generate_tournament_round(uuid)
  to authenticated;

select pg_notify('pgrst', 'reload schema');
```

- [ ] **Step 4: Run migration tests and verify pass**

Run:

```bash
flutter test test/supabase/check_in_play_mode_migration_test.dart test/supabase/tournament_round_orchestration_migration_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit backend eligibility slice**

```bash
git add supabase/migrations/20260604130000_remove_player_tag_seating_requirement.sql test/supabase/check_in_play_mode_migration_test.dart test/supabase/tournament_round_orchestration_migration_test.dart
git commit -m "Remove player tag gate from tournament seating SQL"
```

---

### Task 5: Full Verification

**Files:**
- Verify all files touched by Tasks 1-4.

- [ ] **Step 1: Run focused Flutter and migration tests**

Run:

```bash
flutter test \
  test/features/guests/controllers/guest_roster_controller_test.dart \
  test/features/guests/screens/guest_roster_screen_test.dart \
  test/features/tables/controllers/seating_assignment_controller_test.dart \
  test/supabase/check_in_play_mode_migration_test.dart \
  test/supabase/tournament_round_orchestration_migration_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: PASS with no new analyzer errors. If it reports unused `_assignTag` or `_tagSummary`, remove the unused method/import and rerun.

- [ ] **Step 3: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS. If unrelated tests fail, capture the failing test names and error text before deciding whether they are in scope.

- [ ] **Step 4: Final commit for verification-only cleanup**

If Step 2 or Step 3 required analyzer/test cleanup, commit it:

```bash
git add lib test supabase
git commit -m "Finish check-in play mode cleanup"
```

If no cleanup was needed, do not create an empty commit.
