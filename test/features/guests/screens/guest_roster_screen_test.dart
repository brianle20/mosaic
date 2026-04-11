import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/screens/guest_roster_screen.dart';

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository(this.guests);

  final List<EventGuestRecord> guests;

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => guests;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      guests;

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders guests for an event', (tester) async {
    final repository = _FakeGuestRepository([
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
    ]);

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
  });
}
