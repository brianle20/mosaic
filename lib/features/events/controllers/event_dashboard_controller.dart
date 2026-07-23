import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/prize_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/table_scan_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';

const scoringPhaseLiveSessionBlockedMessage =
    'End active or paused sessions before changing scoring phase.';

class _LoadResult<T> {
  const _LoadResult.success(this.value, {this.fromRemote = true})
      : succeeded = true;
  const _LoadResult.failure(this.value)
      : succeeded = false,
        fromRemote = false;

  final T value;
  final bool succeeded;
  final bool fromRemote;
}

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
    FinalsRepository? finalsRepository,
    this.callerRole = MosaicAccessRole.owner,
  })  : _eventRepository = eventRepository,
        _guestRepository = guestRepository,
        _leaderboardRepository = leaderboardRepository,
        _prizeRepository = prizeRepository,
        _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _seatingRepository = seatingRepository,
        _finalsRepository = finalsRepository;

  final EventRepository _eventRepository;
  final GuestRepository _guestRepository;
  final LeaderboardRepository? _leaderboardRepository;
  final PrizeRepository? _prizeRepository;
  final TableRepository? _tableRepository;
  SessionRepository? _sessionRepository;
  SeatingRepository? _seatingRepository;
  final FinalsRepository? _finalsRepository;
  MosaicAccessRole callerRole;
  int _stateRequestToken = 0;

  bool isLoading = true;
  bool isSubmittingLifecycle = false;
  bool isScanningTable = false;
  String? error;
  String? lifecycleError;
  String? tableScanError;
  String? finalsActionError;
  EventRecord? event;
  BonusRoundState? bonusRoundState;
  FinalsState? finalsState;
  int guestCount = 0;
  int checkedInGuestCount = 0;
  int qualifyingGuestCount = 0;
  int qualifiedGuestCount = 0;
  int tableCount = 0;
  int? prizePoolCents;
  String leaderLabel = 'No scores';
  BonusRoundResultsSummary bonusRoundResults = const BonusRoundResultsSummary();
  TournamentRoundSummary tournamentRoundSummary =
      TournamentRoundSummary.empty();
  TournamentRoundSummary finalsRoundSummary = TournamentRoundSummary.empty();
  List<EventHandLedgerEntry> _bonusLedgerEntries = const [];
  List<LeaderboardEntry> _leaderboardEntries = const [];
  int? _loadingRequestToken;
  bool _isDisposed = false;
  String? _loadedEventId;
  Future<FinalsState?>? _finalsActionFuture;

  FinalsAction? get primaryFinalsAction => finalsState?.primaryAction;

  bool get isExecutingFinalsAction => _finalsActionFuture != null;

  bool get canManageEvent => callerRole.canManageEvent;

  bool get canManageStaff => callerRole.canManageStaff;

  bool get canCheckInGuests => callerRole.canCheckInGuests;

  bool get canScoreLegacyQualification =>
      callerRole.canScoreLegacyQualification;

  bool get canScoreTournament => callerRole.canScoreTournament;

  bool get canScoreBonus => callerRole.canScoreBonus;

  EventScoringPhase? get effectiveScoringPhase {
    if (finalsState case final state?
        when state.overallStatus != FinalsOverallStatus.notStarted) {
      return EventScoringPhase.bonus;
    }
    return event?.currentScoringPhase;
  }

  bool get isSuddenDeathRequired =>
      bonusRoundState?.suddenDeathStatus == 'required';

  bool get isSuddenDeathActive =>
      bonusRoundState?.suddenDeathStatus == 'active';

  bool get isSuddenDeathCompleted =>
      bonusRoundState?.suddenDeathStatus == 'completed';

  Future<void> load(String eventId, {bool silent = false}) async {
    _loadedEventId = eventId;
    final requestToken = _beginStateRequest(silent: silent);
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
    final cachedTournamentRoundSummary =
        await _readCachedTournamentRoundSummary(eventId);
    final cachedFinalsRoundSummary =
        await _readCachedFinalsRoundSummary(eventId);
    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }

    if (!silent) {
      isLoading = true;
    }
    error = null;
    lifecycleError = null;
    tableScanError = null;
    if (!silent || cachedEvent != null) {
      event = cachedEvent;
    }
    if (!silent) {
      bonusRoundState = null;
      finalsState = null;
    }
    if (!silent || cachedGuests.isNotEmpty) {
      _updateGuestSummaries(cachedGuests);
    }
    if (!silent || cachedTables != null && cachedTables.isNotEmpty) {
      tableCount = cachedTables?.length ?? 0;
    }
    if (!silent || cachedLeaderboard != null && cachedLeaderboard.isNotEmpty) {
      leaderLabel = _formatLeader(cachedLeaderboard);
      _leaderboardEntries = cachedLeaderboard ?? const [];
    }
    if (!silent) {
      _bonusLedgerEntries = cachedLedger ?? const [];
    }
    _rebuildBonusRoundResults();
    if (!silent) {
      tournamentRoundSummary =
          event?.currentScoringPhase == EventScoringPhase.tournament
              ? cachedTournamentRoundSummary
              : TournamentRoundSummary.empty();
    }
    if (!silent) {
      finalsRoundSummary = cachedFinalsRoundSummary;
      if (cachedFinalsRoundSummary.hasCurrentRound) {
        tournamentRoundSummary = TournamentRoundSummary.empty();
      }
    }
    if (!silent || cachedPrizePlan != null) {
      prizePoolCents = _totalPrizeCents(cachedPrizePlan);
    }
    notifyListeners();

    try {
      final loadedEvent = await _eventRepository.getEvent(eventId);
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      event = loadedEvent;
    } catch (exception) {
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      if (event == null) {
        error = userFacingError(exception,
            fallback: 'Unable to load event details.');
      }
    }

    try {
      final remoteGuests = await _guestRepository.listGuests(eventId);
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      _updateGuestSummaries(remoteGuests);
    } catch (exception) {
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      if (event == null && guestCount == 0) {
        error ??= userFacingError(exception,
            fallback: 'Unable to load event details.');
      }
    }

    try {
      final remoteTables = await _tableRepository?.listTables(eventId);
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      if (remoteTables != null) {
        tableCount = remoteTables.length;
      }
    } catch (_) {
      // Table count is a dashboard shortcut only; keep event loading usable.
    }

    try {
      final leaderboard = await _leaderboardRepository?.loadLeaderboard(
        eventId,
      );
      if (!_isCurrentStateRequest(requestToken)) {
        return;
      }
      if (leaderboard != null) {
        leaderLabel = _formatLeader(leaderboard);
        _leaderboardEntries = leaderboard;
        _rebuildBonusRoundResults();
      }
    } catch (_) {
      // Leaderboard is a dashboard shortcut only; keep event loading usable.
    }

    final ledgerResult = await _loadBonusLedger(eventId);
    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }
    if (ledgerResult.succeeded) {
      _bonusLedgerEntries = ledgerResult.value;
      _rebuildBonusRoundResults();
    }

    final prizeResult = await _loadPrizePlan(eventId);
    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }
    if (prizeResult.succeeded) {
      prizePoolCents = _totalPrizeCents(prizeResult.value);
    }

    final currentScoringPhase = event?.currentScoringPhase;
    final loadedTournamentRoundSummary =
        currentScoringPhase == EventScoringPhase.tournament
            ? await _loadTournamentRoundSummary(eventId)
            : _LoadResult.failure(TournamentRoundSummary.empty());
    final loadedFinalsRoundSummary = await _loadFinalsRoundSummary(eventId);
    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }
    if (!silent) {
      tournamentRoundSummary = loadedFinalsRoundSummary.value.hasCurrentRound
          ? TournamentRoundSummary.empty()
          : loadedTournamentRoundSummary.value;
      finalsRoundSummary = loadedFinalsRoundSummary.value;
    } else {
      if (loadedFinalsRoundSummary.succeeded &&
          loadedFinalsRoundSummary.fromRemote) {
        finalsRoundSummary = loadedFinalsRoundSummary.value;
        if (loadedFinalsRoundSummary.value.hasCurrentRound ||
            currentScoringPhase != EventScoringPhase.tournament) {
          tournamentRoundSummary = TournamentRoundSummary.empty();
        } else if (loadedTournamentRoundSummary.succeeded &&
            loadedTournamentRoundSummary.fromRemote) {
          tournamentRoundSummary = loadedTournamentRoundSummary.value;
        }
      } else if (loadedTournamentRoundSummary.succeeded &&
          loadedTournamentRoundSummary.fromRemote) {
        tournamentRoundSummary = loadedTournamentRoundSummary.value;
      }
    }

    final loadedBonusRoundState = await _loadBonusRoundState(eventId);
    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }
    if (!silent || loadedBonusRoundState.succeeded) {
      bonusRoundState = loadedBonusRoundState.value;
      _rebuildBonusRoundResults();
    }

    final finalsRepository = _finalsRepository;
    if (finalsRepository != null) {
      try {
        final loadedFinalsState =
            await finalsRepository.loadFinalsState(eventId);
        if (!_isCurrentStateRequest(requestToken)) {
          return;
        }
        finalsState = loadedFinalsState;
        if (loadedFinalsState.overallStatus != FinalsOverallStatus.notStarted) {
          tournamentRoundSummary = TournamentRoundSummary.empty();
        }
      } catch (exception) {
        if (!_isCurrentStateRequest(requestToken)) {
          return;
        }
        if (finalsState == null && !silent) {
          error ??= userFacingError(
            exception,
            fallback: 'Unable to load Finals.',
          );
        }
      }
    }

    if (!_isCurrentStateRequest(requestToken)) {
      return;
    }
    if (!silent && _loadingRequestToken == requestToken) {
      isLoading = false;
      _loadingRequestToken = null;
    }
    notifyListeners();
  }

  Future<FinalsState?> executeFinalsAction(FinalsAction action) {
    final isServerAction = finalsState?.allowedActions.any(
          (serverAction) => identical(serverAction, action),
        ) ??
        false;
    if (!isServerAction) return Future.value(finalsState);
    final existing = _finalsActionFuture;
    if (existing != null) return existing;

    final future = _executeFinalsAction(action);
    _finalsActionFuture = future;
    notifyListeners();
    future.whenComplete(() {
      if (identical(_finalsActionFuture, future)) {
        _finalsActionFuture = null;
        if (!_isDisposed) notifyListeners();
      }
    });
    return future;
  }

  Future<FinalsState?> _executeFinalsAction(FinalsAction action) async {
    final finalsRepository = _finalsRepository;
    if (finalsRepository == null) return finalsState;

    finalsActionError = null;
    try {
      final updatedState = switch (action.kind) {
        FinalsActionKind.startFinalsTables ||
        FinalsActionKind.resumeFinalsStart =>
          await finalsRepository.resumeFinalsStart(
            ResumeFinalsStartInput(
              eventId: _eventIdForFinalsAction(),
              recoveryToken: action.recoveryToken!,
            ),
          ),
        FinalsActionKind.startContest => await finalsRepository.startContest(
            StartFinalsContestInput(
              contestId: action.contestId!,
              tableId: action.tableId,
              expectedStateVersion: action.expectedStateVersion!,
            ),
          ),
      };
      finalsState = updatedState;
      await _refreshFinalsSupportingData();
      return updatedState;
    } catch (exception) {
      finalsActionError = userFacingError(
        exception,
        fallback:
            'Unable to complete that Finals action right now. Refresh and try again.',
      );
      return null;
    }
  }

  String _eventIdForFinalsAction() {
    final eventId = _loadedEventId;
    if (eventId == null) {
      throw StateError('Refresh Finals before trying that action.');
    }
    return eventId;
  }

  Future<void> _refreshFinalsSupportingData() async {
    final eventId = _eventIdForFinalsAction();
    final loadedFinalsRoundSummary = await _loadFinalsRoundSummary(eventId);
    if (loadedFinalsRoundSummary.succeeded) {
      finalsRoundSummary = loadedFinalsRoundSummary.value;
    }
    final loadedBonusRoundState = await _loadBonusRoundState(eventId);
    if (loadedBonusRoundState.succeeded) {
      bonusRoundState = loadedBonusRoundState.value;
    }
    final ledgerResult = await _loadBonusLedger(eventId);
    if (ledgerResult.succeeded) {
      _bonusLedgerEntries = ledgerResult.value;
    }
    _rebuildBonusRoundResults();
  }

  int _beginStateRequest({required bool silent}) {
    _stateRequestToken += 1;
    final requestToken = _stateRequestToken;
    if (silent) {
      _loadingRequestToken = null;
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
    } else {
      _loadingRequestToken = requestToken;
      isLoading = true;
    }
    return requestToken;
  }

  bool _isCurrentStateRequest(int requestToken) {
    return !_isDisposed && requestToken == _stateRequestToken;
  }

  void _beginHostMutation() {
    _stateRequestToken += 1;
    _loadingRequestToken = null;
    isLoading = false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stateRequestToken += 1;
    super.dispose();
  }

  void _updateGuestSummaries(List<EventGuestRecord> guests) {
    final activeGuests = guests
        .where(
          (guest) => guest.tournamentStatus != EventTournamentStatus.withdrawn,
        )
        .toList(growable: false);
    guestCount = activeGuests.length;
    checkedInGuestCount =
        activeGuests.where((guest) => guest.isCheckedIn).length;
    qualifyingGuestCount = activeGuests
        .where(
          (guest) => guest.tournamentStatus == EventTournamentStatus.qualifying,
        )
        .length;
    qualifiedGuestCount = activeGuests
        .where(
          (guest) => guest.tournamentStatus == EventTournamentStatus.qualified,
        )
        .length;
  }

  String _formatLeader(List<LeaderboardEntry>? entries) {
    if (entries == null || entries.isEmpty) {
      return 'No scores';
    }

    final leader = entries.where((entry) => entry.rank == 1).firstOrNull ??
        entries.firstOrNull;
    return leader == null ? 'No scores' : leader.displayName;
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

  Future<_LoadResult<List<EventHandLedgerEntry>>> _loadBonusLedger(
    String eventId,
  ) async {
    final repository = _sessionRepository;
    if (repository == null) {
      return const _LoadResult.failure([]);
    }

    try {
      return _LoadResult.success(
        await repository.loadEventHandLedger(eventId),
      );
    } catch (_) {
      return const _LoadResult.failure([]);
    }
  }

  Future<_LoadResult<BonusRoundState?>> _loadBonusRoundState(
    String eventId,
  ) async {
    final repository = _seatingRepository;
    if (repository == null) {
      return const _LoadResult.failure(null);
    }
    try {
      return _LoadResult.success(await repository.loadBonusRoundState(eventId));
    } catch (_) {
      return const _LoadResult.failure(null);
    }
  }

  Future<_LoadResult<PrizePlanDetail?>> _loadPrizePlan(String eventId) async {
    final repository = _prizeRepository;
    if (repository == null) {
      return const _LoadResult.failure(null);
    }
    try {
      return _LoadResult.success(
        await repository.loadPrizePlan(eventId: eventId),
      );
    } catch (_) {
      return const _LoadResult.failure(null);
    }
  }

  void _rebuildBonusRoundResults() {
    bonusRoundResults = buildBonusRoundResultsSummary(
      ledgerEntries: _bonusLedgerEntries,
      leaderboardEntries: _leaderboardEntries,
      bonusRoundState: bonusRoundState,
    );
  }

  Future<TournamentRoundSummary> _readCachedTournamentRoundSummary(
    String eventId,
  ) async {
    try {
      return await _seatingRepository?.readCachedTournamentRoundSummary(
            eventId,
          ) ??
          TournamentRoundSummary.empty();
    } catch (_) {
      return TournamentRoundSummary.empty();
    }
  }

  Future<_LoadResult<TournamentRoundSummary>> _loadTournamentRoundSummary(
    String eventId,
  ) async {
    final repository = _seatingRepository;
    if (repository == null) {
      return _LoadResult.failure(TournamentRoundSummary.empty());
    }
    try {
      return _LoadResult.success(
        await repository.loadTournamentRoundSummary(eventId),
      );
    } catch (_) {
      final cached = await _readCachedTournamentRoundSummary(eventId);
      return cached.hasCurrentRound
          ? _LoadResult.success(cached, fromRemote: false)
          : _LoadResult.failure(TournamentRoundSummary.empty());
    }
  }

  Future<TournamentRoundSummary> _readCachedFinalsRoundSummary(
    String eventId,
  ) async {
    try {
      final assignments =
          await _seatingRepository?.readCachedAssignments(eventId) ?? const [];
      final sessions =
          await _sessionRepository?.readCachedSessions(eventId) ?? const [];
      final tables = await _tableRepository?.readCachedTables(eventId) ??
          const <EventTableRecord>[];
      return _buildFinalsRoundSummary(
        assignments: assignments,
        sessions: sessions,
        tables: tables,
      );
    } catch (_) {
      return TournamentRoundSummary.empty();
    }
  }

  Future<_LoadResult<TournamentRoundSummary>> _loadFinalsRoundSummary(
    String eventId,
  ) async {
    if (_seatingRepository == null) {
      return _LoadResult.failure(TournamentRoundSummary.empty());
    }
    try {
      final assignments =
          await _seatingRepository?.loadAssignments(eventId) ?? const [];
      final sessions = await _sessionRepository?.listSessions(eventId) ??
          const <TableSessionRecord>[];
      final tables = await _tableRepository?.listTables(eventId) ??
          const <EventTableRecord>[];
      return _LoadResult.success(
        _buildFinalsRoundSummary(
          assignments: assignments,
          sessions: sessions,
          tables: tables,
        ),
      );
    } catch (_) {
      final cached = await _readCachedFinalsRoundSummary(eventId);
      return cached.hasCurrentRound
          ? _LoadResult.success(cached, fromRemote: false)
          : _LoadResult.failure(TournamentRoundSummary.empty());
    }
  }

  TournamentRoundSummary _buildFinalsRoundSummary({
    required List<SeatingAssignmentRecord> assignments,
    required List<TableSessionRecord> sessions,
    required List<EventTableRecord> tables,
  }) {
    final bonusAssignments = _activeBonusAssignments(assignments);
    if (bonusAssignments.isEmpty) {
      return TournamentRoundSummary.empty();
    }

    final tableOrderById = {
      for (final table in tables) table.id: table.displayOrder,
    };
    final sessionsByTableId = _sessionsByTableId(sessions);
    final groupedAssignments = _assignmentsByTableId(bonusAssignments);
    final tableSummaries = [
      for (final entry in groupedAssignments.entries)
        _finalsTableSummary(
          eventTableId: entry.key,
          assignments: entry.value,
          sessions: sessionsByTableId[entry.key] ?? const [],
          tableDisplayOrder: tableOrderById[entry.key] ?? 0,
        ),
    ]..sort((left, right) {
        final roleCompare = _bonusRoleSort(
          groupedAssignments[left.eventTableId],
        ).compareTo(
          _bonusRoleSort(groupedAssignments[right.eventTableId]),
        );
        if (roleCompare != 0) {
          return roleCompare;
        }
        return left.tableDisplayOrder.compareTo(right.tableDisplayOrder);
      });

    final activeCount = tableSummaries
        .where((table) => table.status == TournamentRoundTableStatus.active)
        .length;
    final pausedCount = tableSummaries
        .where((table) => table.status == TournamentRoundTableStatus.paused)
        .length;
    final completeCount = tableSummaries
        .where((table) => table.status == TournamentRoundTableStatus.complete)
        .length;
    final notStartedCount = tableSummaries
        .where(
          (table) => table.status == TournamentRoundTableStatus.notStarted,
        )
        .length;
    final status = completeCount >= tableSummaries.length
        ? TournamentRoundStatus.complete
        : activeCount + pausedCount > 0
            ? TournamentRoundStatus.active
            : TournamentRoundStatus.seating;
    final assignmentRound = bonusAssignments.first.assignmentRound;

    return TournamentRoundSummary(
      round: TournamentRoundRecord(
        id: bonusAssignments.first.bonusRoundId ?? 'bonus_$assignmentRound',
        eventId: bonusAssignments.first.eventId,
        roundNumber: assignmentRound,
        scoringPhase: EventScoringPhase.bonus,
        status: status,
        assignmentRound: assignmentRound,
      ),
      assignedTableCount: tableSummaries.length,
      completeTableCount: completeCount,
      activeTableCount: activeCount,
      pausedTableCount: pausedCount,
      notStartedTableCount: notStartedCount,
      currentRoundTables: tableSummaries,
      otherTables: const [],
    );
  }

  List<SeatingAssignmentRecord> _activeBonusAssignments(
    List<SeatingAssignmentRecord> assignments,
  ) {
    return assignments
        .where(
          (assignment) =>
              assignment.assignmentType == SeatingAssignmentType.bonus &&
              assignment.status == 'active',
        )
        .toList(growable: false)
      ..sort((left, right) {
        final tableCompare = left.tableLabel.compareTo(right.tableLabel);
        if (tableCompare != 0) {
          return tableCompare;
        }
        return left.seatIndex.compareTo(right.seatIndex);
      });
  }

  Map<String, List<SeatingAssignmentRecord>> _assignmentsByTableId(
    List<SeatingAssignmentRecord> assignments,
  ) {
    final grouped = <String, List<SeatingAssignmentRecord>>{};
    for (final assignment in assignments) {
      grouped.putIfAbsent(assignment.eventTableId, () => []).add(assignment);
    }
    return grouped;
  }

  Map<String, List<TableSessionRecord>> _sessionsByTableId(
    List<TableSessionRecord> sessions,
  ) {
    final grouped = <String, List<TableSessionRecord>>{};
    for (final session in sessions) {
      grouped.putIfAbsent(session.eventTableId, () => []).add(session);
    }
    for (final tableSessions in grouped.values) {
      tableSessions.sort(
        (left, right) => right.startedAt.compareTo(left.startedAt),
      );
    }
    return grouped;
  }

  int _bonusRoleSort(List<SeatingAssignmentRecord>? assignments) {
    final role = assignments == null || assignments.isEmpty
        ? null
        : assignments.first.bonusTableRole;
    return switch (role) {
      BonusTableRole.tableOfChampions => 0,
      BonusTableRole.tableOfChampionsPlayIn => 1,
      BonusTableRole.tableOfRedemption => 2,
      BonusTableRole.tableOfChampionsSuddenDeath => 3,
      null => 4,
    };
  }

  TournamentRoundTableSummary _finalsTableSummary({
    required String eventTableId,
    required List<SeatingAssignmentRecord> assignments,
    required List<TableSessionRecord> sessions,
    required int tableDisplayOrder,
  }) {
    assignments
        .sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final bonusTableRole = assignments.first.bonusTableRole;
    final activeSession = sessions.firstWhereOrNull(
      (session) =>
          session.scoringPhase == EventScoringPhase.bonus &&
          _matchesBonusTableRole(session, bonusTableRole) &&
          (session.status == SessionStatus.active ||
              session.status == SessionStatus.paused),
    );
    final latestEndedSession = sessions.firstWhereOrNull(
      (session) =>
          session.scoringPhase == EventScoringPhase.bonus &&
          _matchesBonusTableRole(session, bonusTableRole) &&
          (session.status == SessionStatus.completed ||
              session.status == SessionStatus.endedEarly),
    );
    final status = switch (activeSession?.status) {
      SessionStatus.active => TournamentRoundTableStatus.active,
      SessionStatus.paused => TournamentRoundTableStatus.paused,
      _ => latestEndedSession == null
          ? TournamentRoundTableStatus.notStarted
          : TournamentRoundTableStatus.complete,
    };

    return TournamentRoundTableSummary(
      eventTableId: eventTableId,
      tableLabel: assignments.first.tableLabel,
      tableDisplayOrder: tableDisplayOrder,
      status: status,
      activeSessionId: activeSession?.id,
      latestEndedSessionId: latestEndedSession?.id,
      assignedPlayers: [
        for (final assignment in assignments)
          TournamentRoundAssignedPlayer(
            eventGuestId: assignment.eventGuestId,
            displayName: assignment.displayName,
            seatIndex: assignment.seatIndex,
          ),
      ],
    );
  }

  bool _matchesBonusTableRole(
    TableSessionRecord session,
    BonusTableRole? bonusTableRole,
  ) {
    return bonusTableRole == null || session.bonusTableRole == bonusTableRole;
  }

  Future<void> completeEvent() async {
    final currentEvent = event;
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return false;
    }

    _beginHostMutation();
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

  Future<EventRecord?> copyEventForTesting() async {
    final currentEvent = event;
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return null;
    }

    _beginHostMutation();
    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      final copiedEvent =
          await _eventRepository.copyEventForTesting(currentEvent.id);
      isSubmittingLifecycle = false;
      notifyListeners();
      return copiedEvent;
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return null;
    }
  }

  String _formatLifecycleError(Object exception) {
    return userFacingError(exception);
  }

  void recordTableScanError(Object exception) {
    tableScanError = _formatLifecycleError(exception);
    notifyListeners();
  }

  Future<void> startEvent() async {
    final currentEvent = event;
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return;
    }

    _beginHostMutation();
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

  Future<List<SeatingAssignmentRecord>?> startTournament() async {
    final currentEvent = event;
    final seatingRepository = _seatingRepository;
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return null;
    }
    if (seatingRepository == null) {
      lifecycleError = 'Seating setup is required to start tournament play.';
      notifyListeners();
      return null;
    }

    _beginHostMutation();
    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      final assignments =
          await seatingRepository.generateTournamentRound(currentEvent.id);
      event = EventRecord.fromJson({
        ...currentEvent.toJson(),
        'current_scoring_phase':
            eventScoringPhaseToJson(EventScoringPhase.tournament),
      });
      tournamentRoundSummary =
          (await _loadTournamentRoundSummary(currentEvent.id)).value;
      isSubmittingLifecycle = false;
      notifyListeners();
      return assignments;
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return null;
    }
  }

  Future<List<SeatingAssignmentRecord>?> startNextTournamentRound() async {
    final currentEvent = event;
    final seatingRepository = _seatingRepository;
    if (!canManageEvent || currentEvent == null || isSubmittingLifecycle) {
      return null;
    }
    if (seatingRepository == null) {
      lifecycleError =
          'Seating setup is required to start the next tournament round.';
      notifyListeners();
      return null;
    }

    _beginHostMutation();
    isSubmittingLifecycle = true;
    lifecycleError = null;
    notifyListeners();

    try {
      final assignments =
          await seatingRepository.generateTournamentRound(currentEvent.id);
      tournamentRoundSummary =
          (await _loadTournamentRoundSummary(currentEvent.id)).value;
      isSubmittingLifecycle = false;
      notifyListeners();
      return assignments;
    } catch (exception) {
      lifecycleError = _formatLifecycleError(exception);
      isSubmittingLifecycle = false;
      notifyListeners();
      return null;
    }
  }

  Future<DashboardTableScanResult?> resolveScannedTableTag(
    String normalizedUid,
  ) async {
    final currentEvent = event;
    final tableRepository = _tableRepository;
    final sessionRepository = _sessionRepository;
    if (!_canScoreCurrentPhase()) {
      tableScanError = 'Your role cannot score this phase.';
      notifyListeners();
      return null;
    }
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

  bool _canScoreCurrentPhase() {
    final phase = effectiveScoringPhase ?? event?.currentScoringPhase;
    return switch (phase) {
      EventScoringPhase.qualification => canScoreLegacyQualification,
      EventScoringPhase.tournament => canScoreTournament,
      EventScoringPhase.bonus => canScoreBonus,
      null => false,
    };
  }
}
