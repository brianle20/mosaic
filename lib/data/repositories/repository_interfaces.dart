import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/activity_models.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/hand_evidence_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/ruleset_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/staff_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';

abstract interface class AuthRepository {
  HostAuthUser? get currentHost;

  Stream<HostAuthUser?> authStateChanges();

  Future<MosaicAccessState> loadCurrentAccess();

  Future<HostAuthUser?> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> sendEmailOtp({required String email});

  Future<HostAuthUser?> verifyEmailOtp({
    required String email,
    required String code,
  });

  Future<void> signOut();
}

abstract interface class StaffRepository {
  Future<List<EventStaffMembershipRecord>> listEventStaff(String eventId);

  Future<EventStaffMembershipRecord> upsertEventStaff(
    UpsertEventStaffMembershipInput input,
  );

  Future<EventStaffMembershipRecord> disableEventStaffMembership(
    String membershipId,
  );
}

abstract interface class EventRepository {
  Future<List<EventRecord>> readCachedEvents();

  Future<List<EventRecord>> listEvents();

  Future<EventRecord?> getEvent(String eventId);

  Future<EventRecord> createEvent(CreateEventInput input);

  Future<EventRecord> updateEventMetadata(UpdateEventInput input);

  Future<EventRecord> copyEventForTesting(String eventId);

  Future<EventRecord> startEvent(String eventId);

  Future<EventRecord> setOperationalFlags({
    required String eventId,
    required bool checkinOpen,
    required bool scoringOpen,
  });

  Future<EventRecord> updateEventScoringPhase({
    required String eventId,
    required EventScoringPhase phase,
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

  Future<List<GuestProfileRecord>> listGuestProfiles();

  Future<List<GuestCoverEntryRecord>> readCachedGuestCoverEntries(
    String guestId,
  );

  Future<List<GuestCoverEntryRecord>> loadGuestCoverEntries(String guestId);

  Future<GuestDetailRecord?> getGuestDetail(String guestId);

  Future<List<GuestProfileMatch>> findGuestProfileMatches(
    GuestProfileLookupInput input,
  );

  Future<EventGuestRecord> createGuest(CreateGuestInput input);

  Future<List<EventGuestRecord>> createGuests(BulkCreateGuestsInput input);

  Future<EventGuestRecord> updateGuest(UpdateGuestInput input);

  Future<void> removeGuest(String guestId);

  Future<EventGuestRecord> updateEventGuestTournamentStatus({
    required String eventGuestId,
    required EventTournamentStatus status,
  });

  Future<GuestDetailRecord> recordCoverEntry({
    required String guestId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  });

  Future<GuestDetailRecord> updateCoverEntry({
    required String guestId,
    required String coverEntryId,
    required int amountCents,
    required CoverEntryMethod method,
    required DateTime transactionOn,
    String? note,
  });

  Future<GuestDetailRecord> deleteCoverEntry({
    required String guestId,
    required String coverEntryId,
  });

  Future<GuestDetailRecord> checkInGuest(String guestId);

  Future<EventGuestRecord> undoGuestCheckIn(String guestId);
}

abstract interface class RulesetRepository {
  Future<List<RulesetRecord>> listRulesets();
}

abstract interface class TableRepository {
  Future<List<EventTableRecord>> readCachedTables(String eventId);

  Future<List<EventTableRecord>> listTables(String eventId);

  Future<EventTableRecord> resolveTableByTag({
    required String eventId,
    required String scannedUid,
  });

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

  Future<List<EventHandLedgerEntry>> readCachedEventHandLedger(String eventId);

  Future<List<EventHandLedgerEntry>> loadEventHandLedger(String eventId);

  Future<StartedTableSessionRecord> startAssignedSession(
    StartAssignedTableSessionInput input,
  );

  Future<List<TableSessionRecord>> startCurrentTournamentRoundSessions(
    String eventId,
  );

  Future<SessionDetailRecord> pauseSession(String sessionId);

  Future<SessionDetailRecord> resumeSession(String sessionId);

  Future<SessionDetailRecord> endSession({
    required String sessionId,
    required String reason,
  });

  Future<SessionDetailRecord> recordHand(RecordHandResultInput input);

  Future<SessionDetailRecord> recordFalseWinPenalty(
    RecordFalseWinPenaltyInput input,
  );

  Future<SessionDetailRecord> editHand(EditHandResultInput input);

  Future<SessionDetailRecord> voidHand(VoidHandResultInput input);
}

abstract interface class HandEvidenceRepository {
  Future<void> uploadAndAttachHandPhoto({
    required String eventId,
    required String handResultId,
    required String clientPhotoId,
    required String localPath,
    required DateTime capturedAt,
  });
}

abstract interface class MosaicProfileRepository {
  Future<List<HandEvidenceReviewRecord>> listHandEvidenceReview(String eventId);

  Future<Uri?> createHandPhotoSignedUrl(HandPhotoRecord photo);

  Future<HandTileEntryRecord> upsertHandTileEntry({
    required String handResultId,
    required Map<String, dynamic> tilesJson,
    required int? calculatedFanCount,
    required HandTileReviewStatus reviewStatus,
    required String calculationVersion,
  });
}

abstract interface class PrizeRepository {
  Future<PrizePlanDetail?> readCachedPrizePlan(String eventId);

  Future<PrizePlanDetail?> loadPrizePlan({
    required String eventId,
  });

  Future<PrizePlanDetail> upsertPrizePlan(UpsertPrizePlanInput input);

  Future<List<PrizeAwardPreviewRow>> readCachedPrizePreview(String eventId);

  Future<List<PrizeAwardPreviewRow>> loadPrizePreview(String eventId);

  Future<List<PrizeAwardRecord>> readCachedPrizeAwards(String eventId);

  Future<List<PrizeAwardRecord>> loadPrizeAwards(String eventId);

  Future<List<PrizeAwardRecord>> lockPrizeAwards(String eventId);
}

abstract interface class LeaderboardRepository {
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId);

  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId);
}

abstract interface class SeatingRepository {
  Future<List<SeatingAssignmentRecord>> readCachedAssignments(String eventId);

  Future<TournamentRoundSummary?> readCachedTournamentRoundSummary(
    String eventId,
  );

  Future<List<SeatingAssignmentRecord>> loadAssignments(String eventId);

  Future<TournamentRoundSummary> loadTournamentRoundSummary(String eventId);

  Future<BonusRoundState?> loadBonusRoundState(String eventId);

  Future<List<SeatingAssignmentRecord>> generateRandomAssignments(
    String eventId,
  );

  Future<List<SeatingAssignmentRecord>> generateTournamentRound(
    String eventId,
  );

  Future<List<SeatingAssignmentRecord>> generateBonusRoundAssignments({
    required String eventId,
    required String championsTableId,
    String? redemptionTableId,
  });

  Future<List<SeatingAssignmentRecord>> startBonusRoundSuddenDeath({
    required String eventId,
    required String tableId,
  });

  Future<List<SeatingAssignmentRecord>> startTableOfChampionsPlayIn({
    required String eventId,
    required String tableId,
  });

  Future<List<SeatingAssignmentRecord>> clearAssignments(String eventId);
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
