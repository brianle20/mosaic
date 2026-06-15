import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/ruleset_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class ThrowingEventRepository implements EventRepository {
  const ThrowingEventRepository();

  @override
  Future<List<EventRecord>> readCachedEvents() => throw UnimplementedError();

  @override
  Future<List<EventRecord>> listEvents() => throw UnimplementedError();

  @override
  Future<EventRecord?> getEvent(String eventId) => throw UnimplementedError();

  @override
  Future<EventRecord> createEvent(CreateEventInput input) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> updateEventMetadata(UpdateEventInput input) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> copyEventForTesting(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> startEvent(String eventId) => throw UnimplementedError();

  @override
  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  }) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> updateEventScoringPhase({
    required String eventId,
    required EventScoringPhase phase,
  }) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> completeEvent(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> finalizeEvent(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventRecord> cancelEvent(String eventId) => throw UnimplementedError();

  @override
  Future<EventRecord> revertEventToDraft(String eventId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteEvent(String eventId) => throw UnimplementedError();
}

class ThrowingGuestRepository implements GuestRepository {
  const ThrowingGuestRepository();

  @override
  Future<List<EventGuestRecord>> readCachedGuests(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<EventGuestRecord>> listGuests(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId) =>
      throw UnimplementedError();

  @override
  Future<GuestDetailRecord?> getGuestDetail(String guestId) =>
      throw UnimplementedError();

  @override
  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  ) =>
      throw UnimplementedError();

  @override
  Future<EventGuestRecord> createGuest(CreateGuestInput input) =>
      throw UnimplementedError();

  @override
  Future<EventGuestRecord> updateGuest(UpdateGuestInput input) =>
      throw UnimplementedError();

  @override
  Future<void> removeGuest(String guestId) => throw UnimplementedError();

  @override
  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  }) =>
      throw UnimplementedError();

  @override
  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) =>
      throw UnimplementedError();

  @override
  Future<GuestDetailRecord> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  }) =>
      throw UnimplementedError();

  @override
  Future<GuestDetailRecord> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  }) =>
      throw UnimplementedError();

  @override
  Future<GuestDetailRecord> checkInGuest(String guestId) =>
      throw UnimplementedError();

  @override
  Future<EventGuestRecord> undoGuestCheckIn(String guestId) =>
      throw UnimplementedError();
}

class ThrowingTableRepository implements TableRepository {
  const ThrowingTableRepository();

  @override
  Future<List<EventTableRecord>> readCachedTables(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<EventTableRecord>> listTables(String eventId) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  }) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> createTable(CreateEventTableInput input) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> updateTable(UpdateEventTableInput input) =>
      throw UnimplementedError();

  @override
  Future<EventTableRecord> bindTableTag({
    required String tableId,
    required String scannedUid,
    String? displayLabel,
  }) =>
      throw UnimplementedError();
}

class ThrowingSessionRepository implements SessionRepository {
  const ThrowingSessionRepository();

  @override
  Future<List<TableSessionRecord>> readCachedSessions(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<TableSessionRecord>> listSessions(String eventId) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord?> readCachedSessionDetail(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> loadSessionDetail(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(
    String eventId,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId) =>
      throw UnimplementedError();

  @override
  Future<StartedTableSessionRecord> startAssignedSession(
          StartAssignedTableSessionInput input) =>
      throw UnimplementedError();

  @override
  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  ) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> pauseSession(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> resumeSession(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  }) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> recordHand(RecordHandResultInput input) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> editHand(EditHandResultInput input) =>
      throw UnimplementedError();

  @override
  Future<SessionDetailRecord> voidHand(VoidHandResultInput input) =>
      throw UnimplementedError();
}

class ThrowingSeatingRepository implements SeatingRepository {
  const ThrowingSeatingRepository();

  @override
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(String eventId) =>
      throw UnimplementedError();

  @override
  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId) =>
      throw UnimplementedError();

  @override
  Future<TournamentRoundSummary> loadTournamentRoundSummary(String eventId) =>
      throw UnimplementedError();

  @override
  Future<BonusRoundState?> loadBonusRoundState(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> startTableOfChampionsPlayIn({
    required String eventId,
    required String tableId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId) =>
      throw UnimplementedError();
}

class ThrowingAuthRepository implements AuthRepository {
  const ThrowingAuthRepository();

  @override
  HostAuthUser? get currentHost => throw UnimplementedError();

  @override
  Stream<HostAuthUser?> authStateChanges() => throw UnimplementedError();

  @override
  Future<MosaicAccessState> loadCurrentAccess() => throw UnimplementedError();

  @override
  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailOtp({required String email}) =>
      throw UnimplementedError();

  @override
  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();
}

class ThrowingRulesetRepository implements RulesetRepository {
  const ThrowingRulesetRepository();

  @override
  Future<List<RulesetRecord>> listRulesets() => throw UnimplementedError();
}

class ThrowingPrizeRepository implements PrizeRepository {
  const ThrowingPrizeRepository();

  @override
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId) =>
      throw UnimplementedError();

  @override
  Future<PrizePlanDetail?> loadPrizePlan({required String eventId}) =>
      throw UnimplementedError();

  @override
  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input) =>
      throw UnimplementedError();

  @override
  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId) =>
      throw UnimplementedError();
}

class ThrowingLeaderboardRepository implements LeaderboardRepository {
  const ThrowingLeaderboardRepository();

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) =>
      throw UnimplementedError();

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) =>
      throw UnimplementedError();
}

class ThrowingActivityRepository implements ActivityRepository {
  const ThrowingActivityRepository();

  @override
  Future<List<EventActivityEntry>> readCachedActivity(
    String eventId,
    EventActivityCategory category,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<EventActivityEntry>> loadActivity(
    String eventId,
    EventActivityCategory category,
  ) =>
      throw UnimplementedError();
}
