import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_form_controller.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';

class _CompleterEventRepository implements EventRepository {
  final createEventCompleter = Completer<EventRecord>();

  CreateEventInput? capturedInput;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    capturedInput = input;
    return createEventCompleter.future;
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
  Future<EventRecord> startEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async => null;

  @override
  Future<List<EventRecord>> listEvents() async => const [];

  @override
  Future<List<EventRecord>> readCachedEvents() async => const [];
}

class _ImmediateEventRepository implements EventRepository {
  CreateEventInput? capturedInput;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) async {
    capturedInput = input;
    return _eventRecordFromInput(input);
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
  Future<EventRecord> startEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> completeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async => null;

  @override
  Future<List<EventRecord>> listEvents() async => const [];

  @override
  Future<List<EventRecord>> readCachedEvents() async => const [];
}

final _validDraft = EventFormDraft(
  title: 'Friday Night Mahjong',
  timezone: 'America/Los_Angeles',
  startsAt: DateTime(2026, 5, 1, 19),
  coverChargeCents: 1500,
);

EventRecord _eventRecordFromInput(CreateEventInput input) {
  return EventRecord.fromJson({
    'id': 'evt_01',
    'owner_user_id': 'usr_01',
    'title': input.title,
    'timezone': input.timezone,
    'starts_at': input.startsAt.toIso8601String(),
    'lifecycle_status': 'draft',
    'checkin_open': false,
    'scoring_open': false,
    'cover_charge_cents': input.coverChargeCents,
    'default_ruleset_id': input.defaultRulesetId,
    'prevailing_wind': 'east',
    'venue_name': input.venueName,
    'venue_address': input.venueAddress,
    'description': input.description,
  });
}

void main() {
  test('submit returns event when repository completes after dispose',
      () async {
    final repository = _CompleterEventRepository();
    final controller = EventFormController(eventRepository: repository);

    final submitFuture = controller.submit(_validDraft);
    expect(controller.isSubmitting, isTrue);

    controller.dispose();
    repository.createEventCompleter.complete(
      _eventRecordFromInput(repository.capturedInput!),
    );

    final event = await submitFuture;

    expect(event, isNotNull);
    expect(event!.id, 'evt_01');
  });

  test('active submit toggles isSubmitting and returns event', () async {
    final repository = _ImmediateEventRepository();
    final controller = EventFormController(eventRepository: repository);
    addTearDown(controller.dispose);
    final isSubmittingStates = <bool>[];
    controller.addListener(() {
      isSubmittingStates.add(controller.isSubmitting);
    });

    final event = await controller.submit(_validDraft);

    expect(event, isNotNull);
    expect(event!.id, 'evt_01');
    expect(isSubmittingStates, [true, false]);
    expect(controller.isSubmitting, isFalse);
  });
}
