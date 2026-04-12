import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/create_event_screen.dart';

class _RecordingEventRepository implements EventRepository {
  CreateEventInput? capturedInput;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) async {
    capturedInput = input;
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
      'prize_budget_cents': input.prizeBudgetCents,
      'default_ruleset_id': input.defaultRulesetId,
      'prevailing_wind': 'east',
      'venue_name': input.venueName,
      'venue_address': input.venueAddress,
      'description': input.description,
      'prize_budget_note': input.prizeBudgetNote,
    });
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

void main() {
  testWidgets('shows validation feedback and submits valid data',
      (tester) async {
    final repository = _RecordingEventRepository();
    EventRecord? createdEvent;

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: repository,
          onCreated: (event) => createdEvent = event,
        ),
      ),
    );

    await tester.tap(find.text('Save Event'));
    await tester.pump();
    expect(find.text('Title is required.'), findsOneWidget);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'Friday Night Mahjong');
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.capturedInput, isNotNull);
    expect(repository.capturedInput!.title, 'Friday Night Mahjong');
    expect(createdEvent, isNotNull);
  });
}
