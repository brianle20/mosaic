import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/controllers/guest_check_in_controller.dart';

void main() {
  test('cached guest detail is usable while remote revalidation is pending',
      () async {
    final remote = Completer<GuestDetailRecord?>();
    final repository = _FakeGuestRepository(
      cachedGuest: _guestDetail('Cached Player'),
      remoteDetail: remote,
    );
    final controller = GuestCheckInController(guestRepository: repository);

    final load = controller.load(
      eventId: 'evt_01',
      guestId: 'gst_01',
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.detail?.guest.displayName, 'Cached Player');
    expect(controller.isLoading, isFalse);

    remote.complete(_guestDetail('Remote Player'));
    await load;
    expect(controller.detail?.guest.displayName, 'Remote Player');
    controller.dispose();
  });

  test('disposed guest detail controller ignores late remote results', () async {
    final remote = Completer<GuestDetailRecord?>();
    final repository = _FakeGuestRepository(remoteDetail: remote);
    final controller = GuestCheckInController(guestRepository: repository);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    final load = controller.load(eventId: 'evt_01', guestId: 'gst_01');
    await Future<void>.delayed(Duration.zero);
    final notificationsBeforeDispose = notifications;
    controller.dispose();
    remote.complete(_guestDetail('Late Player'));
    await load;

    expect(notifications, notificationsBeforeDispose);
  });
}

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository({this.cachedGuest, this.remoteDetail});

  final GuestDetailRecord? cachedGuest;
  final Completer<GuestDetailRecord?>? remoteDetail;

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      cachedGuest == null ? const [] : [cachedGuest!.guest];

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) =>
      remoteDetail?.future ?? Future.value(cachedGuest);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

GuestDetailRecord _guestDetail(String name) {
  return GuestDetailRecord(
    guest: EventGuestRecord.fromJson({
      'id': 'gst_01',
      'event_id': 'evt_01',
      'display_name': name,
      'normalized_name': name.toLowerCase(),
      'attendance_status': 'checked_in',
      'cover_status': 'paid',
      'cover_amount_cents': 0,
      'is_comped': false,
      'has_scored_play': false,
    }),
  );
}
