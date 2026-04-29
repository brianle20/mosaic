import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
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
      'default_ruleset_id': input.defaultRulesetId,
      'prevailing_wind': 'east',
      'venue_name': input.venueName,
      'venue_address': input.venueAddress,
      'description': input.description,
    });
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

void main() {
  testWidgets('shows host-facing fields without internal/raw details',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: _RecordingEventRepository(),
        ),
      ),
    );

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Starts'), findsOneWidget);
    expect(find.text('Venue Name'), findsOneWidget);
    expect(find.text('Venue Address'), findsOneWidget);
    expect(find.text('Cover Charge'), findsOneWidget);
    expect(find.text('Prize Budget'), findsNothing);

    expect(find.text('Timezone'), findsNothing);
    expect(find.text('Cover Charge (cents)'), findsNothing);
    expect(find.text('Prize Budget (cents)'), findsNothing);
    expect(find.textContaining(RegExp(r'\.\d{6}')), findsNothing);
  });

  testWidgets('shows dollar prefixes for money fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: _RecordingEventRepository(),
        ),
      ),
    );

    expect(find.text(r'$'), findsOneWidget);
  });

  testWidgets('formats money fields as cents while typing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: _RecordingEventRepository(),
        ),
      ),
    );

    EditableText moneyEditable() => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(createEventCoverChargeFieldKey),
            matching: find.byType(EditableText),
          ),
        );

    expect(moneyEditable().controller.text, '0.00');

    await tester.tap(find.byKey(createEventCoverChargeFieldKey));
    await tester.pump();
    tester.testTextInput.enterText('${moneyEditable().controller.text}5');
    await tester.pump();
    expect(moneyEditable().controller.text, '0.05');

    tester.testTextInput.enterText('${moneyEditable().controller.text}0');
    await tester.pump();
    expect(moneyEditable().controller.text, '0.50');

    tester.testTextInput.enterText('${moneyEditable().controller.text}0');
    await tester.pump();
    expect(moneyEditable().controller.text, '5.00');
  });

  testWidgets('empty title still validates with the existing message',
      (tester) async {
    final repository = _RecordingEventRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: repository,
        ),
      ),
    );

    await tester.tap(find.text('Save Event'));
    await tester.pump();

    expect(find.text('Title is required.'), findsOneWidget);
  });

  testWidgets('submits host-facing fields and dollar money amounts',
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

    await tester.enterText(
      find.byKey(createEventTitleFieldKey),
      'Friday Night Mahjong',
    );
    await tester.enterText(find.byKey(createEventVenueNameFieldKey), 'Club 88');
    await tester.enterText(
      find.byKey(createEventVenueAddressFieldKey),
      '123 Bamboo Ave',
    );
    await tester.enterText(find.byKey(createEventCoverChargeFieldKey), '1500');
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.capturedInput, isNotNull);
    expect(repository.capturedInput!.title, 'Friday Night Mahjong');
    expect(repository.capturedInput!.venueName, 'Club 88');
    expect(repository.capturedInput!.venueAddress, '123 Bamboo Ave');
    expect(repository.capturedInput!.coverChargeCents, 1500);
    expect(repository.capturedInput!.timezone, 'America/Los_Angeles');
    expect(repository.capturedInput!.startsAt.second, 0);
    expect(repository.capturedInput!.startsAt.millisecond, 0);
    expect(repository.capturedInput!.startsAt.microsecond, 0);
    expect(createdEvent, isNotNull);
  });

  testWidgets('blank money fields submit as zero cents', (tester) async {
    final repository = _RecordingEventRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: repository,
          onCreated: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(createEventTitleFieldKey), 'Open Play');
    await tester.enterText(find.byKey(createEventCoverChargeFieldKey), '');
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.capturedInput, isNotNull);
    expect(repository.capturedInput!.coverChargeCents, 0);
  });

  testWidgets('invalid money fields show friendly validation messages',
      (tester) async {
    final repository = _RecordingEventRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: repository,
        ),
      ),
    );

    await tester.enterText(find.byKey(createEventTitleFieldKey), 'Open Play');
    await tester.enterText(find.byKey(createEventCoverChargeFieldKey), '-1');
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pump();

    expect(find.text('Amount must be zero or more.'), findsOneWidget);
    expect(repository.capturedInput, isNull);
  });

  testWidgets(
      'tapping Starts opens date and time pickers then updates startsAt',
      (tester) async {
    final repository = _RecordingEventRepository();
    final targetDate = DateTime.now();

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(
          eventRepository: repository,
          onCreated: (_) {},
        ),
      ),
    );

    await tester.enterText(find.byKey(createEventTitleFieldKey), 'Open Play');
    await tester.tap(find.byKey(createEventStartsTileKey));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    final targetDay = find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('${targetDate.day}'),
    );
    await tester.tap(targetDay.last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.capturedInput, isNotNull);
    expect(repository.capturedInput!.startsAt.year, targetDate.year);
    expect(repository.capturedInput!.startsAt.month, targetDate.month);
    expect(repository.capturedInput!.startsAt.day, targetDate.day);
  });

  testWidgets('successful submit navigates to the created event dashboard',
      (tester) async {
    final repository = _RecordingEventRepository();
    EventDashboardArgs? capturedArgs;

    await tester.pumpWidget(
      MaterialApp(
        home: CreateEventScreen(eventRepository: repository),
        onGenerateRoute: (settings) {
          if (settings.name == AppRouter.eventDashboardRoute) {
            capturedArgs = settings.arguments as EventDashboardArgs;
            return MaterialPageRoute<void>(
              builder: (_) => const Text('Event dashboard'),
              settings: settings,
            );
          }

          return null;
        },
      ),
    );

    await tester.enterText(find.byKey(createEventTitleFieldKey), 'Open Play');
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(capturedArgs, isNotNull);
    expect(capturedArgs!.eventId, 'evt_01');
    expect(find.text('Event dashboard'), findsOneWidget);
  });
}
