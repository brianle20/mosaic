import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';

const scoringPhaseLiveSessionBlockedMessage =
    'End active or paused sessions before changing scoring phase.';

sealed class DashboardTableScanResult {
  const DashboardTableScanResult();
}

class DashboardTableScanOpenSession extends DashboardTableScanResult {
  const DashboardTableScanOpenSession({required this.sessionId});

  final String sessionId;
}

class DashboardTableScanStartSession extends DashboardTableScanResult {
  const DashboardTableScanStartSession({
    required this.table,
    required this.preverifiedTableTagUid,
  });

  final EventTableRecord table;
  final String preverifiedTableTagUid;
}

class EventDashboardController extends ChangeNotifier {
  EventDashboardController({
    required EventRepository eventRepository,
    required GuestRepository guestRepository,
    LeaderboardRepository? leaderboardRepository,
    PrizeRepository? prizeRepository,
    TableRepository? tableRepository,
    SessionRepository? sessionRepository,
    SeatingRepository? seatingRepository,
  })  : _eventRepository = eventRepository,
        _guestRepository = guestRepository,
        _leaderboardRepository = leaderboardRepository,
        _prizeRepository = prizeRepository,
        _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _seatingRepository = seatingRepository;

  final EventRepository _eventRepository;
  final GuestRepository _guestRepository;
  final LeaderboardRepository? _leaderboardRepository;
  final PrizeRepository? _prizeRepository;
  final TableRepository? _tableRepository;
  SessionRepository? _sessionRepository;
  SeatingRepository? _seatingRepository;

  bool isLoading = true;
  bool isSubmittingLifecycle = false;
  bool isScanningTable = false;
  String? error;
  String? lifecycleError;
  String? tableScanError;
  EventRecord? event;
  int guestCount = 0;
  int checkedInGuestCount = 0;
  int qualifyingGuestCount = 0;
  int qualifiedGuestCount = 0;
  int tableCount = 0;
  int? prizePoolCents;
  String leaderLabel = 'No scores';
  List<QualificationLeaderboardRow> qualificationLeaderboard = const [];
  BonusRoundResultsSummary bonusRoundResults = const BonusRoundResultsSummary();

  Future<void> load(String eventId) async {
    final cachedEvent = (await _eventRepository.readCachedEvents())
        .where((record) => record.id == eventId)
        .firstOrNull;
    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    final cachedTables = await _tableRepository?.readCachedTables(eventId);
    final cachedLeaderboard =
        await _leaderboardRepository?.readCachedLeaderboard(eventId);
    final cachedLedger = await _sessionRepository?.readCachedEventHandLedger(
      eventId,
    );
    final cachedPrizePlan = await _prizeRepository?.readCachedPrizePlan(
      eventId,
    );

    isLoading = true;
    error = null;
    lifecycleError = null;
    tableScanError = null;
    event = cachedEvent;
    _updateGuestSummaries(cachedGuests);
    tableCount = cachedTables?.length ?? 0;
    leaderLabel = _formatLeader(cachedLeaderboard);
    qualificationLeaderboard = const [];
    bonusRoundResults = buildBonusRoundResultsSummary(
      ledgerEntries: cachedLedger ?? const [],
      leaderboardEntries: cachedLeaderboard ?? const [],
    );
    prizePoolCents = _totalPrizeCents(cachedPrizePlan);
    notifyListeners();

    try {
      event = await _eventRepository.getEvent(eventId) ?? event;
    } catch (exception) {
      if (event == null) {
        error = exception.toString();
      }
    }

    try {
      final remoteGuests = await _guestRepository.listGuests(eventId);
      _updateGuestSummaries(remoteGuests);
    } catch (exception) {
      if (event == null && guestCount == 0) {
        error ??= exception.toString();
      }
    }

    try {
      tableCount = (await _tableRepository?.listTables(eventId))?.length ?? 0;
    } catch (_) {
      // Table count is a dashboard shortcut only; keep event loading usable.
    }

    try {
      final leaderboard = await _leaderboardRepository?.loadLeaderboard(
        eventId,
      );
      leaderLabel = _formatLeader(leaderboard);
      bonusRoundResults = buildBonusRoundResultsSummary(
        ledgerEntries: await _loadBonusLedger(eventId),
        leaderboardEntries: leaderboard ?? const [],
      );
    } catch (_) {
      // Leaderboard is a dashboard shortcut only; keep event loading usable.
    }

    try {
      prizePoolCents = _totalPrizeCents(
        await _prizeRepository?.loadPrizePlan(eventId: eventId),
      );
    } catch (_) {
      // Prize setup is a dashboard summary only; keep event loading usable.
    }

    try {
      qualificationLeaderboard = await _guestRepository
          .fetchQualificationLeaderboard(eventId: eventId);
    } catch (_) {
      qualificationLeaderboard = const [];
    }

    isLoading = false;
    notifyListeners();
  }

  void _updateGuestSummaries(List<EventGuestRecord> guests) {
    guestCount = guests.length;
    checkedInGuestCount = guests.where((guest) => guest.isCheckedIn).length;
    qualifyingGuestCount = guests
        .where(
          (guest) => guest.tournamentStatus == EventTournamentStatus.qualifying,
        )
        .length;
    qualifiedGuestCount = guests
        .where(
          (guest) => guest.tournamentStatus == EventTournamentStatus.qualified,
        )
        .length;
  }

  String _formatLeader(List<LeaderboardEntry>? entries) {
    if (entries == null || entries.isEmpty) {
      return 'No scores';
    }

    final minimumHands = _minimumHandsForPrize(entries);
    final qualifiedEntries = minimumHands <= 0
        ? entries
        : entries
            .where((entry) => entry.handsPlayed >= minimumHands)
            .toList(growable: false);
    final leaderEntries = qualifiedEntries.isEmpty ? entries : qualifiedEntries;
    final leader =
        leaderEntries.where((entry) => entry.rank == 1).firstOrNull ??
            leaderEntries.firstOrNull;
    return leader == null ? 'No scores' : leader.displayName;
  }

  int _minimumHandsForPrize(List<LeaderboardEntry> entries) {
    final scoredHands = entries
        .map((entry) => entry.handsPlayed)
        .where((handsPlayed) => handsPlayed > 0)
        .toList()
      ..sort();
    if (scoredHands.isEmpty) {
      return 0;
    }

    final midpoint = scoredHands.length ~/ 2;
    final medianHands = scoredHands.length.isOdd
        ? scoredHands[midpoint].toDouble()
        : (scoredHands[midpoint - 1] + scoredHands[midpoint]) / 2;
    final minimumHands = (medianHands * 0.5).ceil();
    return minimumHands < 1 ? 1 : minimumHands;
  }

  int? _totalPrizeCents(PrizePlanDetail? detail) {
    if (detail == null) {
      return null;
    }

    final total = detail.tiers.fold<int>(
      0,
      (sum, tier) =>
          sum + ((tier.fixedAmountCents ?? 0) > 0 ? tier.fixedAmountCents! : 0),
    );

    return total > 0 ? total : null;
  }

  Future<List<EventHandLedgerEntry>> _loadBonusLedger(String eventId) async {
    final repository = _sessionRepository;
    if (repository == null) {
      return const [];
    }

    try {
      return await repository.loadEventHandLedger(eventId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> completeEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.completeEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> finalizeEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.finalizeEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> cancelEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.cancelEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> revertToDraft() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.revertEventToDraft(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<bool> deleteEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return false;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      await _eventRepository.deleteEvent(currentEvent.id);
      event = null;
      isSubmittingLifecycle = false;
      notifyListeners();
      return true;
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return false;
    }
  }

  String _formatLifecycleError(Object exception) {
    final message = exception.toString();
    const statePrefix = 'Bad state: ';
    if (message.startsWith(statePrefix)) {
      return message.substring(statePrefix.length);
    }
    return message;
  }

  void recordTableScanError(Object exception) {
    tableScanError = _formatLifecycleError(exception);
    notifyListeners();
  }

  Future<void> startEvent() async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.startEvent(currentEvent.id);
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> setOperationalFlags({
    required bool checkinOpen,
    required bool scoringOpen,
  }) async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      event = await _eventRepository.setOperationalFlags(
        eventId: currentEvent.id,
        checkinOpen: checkinOpen,
        scoringOpen: scoringOpen,
      );
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  Future<void> setScoringPhase(EventScoringPhase phase) async {
    final currentEvent = event;
    if (currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      final sessions = await _sessionRepository?.listSessions(currentEvent.id);
      final hasLiveSessions = sessions?.any(
            (session) =>
                session.status == SessionStatus.active ||
                session.status == SessionStatus.paused,
          ) ??
          false;
      if (hasLiveSessions) {
        throw StateError(scoringPhaseLiveSessionBlockedMessage);
      }

      event = await _eventRepository.updateEventScoringPhase(
        eventId: currentEvent.id,
        phase: phase,
      );
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
    }

    isSubmittingLifecycle = false;
    notifyListeners();
  }

  void updateRuntimeRepositories({
    SessionRepository? sessionRepository,
    SeatingRepository? seatingRepository,
  }) {
    _sessionRepository = sessionRepository ?? _sessionRepository;
    _seatingRepository = seatingRepository ?? _seatingRepository;
  }

  Future<bool> startTournament() async {
    final currentEvent = event;
    final sessionRepository = _sessionRepository;
    final seatingRepository = _seatingRepository;
    if (currentEvent == null || isSubmittingLifecycle) {
      return false;
    }
    if (sessionRepository == null || seatingRepository == null) {
      lifecycleError =
          'Session and seating setup are required to start tournament play.';
      notifyListeners();
      return false;
    }

    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    var switchedToTournament = false;
    try {
      final sessions = await sessionRepository.listSessions(currentEvent.id);
      final liveQualificationSessions = sessions.where(
        (session) =>
            session.scoringPhase == EventScoringPhase.qualification &&
            (session.status == SessionStatus.active ||
                session.status == SessionStatus.paused),
      );
      for (final session in liveQualificationSessions) {
        await sessionRepository.endSession(
          sessionId: session.id,
          reason: 'tournament_started',
        );
      }

      event = await _eventRepository.updateEventScoringPhase(
        eventId: currentEvent.id,
        phase: EventScoringPhase.tournament,
      );
      switchedToTournament = true;

      await seatingRepository.generateRandomAssignments(currentEvent.id);
      isSubmittingLifecycle = false;
      notifyListeners();
      return true;
    } catch (exception) {
      if (switchedToTournament) {
        try {
          event = await _eventRepository.updateEventScoringPhase(
            eventId: currentEvent.id,
            phase: EventScoringPhase.qualification,
          );
        } catch (_) {
          // Keep the original assignment/start error visible to the host.
        }
      }
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return false;
    }
  }

  Future<DashboardTableScanResult?> resolveScannedTableTag(
    String normalizedUid,
  ) async {
    final currentEvent = event;
    final tableRepository = _tableRepository;
    final sessionRepository = _sessionRepository;
    if (currentEvent == null ||
        tableRepository == null ||
        sessionRepository == null ||
        isScanningTable) {
      return null;
    }

    isScanningTable = true;
    tableScanError = null;
    notifyListeners();

    try {
      final table = await tableRepository.resolveTableByTag(
        eventId: currentEvent.id,
        scannedUid: normalizedUid,
      );
      final sessions = await sessionRepository.listSessions(currentEvent.id);
      final liveSession = sessions.firstWhereOrNull(
        (session) =>
            session.eventTableId == table.id &&
            (session.status == SessionStatus.active ||
                session.status == SessionStatus.paused),
      );

      if (liveSession != null) {
        return DashboardTableScanOpenSession(sessionId: liveSession.id);
      }

      if (!currentEvent.scoringOpen) {
        tableScanError = 'Open scoring before starting a table session.';
        return null;
      }

      return DashboardTableScanStartSession(
        table: table,
        preverifiedTableTagUid: normalizedUid,
      );
    } on TableTagResolutionException catch (exception) {
      tableScanError = exception.message;
      return null;
    } catch (exception) {
      tableScanError = _formatLifecycleError(exception);
      return null;
    } finally {
      isScanningTable = false;
      notifyListeners();
    }
  }
}
