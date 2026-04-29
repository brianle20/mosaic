import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/screens/guest_detail_screen.dart';
import 'package:mosaic/services/nfc/manual_entry_nfc_service.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository(this.detail);

  GuestDetailRecord detail;
  String? lastAssignedUid;
  String? lastReplacedUid;
  int? lastRecordedAmountCents;
  CoverEntryMethod? lastRecordedMethod;
  String? lastRecordedNote;
  int detailLoadCount = 0;

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    lastAssignedUid = scannedUid;
    return detail = GuestDetailRecord(
      guest: EventGuestRecord(
        id: detail.guest.id,
        eventId: detail.guest.eventId,
        guestProfileId: detail.guest.guestProfileId,
        displayName: detail.guest.displayName,
        normalizedName: detail.guest.normalizedName,
        phoneE164: detail.guest.phoneE164,
        emailLower: detail.guest.emailLower,
        attendanceStatus: AttendanceStatus.checkedIn,
        coverStatus: detail.guest.coverStatus,
        coverAmountCents: detail.guest.coverAmountCents,
        isComped: detail.guest.isComped,
        hasScoredPlay: detail.guest.hasScoredPlay,
        note: detail.guest.note,
        checkedInAt: detail.guest.checkedInAt ??
            DateTime.parse('2026-04-24T19:15:00-07:00'),
        rowVersion: detail.guest.rowVersion,
      ),
      coverEntries: detail.coverEntries,
      activeTagAssignment: GuestTagAssignmentSummary.fromJson({
        'assignment_id': 'asg_new',
        'event_id': detail.guest.eventId,
        'event_guest_id': detail.guest.id,
        'status': 'assigned',
        'assigned_at': '2026-04-24T19:16:00-07:00',
        'nfc_tag': {
          'id': 'tag_new',
          'uid_hex': scannedUid.toUpperCase().replaceAll(' ', ''),
          'uid_fingerprint': scannedUid.toUpperCase().replaceAll(' ', ''),
          'default_tag_type': 'player',
          'status': 'active',
          'display_label': displayLabel,
        },
      }),
    );
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    return detail = GuestDetailRecord(
      guest: EventGuestRecord(
        id: detail.guest.id,
        eventId: detail.guest.eventId,
        guestProfileId: detail.guest.guestProfileId,
        displayName: detail.guest.displayName,
        normalizedName: detail.guest.normalizedName,
        phoneE164: detail.guest.phoneE164,
        emailLower: detail.guest.emailLower,
        attendanceStatus: AttendanceStatus.checkedIn,
        coverStatus: detail.guest.coverStatus,
        coverAmountCents: detail.guest.coverAmountCents,
        isComped: detail.guest.isComped,
        hasScoredPlay: detail.guest.hasScoredPlay,
        note: detail.guest.note,
        checkedInAt: DateTime.parse('2026-04-24T19:15:00-07:00'),
        rowVersion: detail.guest.rowVersion,
      ),
      coverEntries: detail.coverEntries,
      activeTagAssignment: detail.activeTagAssignment,
    );
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
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

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
    String? note,
  }) async {
    lastRecordedAmountCents = amountCents;
    lastRecordedMethod = method;
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
          recordedAt: DateTime.parse('2026-04-24T19:20:00-07:00'),
          note: note,
          createdAt: DateTime.parse('2026-04-24T19:20:00-07:00'),
        ),
        ...detail.coverEntries,
      ],
      activeTagAssignment: detail.activeTagAssignment,
    );
  }

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    lastReplacedUid = scannedUid;
    return detail = GuestDetailRecord(
      guest: EventGuestRecord(
        id: detail.guest.id,
        eventId: detail.guest.eventId,
        guestProfileId: detail.guest.guestProfileId,
        displayName: detail.guest.displayName,
        normalizedName: detail.guest.normalizedName,
        phoneE164: detail.guest.phoneE164,
        emailLower: detail.guest.emailLower,
        attendanceStatus: AttendanceStatus.checkedIn,
        coverStatus: detail.guest.coverStatus,
        coverAmountCents: detail.guest.coverAmountCents,
        isComped: detail.guest.isComped,
        hasScoredPlay: detail.guest.hasScoredPlay,
        note: detail.guest.note,
        checkedInAt: detail.guest.checkedInAt ??
            DateTime.parse('2026-04-24T19:15:00-07:00'),
        rowVersion: detail.guest.rowVersion,
      ),
      coverEntries: detail.coverEntries,
      activeTagAssignment: GuestTagAssignmentSummary.fromJson({
        'assignment_id': 'asg_replaced',
        'event_id': detail.guest.eventId,
        'event_guest_id': detail.guest.id,
        'status': 'assigned',
        'assigned_at': '2026-04-24T19:17:00-07:00',
        'nfc_tag': {
          'id': 'tag_replaced',
          'uid_hex': scannedUid.toUpperCase().replaceAll(' ', ''),
          'uid_fingerprint': scannedUid.toUpperCase().replaceAll(' ', ''),
          'default_tag_type': 'player',
          'status': 'active',
          'display_label': displayLabel ?? 'Replacement Tag',
        },
      }),
    );
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

class _FakeNfcService implements NfcService {
  const _FakeNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
      BuildContext context) async {
    return const TagScanResult(
      rawUid: '04AABB',
      normalizedUid: '04AABB',
      isManualEntry: true,
    );
  }

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async {
    return const TagScanResult(
      rawUid: '04AABB',
      normalizedUid: '04AABB',
      isManualEntry: true,
    );
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return const TagScanResult(
      rawUid: 'TABLE001',
      normalizedUid: 'TABLE001',
      isManualEntry: true,
    );
  }
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
          nfcService: const _FakeNfcService(),
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

  testWidgets('shows check-in and assign action for eligible guest',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_01',
          'event_id': 'evt_01',
          'display_name': 'Alice Wong',
          'normalized_name': 'alice wong',
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
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check In and Assign Tag'), findsOneWidget);
    expect(find.text('Tag Unassigned'), findsOneWidget);
    expect(find.text('Attendance Status'), findsOneWidget);
    expect(find.text('Cover Status'), findsOneWidget);
    expect(find.text('Player Tag'), findsOneWidget);
    expect(
      find.text('This guest is ready to check in and receive a player tag.'),
      findsOneWidget,
    );
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
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Mark this guest paid or comped before assigning a player tag.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Update the cover status, then return here to continue check-in.',
      ),
      findsOneWidget,
    );
    expect(find.text('Check In and Assign Tag'), findsNothing);
  });

  testWidgets('shows replace action when guest already has an active tag',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_03',
          'event_id': 'evt_01',
          'display_name': 'Carol Ng',
          'normalized_name': 'carol ng',
          'attendance_status': 'checked_in',
          'cover_status': 'comped',
          'cover_amount_cents': 0,
          'is_comped': true,
          'has_scored_play': false,
        }),
        activeTagAssignment: GuestTagAssignmentSummary.fromJson(const {
          'assignment_id': 'asg_01',
          'event_id': 'evt_01',
          'event_guest_id': 'gst_03',
          'status': 'assigned',
          'assigned_at': '2026-04-24T19:15:00-07:00',
          'nfc_tag': {
            'id': 'tag_01',
            'uid_hex': '04AABB',
            'uid_fingerprint': '04AABB',
            'default_tag_type': 'player',
            'status': 'active',
            'display_label': 'Player 7',
          },
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_03',
          eventId: 'evt_01',
          guestRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replace Tag'), findsOneWidget);
    expect(find.text('Player 7'), findsOneWidget);
  });

  testWidgets('assigns a tag for an already checked-in eligible guest',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_06',
          'event_id': 'evt_01',
          'display_name': 'Faye Lim',
          'normalized_name': 'faye lim',
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
          guestId: 'gst_06',
          eventId: 'evt_01',
          guestRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assign Tag'), findsOneWidget);

    await tester.tap(find.text('Assign Tag'));
    await tester.pumpAndSettle();

    expect(repository.lastAssignedUid, '04AABB');
    expect(find.text('Replace Tag'), findsOneWidget);
    expect(find.text('Tag Assigned'), findsOneWidget);
  });

  testWidgets('replaces an existing tag for an eligible guest', (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_07',
          'event_id': 'evt_01',
          'display_name': 'Gwen Ma',
          'normalized_name': 'gwen ma',
          'attendance_status': 'checked_in',
          'cover_status': 'comped',
          'cover_amount_cents': 0,
          'is_comped': true,
          'has_scored_play': false,
        }),
        activeTagAssignment: GuestTagAssignmentSummary.fromJson(const {
          'assignment_id': 'asg_07',
          'event_id': 'evt_01',
          'event_guest_id': 'gst_07',
          'status': 'assigned',
          'assigned_at': '2026-04-24T19:15:00-07:00',
          'nfc_tag': {
            'id': 'tag_07',
            'uid_hex': 'OLDTAG',
            'uid_fingerprint': 'OLDTAG',
            'default_tag_type': 'player',
            'status': 'active',
            'display_label': 'Old Tag',
          },
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestDetailScreen(
          guestId: 'gst_07',
          eventId: 'evt_01',
          guestRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace Tag'));
    await tester.pumpAndSettle();

    expect(repository.lastReplacedUid, '04AABB');
    expect(find.text('Tag Assigned'), findsOneWidget);
  });

  testWidgets('opens manual tag entry and assigns a tag for an eligible guest',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_04',
          'event_id': 'evt_01',
          'display_name': 'Dee Wu',
          'normalized_name': 'dee wu',
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
          guestId: 'gst_04',
          eventId: 'evt_01',
          guestRepository: repository,
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In and Assign Tag'));
    await tester.pumpAndSettle();

    expect(repository.lastAssignedUid, '04AABB');
    expect(find.text('Replace Tag'), findsOneWidget);
    expect(find.text('Tag Assigned'), findsOneWidget);
  });

  testWidgets('shows manual UID entry flow for simulator scanning',
      (tester) async {
    final repository = _FakeGuestRepository(
      GuestDetailRecord(
        guest: EventGuestRecord.fromJson(const {
          'id': 'gst_05',
          'event_id': 'evt_01',
          'display_name': 'Evan Ho',
          'normalized_name': 'evan ho',
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
          guestId: 'gst_05',
          eventId: 'evt_01',
          guestRepository: repository,
          nfcService: const ManualEntryNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In and Assign Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Tag UID'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '04aa bb');
    await tester.tap(find.text('Use Tag'));
    await tester.pumpAndSettle();

    expect(repository.lastAssignedUid, '04AABB');
    expect(find.text('Replace Tag'), findsOneWidget);
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
            recordedAt: DateTime.parse('2026-04-24T19:10:00-07:00'),
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
            recordedAt: DateTime.parse('2026-04-24T19:00:00-07:00'),
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
          nfcService: const _FakeNfcService(),
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
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Cover Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Record Cover Entry'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, '2000');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Venmo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Paid after seating');
    await tester.tap(find.text('Save Cover Entry'));
    await tester.pumpAndSettle();

    expect(repository.lastRecordedAmountCents, 2000);
    expect(repository.lastRecordedMethod, CoverEntryMethod.venmo);
    expect(repository.lastRecordedNote, 'Paid after seating');
    expect(find.text('Paid after seating'), findsOneWidget);
  });
}
