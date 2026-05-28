import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';

void main() {
  test('removeGuest deletes the guest from the loaded roster', () async {
    final alice = _guest(id: 'gst_01', name: 'Alice Wong');
    final bob = _guest(id: 'gst_02', name: 'Bob Lee');
    final repository = _FakeGuestRepository([alice, bob]);
    final controller = GuestRosterController(guestRepository: repository);

    await controller.load('evt_01');
    await controller.removeGuest('gst_01');

    expect(repository.removedGuestIds, ['gst_01']);
    expect(controller.guests.map((guest) => guest.displayName), ['Bob Lee']);
  });
}

class _FakeGuestRepository extends ThrowingGuestRepository {
  _FakeGuestRepository(this._guests);

  final List<EventGuestRecord> _guests;
  final removedGuestIds = <String>[];

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async =>
      List<EventGuestRecord>.from(_guests);

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<void> removeGuest(String guestId) async {
    removedGuestIds.add(guestId);
    _guests.removeWhere((guest) => guest.id == guestId);
  }
}

EventGuestRecord _guest({
  required String id,
  required String name,
}) {
  return EventGuestRecord.fromJson({
    'id': id,
    'event_id': 'evt_01',
    'display_name': name,
    'normalized_name': name.toLowerCase(),
    'attendance_status': 'expected',
    'cover_status': 'unpaid',
    'cover_amount_cents': 0,
    'is_comped': false,
    'has_scored_play': false,
    'tournament_status': 'open_play_only',
  });
}
