import 'package:flutter/foundation.dart';
import 'package:mosaic/core/errors/user_facing_error.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';
import 'package:mosaic/features/tables/models/finals_overview_view_models.dart';

class TableListController extends ChangeNotifier {
  TableListController({
    required TableRepository tableRepository,
    required SessionRepository sessionRepository,
    required GuestRepository guestRepository,
    FinalsRepository? finalsRepository,
    SeatingRepository? seatingRepository,
    this.scoringPhase = EventScoringPhase.tournament,
    DateTime Function()? now,
  })  : _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _guestRepository = guestRepository,
        _finalsRepository = finalsRepository,
        _seatingRepository = seatingRepository,
        _now = now ?? DateTime.now;

  final TableRepository _tableRepository;
  final SessionRepository _sessionRepository;
  final GuestRepository _guestRepository;
  final FinalsRepository? _finalsRepository;
  final SeatingRepository? _seatingRepository;
  final EventScoringPhase scoringPhase;
  final DateTime Function() _now;

  late EventScoringPhase effectiveScoringPhase = scoringPhase;
  bool isLoading = true;
  bool isStartingNextRound = false;
  bool isStartingAllTables = false;
  bool isUpdatingTimers = false;
  String? error;
  String? finalsActionError;
  List<EventTableRecord> tables = const [];
  Map<String, TableSessionRecord> activeSessionsByTableId = const {};
  Map<String, List<TableSessionRecord>> sessionsByTableId = const {};
  Map<String, SessionDetailRecord> sessionDetailsBySessionId = const {};
  Map<String, String> guestNamesById = const {};
  TournamentRoundSummary tournamentRoundSummary =
      TournamentRoundSummary.empty();
  BonusRoundState? bonusRoundState;
  FinalsState? finalsState;
  FinalsOverviewSummary? finalsSummary;
  List<SeatingAssignmentRecord> bonusAssignments = const [];
  List<TableOverviewCardData> cards = const [];
  List<TableOverviewCardData> currentRoundCards = const [];
  List<TableOverviewCardData> otherCards = const [];
  int _requestGeneration = 0;
  bool _isDisposed = false;
  Future<FinalsState?>? _finalsActionFuture;

  FinalsAction? get primaryFinalsAction => finalsState?.primaryAction;

  bool get isExecutingFinalsAction => _finalsActionFuture != null;

  bool get isSuddenDeathRequired =>
      bonusRoundState?.suddenDeathStatus == 'required';

  bool get isSuddenDeathActive =>
      bonusRoundState?.suddenDeathStatus == 'active';

  bool get isPlayInRequired => bonusRoundState?.playInStatus == 'required';

  bool get isPlayInActive => bonusRoundState?.playInStatus == 'active';

  bool get canStartAllTables =>
      effectiveScoringPhase == EventScoringPhase.tournament &&
      tournamentRoundSummary.round?.status == TournamentRoundStatus.seating &&
      tournamentRoundSummary.assignedTableCount > 0 &&
      activeSessionsByTableId.isEmpty;

  void refreshRoundTimers() {
    if (activeSessionsByTableId.isEmpty) {
      return;
    }

    _refreshCards();
    _notifyIfActive();
  }

  Future<void> load(String eventId, {bool silent = false}) async {
    _loadedEventId = eventId;
    final generation = ++_requestGeneration;
    final cachedTables = await _tableRepository.readCachedTables(eventId);
    final cachedSessions = await _sessionRepository.readCachedSessions(eventId);
    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    final cachedRoundSummary = await _readCachedTournamentRoundSummary(eventId);
    final cachedBonusAssignments = await _readCachedBonusAssignments(eventId);
    if (!_isCurrent(generation)) return;
    final cachedSummaryIsUsable = _hasUsableRoundSummary(cachedRoundSummary);

    if (!silent) {
      isLoading = true;
    }
    error = null;
    if (!silent || cachedTables.isNotEmpty || tables.isEmpty) {
      tables = cachedTables;
    }
    if (!silent || cachedSessions.isNotEmpty || sessionsByTableId.isEmpty) {
      activeSessionsByTableId = _activeSessionsByTable(cachedSessions);
      sessionsByTableId = _sessionsByTable(cachedSessions);
    }
    if (!silent || cachedGuests.isNotEmpty || guestNamesById.isEmpty) {
      guestNamesById = _guestNamesById(cachedGuests);
    }
    if (!silent ||
        cachedBonusAssignments.isNotEmpty ||
        bonusAssignments.isEmpty) {
      bonusAssignments = cachedBonusAssignments;
    }
    if (!silent) {
      bonusRoundState = null;
    }
    final resolvedScoringPhase = _resolveEffectiveScoringPhase(
      sessions: cachedSessions,
      activeBonusAssignments: cachedBonusAssignments,
    );
    if (!silent ||
        cachedSessions.isNotEmpty ||
        cachedBonusAssignments.isNotEmpty ||
        effectiveScoringPhase == scoringPhase) {
      effectiveScoringPhase = resolvedScoringPhase;
    }
    if (effectiveScoringPhase == EventScoringPhase.bonus) {
      if (_finalsRepository != null) {
        tournamentRoundSummary = TournamentRoundSummary.empty();
      } else if (!silent ||
          cachedBonusAssignments.isNotEmpty ||
          bonusRoundState == null) {
        tournamentRoundSummary = _buildBonusRoundSummary();
      }
    } else if (!silent ||
        cachedSummaryIsUsable ||
        !_hasUsableRoundSummary(tournamentRoundSummary)) {
      tournamentRoundSummary =
          cachedRoundSummary ?? TournamentRoundSummary.empty();
    }
    final cachedSessionDetails =
        await _readCachedDetails(activeSessionsByTableId.values);
    if (!silent ||
        cachedSessionDetails.isNotEmpty ||
        sessionDetailsBySessionId.isEmpty) {
      sessionDetailsBySessionId = cachedSessionDetails;
    }
    _refreshCards();
    _notifyIfActive();

    try {
      final loadedTables = await _tableRepository.listTables(eventId);
      if (!_isCurrent(generation)) return;
      tables = loadedTables;
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error = userFacingError(exception, fallback: 'Unable to load tables.');
      }
    }

    try {
      final guests = await _guestRepository.listGuests(eventId);
      if (!_isCurrent(generation)) return;
      guestNamesById = _guestNamesById(guests);
    } catch (_) {
      // Cached guest names are enough for the table list fallback.
    }

    try {
      final sessions = await _sessionRepository.listSessions(eventId);
      if (!_isCurrent(generation)) return;
      activeSessionsByTableId = _activeSessionsByTable(sessions);
      sessionsByTableId = _sessionsByTable(sessions);
      final loadedDetails = await _loadDetails(activeSessionsByTableId.values);
      if (!_isCurrent(generation)) return;
      sessionDetailsBySessionId = loadedDetails;
    } catch (exception) {
      if (!_isCurrent(generation)) return;
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error ??=
            userFacingError(exception, fallback: 'Unable to load tables.');
      }
    }

    final loadedBonusAssignments = await _loadBonusAssignments(eventId);
    if (!_isCurrent(generation)) return;
    if (!silent ||
        loadedBonusAssignments.succeeded ||
        bonusAssignments.isEmpty) {
      bonusAssignments = loadedBonusAssignments.value;
    }
    final resolvedRemoteScoringPhase = _resolveEffectiveScoringPhase(
      sessions: sessionsByTableId.values.expand((sessions) => sessions),
      activeBonusAssignments: bonusAssignments,
    );
    effectiveScoringPhase = resolvedRemoteScoringPhase;
    if (effectiveScoringPhase == EventScoringPhase.bonus) {
      BonusRoundState? loadedBonusRoundState;
      var didLoadBonusRoundState = false;
      try {
        loadedBonusRoundState =
            await _seatingRepository?.loadBonusRoundState(eventId);
        if (!_isCurrent(generation)) return;
        didLoadBonusRoundState = true;
      } catch (_) {
        // Preserve the current bonus state when recovery cannot reach remote.
      }
      if (!silent || didLoadBonusRoundState || bonusRoundState == null) {
        bonusRoundState = loadedBonusRoundState;
      }
      if (_finalsRepository != null) {
        tournamentRoundSummary = TournamentRoundSummary.empty();
      } else if (!silent ||
          loadedBonusAssignments.succeeded ||
          bonusRoundState == null) {
        tournamentRoundSummary = _buildBonusRoundSummary();
      }

      final finalsRepository = _finalsRepository;
      if (finalsRepository != null) {
        try {
          final loadedFinalsState =
              await finalsRepository.loadFinalsState(eventId);
          if (!_isCurrent(generation)) return;
          _setFinalsState(loadedFinalsState);
          tournamentRoundSummary = TournamentRoundSummary.empty();
        } catch (exception) {
          if (!_isCurrent(generation)) return;
          if (finalsState == null) {
            tournamentRoundSummary = TournamentRoundSummary.empty();
            if (!silent) {
              error ??= userFacingError(
                exception,
                fallback: 'Unable to load Finals.',
              );
            }
          }
        }
      }
    } else {
      bonusRoundState = null;
      finalsState = null;
      finalsSummary = null;
      final loadedSummary = await _loadTournamentRoundSummary(eventId);
      if (!_isCurrent(generation)) return;
      if (!silent ||
          loadedSummary.succeeded ||
          !_hasUsableRoundSummary(tournamentRoundSummary)) {
        tournamentRoundSummary = loadedSummary.value;
      }
    }

    if (_isCurrent(generation)) {
      _refreshCards();
      isLoading = false;
      _notifyIfActive();
    }
  }

  Future<FinalsState?> executeFinalsAction(
    FinalsAction action, {
    String? tableId,
  }) {
    final isServerAction = finalsState?.allowedActions.any(
          (serverAction) => identical(serverAction, action),
        ) ??
        false;
    if (!isServerAction) return Future.value(finalsState);
    if (action.kind == FinalsActionKind.startContest) {
      final selectedTableId = tableId ?? action.tableId;
      if (selectedTableId == null ||
          !usableTablesForFinalsAction(action)
              .any((table) => table.id == selectedTableId)) {
        return Future.value(finalsState);
      }
    }
    final existing = _finalsActionFuture;
    if (existing != null) return existing;

    final future = _executeFinalsAction(action, tableId: tableId);
    _finalsActionFuture = future;
    _notifyIfActive();
    future.whenComplete(() {
      if (identical(_finalsActionFuture, future)) {
        _finalsActionFuture = null;
        _notifyIfActive();
      }
    });
    return future;
  }

  Future<FinalsState?> _executeFinalsAction(
    FinalsAction action, {
    String? tableId,
  }) async {
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
              tableId: tableId ?? action.tableId,
              expectedStateVersion: action.expectedStateVersion!,
            ),
          ),
      };
      _setFinalsState(updatedState);
      await _refreshSessionsAfterFinalsAction();
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

  String? _loadedEventId;

  String _eventIdForFinalsAction() {
    final eventId = _loadedEventId;
    if (eventId == null) {
      throw StateError('Refresh Finals before trying that action.');
    }
    return eventId;
  }

  void _setFinalsState(FinalsState state) {
    finalsState = state;
    finalsSummary = FinalsOverviewSummary.fromState(state);
  }

  Future<void> _refreshSessionsAfterFinalsAction() async {
    final eventId = _eventIdForFinalsAction();
    try {
      final sessions = await _sessionRepository.listSessions(eventId);
      activeSessionsByTableId = _activeSessionsByTable(sessions);
      sessionsByTableId = _sessionsByTable(sessions);
      sessionDetailsBySessionId =
          await _loadDetails(activeSessionsByTableId.values);
      _refreshCards();
    } catch (_) {
      // The returned Finals state remains authoritative and usable.
    }
  }

  List<EventTableRecord> usableTablesForFinalsAction(FinalsAction action) {
    if (action.kind != FinalsActionKind.startContest) return const [];
    final contest = finalsState?.contests
        .where((contest) => contest.id == action.contestId)
        .firstOrNull;
    if (contest == null || contest.status != FinalsContestStatus.ready) {
      return const [];
    }
    final availableTableIds = action.availableTableIds.toSet();
    final participantIds = {
      for (final participant in contest.participants) participant.eventGuestId,
    };
    var hasParticipantConflict = false;
    for (final entry in activeSessionsByTableId.entries) {
      final detail = sessionDetailsBySessionId[entry.value.id];
      if (detail != null &&
          detail.seats.any(
            (seat) => participantIds.contains(seat.eventGuestId),
          )) {
        hasParticipantConflict = true;
      }
    }
    if (hasParticipantConflict) return const [];
    return tables
        .where(
          (table) =>
              availableTableIds.contains(table.id) &&
              table.nfcTagId != null &&
              !activeSessionsByTableId.containsKey(table.id),
        )
        .toList(growable: false)
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
  }

  Future<List<SeatingAssignmentRecord>?> startNextTournamentRound(
    String eventId,
  ) async {
    final seatingRepository = _seatingRepository;
    if (seatingRepository == null || !tournamentRoundSummary.isComplete) {
      return null;
    }

    isStartingNextRound = true;
    error = null;
    _notifyIfActive();

    try {
      final assignments =
          await seatingRepository.generateTournamentRound(eventId);
      await load(eventId);
      return assignments;
    } catch (exception) {
      error = userFacingError(exception);
      return null;
    } finally {
      isStartingNextRound = false;
      _notifyIfActive();
    }
  }

  Future<void> startAllTables(String eventId) async {
    if (!canStartAllTables || isStartingAllTables) {
      return;
    }

    isStartingAllTables = true;
    error = null;
    _notifyIfActive();

    try {
      await _sessionRepository.startCurrentTournamentRoundSessions(eventId);
      await load(eventId);
    } catch (exception) {
      await load(eventId);
      if (activeSessionsByTableId.isEmpty) {
        error = userFacingError(exception);
      }
    } finally {
      isStartingAllTables = false;
      _notifyIfActive();
    }
  }

  Future<void> pauseSessionTimer(String eventId, String sessionId) async {
    await _updateOneSessionTimer(
      eventId: eventId,
      sessionId: sessionId,
      update: _sessionRepository.pauseSession,
    );
  }

  Future<void> resumeSessionTimer(String eventId, String sessionId) async {
    await _updateOneSessionTimer(
      eventId: eventId,
      sessionId: sessionId,
      update: _sessionRepository.resumeSession,
    );
  }

  Future<void> pauseAllRoundTimers(String eventId) async {
    final sessionIds = _currentRoundSessionIdsForStatus(SessionStatus.active);
    await _updateManySessionTimers(
      eventId: eventId,
      sessionIds: sessionIds,
      update: _sessionRepository.pauseSession,
    );
  }

  Future<void> resumeAllRoundTimers(String eventId) async {
    final sessionIds = _currentRoundSessionIdsForStatus(SessionStatus.paused);
    await _updateManySessionTimers(
      eventId: eventId,
      sessionIds: sessionIds,
      update: _sessionRepository.resumeSession,
    );
  }

  Future<void> _updateOneSessionTimer({
    required String eventId,
    required String sessionId,
    required Future<SessionDetailRecord> Function(String sessionId) update,
  }) async {
    await _updateManySessionTimers(
      eventId: eventId,
      sessionIds: [sessionId],
      update: update,
    );
  }

  Future<void> _updateManySessionTimers({
    required String eventId,
    required List<String> sessionIds,
    required Future<SessionDetailRecord> Function(String sessionId) update,
  }) async {
    if (sessionIds.isEmpty || isUpdatingTimers) {
      return;
    }

    isUpdatingTimers = true;
    error = null;
    _notifyIfActive();

    try {
      await Future.wait(sessionIds.map(update));
      await load(eventId);
    } catch (exception) {
      error = userFacingError(exception);
    } finally {
      isUpdatingTimers = false;
      _notifyIfActive();
    }
  }

  List<String> _currentRoundSessionIdsForStatus(SessionStatus status) {
    return [
      for (final card in currentRoundCards)
        if (card.liveSummary?.status == status) card.liveSummary!.sessionId,
    ];
  }

  List<TableSessionRecord> sessionsForTable(String tableId) {
    return sessionsByTableId[tableId] ?? const [];
  }

  Map<String, TableSessionRecord> _activeSessionsByTable(
    List<TableSessionRecord> sessions,
  ) {
    return {
      for (final session in sessions)
        if (session.status == SessionStatus.active ||
            session.status == SessionStatus.paused)
          session.eventTableId: session,
    };
  }

  Map<String, List<TableSessionRecord>> _sessionsByTable(
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

  Map<String, String> _guestNamesById(List<EventGuestRecord> guests) {
    return {
      for (final guest in guests) guest.id: guest.displayName,
    };
  }

  Future<Map<String, SessionDetailRecord>> _readCachedDetails(
    Iterable<TableSessionRecord> sessions,
  ) async {
    final details = <String, SessionDetailRecord>{};
    for (final session in sessions) {
      final detail = await _sessionRepository.readCachedSessionDetail(
        session.id,
      );
      if (detail != null) {
        details[session.id] = detail;
      }
    }
    return details;
  }

  Future<Map<String, SessionDetailRecord>> _loadDetails(
    Iterable<TableSessionRecord> sessions,
  ) async {
    final entries = await Future.wait(
      sessions.map((session) async {
        try {
          final detail = await _sessionRepository.loadSessionDetail(
            session.id,
          );
          return MapEntry(session.id, detail);
        } catch (_) {
          final cached = await _sessionRepository.readCachedSessionDetail(
            session.id,
          );
          if (cached != null) {
            return MapEntry(session.id, cached);
          }
        }
        return null;
      }),
    );

    return {
      for (final entry in entries)
        if (entry != null) entry.key: entry.value,
    };
  }

  void _refreshCards() {
    cards = _buildCards();
    currentRoundCards =
        cards.where((card) => card.isCurrentRound).toList(growable: false);
    otherCards =
        cards.where((card) => !card.isCurrentRound).toList(growable: false);
  }

  List<TableOverviewCardData> _buildCards() {
    final currentRoundTablesById = {
      for (final table in tournamentRoundSummary.currentRoundTables)
        table.eventTableId: table,
    };
    final bonusAssignmentsByTableId = _bonusAssignmentsByTableId();
    return [
      for (final table in tables)
        TableOverviewCardData(
          table: table,
          liveSummary: _liveSummaryFor(
            table,
            matchScoringPhase: currentRoundTablesById.containsKey(table.id)
                ? effectiveScoringPhase
                : null,
          ),
          currentRoundSummary: currentRoundTablesById[table.id],
          currentRoundHandCount: _currentRoundHandCount(
            currentRoundTablesById[table.id],
          ),
          assignmentTitle: _assignmentTitle(
                bonusAssignmentsByTableId[table.id],
              ) ??
              _playInAssignmentTitle(table.id) ??
              _suddenDeathAssignmentTitle(table.id),
          assignmentSubtitle:
              effectiveScoringPhase == EventScoringPhase.bonus &&
                      currentRoundTablesById.containsKey(table.id)
                  ? table.label
                  : null,
        ),
    ];
  }

  Map<String, List<SeatingAssignmentRecord>> _bonusAssignmentsByTableId() {
    final grouped = <String, List<SeatingAssignmentRecord>>{};
    for (final assignment in bonusAssignments) {
      grouped.putIfAbsent(assignment.eventTableId, () => []).add(assignment);
    }
    return grouped;
  }

  String? _assignmentTitle(List<SeatingAssignmentRecord>? assignments) {
    if (effectiveScoringPhase != EventScoringPhase.bonus ||
        assignments == null ||
        assignments.isEmpty) {
      return null;
    }

    final role = assignments.first.bonusTableRole;
    return switch (role) {
      BonusTableRole.tableOfChampions => 'Table of Champions',
      BonusTableRole.tableOfRedemption => 'Table of Redemption',
      BonusTableRole.tableOfChampionsPlayIn => 'Table of Champions Play-In',
      BonusTableRole.tableOfChampionsSuddenDeath =>
        'Table of Champions Sudden Death',
      null => 'Finals Table',
    };
  }

  String? _suddenDeathAssignmentTitle(String tableId) {
    final state = bonusRoundState;
    if (effectiveScoringPhase != EventScoringPhase.bonus ||
        state == null ||
        state.suddenDeathTableId != tableId ||
        (state.suddenDeathStatus != 'required' &&
            state.suddenDeathStatus != 'active')) {
      return null;
    }

    return 'Table of Champions Sudden Death';
  }

  String? _playInAssignmentTitle(String tableId) {
    final state = bonusRoundState;
    if (effectiveScoringPhase != EventScoringPhase.bonus ||
        state == null ||
        state.playInTableId != tableId ||
        (state.playInStatus != 'required' && state.playInStatus != 'active')) {
      return null;
    }

    return 'Table of Champions Play-In';
  }

  Future<TournamentRoundSummary?> _readCachedTournamentRoundSummary(
    String eventId,
  ) async {
    try {
      return await _seatingRepository?.readCachedTournamentRoundSummary(
        eventId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<SeatingAssignmentRecord>> _readCachedBonusAssignments(
    String eventId,
  ) async {
    try {
      final assignments =
          await _seatingRepository?.readCachedAssignments(eventId) ?? const [];
      return _activeBonusAssignments(assignments);
    } catch (_) {
      return const [];
    }
  }

  Future<_RemoteLoadResult<List<SeatingAssignmentRecord>>>
      _loadBonusAssignments(
    String eventId,
  ) async {
    try {
      final assignments =
          await _seatingRepository?.loadAssignments(eventId) ?? const [];
      return _RemoteLoadResult(
        value: _activeBonusAssignments(assignments),
        succeeded: true,
      );
    } catch (_) {
      final cached = await _readCachedBonusAssignments(eventId);
      return _RemoteLoadResult(value: cached, succeeded: false);
    }
  }

  bool _hasUsableRoundSummary(TournamentRoundSummary? summary) {
    if (summary == null) {
      return false;
    }
    return summary.round != null ||
        summary.assignedTableCount > 0 ||
        summary.currentRoundTables.isNotEmpty ||
        summary.otherTables.isNotEmpty;
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

  EventScoringPhase _resolveEffectiveScoringPhase({
    required Iterable<TableSessionRecord> sessions,
    required List<SeatingAssignmentRecord> activeBonusAssignments,
  }) {
    if (scoringPhase == EventScoringPhase.bonus ||
        activeBonusAssignments.isNotEmpty) {
      return EventScoringPhase.bonus;
    }

    final hasLiveBonusSession = sessions.any(
      (session) =>
          session.scoringPhase == EventScoringPhase.bonus &&
          (session.status == SessionStatus.active ||
              session.status == SessionStatus.paused),
    );
    return hasLiveBonusSession ? EventScoringPhase.bonus : scoringPhase;
  }

  TournamentRoundSummary _buildBonusRoundSummary() {
    final state = bonusRoundState;
    if (state?.playInStatus == 'required' || state?.playInStatus == 'active') {
      final playInSummary = _buildPlayInSummary(state!);
      if (playInSummary != null) {
        return playInSummary;
      }
    }

    if (state?.suddenDeathStatus == 'required' ||
        state?.suddenDeathStatus == 'active') {
      final suddenDeathSummary = _buildSuddenDeathSummary(state!);
      if (suddenDeathSummary != null) {
        return suddenDeathSummary;
      }
    }

    final grouped = _bonusAssignmentsByTableId();
    if (grouped.isEmpty) {
      return TournamentRoundSummary.empty();
    }

    final tableOrderById = {
      for (final table in tables) table.id: table.displayOrder,
    };
    final tableSummaries = [
      for (final entry in grouped.entries)
        _bonusTableSummary(
          eventTableId: entry.key,
          assignments: entry.value,
          tableDisplayOrder: tableOrderById[entry.key] ?? 0,
        ),
    ]..sort((left, right) {
        final roleCompare =
            _bonusRoleSort(left).compareTo(_bonusRoleSort(right));
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
    final assignmentRound = bonusAssignments.first.assignmentRound;
    final status = completeCount >= tableSummaries.length
        ? TournamentRoundStatus.complete
        : activeCount + pausedCount > 0
            ? TournamentRoundStatus.active
            : TournamentRoundStatus.seating;

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

  TournamentRoundSummary? _buildPlayInSummary(BonusRoundState state) {
    final tableId = state.playInTableId;
    if (tableId == null) {
      return null;
    }

    final tableById = {for (final table in tables) table.id: table};
    final table = tableById[tableId];
    if (table == null) {
      return null;
    }

    final assignments = bonusAssignments
        .where(
          (assignment) =>
              assignment.eventTableId == tableId &&
              assignment.assignmentType == SeatingAssignmentType.bonus &&
              assignment.status == 'active' &&
              (assignment.bonusTableRole ==
                      BonusTableRole.tableOfChampionsPlayIn ||
                  assignment.bonusTableRole == null),
        )
        .toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));

    final tableStatus = state.playInStatus == 'required'
        ? TournamentRoundTableStatus.notStarted
        : _bonusSessionStatusFor(
            tableId,
            bonusTableRole: BonusTableRole.tableOfChampionsPlayIn,
          );
    final activeCount =
        tableStatus == TournamentRoundTableStatus.active ? 1 : 0;
    final pausedCount =
        tableStatus == TournamentRoundTableStatus.paused ? 1 : 0;
    final completeCount =
        tableStatus == TournamentRoundTableStatus.complete ? 1 : 0;
    final notStartedCount =
        tableStatus == TournamentRoundTableStatus.notStarted ? 1 : 0;
    final assignmentRound = assignments.isNotEmpty
        ? assignments.first.assignmentRound
        : bonusAssignments.isNotEmpty
            ? bonusAssignments.first.assignmentRound + 1
            : 1;

    return TournamentRoundSummary(
      round: TournamentRoundRecord(
        id: state.bonusRoundId ?? 'bonus_$assignmentRound',
        eventId: state.eventId ?? table.eventId,
        roundNumber: assignmentRound,
        scoringPhase: EventScoringPhase.bonus,
        status: completeCount == 1
            ? TournamentRoundStatus.complete
            : activeCount + pausedCount > 0
                ? TournamentRoundStatus.active
                : TournamentRoundStatus.seating,
        assignmentRound: assignmentRound,
      ),
      assignedTableCount: 1,
      completeTableCount: completeCount,
      activeTableCount: activeCount,
      pausedTableCount: pausedCount,
      notStartedTableCount: notStartedCount,
      currentRoundTables: [
        TournamentRoundTableSummary(
          eventTableId: tableId,
          tableLabel: table.label,
          tableDisplayOrder: table.displayOrder,
          status: tableStatus,
          activeSessionId: _matchingLiveSession(
            eventTableId: tableId,
            scoringPhase: EventScoringPhase.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsPlayIn,
          )?.id,
          latestEndedSessionId: _matchingLatestEndedSession(
            eventTableId: tableId,
            scoringPhase: EventScoringPhase.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsPlayIn,
          )?.id,
          assignedPlayers: assignments.isNotEmpty
              ? [
                  for (final assignment in assignments)
                    TournamentRoundAssignedPlayer(
                      eventGuestId: assignment.eventGuestId,
                      displayName: assignment.displayName,
                      seatIndex: assignment.seatIndex,
                    ),
                ]
              : _playInPlayers(state),
        ),
      ],
      otherTables: const [],
    );
  }

  TournamentRoundSummary? _buildSuddenDeathSummary(BonusRoundState state) {
    final tableId = state.suddenDeathTableId;
    if (tableId == null) {
      return null;
    }

    final tableById = {for (final table in tables) table.id: table};
    final table = tableById[tableId];
    if (table == null) {
      return null;
    }

    final assignments = bonusAssignments
        .where(
          (assignment) =>
              assignment.eventTableId == tableId &&
              assignment.assignmentType == SeatingAssignmentType.bonus &&
              assignment.status == 'active' &&
              (assignment.bonusTableRole ==
                      BonusTableRole.tableOfChampionsSuddenDeath ||
                  assignment.bonusTableRole == null),
        )
        .toList(growable: false)
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));

    final tableStatus = state.suddenDeathStatus == 'required'
        ? TournamentRoundTableStatus.notStarted
        : _bonusSessionStatusFor(
            tableId,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          );
    final activeCount =
        tableStatus == TournamentRoundTableStatus.active ? 1 : 0;
    final pausedCount =
        tableStatus == TournamentRoundTableStatus.paused ? 1 : 0;
    final completeCount =
        tableStatus == TournamentRoundTableStatus.complete ? 1 : 0;
    final notStartedCount =
        tableStatus == TournamentRoundTableStatus.notStarted ? 1 : 0;
    final assignmentRound = assignments.isNotEmpty
        ? assignments.first.assignmentRound
        : bonusAssignments.isNotEmpty
            ? bonusAssignments.first.assignmentRound + 1
            : 1;

    return TournamentRoundSummary(
      round: TournamentRoundRecord(
        id: state.bonusRoundId ?? 'bonus_$assignmentRound',
        eventId: state.eventId ?? table.eventId,
        roundNumber: assignmentRound,
        scoringPhase: EventScoringPhase.bonus,
        status: completeCount == 1
            ? TournamentRoundStatus.complete
            : activeCount + pausedCount > 0
                ? TournamentRoundStatus.active
                : TournamentRoundStatus.seating,
        assignmentRound: assignmentRound,
      ),
      assignedTableCount: 1,
      completeTableCount: completeCount,
      activeTableCount: activeCount,
      pausedTableCount: pausedCount,
      notStartedTableCount: notStartedCount,
      currentRoundTables: [
        TournamentRoundTableSummary(
          eventTableId: tableId,
          tableLabel: table.label,
          tableDisplayOrder: table.displayOrder,
          status: tableStatus,
          activeSessionId: _matchingLiveSession(
            eventTableId: tableId,
            scoringPhase: EventScoringPhase.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          )?.id,
          latestEndedSessionId: _matchingLatestEndedSession(
            eventTableId: tableId,
            scoringPhase: EventScoringPhase.bonus,
            bonusTableRole: BonusTableRole.tableOfChampionsSuddenDeath,
          )?.id,
          assignedPlayers: assignments.isNotEmpty
              ? [
                  for (final assignment in assignments)
                    TournamentRoundAssignedPlayer(
                      eventGuestId: assignment.eventGuestId,
                      displayName: assignment.displayName,
                      seatIndex: assignment.seatIndex,
                    ),
                ]
              : _suddenDeathTiedPlayers(state),
        ),
      ],
      otherTables: const [],
    );
  }

  TournamentRoundTableStatus _bonusSessionStatusFor(
    String tableId, {
    BonusTableRole? bonusTableRole,
  }) {
    final activeSession = _matchingLiveSession(
      eventTableId: tableId,
      scoringPhase: EventScoringPhase.bonus,
      bonusTableRole: bonusTableRole,
    );
    return switch (activeSession?.status) {
      SessionStatus.active => TournamentRoundTableStatus.active,
      SessionStatus.paused => TournamentRoundTableStatus.paused,
      _ => _matchingLatestEndedSession(
                eventTableId: tableId,
                scoringPhase: EventScoringPhase.bonus,
                bonusTableRole: bonusTableRole,
              ) ==
              null
          ? TournamentRoundTableStatus.notStarted
          : TournamentRoundTableStatus.complete,
    };
  }

  List<TournamentRoundAssignedPlayer> _suddenDeathTiedPlayers(
    BonusRoundState state,
  ) {
    return [
      for (var index = 0; index < state.tiedTopPlayers.length; index += 1)
        TournamentRoundAssignedPlayer(
          eventGuestId:
              state.tiedTopPlayers[index].eventGuestId ?? 'tied_$index',
          displayName:
              state.tiedTopPlayers[index].displayName ?? 'Player ${index + 1}',
          seatIndex: index,
        ),
    ];
  }

  List<TournamentRoundAssignedPlayer> _playInPlayers(BonusRoundState state) {
    return [
      for (var index = 0; index < state.playInPlayers.length; index += 1)
        TournamentRoundAssignedPlayer(
          eventGuestId:
              state.playInPlayers[index].eventGuestId ?? 'play_in_$index',
          displayName:
              state.playInPlayers[index].displayName ?? 'Player ${index + 1}',
          seatIndex: index,
        ),
    ];
  }

  int _bonusRoleSort(TournamentRoundTableSummary table) {
    final assignments = _bonusAssignmentsByTableId()[table.eventTableId];
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

  TournamentRoundTableSummary _bonusTableSummary({
    required String eventTableId,
    required List<SeatingAssignmentRecord> assignments,
    required int tableDisplayOrder,
  }) {
    assignments
        .sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final activeSession = _matchingLiveSession(
      eventTableId: eventTableId,
      scoringPhase: EventScoringPhase.bonus,
      bonusTableRole: assignments.first.bonusTableRole,
    );
    final latestEndedSession = _matchingLatestEndedSession(
      eventTableId: eventTableId,
      scoringPhase: EventScoringPhase.bonus,
      bonusTableRole: assignments.first.bonusTableRole,
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

  TableSessionRecord? _matchingLiveSession({
    required String eventTableId,
    required EventScoringPhase scoringPhase,
    BonusTableRole? bonusTableRole,
  }) {
    final session = activeSessionsByTableId[eventTableId];
    if (session == null || session.scoringPhase != scoringPhase) {
      return null;
    }
    if (bonusTableRole != null && session.bonusTableRole != bonusTableRole) {
      return null;
    }
    return session;
  }

  TableSessionRecord? _matchingLatestEndedSession({
    required String eventTableId,
    required EventScoringPhase scoringPhase,
    BonusTableRole? bonusTableRole,
  }) {
    for (final session
        in sessionsByTableId[eventTableId] ?? const <TableSessionRecord>[]) {
      if (session.scoringPhase != scoringPhase) {
        continue;
      }
      if (bonusTableRole != null && session.bonusTableRole != bonusTableRole) {
        continue;
      }
      if (session.status == SessionStatus.completed ||
          session.status == SessionStatus.endedEarly) {
        return session;
      }
    }
    return null;
  }

  Future<_RemoteLoadResult<TournamentRoundSummary>> _loadTournamentRoundSummary(
    String eventId,
  ) async {
    try {
      return _RemoteLoadResult(
        value: await _seatingRepository?.loadTournamentRoundSummary(eventId) ??
            TournamentRoundSummary.empty(),
        succeeded: true,
      );
    } catch (_) {
      final cached = await _readCachedTournamentRoundSummary(eventId);
      return _RemoteLoadResult(
        value: cached ?? TournamentRoundSummary.empty(),
        succeeded: false,
      );
    }
  }

  int _currentRoundHandCount(TournamentRoundTableSummary? roundTable) {
    if (roundTable == null) {
      return 0;
    }

    final sessionId =
        roundTable.activeSessionId ?? roundTable.latestEndedSessionId;
    if (sessionId == null) {
      return 0;
    }

    for (final session in sessionsByTableId[roundTable.eventTableId] ??
        const <TableSessionRecord>[]) {
      if (session.id == sessionId) {
        return session.handCount;
      }
    }

    return 0;
  }

  LiveTableSummary? _liveSummaryFor(
    EventTableRecord table, {
    EventScoringPhase? matchScoringPhase,
  }) {
    final session = activeSessionsByTableId[table.id];
    if (session == null) {
      return null;
    }
    if (matchScoringPhase != null &&
        session.scoringPhase != matchScoringPhase) {
      return null;
    }

    final detail = sessionDetailsBySessionId[session.id];
    if (detail == null) {
      final showRoundTimer = _hasRoundTimer(session);
      final roundTime = showRoundTimer ? _roundTimeFor(session) : null;
      return LiveTableSummary(
        sessionId: session.id,
        status: session.status,
        seats: _fallbackSeats(session),
        handCount: session.handCount,
        roundWindLabel: 'Round Wind: ${_roundWindLabel(session, const [])}',
        dealerLabel: 'Dealer: Unassigned',
        progressLabel: _progressLabel(session.handCount),
        showRoundTimer: showRoundTimer,
        roundTimeLabel: roundTime?.label ?? '',
        isRoundExpired: roundTime?.isExpired ?? false,
        isRoundEndingSoon: roundTime?.isEndingSoon ?? false,
        lastHand: const LastHandSummary(title: 'No scores yet'),
      );
    }

    final recordedHands = detail.hands
        .where((hand) => hand.status == HandResultStatus.recorded)
        .toList(growable: false)
      ..sort((left, right) => left.handNumber.compareTo(right.handNumber));
    final latestHand = recordedHands.isEmpty ? null : recordedHands.last;
    final handCount = recordedHands.length;
    final showRoundTimer = _hasRoundTimer(detail.session);
    final roundTime = showRoundTimer ? _roundTimeFor(detail.session) : null;

    return LiveTableSummary(
      sessionId: session.id,
      status: session.status,
      seats: _seatSummaries(detail),
      handCount: handCount,
      roundWindLabel:
          'Round Wind: ${_roundWindLabel(detail.session, detail.hands)}',
      dealerLabel:
          'Dealer: ${_guestNameForSeat(detail, detail.session.currentDealerSeatIndex)}',
      progressLabel: _progressLabel(handCount),
      showRoundTimer: showRoundTimer,
      roundTimeLabel: roundTime?.label ?? '',
      isRoundExpired: roundTime?.isExpired ?? false,
      isRoundEndingSoon: roundTime?.isEndingSoon ?? false,
      lastHand: _lastHandSummary(detail, latestHand),
    );
  }

  bool _hasRoundTimer(TableSessionRecord session) {
    return session.scoringPhase == EventScoringPhase.tournament ||
        session.scoringPhase == EventScoringPhase.bonus;
  }

  RoundTimerState _roundTimeFor(TableSessionRecord session) {
    return RoundTimerState.fromStartedAt(
      startedAt: session.startedAt,
      pausedAt: session.roundTimerPausedAt,
      pausedSeconds: session.roundTimerPausedSeconds,
      now: _now(),
    );
  }

  List<SeatSummary> _fallbackSeats(TableSessionRecord session) {
    return [
      for (var index = 0; index < 4; index += 1)
        SeatSummary(
          seatIndex: index,
          windLabel: _windLabel(index, session.currentDealerSeatIndex),
          guestName: 'Unassigned',
          isDealer: index == session.currentDealerSeatIndex,
        ),
    ];
  }

  List<SeatSummary> _seatSummaries(SessionDetailRecord detail) {
    return [
      for (var index = 0; index < 4; index += 1)
        SeatSummary(
          seatIndex: index,
          windLabel: _windLabel(index, detail.session.currentDealerSeatIndex),
          guestName: _guestNameForSeat(detail, index),
          isDealer: index == detail.session.currentDealerSeatIndex,
        ),
    ];
  }

  String _guestNameForSeat(SessionDetailRecord detail, int seatIndex) {
    final matchingSeats =
        detail.seats.where((seat) => seat.seatIndex == seatIndex);
    if (matchingSeats.isEmpty) {
      return 'Unassigned';
    }

    final guestId = matchingSeats.first.eventGuestId;
    return guestNamesById[guestId] ?? 'Seat ${seatIndex + 1}';
  }

  LastHandSummary _lastHandSummary(
    SessionDetailRecord detail,
    HandResultRecord? hand,
  ) {
    if (hand == null) {
      return const LastHandSummary(title: 'No scores yet');
    }

    if (hand.resultType == HandResultType.washout) {
      final detailParts = [
        hand.dealerRotated ? 'East rotates.' : 'East retains.',
        ..._attachedFalseWinPenaltyParts(detail, hand.id),
        'Ready for the next hand.',
      ];
      return LastHandSummary(
        title: 'Draw',
        detail: detailParts.join(' '),
      );
    }

    if (hand.resultType == HandResultType.falseWinPenalty) {
      final penaltySeatIndex = hand.penaltySeatIndex;
      final caller = penaltySeatIndex == null
          ? 'Caller'
          : _guestNameForSeat(detail, penaltySeatIndex);
      return LastHandSummary(
        title: '$caller false win penalty',
        detail:
            '${hand.fanCount ?? 6} fan penalty. East retains. Ready for the next hand.',
      );
    }

    final winnerSeatIndex = hand.winnerSeatIndex;
    final winner = winnerSeatIndex == null
        ? 'Winner'
        : _guestNameForSeat(detail, winnerSeatIndex);
    final winLabel =
        hand.winType == HandWinType.discard ? 'discard' : 'self-draw';
    final fanCount = hand.fanCount;
    final scoreDetail =
        fanCount == null ? 'Score recorded.' : '$fanCount fan recorded.';
    final detailParts = [
      scoreDetail,
      ..._attachedFalseWinPenaltyParts(detail, hand.id),
      'Ready for the next hand.',
    ];
    return LastHandSummary(
      title: '$winner $winLabel',
      detail: detailParts.join(' '),
    );
  }

  List<String> _attachedFalseWinPenaltyParts(
    SessionDetailRecord detail,
    String handId,
  ) {
    final penalties = detail.falseWinPenaltiesForHand(handId);
    if (penalties.isEmpty) {
      return const [];
    }

    final callerSummaries = penalties.map((penalty) {
      final callerName = _guestNameForSeat(
        detail,
        penalty.penaltySeatIndex,
      );
      return '$callerName false win';
    }).join(' · ');
    return ['$callerSummaries.'];
  }

  String _progressLabel(int handCount) {
    if (handCount == 0) {
      return 'No hands recorded';
    }
    return 'Hand $handCount';
  }

  String _roundWindLabel(
    TableSessionRecord session,
    List<HandResultRecord> hands,
  ) {
    if (session.scoringPhase == EventScoringPhase.tournament &&
        session.assignmentRound != null) {
      return _windCycleLabel(session.assignmentRound! - 1);
    }

    final dealerRotationCount = hands
        .where(
          (hand) =>
              hand.status == HandResultStatus.recorded && hand.dealerRotated,
        )
        .length;
    return _windCycleLabel(dealerRotationCount ~/ 4);
  }

  String _windCycleLabel(int windCycle) {
    const winds = ['East', 'South', 'West', 'North'];
    return winds[windCycle % winds.length];
  }

  String _windLabel(int seatIndex, int currentDealerSeatIndex) {
    final relativeSeatIndex = (seatIndex - currentDealerSeatIndex) % 4;
    return switch (relativeSeatIndex) {
      0 => 'East',
      1 => 'South',
      2 => 'West',
      3 => 'North',
      _ => 'Seat',
    };
  }

  bool _isCurrent(int generation) =>
      !_isDisposed && generation == _requestGeneration;

  void _notifyIfActive() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestGeneration += 1;
    super.dispose();
  }
}

class _RemoteLoadResult<T> {
  const _RemoteLoadResult({required this.value, required this.succeeded});

  final T value;
  final bool succeeded;
}
