import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/events/controllers/event_list_controller.dart';

void main() {
  test('staff-only access cannot create events and exposes event role', () {
    final controller = EventListController(
      eventRepository: _FakeEventRepository(
        cachedEvents: const <EventRecord>[],
        remoteEventsFuture: Future.value(const <EventRecord>[]),
      ),
      accessState: const MosaicAccessState(
        userId: 'usr_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Friday Night Mahjong',
            role: MosaicAccessRole.qualificationScorer,
          ),
        ],
      ),
    );

    expect(controller.canCreateEvents, isFalse);
    expect(
      controller.roleForEvent('evt_01'),
      MosaicAccessRole.qualificationScorer,
    );
  });

  test('staff access filters cached and remote events to allowed ids',
      () async {
    final allowed = _eventRecord('evt_01', 'Allowed Event');
    final denied = _eventRecord('evt_02', 'Denied Event');
    final controller = EventListController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [allowed, denied],
        remoteEventsFuture: Future.value([denied, allowed]),
      ),
      accessState: const MosaicAccessState(
        userId: 'usr_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Allowed Event',
            role: MosaicAccessRole.eventScorer,
          ),
        ],
      ),
    );

    await controller.load();

    expect(controller.events, [allowed]);
    expect(controller.roleForEvent('evt_02'), isNull);
  });

  test('owner access includes newly owned events missing from access snapshot',
      () async {
    final existing = _eventRecord('evt_01', 'Existing Event');
    final copied = _eventRecord('evt_02', 'Copied Event');
    final controller = EventListController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [existing],
        remoteEventsFuture: Future.value([copied, existing]),
      ),
      accessState: const MosaicAccessState(
        userId: 'owner_01',
        isActive: true,
        events: [
          MosaicAccessEvent(
            eventId: 'evt_01',
            title: 'Existing Event',
            role: MosaicAccessRole.owner,
          ),
        ],
      ),
    );

    await controller.load();

    expect(controller.events, [copied, existing]);
    expect(controller.roleForEvent('evt_02'), MosaicAccessRole.owner);
  });

  test('load does not notify after dispose while async work is in flight',
      () async {
    final completer = Completer<List<EventRecord>>();
    final controller = EventListController(
      eventRepository: _FakeEventRepository(
        cachedEvents: const <EventRecord>[],
        remoteEventsFuture: completer.future,
      ),
    );

    final future = controller.load();
    controller.dispose();
    completer.complete(const <EventRecord>[]);

    await expectLater(future, completes);
  });
}

EventRecord _eventRecord(String id, String title) {
  return EventRecord.fromJson({
    'id': id,
    'owner_user_id': 'owner_01',
    'title': title,
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-05-24T19:00:00-07:00',
    'lifecycle_status': 'active',
    'checkin_open': true,
    'scoring_open': true,
    'current_scoring_phase': 'qualification',
    'cover_charge_cents': 2000,
    'default_ruleset_id': 'HK_STANDARD',
    'prevailing_wind': 'east',
  });
}

class _FakeEventRepository extends ThrowingEventRepository {
  _FakeEventRepository({
    required this.cachedEvents,
    required this.remoteEventsFuture,
  });

  final List<EventRecord> cachedEvents;
  final Future<List<EventRecord>> remoteEventsFuture;

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventRecord>> listEvents() => remoteEventsFuture;

  @override
  Future<List<EventRecord>> readCachedEvents() async => cachedEvents;

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> startEvent(String eventId) {
    throw UnimplementedError();
  }
}
