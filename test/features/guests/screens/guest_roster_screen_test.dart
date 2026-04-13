import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository(this.guests, {this.activeAssignments = const {}});

  final List<EventGuestRecord> guests;
  final Map<String, GuestTagAssignmentSummary> activeAssignments;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      activeAssignments;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

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
  }) {
    throw UnimplementedError();
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
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders guests for an event', (tester) async {
    final repository = _FakeGuestRepository(
      [
        EventGuestRecord.fromJson(const {
          'id': 'gst_01',
          'event_id': 'evt_01',
          'display_name': 'Alice Wong',
          'normalized_name': 'alice wong',
          'attendance_status': 'checked_in',
          'cover_status': 'paid',
          'cover_amount_cents': 2000,
          'is_comped': false,
          'has_scored_play': false,
        }),
      ],
      activeAssignments: {
        'gst_01': GuestTagAssignmentSummary.fromJson(const {
          'assignment_id': 'asg_01',
          'event_id': 'evt_01',
          'event_guest_id': 'gst_01',
          'status': 'assigned',
          'assigned_at': '2026-04-24T19:15:00-07:00',
          'nfc_tag': {
            'id': 'tag_01',
            'uid_hex': '04AABB',
            'uid_fingerprint': '04AABB',
            'default_tag_type': 'player',
            'status': 'active',
          },
        }),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: GuestRosterScreen(
          eventId: 'evt_01',
          eventTitle: 'Friday Night Mahjong',
          guestRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('Alice Wong'), findsOneWidget);
    expect(find.textContaining('paid'), findsOneWidget);
    expect(find.text('Tag Assigned'), findsOneWidget);
  });
}
