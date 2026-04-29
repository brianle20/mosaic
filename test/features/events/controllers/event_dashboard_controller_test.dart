import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository({
    required this.cachedEvents,
    this.eventLoader,
  });

  final List<EventRecord> cachedEvents;
  final Future<EventRecord?> Function(String eventId)? eventLoader;
  EventRecord Function(String eventId)? cancelHandler;
  EventRecord Function(String eventId)? revertToDraftHandler;
  void Function(String eventId)? deleteHandler;

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> cancelEvent(String eventId) async {
    final handler = cancelHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> revertEventToDraft(String eventId) async {
    final handler = revertToDraftHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    return handler(eventId);
  }

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    final handler = deleteHandler;
    if (handler == null) {
      throw UnimplementedError();
    }
    handler(eventId);
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async {
    final loader = eventLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedEvents.where((event) => event.id == eventId).firstOrNull;
  }

  @override
  Future<List<EventRecord>> listEvents() {
    throw UnimplementedError();
  }

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

class _FakeGuestRepository implements GuestRepository {
  _FakeGuestRepository({
    required this.cachedGuests,
    this.guestLoader,
  });

  final List<EventGuestRecord> cachedGuests;
  final Future<List<EventGuestRecord>> Function(String eventId)? guestLoader;

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
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async {
    final loader = guestLoader;
    if (loader != null) {
      return loader(eventId);
    }
    return cachedGuests;
  }

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      cachedGuests;

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId) {
    throw UnimplementedError();
  }

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
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
  test('loads cached dashboard data when remote fetches fail', () async {
    final cachedEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'prize_budget_cents': 50000,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'prevailing_wind': 'east',
    });
    final cachedGuest = EventGuestRecord.fromJson(const {
      'id': 'gst_01',
      'event_id': 'evt_01',
      'display_name': 'Alice Wong',
      'normalized_name': 'alice wong',
      'attendance_status': 'expected',
      'cover_status': 'paid',
      'cover_amount_cents': 2000,
      'is_comped': false,
      'has_scored_play': false,
    });

    final controller = EventDashboardController(
      eventRepository: _FakeEventRepository(
        cachedEvents: [cachedEvent],
        eventLoader: (_) async => throw Exception('event fetch failed'),
      ),
      guestRepository: _FakeGuestRepository(
        cachedGuests: [cachedGuest],
        guestLoader: (_) async => throw Exception('guest fetch failed'),
      ),
    );

    await controller.load('evt_01');

    expect(controller.event?.id, 'evt_01');
    expect(controller.guestCount, 1);
    expect(controller.error, isNull);
  });

  test('cancelEvent updates the event to cancelled', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'prize_budget_cents': 50000,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.cancelHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'cancelled',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.cancelEvent();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.cancelled);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });

  test('deleteEvent removes a draft event', () async {
    final draftEvent = EventRecord.fromJson(const {
      'id': 'evt_00',
      'owner_user_id': 'usr_01',
      'title': 'Draft Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'draft',
      'checkin_open': false,
      'scoring_open': false,
      'cover_charge_cents': 2000,
      'prize_budget_cents': 50000,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'prevailing_wind': 'east',
    });
    var deletedEventId = '';
    final repository = _FakeEventRepository(cachedEvents: [draftEvent]);
    repository.deleteHandler = (eventId) {
      deletedEventId = eventId;
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_00');

    final deleted = await controller.deleteEvent();

    expect(deleted, isTrue);
    expect(deletedEventId, 'evt_00');
    expect(controller.event, isNull);
    expect(controller.lifecycleError, isNull);
  });

  test('revertToDraft updates an active event to draft', () async {
    final activeEvent = EventRecord.fromJson(const {
      'id': 'evt_01',
      'owner_user_id': 'usr_01',
      'title': 'Friday Night Mahjong',
      'timezone': 'America/Los_Angeles',
      'starts_at': '2026-04-24T19:00:00-07:00',
      'lifecycle_status': 'active',
      'checkin_open': true,
      'scoring_open': true,
      'cover_charge_cents': 2000,
      'prize_budget_cents': 50000,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'prevailing_wind': 'east',
    });
    final repository = _FakeEventRepository(cachedEvents: [activeEvent]);
    repository.revertToDraftHandler = (eventId) {
      expect(eventId, 'evt_01');
      return EventRecord.fromJson({
        ...activeEvent.toJson(),
        'lifecycle_status': 'draft',
        'checkin_open': false,
        'scoring_open': false,
      });
    };
    final controller = EventDashboardController(
      eventRepository: repository,
      guestRepository: _FakeGuestRepository(cachedGuests: const []),
    );
    await controller.load('evt_01');

    await controller.revertToDraft();

    expect(controller.event?.lifecycleStatus, EventLifecycleStatus.draft);
    expect(controller.event?.checkinOpen, isFalse);
    expect(controller.event?.scoringOpen, isFalse);
    expect(controller.lifecycleError, isNull);
  });
}
