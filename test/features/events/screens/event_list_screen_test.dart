import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
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
  Future<EventRecord?> getEvent(String eventId) async {
    for (final event in events) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  @override
  Future<List<EventRecord>> listEvents() async =>
      List<EventRecord>.from(events);

  @override
  Future<List<EventRecord>> readCachedEvents() async =>
      List<EventRecord>.from(events);
}

void main() {
  EventRecord eventRecord({
    required String id,
    required String title,
    required String startsAt,
    required String lifecycleStatus,
    required String createdAt,
    String timezone = 'America/Los_Angeles',
    String? venueName,
    String? venueAddress,
    bool checkinOpen = false,
    bool scoringOpen = false,
  }) {
    return EventRecord.fromJson({
      'id': id,
      'owner_user_id': 'usr_01',
      'title': title,
      'venue_name': venueName,
      'venue_address': venueAddress,
      'timezone': timezone,
      'starts_at': startsAt,
      'lifecycle_status': lifecycleStatus,
      'checkin_open': checkinOpen,
      'scoring_open': scoringOpen,
      'cover_charge_cents': 2000,
      'default_ruleset_id': 'HK_STANDARD_V1',
      'prevailing_wind': 'east',
      'created_at': createdAt,
    });
  }

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

  testWidgets('sorts newest-created first and shows human tile details',
      (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_01',
        title: 'Test Event 1',
        startsAt: '2026-04-24T19:00:00-07:00',
        lifecycleStatus: 'cancelled',
        createdAt: '2026-04-24T17:00:00-07:00',
      ),
      eventRecord(
        id: 'evt_02',
        title: 'Test Event 2',
        startsAt: '2026-04-30T00:30:00-07:00',
        lifecycleStatus: 'draft',
        createdAt: '2026-04-29T14:40:00-07:00',
        venueName: 'Green Room',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Test Event 2')).dy,
      lessThan(tester.getTopLeft(find.text('Test Event 1')).dy),
    );
    expect(
      find.text('Setup • Apr 30, 12:30 AM'),
      findsOneWidget,
    );
    expect(find.text('Green Room'), findsOneWidget);
    expect(find.text('Cancelled • Apr 24, 7:00 PM'), findsOneWidget);
    expect(find.text('America/Los_Angeles • draft'), findsNothing);
    expect(find.text('America/Los_Angeles • cancelled'), findsNothing);
  });

  testWidgets('formats event starts in the event timezone', (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_02',
        title: 'Pacific Event',
        startsAt: '2026-04-30T05:00:00Z',
        timezone: 'UTC',
        lifecycleStatus: 'draft',
        createdAt: '2026-04-29T14:40:00-07:00',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Setup • Apr 30, 5:00 AM'), findsOneWidget);
    expect(find.text('Setup • Apr 29, 10:00 PM'), findsNothing);
  });

  testWidgets('event tiles describe active operational state', (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_02',
        title: 'Check-In Event',
        startsAt: '2026-04-30T05:00:00Z',
        lifecycleStatus: 'active',
        createdAt: '2026-04-29T14:40:00-07:00',
        checkinOpen: true,
      ),
      eventRecord(
        id: 'evt_03',
        title: 'Scoring Event',
        startsAt: '2026-04-30T05:00:00Z',
        lifecycleStatus: 'active',
        createdAt: '2026-04-29T14:41:00-07:00',
        checkinOpen: true,
        scoringOpen: true,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check-In Open • Apr 29, 10:00 PM'), findsOneWidget);
    expect(find.text('Scoring Open • Apr 29, 10:00 PM'), findsOneWidget);
    expect(find.textContaining('In Progress'), findsNothing);
  });

  testWidgets('event tile content has balanced vertical padding',
      (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_02',
        title: 'Test Event 2',
        startsAt: '2026-04-29T19:00:00-07:00',
        lifecycleStatus: 'draft',
        createdAt: '2026-04-29T14:40:00-07:00',
        venueName: 'Test Venue',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('Test Event 2'),
      matching: find.byType(Card),
    );
    final cardTop = tester.getTopLeft(cardFinder).dy;
    final cardBottom = tester.getBottomRight(cardFinder).dy;
    final contentTop = tester.getTopLeft(find.text('Test Event 2')).dy;
    final contentBottom = tester.getBottomRight(find.text('Test Venue')).dy;

    expect(
      (contentTop - cardTop - (cardBottom - contentBottom)).abs(),
      lessThanOrEqualTo(4),
    );
    expect(
      find.descendant(of: cardFinder, matching: find.byType(ListTile)),
      findsNothing,
    );
  });

  testWidgets('refreshes events after returning from an event dashboard',
      (tester) async {
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
        'default_ruleset_id': 'HK_STANDARD_V1',
        'prevailing_wind': 'east',
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.eventDashboardRoute) {
            return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    repository.events.clear();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Delete and return'),
                ),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Friday Night Mahjong'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete and return'));
    await tester.pumpAndSettle();

    expect(find.text('Friday Night Mahjong'), findsNothing);
    expect(find.text('No events yet'), findsOneWidget);
  });

  testWidgets('refreshes events after returning from create event',
      (tester) async {
    final repository = _FakeEventRepository([
      EventRecord.fromJson(const {
        'id': 'evt_01',
        'owner_user_id': 'usr_01',
        'title': 'Test Event 1',
        'timezone': 'America/Los_Angeles',
        'starts_at': '2026-04-24T19:00:00-07:00',
        'lifecycle_status': 'cancelled',
        'checkin_open': false,
        'scoring_open': false,
        'cover_charge_cents': 2000,
        'default_ruleset_id': 'HK_STANDARD_V1',
        'prevailing_wind': 'east',
      }),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.createEventRoute) {
            return MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () {
                    repository.events.add(
                      EventRecord.fromJson(const {
                        'id': 'evt_02',
                        'owner_user_id': 'usr_01',
                        'title': 'Test Event 2',
                        'timezone': 'America/Los_Angeles',
                        'starts_at': '2026-04-25T19:00:00-07:00',
                        'lifecycle_status': 'draft',
                        'checkin_open': false,
                        'scoring_open': false,
                        'cover_charge_cents': 2500,
                        'default_ruleset_id': 'HK_STANDARD_V1',
                        'prevailing_wind': 'east',
                      }),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text('Create and return'),
                ),
              ),
            );
          }

          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Event 1'), findsOneWidget);
    expect(find.text('Test Event 2'), findsNothing);

    await tester.tap(find.text('Create Event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create and return'));
    await tester.pumpAndSettle();

    expect(find.text('Test Event 1'), findsOneWidget);
    expect(find.text('Test Event 2'), findsOneWidget);
  });
}
