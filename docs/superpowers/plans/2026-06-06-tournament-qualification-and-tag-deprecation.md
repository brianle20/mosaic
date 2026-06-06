# Tournament Qualification and Player Tag Deprecation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add guest-level tournament qualification intent, render check-in from that intent, add bulk qualification for considered guests, and hide player tag workflows from active guest operations.

**Architecture:** Reuse `EventTournamentStatus` as the persisted state and add guest-management labels around it. Keep player tag repository/model/database code for historical safety, but remove tag-driven controls from roster and guest detail screens. Implement the behavior in small test-first slices: model inputs, form UI, repository persistence, roster check-in/bulk actions, and guest detail cleanup.

**Tech Stack:** Flutter, Dart, Supabase repository layer, `flutter_test`, existing fake repositories, existing `StatusChip` and guest screen patterns.

---

## File Structure

- Modify `lib/data/models/guest_models.dart`
  - Add `tournamentStatus` to `CreateGuestInput` and `UpdateGuestInput`.
  - Serialize selected tournament status in `toInsertJson()` and `toUpdateJson()`.
- Modify `lib/features/guests/models/guest_form_draft.dart`
  - Carry selected `EventTournamentStatus`.
  - Default new guests to `EventTournamentStatus.qualified`.
  - Pass status into create/update inputs.
- Modify `lib/features/guests/screens/guest_form_screen.dart`
  - Initialize status from `initialGuest`.
  - Add a `Tournament Qualification` segmented control.
  - Save status through `GuestFormDraft`.
- Modify `lib/data/repositories/supabase_guest_repository.dart`
  - Stop overriding create status to `open_play_only`.
  - Let update save selected tournament status with the guest row.
- Modify `lib/features/guests/controllers/guest_roster_controller.dart`
  - Add bulk qualification for checked-in considered guests.
  - Keep existing tag methods available but no longer used by active UI.
- Modify `lib/features/guests/screens/guest_roster_screen.dart`
  - Hide `Scan Player Tag`.
  - Replace two-choice check-in with one status-derived button.
  - Rename guest-management labels to `Prequalified`, `Considered`, and `Not Playing Tournament`.
  - Remove primary `Mark Qualified` / `Mark Qualifying` progression.
  - Add host-only `Qualify Checked-In Considered` bulk action.
- Modify `lib/features/checkin/controllers/guest_check_in_controller.dart`
  - Remove tag-driven promotion behavior from active check-in methods.
  - Make guest detail check-in preserve the guest's saved tournament status.
- Modify `lib/features/checkin/screens/guest_detail_screen.dart`
  - Hide player tag cards/prompts/actions.
  - Render status-derived check-in labels.
- Modify tests:
  - `test/data/models/guest_models_tournament_test.dart`
  - `test/features/guests/models/guest_form_draft_test.dart`
  - `test/data/repositories/supabase_guest_repository_tournament_test.dart`
  - `test/features/guests/screens/guest_form_screen_test.dart`
  - `test/features/guests/controllers/guest_roster_controller_test.dart`
  - `test/features/guests/screens/guest_roster_screen_test.dart`
  - `test/features/checkin/screens/guest_detail_screen_test.dart`

## Task 1: Persist Tournament Qualification on Guest Inputs

**Files:**
- Modify: `lib/data/models/guest_models.dart`
- Test: `test/data/models/guest_models_tournament_test.dart`
- Test: `test/features/guests/models/guest_form_draft_test.dart`

- [ ] **Step 1: Add failing model tests**

Add these tests inside `group('EventTournamentStatus', ...)` in `test/data/models/guest_models_tournament_test.dart`:

```dart
test('create input serializes selected tournament status', () {
  final input = CreateGuestInput(
    eventId: 'evt_01',
    displayName: 'Alice Wong',
    normalizedName: 'alice wong',
    tournamentStatus: EventTournamentStatus.qualified,
    coverStatus: CoverStatus.paid,
    coverAmountCents: 2000,
    isComped: false,
  );

  expect(input.toInsertJson()['tournament_status'], 'qualified');
});

test('update input serializes selected tournament status', () {
  final input = UpdateGuestInput(
    id: 'gst_01',
    eventId: 'evt_01',
    displayName: 'Alice Wong',
    normalizedName: 'alice wong',
    tournamentStatus: EventTournamentStatus.qualifying,
    coverStatus: CoverStatus.paid,
    coverAmountCents: 2000,
    isComped: false,
  );

  expect(input.toUpdateJson()['tournament_status'], 'qualifying');
});
```

Add this test in `test/features/guests/models/guest_form_draft_test.dart`:

```dart
test('defaults tournament qualification to prequalified', () {
  const draft = GuestFormDraft(displayName: 'Alice Wong');

  expect(draft.tournamentStatus, EventTournamentStatus.qualified);
  expect(
    draft.toCreateInput(eventId: 'evt_01').tournamentStatus,
    EventTournamentStatus.qualified,
  );
});
```

- [ ] **Step 2: Run failing tests**

Run:

```bash
flutter test test/data/models/guest_models_tournament_test.dart test/features/guests/models/guest_form_draft_test.dart
```

Expected: FAIL because `CreateGuestInput`, `UpdateGuestInput`, and `GuestFormDraft` do not expose `tournamentStatus` yet.

- [ ] **Step 3: Implement guest input status fields**

In `lib/data/models/guest_models.dart`, update `CreateGuestInput`:

```dart
class CreateGuestInput {
  const CreateGuestInput({
    required this.eventId,
    required this.displayName,
    required this.normalizedName,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    this.tournamentStatus = EventTournamentStatus.qualified,
    this.publicDisplayName,
    this.phoneE164,
    this.emailLower,
    this.instagramHandle,
    this.guestProfileId,
    this.note,
  });

  final String eventId;
  final String displayName;
  final String normalizedName;
  final EventTournamentStatus tournamentStatus;
  final String? publicDisplayName;
  final String? guestProfileId;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final String? note;
```

In `CreateGuestInput.toInsertJson`, replace the hard-coded `openPlayOnly` value:

```dart
'tournament_status': _eventTournamentStatusToJson(tournamentStatus),
```

In the same file, update `UpdateGuestInput`:

```dart
class UpdateGuestInput {
  const UpdateGuestInput({
    required this.id,
    required this.eventId,
    required this.displayName,
    required this.normalizedName,
    required this.coverStatus,
    required this.coverAmountCents,
    required this.isComped,
    this.tournamentStatus,
    this.publicDisplayName,
    this.phoneE164,
    this.emailLower,
    this.instagramHandle,
    this.note,
  });

  final String id;
  final String eventId;
  final String displayName;
  final String normalizedName;
  final EventTournamentStatus? tournamentStatus;
  final String? publicDisplayName;
  final String? phoneE164;
  final String? emailLower;
  final String? instagramHandle;
  final CoverStatus coverStatus;
  final int coverAmountCents;
  final bool isComped;
  final String? note;
```

In `UpdateGuestInput.toUpdateJson`, include the selected status when present:

```dart
if (tournamentStatus != null)
  'tournament_status': _eventTournamentStatusToJson(tournamentStatus!),
```

- [ ] **Step 4: Implement draft status field**

In `lib/features/guests/models/guest_form_draft.dart`, add the field to the constructor and class:

```dart
const GuestFormDraft({
  required this.displayName,
  this.publicDisplayName,
  this.isPublicDisplayNameManuallyEdited = false,
  this.phoneE164 = '',
  this.email = '',
  this.instagramHandle = '',
  this.note = '',
  this.coverAmountCents = 0,
  this.coverStatus = CoverStatus.unpaid,
  this.tournamentStatus = EventTournamentStatus.qualified,
});

final EventTournamentStatus tournamentStatus;
```

Preserve the field in `withDisplayName` and `withPublicDisplayName`:

```dart
tournamentStatus: tournamentStatus,
```

Pass it through `toCreateInput`:

```dart
tournamentStatus: tournamentStatus,
```

Pass it through `toUpdateInput`:

```dart
tournamentStatus: tournamentStatus,
```

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/data/models/guest_models_tournament_test.dart test/features/guests/models/guest_form_draft_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/data/models/guest_models.dart lib/features/guests/models/guest_form_draft.dart test/data/models/guest_models_tournament_test.dart test/features/guests/models/guest_form_draft_test.dart
git commit -m "Add guest tournament qualification inputs"
```

## Task 2: Add Tournament Qualification to Guest Form

**Files:**
- Modify: `lib/features/guests/screens/guest_form_screen.dart`
- Modify: `test/features/guests/screens/guest_form_screen_test.dart`

- [ ] **Step 1: Add failing form tests**

In `test/features/guests/screens/guest_form_screen_test.dart`, update `_RecordingGuestRepository.createGuest` and `updateGuest` returned JSON to include the input status:

```dart
'tournament_status': eventTournamentStatusToJson(input.tournamentStatus),
```

For `UpdateGuestInput`, use:

```dart
'tournament_status': eventTournamentStatusToJson(
  input.tournamentStatus ?? EventTournamentStatus.openPlayOnly,
),
```

Add these widget tests:

```dart
testWidgets('defaults new guests to prequalified tournament status',
    (tester) async {
  final repository = _RecordingGuestRepository();

  await tester.pumpWidget(
    MaterialApp(
      home: GuestFormScreen(
        eventId: 'evt_01',
        existingGuests: const [],
        guestRepository: repository,
        onSaved: (_) {},
      ),
    ),
  );

  expect(find.text('Tournament Qualification'), findsOneWidget);
  expect(find.text('Prequalified'), findsOneWidget);
  expect(find.text('Considered'), findsOneWidget);
  expect(find.text('Not Playing Tournament'), findsOneWidget);

  await tester.enterText(find.byKey(guestNameFieldKey), 'Alice Wong');
  await tester.ensureVisible(find.text('Save Guest'));
  await tester.tap(find.text('Save Guest'));
  await tester.pumpAndSettle();

  expect(repository.created!.tournamentStatus, EventTournamentStatus.qualified);
});

testWidgets('saves considered tournament status for new guests',
    (tester) async {
  final repository = _RecordingGuestRepository();

  await tester.pumpWidget(
    MaterialApp(
      home: GuestFormScreen(
        eventId: 'evt_01',
        existingGuests: const [],
        guestRepository: repository,
        onSaved: (_) {},
      ),
    ),
  );

  await tester.enterText(find.byKey(guestNameFieldKey), 'Alice Wong');
  await tester.tap(find.text('Considered'));
  await tester.ensureVisible(find.text('Save Guest'));
  await tester.tap(find.text('Save Guest'));
  await tester.pumpAndSettle();

  expect(repository.created!.tournamentStatus, EventTournamentStatus.qualifying);
});

testWidgets('editing a guest preserves tournament qualification',
    (tester) async {
  final repository = _RecordingGuestRepository();

  await tester.pumpWidget(
    MaterialApp(
      home: GuestFormScreen(
        eventId: 'evt_01',
        existingGuests: const [],
        guestRepository: repository,
        initialGuest: _guestRecord(
          id: 'gst_01',
          name: 'Alice Wong',
          tournamentStatus: EventTournamentStatus.openPlayOnly,
        ),
        onSaved: (_) {},
      ),
    ),
  );

  await tester.ensureVisible(find.text('Save Guest'));
  await tester.tap(find.text('Save Guest'));
  await tester.pumpAndSettle();

  expect(
    repository.updated!.tournamentStatus,
    EventTournamentStatus.openPlayOnly,
  );
});
```

Update `_guestRecord` helper in the same test file:

```dart
EventGuestRecord _guestRecord({
  required String id,
  required String name,
  String? guestProfileId,
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    if (guestProfileId != null) 'guest_profile_id': guestProfileId,
    'display_name': name,
    'normalized_name': name.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        ),
    'attendance_status': 'expected',
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
  });
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
flutter test test/features/guests/screens/guest_form_screen_test.dart
```

Expected: FAIL because the form has no tournament qualification control.

- [ ] **Step 3: Implement form state**

In `lib/features/guests/screens/guest_form_screen.dart`, add state:

```dart
late EventTournamentStatus _tournamentStatus;
```

Initialize it in `initState()`:

```dart
_tournamentStatus =
    guest?.tournamentStatus ?? EventTournamentStatus.qualified;
```

Add it to `_buildDraft()`:

```dart
tournamentStatus: _tournamentStatus,
```

- [ ] **Step 4: Implement form control**

Add this widget method in `_GuestFormScreenState`:

```dart
Widget _buildTournamentQualificationField() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Tournament Qualification',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      SegmentedButton<EventTournamentStatus>(
        segments: const [
          ButtonSegment(
            value: EventTournamentStatus.qualified,
            label: Text('Prequalified'),
          ),
          ButtonSegment(
            value: EventTournamentStatus.qualifying,
            label: Text('Considered'),
          ),
          ButtonSegment(
            value: EventTournamentStatus.openPlayOnly,
            label: Text('Not Playing Tournament'),
          ),
        ],
        selected: {_tournamentStatus},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          setState(() {
            _tournamentStatus = selection.single;
          });
        },
      ),
    ],
  );
}
```

Insert it in the `ListView` after `Cover Amount` and before `Note`:

```dart
const SizedBox(height: 12),
_buildTournamentQualificationField(),
```

- [ ] **Step 5: Run test**

Run:

```bash
flutter test test/features/guests/screens/guest_form_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/guests/screens/guest_form_screen.dart test/features/guests/screens/guest_form_screen_test.dart
git commit -m "Add tournament qualification to guest form"
```

## Task 3: Persist Selected Status in Supabase Guest Repository

**Files:**
- Modify: `lib/data/repositories/supabase_guest_repository.dart`
- Modify: `test/data/repositories/supabase_guest_repository_tournament_test.dart`

- [ ] **Step 1: Update failing repository tests**

In `test/data/repositories/supabase_guest_repository_tournament_test.dart`, rename the first test and change its expected status:

```dart
test('creating a guest writes generated public names and selected status',
    () async {
```

In the create input for that test, pass:

```dart
tournamentStatus: EventTournamentStatus.qualified,
```

Update the expectations:

```dart
expect(capturedEventGuestInsert['tournament_status'], 'qualified');
expect(guest.tournamentStatus, EventTournamentStatus.qualified);
```

Add this test in the same group:

```dart
test('updating a guest writes selected tournament status', () async {
  final cache = await LocalCache.create();
  final repository = SupabaseGuestRepository(
    client: SupabaseClient('https://example.com', 'publishable-key'),
    cache: cache,
    guestByIdLoader: (_) async => _guestRow(id: 'gst_01'),
  );

  final json = UpdateGuestInput(
    id: 'gst_01',
    eventId: 'evt_01',
    displayName: 'Brian Le',
    normalizedName: 'brian le',
    publicDisplayName: 'Brian L.',
    tournamentStatus: EventTournamentStatus.qualifying,
    coverStatus: CoverStatus.paid,
    coverAmountCents: 2000,
    isComped: false,
  ).toUpdateJson();

  expect(json['tournament_status'], 'qualifying');
});
```

- [ ] **Step 2: Run failing test**

Run:

```bash
flutter test test/data/repositories/supabase_guest_repository_tournament_test.dart
```

Expected: FAIL because `createGuest` still overwrites `tournament_status` to `open_play_only`.

- [ ] **Step 3: Remove create override**

In `lib/data/repositories/supabase_guest_repository.dart`, update `createGuest` by removing the explicit `open_play_only` override. Replace:

```dart
final inserted = await _insertEventGuest({
  ...input.toInsertJson(guestProfileId: profile.id),
  'public_display_name': publicDisplayName,
  'tournament_status': eventTournamentStatusToJson(
    EventTournamentStatus.openPlayOnly,
  ),
});
```

with:

```dart
final inserted = await _insertEventGuest({
  ...input.toInsertJson(guestProfileId: profile.id),
  'public_display_name': publicDisplayName,
});
```

No repository-specific update code is needed if `UpdateGuestInput.toUpdateJson()` already includes `tournament_status`.

- [ ] **Step 4: Run test**

Run:

```bash
flutter test test/data/repositories/supabase_guest_repository_tournament_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/supabase_guest_repository.dart test/data/repositories/supabase_guest_repository_tournament_test.dart
git commit -m "Persist selected guest tournament status"
```

## Task 4: Add Bulk Qualification to Roster Controller

**Files:**
- Modify: `lib/features/guests/controllers/guest_roster_controller.dart`
- Modify: `test/features/guests/controllers/guest_roster_controller_test.dart`

- [ ] **Step 1: Add failing controller test**

Add this test in `test/features/guests/controllers/guest_roster_controller_test.dart`:

```dart
test('qualifyCheckedInConsidered promotes only checked-in considered guests',
    () async {
  final repository = _FakeGuestRepository([
    _guest(
      id: 'gst_checked_considered',
      name: 'Checked Considered',
      attendanceStatus: AttendanceStatus.checkedIn,
      tournamentStatus: EventTournamentStatus.qualifying,
    ),
    _guest(
      id: 'gst_expected_considered',
      name: 'Expected Considered',
      attendanceStatus: AttendanceStatus.expected,
      tournamentStatus: EventTournamentStatus.qualifying,
    ),
    _guest(
      id: 'gst_checked_open',
      name: 'Checked Open',
      attendanceStatus: AttendanceStatus.checkedIn,
      tournamentStatus: EventTournamentStatus.openPlayOnly,
    ),
  ]);
  final controller = GuestRosterController(guestRepository: repository);

  await controller.load('event-1');
  final count = await controller.qualifyCheckedInConsidered();

  expect(count, 1);
  expect(repository.statusUpdates, {
    'gst_checked_considered': EventTournamentStatus.qualified,
  });
});
```

Update the `_guest` helper signature in the same test file:

```dart
EventGuestRecord _guest({
  required String id,
  required String name,
  AttendanceStatus attendanceStatus = AttendanceStatus.expected,
  EventTournamentStatus tournamentStatus = EventTournamentStatus.openPlayOnly,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'event-1',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': switch (attendanceStatus) {
      AttendanceStatus.expected => 'expected',
      AttendanceStatus.checkedIn => 'checked_in',
      AttendanceStatus.checkedOut => 'checked_out',
      AttendanceStatus.noShow => 'no_show',
    },
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': eventTournamentStatusToJson(tournamentStatus),
  });
}
```

- [ ] **Step 2: Run failing test**

Run:

```bash
flutter test test/features/guests/controllers/guest_roster_controller_test.dart
```

Expected: FAIL because `qualifyCheckedInConsidered` does not exist.

- [ ] **Step 3: Implement bulk controller method**

Add this method to `GuestRosterController`:

```dart
Future<int> qualifyCheckedInConsidered() async {
  final targets = guests
      .where((guest) =>
          guest.isCheckedIn &&
          guest.tournamentStatus == EventTournamentStatus.qualifying)
      .toList(growable: false);

  if (targets.isEmpty) {
    return 0;
  }

  for (final guest in targets) {
    _submittingGuestIds.add(guest.id);
  }
  notifyListeners();

  var promotedCount = 0;
  try {
    for (final guest in targets) {
      final updated = await _guestRepository.updateEventGuestTournamentStatus(
        eventGuestId: guest.id,
        status: EventTournamentStatus.qualified,
      );
      _mergeGuest(updated);
      promotedCount += 1;
    }
  } finally {
    for (final guest in targets) {
      _submittingGuestIds.remove(guest.id);
    }
    notifyListeners();
  }

  return promotedCount;
}
```

- [ ] **Step 4: Run test**

Run:

```bash
flutter test test/features/guests/controllers/guest_roster_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/guests/controllers/guest_roster_controller.dart test/features/guests/controllers/guest_roster_controller_test.dart
git commit -m "Add bulk considered guest qualification"
```

## Task 5: Update Roster UI and Hide Player Tag Actions

**Files:**
- Modify: `lib/features/guests/screens/guest_roster_screen.dart`
- Modify: `test/features/guests/screens/guest_roster_screen_test.dart`

- [ ] **Step 1: Add failing roster UI tests**

Update existing roster tests so old labels are replaced:

```dart
expect(find.text('Check In: Open Play'), findsNothing);
expect(find.text('Check In: Qualifying'), findsNothing);
expect(find.text('Check In: Prequalified'), findsOneWidget);
expect(find.text('Considered'), findsAtLeastNWidgets(1));
expect(find.text('Not Playing Tournament'), findsAtLeastNWidgets(1));
expect(find.text('Scan Player Tag'), findsNothing);
expect(find.text('Mark Qualifying'), findsNothing);
expect(find.text('Mark Qualified'), findsNothing);
expect(find.text('Assign Tag'), findsNothing);
```

Replace the existing open-play and qualifying check-in tests with these three tests:

```dart
testWidgets('prequalified check-in preserves qualified status',
    (tester) async {
  final nfcService = _CountingNfcService();
  final repository = _FakeGuestRepository([
    _guest(
      id: 'gst_01',
      name: 'Alice Wong',
      attendanceStatus: AttendanceStatus.expected,
      coverStatus: CoverStatus.paid,
      tournamentStatus: EventTournamentStatus.qualified,
    ),
  ]);

  await tester.pumpWidget(
    _buildRosterApp(
      guestRepository: repository,
      nfcService: nfcService,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Check In: Prequalified'));
  await tester.pumpAndSettle();

  expect(nfcService.assignmentScanCount, 0);
  expect(repository.statusUpdates['gst_01'], EventTournamentStatus.qualified);
  expect(find.text('Qualified for tournament play'), findsOneWidget);
});

testWidgets('considered check-in preserves considered status',
    (tester) async {
  final nfcService = _CountingNfcService();
  final repository = _FakeGuestRepository([
    _guest(
      id: 'gst_01',
      name: 'Alice Wong',
      attendanceStatus: AttendanceStatus.expected,
      coverStatus: CoverStatus.paid,
      tournamentStatus: EventTournamentStatus.qualifying,
    ),
  ]);

  await tester.pumpWidget(
    _buildRosterApp(
      guestRepository: repository,
      nfcService: nfcService,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Check In: Considered'));
  await tester.pumpAndSettle();

  expect(nfcService.assignmentScanCount, 0);
  expect(repository.statusUpdates['gst_01'], EventTournamentStatus.qualifying);
  expect(find.text('Checked in as considered'), findsOneWidget);
});

testWidgets('not playing tournament check-in preserves open-play-only status',
    (tester) async {
  final nfcService = _CountingNfcService();
  final repository = _FakeGuestRepository([
    _guest(
      id: 'gst_01',
      name: 'Alice Wong',
      attendanceStatus: AttendanceStatus.expected,
      coverStatus: CoverStatus.paid,
      tournamentStatus: EventTournamentStatus.openPlayOnly,
    ),
  ]);

  await tester.pumpWidget(
    _buildRosterApp(
      guestRepository: repository,
      nfcService: nfcService,
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Check In: Not Playing Tournament'));
  await tester.pumpAndSettle();

  expect(nfcService.assignmentScanCount, 0);
  expect(
    repository.statusUpdates['gst_01'],
    EventTournamentStatus.openPlayOnly,
  );
  expect(find.text('Checked in; not playing tournament'), findsOneWidget);
});
```

Add this bulk action test:

```dart
testWidgets('bulk qualifies checked-in considered guests', (tester) async {
  final repository = _FakeGuestRepository([
    _guest(
      id: 'gst_01',
      name: 'Alice Wong',
      attendanceStatus: AttendanceStatus.checkedIn,
      coverStatus: CoverStatus.paid,
      tournamentStatus: EventTournamentStatus.qualifying,
    ),
  ]);

  await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
  await tester.pumpAndSettle();

  expect(find.text('Qualify Checked-In Considered'), findsOneWidget);

  await tester.tap(find.text('Qualify Checked-In Considered'));
  await tester.pumpAndSettle();

  expect(repository.statusUpdates['gst_01'], EventTournamentStatus.qualified);
  expect(find.text('Qualified 1 considered guest.'), findsOneWidget);
});
```

- [ ] **Step 2: Run failing roster tests**

Run:

```bash
flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: FAIL because old labels/actions still render.

- [ ] **Step 3: Add roster label helpers**

In `lib/features/guests/screens/guest_roster_screen.dart`, update tournament filter labels:

```dart
label: 'Considered',
label: 'Prequalified',
label: 'Not Playing Tournament',
```

Replace `_tournamentStatusLabel` with:

```dart
String _tournamentStatusLabel(EventGuestRecord guest) {
  return switch (guest.tournamentStatus) {
    EventTournamentStatus.openPlayOnly => 'Not Playing Tournament',
    EventTournamentStatus.qualifying => 'Considered',
    EventTournamentStatus.qualified =>
      guest.isCheckedIn ? 'Qualified' : 'Prequalified',
    EventTournamentStatus.withdrawn => 'Withdrawn',
  };
}
```

Update all call sites from `_tournamentStatusLabel(guest.tournamentStatus)` to `_tournamentStatusLabel(guest)`.

Add:

```dart
String _checkInActionLabel(EventTournamentStatus status) {
  return switch (status) {
    EventTournamentStatus.openPlayOnly => 'Check In: Not Playing Tournament',
    EventTournamentStatus.qualifying => 'Check In: Considered',
    EventTournamentStatus.qualified => 'Check In: Prequalified',
    EventTournamentStatus.withdrawn => 'Check In: Withdrawn',
  };
}
```

- [ ] **Step 4: Replace pending check-in actions**

In `_buildQuickActionsForGuest`, replace the two-button pending check-in row with:

```dart
if (!guest.isCheckedIn) {
  if (!widget.canCheckIn ||
      guest.tournamentStatus == EventTournamentStatus.withdrawn) {
    return const SizedBox.shrink();
  }
  return FilledButton(
    style: _compactActionButtonStyle(),
    onPressed: isSubmitting ? null : () => _checkInGuest(guest),
    child: _singleLineButtonLabel(_checkInActionLabel(guest.tournamentStatus)),
  );
}
```

Change `_checkInGuest` signature:

```dart
Future<void> _checkInGuest(EventGuestRecord guest) async {
  if (!widget.canCheckIn) {
    return;
  }
  final status = guest.tournamentStatus;
  await _runQuickAction(
    () => _controller.checkInForPlayMode(
      guestId: guest.id,
      status: status,
    ),
    successMessage: _checkInSuccessMessage(guest, status),
  );
}
```

Add:

```dart
String _checkInSuccessMessage(
  EventGuestRecord guest,
  EventTournamentStatus status,
) {
  final statusLabel = switch (status) {
    EventTournamentStatus.openPlayOnly => 'not playing tournament',
    EventTournamentStatus.qualifying => 'considered',
    EventTournamentStatus.qualified => 'prequalified',
    EventTournamentStatus.withdrawn => 'withdrawn',
  };
  return '${guest.displayName} is checked in as $statusLabel.';
}
```

- [ ] **Step 5: Hide tag scan and remove primary progression**

Remove this top-level button from `build`:

```dart
OutlinedButton.icon(
  style: _topActionButtonStyle(),
  onPressed: _controller.isIdentifyingTag ? null : _identifyTag,
  icon: const Icon(Icons.nfc),
  label: const Text('Scan Player Tag'),
),
```

Make `_primaryActionForGuest` return no tournament progression:

```dart
Widget? _primaryActionForGuest(EventGuestRecord guest) {
  return null;
}
```

Leave `_identifyTag`, `_showIdentifiedTagSheet`, and `_showTagNotFoundSheet` in place only as unreachable private helpers for this soft-deprecation pass. They must not be called from active UI.

- [ ] **Step 6: Simplify overflow tournament actions**

Update `_GuestRosterOverflowAction` to remove `markQualifying` and `markQualified`. Keep:

```dart
enum _GuestRosterOverflowAction {
  markPaidManually,
  addCoverEntry,
  moveToOpenPlayOnly,
  withdraw,
  removeGuest,
}
```

Update `_overflowActionsForGuest` tournament section:

```dart
switch (guest.tournamentStatus) {
  case EventTournamentStatus.openPlayOnly:
    actions.add(_GuestRosterOverflowAction.withdraw);
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
    actions.add(_GuestRosterOverflowAction.moveToOpenPlayOnly);
}
```

Update labels:

```dart
_GuestRosterOverflowAction.moveToOpenPlayOnly => 'Not Playing Tournament',
```

Remove the deleted cases from `_handleOverflowAction`.

- [ ] **Step 7: Add bulk button**

In `build`, compute:

```dart
final checkedInConsideredCount = _controller.guests
    .where((guest) =>
        guest.isCheckedIn &&
        guest.tournamentStatus == EventTournamentStatus.qualifying)
    .length;
```

After the add guest button and before guest filters, render:

```dart
if (widget.canManageTournamentStatus && checkedInConsideredCount > 0) ...[
  OutlinedButton.icon(
    style: _topActionButtonStyle(),
    onPressed: _controller.guests
            .any((guest) => _controller.isSubmittingGuest(guest.id))
        ? null
        : _qualifyCheckedInConsidered,
    icon: const Icon(Icons.done_all),
    label: const Text('Qualify Checked-In Considered'),
  ),
  const SizedBox(height: 6),
],
```

Add method:

```dart
Future<void> _qualifyCheckedInConsidered() async {
  if (!widget.canManageTournamentStatus) {
    return;
  }
  try {
    final count = await _controller.qualifyCheckedInConsidered();
    if (!mounted || count == 0) {
      return;
    }
    final guestLabel = count == 1 ? 'guest' : 'guests';
    _showMessage('Qualified $count considered $guestLabel.');
  } catch (exception) {
    if (!mounted) {
      return;
    }
    _showMessage(_formatActionError(exception));
  }
}
```

- [ ] **Step 8: Update row summaries**

Replace `_rowSummary` tournament cases:

```dart
return switch (guest.tournamentStatus) {
  EventTournamentStatus.openPlayOnly =>
    'Checked in; not playing tournament',
  EventTournamentStatus.qualifying => 'Checked in as considered',
  EventTournamentStatus.qualified => 'Qualified for tournament play',
  EventTournamentStatus.withdrawn => 'Withdrawn from tournament play',
};
```

- [ ] **Step 9: Run roster tests**

Run:

```bash
flutter test test/features/guests/screens/guest_roster_screen_test.dart
```

Expected: PASS after updating obsolete assertions throughout the file.

- [ ] **Step 10: Commit**

```bash
git add lib/features/guests/screens/guest_roster_screen.dart test/features/guests/screens/guest_roster_screen_test.dart
git commit -m "Update roster qualification check-in flow"
```

## Task 6: Hide Player Tags from Guest Detail

**Files:**
- Modify: `lib/features/checkin/controllers/guest_check_in_controller.dart`
- Modify: `lib/features/checkin/screens/guest_detail_screen.dart`
- Modify: `test/features/checkin/screens/guest_detail_screen_test.dart`

- [ ] **Step 1: Add failing guest detail tests**

Replace the test named `shows separate check-in and assign-tag actions for eligible guest` with:

```dart
testWidgets('shows status-derived check-in without player tag actions',
    (tester) async {
  final repository = _FakeGuestRepository(
    GuestDetailRecord(
      guest: EventGuestRecord.fromJson(const {
        'id': 'gst_01',
        'event_id': 'evt_01',
        'display_name': 'Alice Wong',
        'normalized_name': 'alice wong',
        'attendance_status': 'expected',
        'tournament_status': 'qualified',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      }),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: GuestDetailScreen(
        guestId: 'gst_01',
        eventId: 'evt_01',
        guestRepository: repository,
        nfcService: const _FakeNfcService(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Check In: Prequalified'), findsOneWidget);
  expect(find.text('Assign Tag'), findsNothing);
  expect(find.text('Replace Tag'), findsNothing);
  expect(find.text('Player Tag'), findsNothing);
  expect(find.text('Tag Unassigned'), findsNothing);
});
```

Replace `checks in open-play-only guest without assigning a tag` with:

```dart
testWidgets('checks in not-playing guest without tag actions', (tester) async {
  final repository = _FakeGuestRepository(
    GuestDetailRecord(
      guest: EventGuestRecord.fromJson(const {
        'id': 'gst_01',
        'event_id': 'evt_01',
        'display_name': 'Alice Wong',
        'normalized_name': 'alice wong',
        'attendance_status': 'expected',
        'tournament_status': 'open_play_only',
        'cover_status': 'paid',
        'cover_amount_cents': 2000,
        'is_comped': false,
        'has_scored_play': false,
      }),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: GuestDetailScreen(
        guestId: 'gst_01',
        eventId: 'evt_01',
        guestRepository: repository,
        nfcService: const _FakeNfcService(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Check In: Not Playing Tournament'));
  await tester.pumpAndSettle();

  expect(repository.lastAssignedUid, isNull);
  expect(find.text('Assign Tag'), findsNothing);
  expect(find.text('Tag Unassigned'), findsNothing);
  expect(find.text('Checked In'), findsOneWidget);
});
```

- [ ] **Step 2: Run failing test**

Run:

```bash
flutter test test/features/checkin/screens/guest_detail_screen_test.dart
```

Expected: FAIL because guest detail still shows tag UI and generic check-in labels.

- [ ] **Step 3: Remove tag promotion from controller**

In `lib/features/checkin/controllers/guest_check_in_controller.dart`, remove this block from `assignTag`:

```dart
if (currentDetail.guest.tournamentStatus ==
    EventTournamentStatus.openPlayOnly) {
  await _promoteOpenPlayOnlyGuest(guestId);
}
```

Remove `_promoteOpenPlayOnlyGuest` entirely if it becomes unused.

Update `checkIn` to preserve the current tournament status explicitly:

```dart
detail = await _guestRepository.checkInGuest(guestId);
final updatedGuest = await _guestRepository.updateEventGuestTournamentStatus(
  eventGuestId: guestId,
  status: currentDetail.guest.tournamentStatus,
);
detail = GuestDetailRecord(
  guest: updatedGuest,
  coverEntries: detail?.coverEntries ?? const [],
  activeTagAssignment: detail?.activeTagAssignment,
);
```

- [ ] **Step 4: Hide tag UI in guest detail screen**

In `lib/features/checkin/screens/guest_detail_screen.dart`, remove or stop rendering:

```dart
_tagDetailText(...)
_tagPromptForGuest(...)
Assign Tag
Replace Tag
Player Tag
Tag Unassigned
```

Add a status-derived check-in label helper:

```dart
String _checkInLabel(EventTournamentStatus status) {
  return switch (status) {
    EventTournamentStatus.openPlayOnly => 'Check In: Not Playing Tournament',
    EventTournamentStatus.qualifying => 'Check In: Considered',
    EventTournamentStatus.qualified => 'Check In: Prequalified',
    EventTournamentStatus.withdrawn => 'Check In: Withdrawn',
  };
}
```

For eligible, not-checked-in guests, render only:

```dart
SizedBox(
  width: double.infinity,
  child: FilledButton(
    onPressed: _controller.isSubmitting
        ? null
        : () => _controller.checkIn(guestId: widget.guestId),
    child: Text(
      _controller.isSubmitting
          ? 'Saving...'
          : _checkInLabel(guest.tournamentStatus),
    ),
  ),
),
```

Do not render a check-in button for withdrawn guests:

```dart
if (guest.tournamentStatus != EventTournamentStatus.withdrawn)
```

- [ ] **Step 5: Run guest detail tests**

Run:

```bash
flutter test test/features/checkin/screens/guest_detail_screen_test.dart
```

Expected: PASS after updating obsolete tag assertions throughout the file.

- [ ] **Step 6: Commit**

```bash
git add lib/features/checkin/controllers/guest_check_in_controller.dart lib/features/checkin/screens/guest_detail_screen.dart test/features/checkin/screens/guest_detail_screen_test.dart
git commit -m "Hide player tags from guest detail"
```

## Task 7: Full Regression Pass

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run targeted guest tests**

Run:

```bash
flutter test test/data/models/guest_models_tournament_test.dart test/features/guests/models/guest_form_draft_test.dart test/data/repositories/supabase_guest_repository_tournament_test.dart test/features/guests/screens/guest_form_screen_test.dart test/features/guests/controllers/guest_roster_controller_test.dart test/features/guests/screens/guest_roster_screen_test.dart test/features/checkin/screens/guest_detail_screen_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run full test suite**

Run:

```bash
flutter test
```

Expected: PASS with no failing tests.

- [ ] **Step 4: Inspect player tag UI references**

Run:

```bash
rg -n "Scan Player Tag|Assign Tag|Replace Tag|Check In & Tag|Tag Unassigned|Player Tag" lib/features/guests lib/features/checkin test/features/guests test/features/checkin
```

Expected: No matches in active guest roster/detail UI assertions except unreachable helper names or tests explicitly asserting hidden text. If reachable UI text remains, remove it or update the test to prove it is hidden.

- [ ] **Step 5: Inspect diff**

Run:

```bash
git diff --stat
git diff -- lib/data/models/guest_models.dart lib/features/guests lib/features/checkin test/data/models/guest_models_tournament_test.dart test/features/guests test/features/checkin test/data/repositories/supabase_guest_repository_tournament_test.dart
```

Expected: Diff matches this plan and does not delete Supabase tag schema or table-tag functionality.

- [ ] **Step 6: Final commit if needed**

If Task 7 required cleanup changes, commit them:

```bash
git add lib test
git commit -m "Verify tournament qualification workflow"
```

If Task 7 made no changes, do not create an empty commit.
