import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository(
    List<EventGuestRecord> guests, {
    Map<String, GuestTagAssignmentSummary> activeAssignments = const {},
  })  : _guests = List<EventGuestRecord>.from(guests),
        _activeAssignments =
            Map<String, GuestTagAssignmentSummary>.from(activeAssignments);

  final List<EventGuestRecord> _guests;
  final Map<String, GuestTagAssignmentSummary> _activeAssignments;

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) async {
    final guest = _guestById(guestId);
    final assignment = GuestTagAssignmentSummary.fromJson({
      'assignment_id': 'asg_$guestId',
      'event_id': guest.eventId,
      'event_guest_id': guest.id,
      'status': 'assigned',
      'assigned_at': '2026-04-24T19:15:00-07:00',
      'nfc_tag': {
        'id': 'tag_$guestId',
        'uid_hex': scannedUid.toUpperCase(),
        'uid_fingerprint': scannedUid.toUpperCase(),
        'default_tag_type': 'player',
        'status': 'active',
        'display_label': displayLabel,
      },
    });
    _activeAssignments[guestId] = assignment;
    return GuestDetailRecord(
      guest: guest,
      activeTagAssignment: assignment,
    );
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) async {
    final guest = _guestById(guestId);
    final updatedGuest = EventGuestRecord(
      id: guest.id,
      eventId: guest.eventId,
      displayName: guest.displayName,
      normalizedName: guest.normalizedName,
      phoneE164: guest.phoneE164,
      emailLower: guest.emailLower,
      attendanceStatus: AttendanceStatus.checkedIn,
      coverStatus: guest.coverStatus,
      coverAmountCents: guest.coverAmountCents,
      isComped: guest.isComped,
      hasScoredPlay: guest.hasScoredPlay,
      note: guest.note,
      checkedInAt: DateTime.parse('2026-04-24T19:15:00-07:00'),
      rowVersion: guest.rowVersion,
    );
    _replaceGuest(updatedGuest);
    return GuestDetailRecord(
      guest: updatedGuest,
      activeTagAssignment: _activeAssignments[guestId],
    );
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async {
    final guest = _guestById(guestId);
    return GuestDetailRecord(
      guest: guest,
      activeTagAssignment: _activeAssignments[guestId],
    );
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => _guests;

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      _activeAssignments;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      _guests;

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    String? note,
  }) async {
    final guest = _guestById(guestId);
    return GuestDetailRecord(
      guest: guest,
      coverEntries: [
        GuestCoverEntryRecord(
          id: 'cov_$guestId',
          eventId: guest.eventId,
          eventGuestId: guest.id,
          amountCents: amountCents,
          method: method,
          recordedByUserId: 'usr_01',
          recordedAt: DateTime.parse('2026-04-24T19:20:00-07:00'),
          note: note,
          createdAt: DateTime.parse('2026-04-24T19:20:00-07:00'),
        ),
      ],
      activeTagAssignment: _activeAssignments[guestId],
    );
  }

  @override
  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) async {
    final updated = EventGuestRecord(
      id: input.id,
      eventId: input.eventId,
      displayName: input.displayName,
      normalizedName: input.normalizedName,
      phoneE164: input.phoneE164,
      emailLower: input.emailLower,
      attendanceStatus: _guestById(input.id).attendanceStatus,
      coverStatus: input.coverStatus,
      coverAmountCents: input.coverAmountCents,
      isComped: input.isComped,
      hasScoredPlay: _guestById(input.id).hasScoredPlay,
      note: input.note,
      checkedInAt: _guestById(input.id).checkedInAt,
      rowVersion: _guestById(input.id).rowVersion,
    );
    _replaceGuest(updated);
    return updated;
  }

  EventGuestRecord _guestById(String guestId) {
    return _guests.firstWhere((guest) => guest.id == guestId);
  }

  void _replaceGuest(EventGuestRecord guest) {
    final index = _guests.indexWhere((entry) => entry.id == guest.id);
    _guests[index] = guest;
  }
}

class _FakeNfcService implements NfcService {
  const _FakeNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
    BuildContext context,
  ) async {
    return const TagScanResult(
      rawUid: 'FASTTAG01',
      normalizedUid: 'FASTTAG01',
      isManualEntry: true,
    );
  }

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) {
    throw UnimplementedError();
  }
}

EventGuestRecord _guest({
  required String id,
  required String name,
  required AttendanceStatus attendanceStatus,
  required CoverStatus coverStatus,
  bool isComped = false,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': switch (attendanceStatus) {
      AttendanceStatus.expected => 'expected',
      AttendanceStatus.checkedIn => 'checked_in',
      AttendanceStatus.checkedOut => 'checked_out',
      AttendanceStatus.noShow => 'no_show',
    },
    'cover_status': switch (coverStatus) {
      CoverStatus.unpaid => 'unpaid',
      CoverStatus.paid => 'paid',
      CoverStatus.partial => 'partial',
      CoverStatus.comped => 'comped',
      CoverStatus.refunded => 'refunded',
    },
    'cover_amount_cents': 2000,
    'is_comped': isComped,
    'has_scored_play': false,
  });
}

Widget _buildRosterApp({
  required GuestRepository guestRepository,
  NfcService nfcService = const _FakeNfcService(),
}) {
  return MaterialApp(
    onGenerateRoute: (settings) {
      if (settings.name == AppRouter.guestDetailRoute) {
        return MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('Guest Detail Placeholder')),
          settings: settings,
        );
      }
      return null;
    },
    home: GuestRosterScreen(
      eventId: 'evt_01',
      eventTitle: 'Friday Night Mahjong',
      guestRepository: guestRepository,
      nfcService: nfcService,
    ),
  );
}

void main() {
  testWidgets('renders guests and row-specific quick actions', (tester) async {
    final repository = _FakeGuestRepository(
      [
        _guest(
          id: 'gst_unpaid',
          name: 'Uma',
          attendanceStatus: AttendanceStatus.expected,
          coverStatus: CoverStatus.unpaid,
        ),
        _guest(
          id: 'gst_ready',
          name: 'Pia',
          attendanceStatus: AttendanceStatus.expected,
          coverStatus: CoverStatus.paid,
        ),
        _guest(
          id: 'gst_tag',
          name: 'Tao',
          attendanceStatus: AttendanceStatus.checkedIn,
          coverStatus: CoverStatus.paid,
        ),
        _guest(
          id: 'gst_done',
          name: 'Gia',
          attendanceStatus: AttendanceStatus.checkedIn,
          coverStatus: CoverStatus.paid,
        ),
      ],
      activeAssignments: {
        'gst_done': GuestTagAssignmentSummary.fromJson(const {
          'assignment_id': 'asg_done',
          'event_id': 'evt_01',
          'event_guest_id': 'gst_done',
          'status': 'assigned',
          'assigned_at': '2026-04-24T19:15:00-07:00',
          'nfc_tag': {
            'id': 'tag_done',
            'uid_hex': 'FASTDONE',
            'uid_fingerprint': 'FASTDONE',
            'default_tag_type': 'player',
            'status': 'active',
          },
        }),
      },
    );

    await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Mark Paid'), findsOneWidget);
    expect(find.text('Mark Comped'), findsOneWidget);
    expect(find.text('Check In & Tag'), findsOneWidget);
    expect(find.text('Assign Tag'), findsOneWidget);
    expect(find.text('Add Cover Entry'), findsAtLeastNWidgets(3));
  });

  testWidgets('guest row still opens guest detail on tap', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('guest-row-gst_01')));
    await tester.pumpAndSettle();

    expect(find.text('Guest Detail Placeholder'), findsOneWidget);
  });

  testWidgets('mark paid updates the row and shows feedback', (tester) async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.unpaid,
      ),
    ]);

    await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark Paid'));
    await tester.pumpAndSettle();

    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Check In & Tag'), findsOneWidget);
    expect(find.text('Marked Alice Wong paid'), findsOneWidget);
  });

  testWidgets('mark comped updates the row and shows feedback', (tester) async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.partial,
      ),
    ]);

    await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark Comped'));
    await tester.pumpAndSettle();

    expect(find.text('Comped'), findsOneWidget);
    expect(find.text('Check In & Tag'), findsOneWidget);
    expect(find.text('Marked Alice Wong comped'), findsOneWidget);
  });

  testWidgets('check in and tag completes from the roster', (tester) async {
    final repository = _FakeGuestRepository([
      _guest(
        id: 'gst_01',
        name: 'Alice Wong',
        attendanceStatus: AttendanceStatus.expected,
        coverStatus: CoverStatus.paid,
      ),
    ]);

    await tester.pumpWidget(_buildRosterApp(guestRepository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In & Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Checked In'), findsOneWidget);
    expect(find.text('Tag Assigned'), findsOneWidget);
    expect(find.text('Assigned player tag to Alice Wong'), findsOneWidget);
  });

  testWidgets('assigns a tag for an already checked-in guest', (tester) async {
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

    await tester.tap(find.text('Assign Tag'));
    await tester.pumpAndSettle();

    expect(find.text('Tag Assigned'), findsOneWidget);
    expect(find.text('Assigned player tag to Alice Wong'), findsOneWidget);
  });

  testWidgets('adds a cover entry from the roster and stays in place',
      (tester) async {
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

    await tester.tap(find.text('Add Cover Entry'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Amount (cents)'),
      '2000',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Cover Entry'));
    await tester.pumpAndSettle();

    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Saved cover entry for Alice Wong'), findsOneWidget);
  });
}
