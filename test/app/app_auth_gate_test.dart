import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/app/app.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.host});

  HostAuthUser? host;
  final StreamController<HostAuthUser?> controller =
      StreamController<HostAuthUser?>.broadcast();

  @override
  Stream<HostAuthUser?> authStateChanges() => controller.stream;

  @override
  HostAuthUser? get currentHost => host;

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    host = HostAuthUser(id: 'usr_01', email: email);
    controller.add(host);
    return host;
  }

  @override
  Future<void> signOut() async {
    host = null;
    controller.add(null);
  }
}

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

class _FakeGuestRepository implements GuestRepository {
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

class _FakeTableRepository implements TableRepository {
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

class _FakeSessionRepository implements SessionRepository {
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
          String sessionId) async =>
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

class _FakeLeaderboardRepository implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async =>
      const [];

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      const [];
}

class _FakePrizeRepository implements PrizeRepository {
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

class _FakeNfcService implements NfcService {
  const _FakeNfcService();

  @override
  Future<TagScanResult?> scanPlayerTagForAssignment(
      BuildContext context) async {
    return null;
  }

  @override
  Future<TagScanResult?> scanPlayerTagForSessionSeat(
    BuildContext context, {
    required String seatLabel,
  }) async {
    return null;
  }

  @override
  Future<TagScanResult?> scanTableTag(BuildContext context) async {
    return null;
  }
}

void main() {
  testWidgets('renders host sign in when signed out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: _FakeAuthRepository(),
          eventRepository: _FakeEventRepository(const []),
          guestRepository: _FakeGuestRepository(),
          tableRepository: _FakeTableRepository(),
          sessionRepository: _FakeSessionRepository(),
          leaderboardRepository: _FakeLeaderboardRepository(),
          prizeRepository: _FakePrizeRepository(),
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Host Sign In'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
  });

  testWidgets('renders event list when signed in', (tester) async {
    final authRepository = _FakeAuthRepository(
      host: const HostAuthUser(
        id: 'usr_01',
        email: 'brian.le1678@gmail.com',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: authRepository,
          eventRepository: _FakeEventRepository([
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
          ]),
          guestRepository: _FakeGuestRepository(),
          tableRepository: _FakeTableRepository(),
          sessionRepository: _FakeSessionRepository(),
          leaderboardRepository: _FakeLeaderboardRepository(),
          prizeRepository: _FakePrizeRepository(),
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Friday Night Mahjong'), findsOneWidget);
    expect(find.text('Host Sign In'), findsNothing);
  });

  testWidgets('returns to host sign in after sign out', (tester) async {
    final authRepository = _FakeAuthRepository(
      host: const HostAuthUser(
        id: 'usr_01',
        email: 'brian.le1678@gmail.com',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MosaicApp(
          authRepository: authRepository,
          eventRepository: _FakeEventRepository([
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
          ]),
          guestRepository: _FakeGuestRepository(),
          tableRepository: _FakeTableRepository(),
          sessionRepository: _FakeSessionRepository(),
          leaderboardRepository: _FakeLeaderboardRepository(),
          prizeRepository: _FakePrizeRepository(),
          nfcService: const _FakeNfcService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Host Sign In'), findsOneWidget);
    expect(find.text('Events'), findsNothing);
  });
}
