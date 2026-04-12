import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/screens/event_dashboard_screen.dart';
import 'package:mosaic/features/prizes/screens/prize_plan_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _EventRepository implements EventRepository {
  _EventRepository(
    this.event, {
    this.onComplete,
    this.onFinalize,
  });

  EventRecord event;
  final Future<EventRecord> Function(String eventId)? onComplete;
  final Future<EventRecord> Function(String eventId)? onFinalize;

  @override
  Future<EventRecord> createEvent(CreateEventInput input) {
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

  testWidgets('prizes action routes into the prize plan screen', (
    tester,
  ) async {
    final router = AppRouter(
      eventRepository: _EventRepository(activeEvent),
      guestRepository: _GuestRepository(),
      tableRepository: _TableRepository(),
      sessionRepository: _SessionRepository(),
      leaderboardRepository: _LeaderboardRepository(),
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

    expect(find.text('This event is finalized.'), findsOneWidget);
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
        '1 active or paused session(s) must be ended before changing the event lifecycle.',
      ),
      findsOneWidget,
    );
  });
}
