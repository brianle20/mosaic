import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/screens/guest_detail_screen.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository(
    this.detail, {
    this.returnEmptyCoverEntriesOnCheckIn = false,
  });

  GuestDetailRecord detail;
  final bool returnEmptyCoverEntriesOnCheckIn;
  String? lastAssignedUid;
  String? lastReplacedUid;
  EventTournamentStatus? lastUpdatedTournamentStatus;
  int? lastRecordedAmountCents;
  CoverEntryMethod? lastRecordedMethod;
  DateTime? lastRecordedTransactionOn;
  String? lastRecordedNote;
  String? lastUpdatedCoverEntryId;
  int? lastUpdatedAmountCents;
  CoverEntryMethod? lastUpdatedMethod;
  DateTime? lastUpdatedTransactionOn;
  String? lastUpdatedNote;
  String? lastDeletedCoverEntryId;
  int detailLoadCount = 0;
  int tournamentStatusUpdateCount = 0;

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    return detail = GuestDetailRecord(
      guest: EventGuestRecord(
        id: detail.guest.id,
        eventId: detail.guest.eventId,
        guestProfileId: detail.guest.guestProfileId,
        displayName: detail.guest.displayName,
        normalizedName: detail.guest.normalizedName,
        publicDisplayName: detail.guest.publicDisplayName,
        phoneE164: detail.guest.phoneE164,
        emailLower: detail.guest.emailLower,
        instagramHandle: detail.guest.instagramHandle,
        attendanceStatus: AttendanceStatus.checkedIn,
        tournamentStatus: detail.guest.tournamentStatus,
        coverStatus: detail.guest.coverStatus,
        coverAmountCents: detail.guest.coverAmountCents,
        isComped: detail.guest.isComped,
        hasScoredPlay: detail.guest.hasScoredPlay,
        note: detail.guest.note,
        checkedInAt: DateTime.parse('2026-04-24T19:15:00-07:00'),
        rowVersion: detail.guest.rowVersion,
      ),
      coverEntries:
          returnEmptyCoverEntriesOnCheckIn ? const [] : detail.coverEntries,
    );
  }

  @override
  Future<EventGuestRecord> undoGuestCheckIn(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async {
    detailLoadCount += 1;
    return detail;
  }

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
      String guestId) async {
    return detail.coverEntries;
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => [
        detail.guest,
      ];

  @override
  Future<List<GuestProfileRecord>> listGuestProfiles() async => const [];

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async {
    return detail.coverEntries;
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) async {
    lastRecordedAmountCents = amountCents;
    lastRecordedMethod = method;
    lastRecordedTransactionOn = transactionOn;
    lastRecordedNote = note;
    return detail = GuestDetailRecord(
      guest: detail.guest,
      coverEntries: [
        GuestCoverEntryRecord(
          id: 'cov_new',
          eventId: detail.guest.eventId,
          eventGuestId: detail.guest.id,
          amountCents: amountCents,
          method: method,
          recordedByUserId: 'usr_01',
          transactionOn: transactionOn,
          note: note,
          createdAt: DateTime.parse('2026-04-24T19:20:00-07:00'),
        ),
        ...detail.coverEntries,
      ],
    );
  }

  @override
  Future<GuestDetailRecord> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) async {
    lastUpdatedCoverEntryId = coverEntryId;
    lastUpdatedAmountCents = amountCents;
    lastUpdatedMethod = method;
    lastUpdatedTransactionOn = transactionOn;
    lastUpdatedNote = note;
    return detail = GuestDetailRecord(
      guest: detail.guest,
      coverEntries: detail.coverEntries
          .map(
            (entry) => entry.id == coverEntryId
                ? GuestCoverEntryRecord(
                    id: entry.id,
                    eventId: entry.eventId,
                    eventGuestId: entry.eventGuestId,
                    amountCents: method == CoverEntryMethod.refund
                        ? -amountCents.abs()
                        : amountCents,
                    method: method,
                    recordedByUserId: entry.recordedByUserId,
                    transactionOn: transactionOn,
                    note: note,
                    createdAt: entry.createdAt,
                  )
                : entry,
          )
          .toList(growable: false),
    );
  }

  @override
  Future<GuestDetailRecord> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  }) async {
    lastDeletedCoverEntryId = coverEntryId;
    return detail = GuestDetailRecord(
      guest: detail.guest,
      coverEntries: detail.coverEntries
          .where((entry) => entry.id != coverEntryId)
          .toList(growable: false),
    );
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<void> removeGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) async {
    tournamentStatusUpdateCount += 1;
    lastUpdatedTournamentStatus = status;
    final updatedGuest = EventGuestRecord(
      id: detail.guest.id,
      eventId: detail.guest.eventId,
      guestProfileId: detail.guest.guestProfileId,
      displayName: detail.guest.displayName,
      normalizedName: detail.guest.normalizedName,
      publicDisplayName: detail.guest.publicDisplayName,
      phoneE164: detail.guest.phoneE164,
      emailLower: detail.guest.emailLower,
      instagramHandle: detail.guest.instagramHandle,
      attendanceStatus: detail.guest.attendanceStatus,
      tournamentStatus: status,
      coverStatus: detail.guest.coverStatus,
      coverAmountCents: detail.guest.coverAmountCents,
      isComped: detail.guest.isComped,
      hasScoredPlay: detail.guest.hasScoredPlay,
      note: detail.guest.note,
      checkedInAt: detail.guest.checkedInAt,
      rowVersion: detail.guest.rowVersion,
    );
    detail = GuestDetailRecord(
      guest: updatedGuest,
      coverEntries: detail.coverEntries,
    );
    return updatedGuest;
  }
}

void _expectNoPlayerTagUi() {
  expect(find.text('Assign Tag'), findsNothing);
  expect(find.text('Replace Tag'), findsNothing);
  expect(find.text('Player Tag'), findsNothing);
  expect(find.text('Tag Unassigned'), findsNothing);
  expect(find.text('Tag Assigned'), findsNothing);
  expect(find.text('This guest is ready for a player tag.'), findsNothing);
  expect(
    find.text('This guest is ready to check in and receive a player tag.'),
    findsNothing,
  );
  expect(
    find.text('This guest can check in for open play without a tag.'),
    findsNothing,
  );
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

void main() {
  testWidgets('opens edit guest from the detail screen and reloads on return',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_01',
          'event_id': 'evt_01',
          'guest_profile_id': 'prf_01',
          'display_name': 'Brian Le',
          'normalized_name': 'brian le',
          'phone_e164': '+14155552671',
          'email_lower': 'brian@example.com',
          'attendance_status': 'expected',
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Guest'), findsOneWidget);
    expect(find.text('Brian Le'), findsOneWidget);
    expect(find.text('(415) 555-2671'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(repository.detailLoadCount, 2);
  });

  testWidgets('shows prequalified check-in and hides player tag UI',
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check In: Prequalified'), findsOneWidget);
    expect(find.text('Attendance Status'), findsOneWidget);
    expect(find.text('Cover Status'), findsOneWidget);
    _expectNoPlayerTagUi();

    await tester.tap(find.text('Check In: Prequalified'));
    await tester.pumpAndSettle();

    expect(repository.lastAssignedUid, isNull);
    expect(repository.tournamentStatusUpdateCount, 1);
    expect(repository.lastUpdatedTournamentStatus,
        EventTournamentStatus.qualified);
    expect(find.text('Checked In'), findsOneWidget);
    _expectNoPlayerTagUi();
  });

  testWidgets(
      'checks in open-play-only guest without assigning a tag or showing tag UI',
      (tester) async {
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check In: Not Playing Tournament'), findsOneWidget);
    _expectNoPlayerTagUi();

    await tester.tap(find.text('Check In: Not Playing Tournament'));
    await tester.pumpAndSettle();

    expect(repository.lastAssignedUid, isNull);
    expect(repository.tournamentStatusUpdateCount, 1);
    expect(repository.lastUpdatedTournamentStatus,
        EventTournamentStatus.openPlayOnly);
    expect(repository.detail.guest.tournamentStatus,
        EventTournamentStatus.openPlayOnly);
    expect(find.text('Checked In'), findsOneWidget);
    _expectNoPlayerTagUi();
  });

  testWidgets('preserves cover ledger when check-in returns no ledger data',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_12',
          'event_id': 'evt_01',
          'display_name': 'Ledger Guest',
          'normalized_name': 'ledger guest',
          'attendance_status': 'expected',
          'tournament_status': 'qualified',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
        coverEntries: [
          GuestCoverEntryRecord(
            id: 'cov_existing',
            eventId: 'evt_01',
            eventGuestId: 'gst_12',
            amountCents: 2000,
            method: CoverEntryMethod.cash,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
            note: 'Paid before check-in',
          ),
        ],
      ),
      returnEmptyCoverEntriesOnCheckIn: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_12',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paid before check-in'), findsOneWidget);

    await tester.tap(find.text('Check In: Prequalified'));
    await tester.pumpAndSettle();

    expect(find.text('Checked In'), findsOneWidget);
    expect(find.text('Paid before check-in'), findsOneWidget);
  });

  testWidgets('shows considered check-in for qualifying guest', (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_10',
          'event_id': 'evt_01',
          'display_name': 'Casey Park',
          'normalized_name': 'casey park',
          'attendance_status': 'expected',
          'tournament_status': 'qualifying',
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
          guestId: 'gst_10',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check In: Considered'), findsOneWidget);
    _expectNoPlayerTagUi();
  });

  testWidgets('hides check-in button for withdrawn eligible guest',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_11',
          'event_id': 'evt_01',
          'display_name': 'Will Tan',
          'normalized_name': 'will tan',
          'attendance_status': 'expected',
          'tournament_status': 'withdrawn',
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
          guestId: 'gst_11',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Check In'), findsNothing);
    _expectNoPlayerTagUi();
  });

  testWidgets('shows blocked eligibility messaging for unpaid guest',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_02',
          'event_id': 'evt_01',
          'display_name': 'Bob Lee',
          'normalized_name': 'bob lee',
          'attendance_status': 'expected',
          'cover_status': 'unpaid',
          'cover_amount_cents': 0,
          'is_comped': false,
          'has_scored_play': false,
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_02',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Mark this guest paid or comped before check-in.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Update the cover status, then return here to continue check-in.',
      ),
      findsOneWidget,
    );
    _expectNoPlayerTagUi();
  });

  testWidgets('hides active tag details for checked-in guest', (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_03',
          'event_id': 'evt_01',
          'display_name': 'Carol Ng',
          'normalized_name': 'carol ng',
          'attendance_status': 'checked_in',
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
          guestId: 'gst_03',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectNoPlayerTagUi();
    expect(find.text('UID: 04CCDDEE'), findsNothing);
  });

  testWidgets('shows a cover ledger section with newest entries first',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_08',
          'event_id': 'evt_01',
          'display_name': 'Hana Ko',
          'normalized_name': 'hana ko',
          'attendance_status': 'checked_in',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
        coverEntries: [
          GuestCoverEntryRecord(
            id: 'cov_02',
            eventId: 'evt_01',
            eventGuestId: 'gst_08',
            amountCents: -500,
            method: CoverEntryMethod.refund,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
            note: 'Refunded duplicate charge',
            createdAt: DateTime.parse('2026-04-24T19:10:00-07:00'),
          ),
          GuestCoverEntryRecord(
            id: 'cov_01',
            eventId: 'evt_01',
            eventGuestId: 'gst_08',
            amountCents: 2000,
            method: CoverEntryMethod.cash,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
            note: 'Paid at door',
            createdAt: DateTime.parse('2026-04-24T19:00:00-07:00'),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_08',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cover Ledger'), findsOneWidget);
    expect(find.text('Refunded duplicate charge'), findsOneWidget);
    expect(find.text('Paid at door'), findsOneWidget);
  });

  testWidgets('adds a cover ledger entry from the guest detail screen',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_09',
          'event_id': 'evt_01',
          'display_name': 'Ian Q',
          'normalized_name': 'ian q',
          'attendance_status': 'expected',
          'cover_status': 'partial',
          'cover_amount_cents': 1000,
          'is_comped': false,
          'has_scored_play': false,
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_09',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Cover Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Record Cover Entry'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Amount'), '2000');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Venmo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Paid after seating');
    await tester.tap(find.text('Save Cover Entry'));
    await tester.pumpAndSettle();

    expect(repository.lastRecordedAmountCents, 2000);
    expect(repository.lastRecordedMethod, CoverEntryMethod.venmo);
    expect(repository.lastRecordedTransactionOn, _dateOnly(DateTime.now()));
    expect(repository.lastRecordedNote, 'Paid after seating');
    expect(find.text('Paid after seating'), findsOneWidget);
  });

  testWidgets('edits a cover ledger entry from the guest detail screen',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_09',
          'event_id': 'evt_01',
          'display_name': 'Ian Q',
          'normalized_name': 'ian q',
          'attendance_status': 'expected',
          'cover_status': 'partial',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
        coverEntries: [
          GuestCoverEntryRecord(
            id: 'cov_01',
            eventId: 'evt_01',
            eventGuestId: 'gst_09',
            amountCents: 1000,
            method: CoverEntryMethod.cash,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
            note: 'Paid at door',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_09',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit cover entry'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Cover Entry'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    final amountField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Amount'),
        matching: find.byType(EditableText),
      ),
    );
    expect(amountField.controller.text, '10.00');
    expect(find.widgetWithText(FilledButton, 'Cash'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount'),
      '1500',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Zelle'));
    await tester.enterText(find.byType(TextFormField).last, 'Corrected amount');
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(repository.lastUpdatedCoverEntryId, 'cov_01');
    expect(repository.lastUpdatedAmountCents, 1500);
    expect(repository.lastUpdatedMethod, CoverEntryMethod.zelle);
    expect(repository.lastUpdatedTransactionOn, DateTime(2026, 4, 24));
    expect(repository.lastUpdatedNote, 'Corrected amount');
    expect(find.text('Corrected amount'), findsOneWidget);
    expect(find.text('Zelle \$15.00 - Apr 24, 2026'), findsOneWidget);
  });

  testWidgets('deletes a cover ledger entry after confirmation',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_09',
          'event_id': 'evt_01',
          'display_name': 'Ian Q',
          'normalized_name': 'ian q',
          'attendance_status': 'expected',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
        coverEntries: [
          GuestCoverEntryRecord(
            id: 'cov_01',
            eventId: 'evt_01',
            eventGuestId: 'gst_09',
            amountCents: 500,
            method: CoverEntryMethod.venmo,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
            note: 'Accidental partial payment',
          ),
          GuestCoverEntryRecord(
            id: 'cov_02',
            eventId: 'evt_01',
            eventGuestId: 'gst_09',
            amountCents: 1500,
            method: CoverEntryMethod.cash,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_09',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete cover entry').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete cover entry?'), findsOneWidget);
    expect(
      find.text('Delete Venmo \$5.00 - Apr 24, 2026 from the ledger?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.lastDeletedCoverEntryId, 'cov_01');
    expect(find.text('Venmo \$5.00 - Apr 24, 2026'), findsNothing);
    expect(find.text('Accidental partial payment'), findsNothing);
    expect(find.text('Cash \$15.00 - Apr 24, 2026'), findsOneWidget);
  });

  testWidgets('prefills cover entry amount with remaining balance',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_09',
          'event_id': 'evt_01',
          'display_name': 'Ian Q',
          'normalized_name': 'ian q',
          'attendance_status': 'expected',
          'cover_status': 'partial',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
        coverEntries: [
          GuestCoverEntryRecord(
            id: 'cov_01',
            eventId: 'evt_01',
            eventGuestId: 'gst_09',
            amountCents: 500,
            method: CoverEntryMethod.cash,
            recordedByUserId: 'usr_01',
            transactionOn: DateTime(2026, 4, 24),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_09',
          eventId: 'evt_01',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Cover Entry'));
    await tester.pumpAndSettle();

    final amountField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Amount'),
        matching: find.byType(EditableText),
      ),
    );
    expect(amountField.controller.text, '15.00');
  });
}
