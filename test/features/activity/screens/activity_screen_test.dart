import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/activity/screens/activity_screen.dart';

class _FakeActivityRepository implements ActivityRepository {
  _FakeActivityRepository(this.entriesByCategory);

  final Map<EventActivityCategory, List<EventActivityEntry>> entriesByCategory;
  EventActivityCategory lastLoadedCategory = EventActivityCategory.all;

  @override
  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  ) async {
    lastLoadedCategory = category;
    return entriesByCategory[category] ?? const [];
  }

  @override
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  ) async {
    return entriesByCategory[category] ?? const [];
  }
}

EventActivityEntry _entry({
  required String id,
  required EventActivityCategory category,
  required String summary,
  String? reason,
}) {
  return EventActivityEntry(
    id: id,
    eventId: 'evt_01',
    entityType: 'event',
    entityId: 'evt_01',
    action: 'start',
    category: category,
    summaryText: summary,
    metadataJson: const {},
    createdAt: DateTime.parse('2026-04-24T19:00:00-07:00'),
    reason: reason,
  );
}

void main() {
  testWidgets('renders newest-first activity entries and reason text', (
    tester,
  ) async {
    final repository = _FakeActivityRepository({
      EventActivityCategory.all: [
        _entry(
          id: 'act_02',
          category: EventActivityCategory.payments,
          summary: 'Recorded cover entry: cash 2000',
          reason: 'Paid at door',
        ),
        _entry(
          id: 'act_01',
          category: EventActivityCategory.event,
          summary: 'Started event',
        ),
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(
          eventId: 'evt_01',
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Recorded cover entry: cash 2000'), findsOneWidget);
    expect(find.text('Started event'), findsOneWidget);
    expect(find.text('Paid at door'), findsOneWidget);
  });

  testWidgets('switches category chips and reloads the feed', (tester) async {
    final repository = _FakeActivityRepository({
      EventActivityCategory.all: [
        _entry(
          id: 'act_01',
          category: EventActivityCategory.event,
          summary: 'Started event',
        ),
      ],
      EventActivityCategory.payments: [
        _entry(
          id: 'act_02',
          category: EventActivityCategory.payments,
          summary: 'Recorded cover entry: refund -500',
        ),
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(
          eventId: 'evt_01',
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Started event'), findsOneWidget);

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(repository.lastLoadedCategory, EventActivityCategory.payments);
    expect(find.text('Recorded cover entry: refund -500'), findsOneWidget);
    expect(find.text('Started event'), findsNothing);
  });

  testWidgets('shows an empty state when no activity exists', (tester) async {
    final repository = _FakeActivityRepository({
      EventActivityCategory.all: const [],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityScreen(
          eventId: 'evt_01',
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsOneWidget);
    expect(
      find.text(
          'Event actions, payments, sessions, and prize updates will appear here.'),
      findsOneWidget,
    );
  });
}
