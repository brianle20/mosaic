import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';

class _FakeEventRepository implements EventRepository {
  _FakeEventRepository(this.events);

  final List<EventRecord> events;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
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
  Future<EventRecord?> getEvent(String eventId) async {
    for (final event in events) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  @override
  Future<List<EventRecord>> listEvents() async => events;

  @override
  Future<List<EventRecord>> readCachedEvents() async => events;
}

void main() {
  testWidgets('renders an intentional empty state when no events exist',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(
          eventRepository: _FakeEventRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No events yet'), findsOneWidget);
    expect(
      find.text(
          'Create your first event to start check-in, seating, scoring, and prizes.'),
      findsOneWidget,
    );
    expect(find.text('Create Event'), findsOneWidget);
  });

  testWidgets('renders loaded events and create action', (tester) async {
    var signOutTapped = false;
    final repository = _FakeEventRepository([
      EventRecord.fromJson(const {
        'id': 'evt_01',
        'owner_user_id': 'usr_01',
        'title': 'Friday Night Mahjong',
        'timezone': 'America/Los_Angeles',
        'starts_at': '2026-04-24T19:00:00-07:00',
        'lifecycle_status': 'draft',
        'checkin_open': false,
        'scoring_open': false,
        'cover_charge_cents': 2000,
        'prize_budget_cents': 50000,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'prevailing_wind': 'east',
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(
          eventRepository: repository,
          onSignOut: () async {
            signOutTapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Friday Night Mahjong'), findsOneWidget);
    expect(find.text('Create Event'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(signOutTapped, isTrue);
  });
}
