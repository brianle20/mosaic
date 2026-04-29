import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/event_list_screen.dart';
import 'package:mosaic/widgets/status_chip.dart';

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

  testWidgets('event list uses the soft host shell and hero create action',
      (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_01',
        title: 'Friday Night Mahjong',
        startsAt: '2026-04-24T19:00:00-07:00',
        lifecycleStatus: 'draft',
        createdAt: '2026-04-24T17:00:00-07:00',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('softHostScaffold')), findsOneWidget);
    expect(find.byKey(const ValueKey('glassTitlePill-Events')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('eventsCreateHeroAction')), findsOneWidget);

    final createButton = find.byKey(const ValueKey('eventsCreateHeroAction'));
    final size = tester.getSize(createButton);
    expect(size.width, greaterThan(300));
    expect(size.height, greaterThanOrEqualTo(56));
  });

  testWidgets('event list sign out uses compact glass top action',
      (tester) async {
    var signOutTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(
          eventRepository: _FakeEventRepository(const []),
          onSignOut: () async {
            signOutTapped = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final signOutAction = find.byKey(const ValueKey('eventsSignOutAction'));
    expect(signOutAction, findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    final size = tester.getSize(signOutAction);
    expect(size.height, 40);

    await tester.tap(signOutAction);
    await tester.pumpAndSettle();

    expect(signOutTapped, isTrue);
  });

  testWidgets('event rows use shared list surfaces without Card widgets',
      (tester) async {
    final repository = _FakeEventRepository([
      eventRecord(
        id: 'evt_01',
        title: 'Friday Night Mahjong',
        startsAt: '2026-04-24T19:00:00-07:00',
        lifecycleStatus: 'draft',
        createdAt: '2026-04-24T17:00:00-07:00',
        venueName: 'Green Room',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: EventListScreen(eventRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    final rowSurface = find.byKey(const ValueKey('eventRowSurface-evt_01'));
    expect(rowSurface, findsOneWidget);
    expect(
      find.descendant(of: rowSurface, matching: find.byType(Card)),
      findsNothing,
    );
    expect(find.text('Friday Night Mahjong'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Setup'), findsOneWidget);
    expect(find.text('Green Room'), findsOneWidget);
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
    expect(find.widgetWithText(StatusChip, 'Setup'), findsOneWidget);
    expect(find.text('Apr 30, 12:30 AM'), findsOneWidget);
    expect(find.text('Green Room'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Cancelled'), findsOneWidget);
    expect(find.text('Apr 24, 7:00 PM'), findsOneWidget);
    expect(find.text('America/Los_Angeles • draft'), findsNothing);
    expect(find.text('America/Los_Angeles • cancelled'), findsNothing);
    expect(find.textContaining('Setup •'), findsNothing);
    expect(find.textContaining('Cancelled •'), findsNothing);

    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, 'Setup')).tone,
      StatusChipTone.warning,
    );
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, 'Cancelled'))
          .tone,
      StatusChipTone.danger,
    );
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

    expect(find.widgetWithText(StatusChip, 'Setup'), findsOneWidget);
    expect(find.text('Apr 30, 5:00 AM'), findsOneWidget);
    expect(find.text('Apr 29, 10:00 PM'), findsNothing);
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

    expect(find.widgetWithText(StatusChip, 'Check-In Open'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Scoring Open'), findsOneWidget);
    expect(find.text('Apr 29, 10:00 PM'), findsNWidgets(2));
    expect(find.textContaining('In Progress'), findsNothing);
    expect(find.textContaining('Check-In Open •'), findsNothing);
    expect(find.textContaining('Scoring Open •'), findsNothing);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, 'Check-In Open'))
          .tone,
      StatusChipTone.success,
    );
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, 'Scoring Open'))
          .tone,
      StatusChipTone.info,
    );
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

    final rowSurface = find.byKey(const ValueKey('eventRowSurface-evt_02'));
    final surfaceTop = tester.getTopLeft(rowSurface).dy;
    final surfaceBottom = tester.getBottomRight(rowSurface).dy;
    final contentTop = tester.getTopLeft(find.text('Test Event 2')).dy;
    final contentBottom = tester.getBottomRight(find.text('Test Venue')).dy;

    expect(
      (contentTop - surfaceTop - (surfaceBottom - contentBottom)).abs(),
      lessThanOrEqualTo(4),
    );
    expect(
      find.descendant(of: rowSurface, matching: find.byType(ListTile)),
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
