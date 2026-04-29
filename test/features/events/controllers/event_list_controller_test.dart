import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_list_controller.dart';

void main() {
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

class _FakeEventRepository implements EventRepository {
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
