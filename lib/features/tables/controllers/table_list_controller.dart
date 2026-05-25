import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/scoring/models/round_timer_state.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';

class TableListController extends ChangeNotifier {
  TableListController({
    required TableRepository tableRepository,
    required SessionRepository sessionRepository,
    required GuestRepository guestRepository,
    SeatingRepository? seatingRepository,
    DateTime Function()? now,
  })  : _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _guestRepository = guestRepository,
        _seatingRepository = seatingRepository,
        _now = now ?? DateTime.now;

  final TableRepository _tableRepository;
  final SessionRepository _sessionRepository;
  final GuestRepository _guestRepository;
  final SeatingRepository? _seatingRepository;
  final DateTime Function() _now;

  bool isLoading = true;
  bool isStartingNextRound = false;
  String? error;
  List<EventTableRecord> tables = const [];
  Map<String, TableSessionRecord> activeSessionsByTableId = const {};
  Map<String, List<TableSessionRecord>> sessionsByTableId = const {};
  Map<String, SessionDetailRecord> sessionDetailsBySessionId = const {};
  Map<String, String> guestNamesById = const {};
  TournamentRoundSummary tournamentRoundSummary =
      TournamentRoundSummary.empty();
  List<TableOverviewCardData> cards = const [];
  List<TableOverviewCardData> currentRoundCards = const [];
  List<TableOverviewCardData> otherCards = const [];

  void refreshRoundTimers() {
    if (activeSessionsByTableId.isEmpty) {
      return;
    }

    _refreshCards();
    notifyListeners();
  }

  Future<void> load(String eventId) async {
    final cachedTables = await _tableRepository.readCachedTables(eventId);
    final cachedSessions = await _sessionRepository.readCachedSessions(eventId);
    final cachedGuests = await _guestRepository.readCachedGuests(eventId);
    final cachedRoundSummary = await _readCachedTournamentRoundSummary(eventId);

    isLoading = true;
    error = null;
    tables = cachedTables;
    activeSessionsByTableId = _activeSessionsByTable(cachedSessions);
    sessionsByTableId = _sessionsByTable(cachedSessions);
    guestNamesById = _guestNamesById(cachedGuests);
    tournamentRoundSummary =
        cachedRoundSummary ?? TournamentRoundSummary.empty();
    sessionDetailsBySessionId =
        await _readCachedDetails(activeSessionsByTableId.values);
    _refreshCards();
    notifyListeners();

    try {
      tables = await _tableRepository.listTables(eventId);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error = exception.toString();
      }
    }

    try {
      final guests = await _guestRepository.listGuests(eventId);
      guestNamesById = _guestNamesById(guests);
    } catch (_) {
      // Cached guest names are enough for the table list fallback.
    }

    try {
      final sessions = await _sessionRepository.listSessions(eventId);
      activeSessionsByTableId = _activeSessionsByTable(sessions);
      sessionsByTableId = _sessionsByTable(sessions);
      sessionDetailsBySessionId =
          await _loadDetails(activeSessionsByTableId.values);
    } catch (exception) {
      if (tables.isEmpty && activeSessionsByTableId.isEmpty) {
        error ??= exception.toString();
      }
    }

    tournamentRoundSummary = await _loadTournamentRoundSummary(eventId);

    _refreshCards();
    isLoading = false;
    notifyListeners();
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
    notifyListeners();

    try {
      final assignments =
          await seatingRepository.generateTournamentRound(eventId);
      await load(eventId);
      return assignments;
    } catch (exception) {
      error = exception.toString();
      return null;
    } finally {
      isStartingNextRound = false;
      notifyListeners();
    }
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
    return [
      for (final table in tables)
        TableOverviewCardData(
          table: table,
          liveSummary: _liveSummaryFor(table),
          currentRoundSummary: currentRoundTablesById[table.id],
          currentRoundHandCount: _currentRoundHandCount(
            currentRoundTablesById[table.id],
          ),
        ),
    ];
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

  Future<TournamentRoundSummary> _loadTournamentRoundSummary(
    String eventId,
  ) async {
    try {
      return await _seatingRepository?.loadTournamentRoundSummary(eventId) ??
          TournamentRoundSummary.empty();
    } catch (_) {
      return await _readCachedTournamentRoundSummary(eventId) ??
          TournamentRoundSummary.empty();
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

  LiveTableSummary? _liveSummaryFor(EventTableRecord table) {
    final session = activeSessionsByTableId[table.id];
    if (session == null) {
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
        roundWindLabel: 'Round Wind: East',
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
      roundWindLabel: 'Round Wind: ${_roundWindLabel(detail.hands)}',
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
    return guestNamesById[guestId] ?? guestId;
  }

  LastHandSummary _lastHandSummary(
    SessionDetailRecord detail,
    HandResultRecord? hand,
  ) {
    if (hand == null) {
      return const LastHandSummary(title: 'No scores yet');
    }

    if (hand.resultType == HandResultType.washout) {
      return LastHandSummary(
        title: 'Draw',
        detail: hand.dealerRotated
            ? 'East rotates. Ready for the next hand.'
            : 'East retains. Ready for the next hand.',
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
    return LastHandSummary(
      title: '$winner $winLabel',
      detail: fanCount == null
          ? 'Score recorded. Ready for the next hand.'
          : '$fanCount fan recorded. Ready for the next hand.',
    );
  }

  String _progressLabel(int handCount) {
    if (handCount == 0) {
      return 'No hands recorded';
    }
    return 'Hand $handCount';
  }

  String _roundWindLabel(List<HandResultRecord> hands) {
    final dealerRotationCount = hands
        .where(
          (hand) =>
              hand.status == HandResultStatus.recorded && hand.dealerRotated,
        )
        .length;
    final windCycle = dealerRotationCount ~/ 4;
    const winds = ['East', 'South', 'West'];
    final cappedWindCycle =
        windCycle >= winds.length ? winds.length - 1 : windCycle;
    return winds[cappedWindCycle];
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
}
