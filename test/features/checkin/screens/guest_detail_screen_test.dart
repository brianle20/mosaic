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
      activeTagAssignment: detail.activeTagAssignment,
    );
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => detail;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

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

    expect(find.textContaining('paid or comped'), findsOneWidget);
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
}
