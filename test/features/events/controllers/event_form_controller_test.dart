import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import '../../../helpers/repository_fakes.dart';
import 'package:mosaic/features/events/controllers/event_form_controller.dart';
import 'package:mosaic/features/events/models/event_form_draft.dart';

class _CompleterEventRepository extends ThrowingEventRepository {
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

class _ImmediateEventRepository extends ThrowingEventRepository {
  CreateEventInput? capturedInput;
  UpdateEventInput? capturedUpdateInput;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) async {
    capturedInput = input;
    return _eventRecordFromInput(input);
  }

  @override
  Future<EventRecord> updateEventMetadata(UpdateEventInput input) async {
    capturedUpdateInput = input;
    return _eventRecordFromUpdateInput(input);
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

class _FailingEventRepository extends ThrowingEventRepository {
  const _FailingEventRepository(this.exception);

  final Object exception;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) async {
    throw exception;
  }
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

EventRecord _eventRecordFromUpdateInput(UpdateEventInput input) {
  return EventRecord.fromJson({
    'id': input.id,
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

  test('submit updates existing event metadata instead of creating', () async {
    final repository = _ImmediateEventRepository();
    final controller = EventFormController(eventRepository: repository);
    addTearDown(controller.dispose);

    final event = await controller.submit(_validDraft, eventId: 'evt_01');

    expect(event, isNotNull);
    expect(repository.capturedInput, isNull);
    expect(repository.capturedUpdateInput, isNotNull);
    expect(repository.capturedUpdateInput!.id, 'evt_01');
    expect(repository.capturedUpdateInput!.title, 'Friday Night Mahjong');
  });

  test('submit shows friendly message for event creation permission failures',
      () async {
    final controller = EventFormController(
      eventRepository: const _FailingEventRepository(
        'PostgrestException(message: new row violates row-level security '
        'policy for table "events", code: 42501, details: Forbidden, '
        'hint: null)',
      ),
    );
    addTearDown(controller.dispose);

    final event = await controller.submit(_validDraft);

    expect(event, isNull);
    expect(
      controller.submitError,
      'Only event owners can create events. Sign out and use an owner account.',
    );
    expect(controller.submitError, isNot(contains('PostgrestException')));
  });
}
