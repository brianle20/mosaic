import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/activity/screens/activity_screen.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _EventRepository implements EventRepository {
  _EventRepository(
    this.event, {
    this.onComplete,
    this.onFinalize,
    this.onStart,
    this.onSetOperationalFlags,
  });

  EventRecord event;
  final Future<EventRecord> Function(String eventId)? onComplete;
  final Future<EventRecord> Function(String eventId)? onFinalize;
  final Future<EventRecord> Function(String eventId)? onStart;
  final Future<EventRecord> Function(
    String eventId,
    bool checkinOpen,
    bool scoringOpen,
  )? onSetOperationalFlags;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
    throw UnimplementedError();
  }

  @override
  Future<EventRecord> startEvent(String eventId) async {
    final handler = onStart;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) async {
    final handler = onSetOperationalFlags;
    if (handler != null) {
      event = await handler(eventId, checkinOpen, scoringOpen);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> completeEvent(String eventId) async {
    final handler = onComplete;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord> finalizeEvent(String eventId) async {
    final handler = onFinalize;
    if (handler != null) {
      event = await handler(eventId);
      return event;
    }

    throw UnimplementedError();
  }

  @override
  Future<EventRecord?> getEvent(String eventId) async =>
      event.id == eventId ? event : null;

  @override
  Future<List<EventRecord>> listEvents() async => [event];

  @override
  Future<List<EventRecord>> readCachedEvents() async => [event];
}

class _GuestRepository implements GuestRepository {
  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

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
  Future<GuestDetailRecord?> getGuestDetail(String guestId) async => null;

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) async => const [];

  @override
  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  ) async =>
      const {};

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) async =>
      const [];

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) async =>
      const [];

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
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

class _LeaderboardRepository implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      const [];

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      const [];
}

class _ActivityRepository implements ActivityRepository {
  @override
  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  ) async =>
      const [];

  @override
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  ) async =>
      const [];
}

class _PrizeRepository implements PrizeRepository {
  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  }) async =>
      null;

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) async =>
      const [];

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) async =>
      const [];

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) async => null;

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(
    String eventId,
  ) async =>
      const [];

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) {
    throw UnimplementedError();
  }

  @override
  Future<PrizeAwardRecord> voidPrizeAward({
    required String awardId,
    String? paidNote,
  }) {
    throw UnimplementedError();
  }
}

class _TableRepository implements TableRepository {
  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<EventTableRecord>> listTables(String eventId) async => const [];

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) async =>
      const [];

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) {
    throw UnimplementedError();
  }
}

class _SessionRepository implements SessionRepository {
  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(
    String sessionId,
  ) async =>
      null;

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) async =>
      const [];

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) {
    throw UnimplementedError();
  }

  @override
  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input) {
    throw UnimplementedError();
  }

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) {
    throw UnimplementedError();
  }
}

class _NfcService implements NfcService {
  const _NfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
    BuildContext context,
  ) async =>
      null;

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async =>
      null;

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async => null;
}

void main() {
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
  final completedEvent = EventRecord.fromJson(const {
    'id': 'evt_02',
    'owner_user_id': 'usr_01',
    'title': 'Completed Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'completed',
    'checkin_open': true,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'prize_budget_cents': 50000,
    'default_ruleset_id': 'HK_STANDARD_V1',
    'prevailing_wind': 'east',
  });
  final finalizedEvent = EventRecord.fromJson(const {
    'id': 'evt_03',
    'owner_user_id': 'usr_01',
    'title': 'Finalized Friday Night Mahjong',
    'timezone': 'America/Los_Angeles',
    'starts_at': '2026-04-24T19:00:00-07:00',
    'lifecycle_status': 'finalized',
    'checkin_open': false,
    'scoring_open': false,
    'cover_charge_cents': 2000,
    'prize_budget_cents': 50000,
    'default_ruleset_id': 'HK_STANDARD_V1',
    'prevailing_wind': 'east',
  });

  final activeCheckinOnlyEvent = EventRecord.fromJson(const {
    'id': 'evt_04',
    'owner_user_id': 'usr_01',
    'title': 'Live Friday Night Mahjong',
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

  testWidgets('dashboard exposes a prizes action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prizes'), findsOneWidget);
  });

  testWidgets('dashboard exposes an activity action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity'), findsOneWidget);
  });

  testWidgets('prizes action routes into the prize plan screen', (
    tester,
  ) async {
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      nfcService: const _NfcService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prizes'));
    await tester.pumpAndSettle();

    expect(find.byType(PrizePlanScreen), findsOneWidget);
    expect(find.text('Prize Budget'), findsOneWidget);
    expect(find.text('50000 cents'), findsOneWidget);
  });

  testWidgets('activity action routes into the activity screen',
      (tester) async {
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
      activityRepository: _ActivityRepository(),
      prizeRepository: _PrizeRepository(),
      nfcService: const _NfcService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();

    expect(find.byType(ActivityScreen), findsOneWidget);
  });

  testWidgets('active event shows Complete Event action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(activeEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Complete Event'), findsOneWidget);
    expect(find.text('Finalize Event'), findsNothing);
  });

  testWidgets('draft event shows Start Event action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(
            draftEvent,
            onStart: (_) async => activeCheckinOnlyEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start Event'), findsOneWidget);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Event Phase'), findsOneWidget);
    expect(find.text('Ready to Start'), findsOneWidget);
    expect(
      find.text('Finish setup, then start the event to open check-in.'),
      findsOneWidget,
    );
  });

  testWidgets('starting a draft event enables live controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_00'),
          eventRepository: _EventRepository(
            draftEvent,
            onStart: (_) async => activeCheckinOnlyEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start Event'));
    await tester.pumpAndSettle();

    expect(find.text('Event Phase'), findsOneWidget);
    expect(find.text('Live Event'), findsOneWidget);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Closed'), findsOneWidget);
    expect(find.text('Close Check-In'), findsOneWidget);
    expect(find.text('Open Scoring'), findsOneWidget);
  });

  testWidgets('active event exposes operational flag actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(
            activeCheckinOnlyEvent,
            onSetOperationalFlags: (_, checkinOpen, scoringOpen) async {
              return EventRecord.fromJson({
                ...activeCheckinOnlyEvent.toJson(),
                'checkin_open': checkinOpen,
                'scoring_open': scoringOpen,
              });
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Operations'), findsOneWidget);
    expect(find.text('Check-In Open'), findsOneWidget);
    expect(find.text('Scoring Closed'), findsOneWidget);
    expect(find.text('Close Check-In'), findsOneWidget);
    expect(find.text('Open Scoring'), findsOneWidget);

    await tester.tap(find.text('Open Scoring'));
    await tester.pumpAndSettle();

    expect(find.text('Scoring Open'), findsOneWidget);
    expect(find.text('Close Scoring'), findsOneWidget);
  });

  testWidgets('completed event shows Finalize Event action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_02'),
          eventRepository: _EventRepository(
            completedEvent,
            onFinalize: (_) async => finalizedEvent,
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Finalize Event'), findsOneWidget);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Review Before Finalizing'), findsOneWidget);
    expect(
      find.text('Review standings and locked prizes before finalizing.'),
      findsOneWidget,
    );
  });

  testWidgets('finalized event hides live operation actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_03'),
          eventRepository: _EventRepository(finalizedEvent),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Results Locked'), findsOneWidget);
    expect(
      find.text('Standings and awards are locked for this event.'),
      findsOneWidget,
    );
    expect(find.text('Guests'), findsNothing);
    expect(find.text('Tables'), findsNothing);
    expect(find.text('Add Guest'), findsNothing);
    expect(find.text('Complete Event'), findsNothing);
    expect(find.text('Finalize Event'), findsNothing);
  });

  testWidgets('blocked lifecycle error renders when completion fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_01'),
          eventRepository: _EventRepository(
            activeEvent,
            onComplete: (_) async {
              throw StateError(
                '1 active or paused session(s) must be ended before changing the event lifecycle.',
              );
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Complete Event'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'End all active or paused sessions before changing the event phase.'),
      findsOneWidget,
    );
  });

  testWidgets('blocked operational flag error renders when update fails',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDashboardScreen(
          args: const EventDashboardArgs(eventId: 'evt_04'),
          eventRepository: _EventRepository(
            activeCheckinOnlyEvent,
            onSetOperationalFlags: (_, __, ___) async {
              throw StateError(
                  'Scoring can only open while the event is active.');
            },
          ),
          guestRepository: _GuestRepository(),
          leaderboardRepository: _LeaderboardRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Scoring'));
    await tester.pumpAndSettle();

    expect(
      find.text('Scoring can only open while the event is active.'),
      findsOneWidget,
    );
  });
}
