import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/ruleset_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/tag_models.dart';
import 'package:mosaic/data/models/table_models.dart';

abstract interface class AuthRepository {
  HostAuthUser? get currentHost;

  Stream<HostAuthUser?> authStateChanges();

  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

abstract interface class EventRepository {
  Future<List<EventRecord>> readCachedEvents();

  Future<List<EventRecord>> listEvents();

  Future<EventRecord?> getEvent(String eventId);

  Future<EventRecord> createEvent(CreateEventInput input);

  Future<EventRecord> startEvent(String eventId);

  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  });

  Future<EventRecord> completeEvent(String eventId);

  Future<EventRecord> finalizeEvent(String eventId);

  Future<EventRecord> cancelEvent(String eventId);

  Future<EventRecord> revertEventToDraft(String eventId);

  Future<void> deleteEvent(String eventId);
}

abstract interface class GuestRepository {
  Future<List<EventGuestRecord>> readCachedGuests(String eventId);

  Future<List<EventGuestRecord>> listGuests(String eventId);

  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  );

  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId);

  Future<Map<String, GuestTagAssignmentSummary>> listActiveTagAssignments(
    String eventId,
  );

  Future<GuestDetailRecord?> getGuestDetail(String guestId);

  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  );

  Future<EventGuestRecord> createGuest(CreateGuestInput input);

  Future<EventGuestRecord> updateGuest(UpdateGuestInput input);

  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  });

  Future<GuestDetailRecord> checkInGuest(String guestId);

  Future<GuestDetailRecord> assignGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  });

  Future<GuestDetailRecord> replaceGuestTag({
    required String guestId,
    required String scannedUid,
    String? displayLabel,
  });
}

abstract interface class RulesetRepository {
  Future<List<RulesetRecord>> listRulesets();
}

abstract interface class TableRepository {
  Future<List<EventTableRecord>> readCachedTables(String eventId);

  Future<List<EventTableRecord>> listTables(String eventId);

  Future<EventTableRecord> createTable(CreateEventTableInput input);

  Future<EventTableRecord> updateTable(UpdateEventTableInput input);

  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  });
}

abstract interface class SessionRepository {
  Future<List<TableSessionRecord>> readCachedSessions(String eventId);

  Future<List<TableSessionRecord>> listSessions(String eventId);

  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId);

  Future<SessionDetailRecord> loadSessionDetail(String sessionId);

  Future<StartedTableSessionRecord> startSession(StartTableSessionInput input);

  Future<SessionDetailRecord> pauseSession(String sessionId);

  Future<SessionDetailRecord> resumeSession(String sessionId);

  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  });

  Future<SessionDetailRecord> recordHand(RecordHandResultInput input);

  Future<SessionDetailRecord> editHand(EditHandResultInput input);

  Future<SessionDetailRecord> voidHand(VoidHandResultInput input);
}

abstract interface class PrizeRepository {
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId);

  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
    required int prizeBudgetCents,
  });

  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input);

  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(String eventId);

  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId);

  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId);

  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId);

  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId);

  Future<PrizeAwardRecord> markPrizeAwardPaid({
    required String awardId,
    String? paidMethod,
    String? paidNote,
  });

  Future<PrizeAwardRecord> voidPrizeAward({
    required String awardId,
    String? paidNote,
  });
}

abstract interface class LeaderboardRepository {
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId);

  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId);
}

abstract interface class ActivityRepository {
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  );

  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  );
}
