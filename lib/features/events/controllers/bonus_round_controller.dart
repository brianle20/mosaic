import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

const bonusRoundLiveSessionBlockedMessage =
    'End active or paused sessions first.';
const bonusRoundMinimumPlayersMessage =
    'At least 2 standings-eligible players are required for Table of Champions.';

enum BonusRoundTableRole {
  champions,
  redemption,
}

class BonusRoundController extends ChangeNotifier {
  BonusRoundController({
    required LeaderboardRepository leaderboardRepository,
    required TableRepository tableRepository,
    required SessionRepository sessionRepository,
    required SeatingRepository seatingRepository,
  })  : _leaderboardRepository = leaderboardRepository,
        _tableRepository = tableRepository,
        _sessionRepository = sessionRepository,
        _seatingRepository = seatingRepository;

  final LeaderboardRepository _leaderboardRepository;
  final TableRepository _tableRepository;
  final SessionRepository _sessionRepository;
  final SeatingRepository _seatingRepository;

  bool isLoading = true;
  bool isSubmitting = false;
  bool isResolvingTable = false;
  bool hasLiveSessions = false;
  bool hasCreatedBonusRound = false;
  String? error;
  String? actionError;
  List<EventTableRecord> tables = const [];
  List<BonusRoundSeatPreview> championSeats = const [];
  List<BonusRoundSeatPreview> redemptionSeats = const [];
  EventTableRecord? championsTable;
  EventTableRecord? redemptionTable;

  bool get redemptionRequired => redemptionSeats.isNotEmpty;

  List<EventTableRecord> get readyTables {
    return tables
        .where((table) => table.nfcTagId != null)
        .toList(growable: false);
  }

  bool get canCreateBonusRound {
    return !hasLiveSessions &&
        !hasCreatedBonusRound &&
        championSeats.length >= 2 &&
        championsTable != null &&
        (!redemptionRequired || redemptionTable != null);
  }

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    actionError = null;
    hasCreatedBonusRound = false;

    final cachedTables = await _tableRepository.readCachedTables(eventId);
    tables = cachedTables;
    notifyListeners();

    try {
      final leaderboard = await _leaderboardRepository.loadLeaderboard(eventId);
      final loadedTables = await _tableRepository.listTables(eventId);
      final sessions = await _sessionRepository.listSessions(eventId);
      final tournamentRoundSummary =
          await _seatingRepository.loadTournamentRoundSummary(eventId);
      final eligibleEntries = _standingsEligibleEntries(leaderboard);
      tables = loadedTables;
      championSeats = _championSeats(eligibleEntries);
      redemptionSeats = _redemptionSeats(eligibleEntries);
      hasLiveSessions = _hasBlockingLiveSessions(
        sessions,
        tournamentRoundSummary.round?.id,
      );
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  void selectTable({
    required BonusRoundTableRole role,
    required EventTableRecord table,
  }) {
    actionError = null;

    switch (role) {
      case BonusRoundTableRole.champions:
        championsTable = table;
        if (redemptionTable?.id == table.id) {
          redemptionTable = null;
        }
      case BonusRoundTableRole.redemption:
        redemptionTable = table;
        if (championsTable?.id == table.id) {
          championsTable = null;
        }
    }

    notifyListeners();
  }

  Future<void> resolveScannedTable({
    required String eventId,
    required BonusRoundTableRole role,
    required String normalizedUid,
  }) async {
    if (isResolvingTable) {
      return;
    }

    isResolvingTable = true;
    actionError = null;
    notifyListeners();

    try {
      final table = await _tableRepository.resolveTableByTag(
        eventId: eventId,
        scannedUid: normalizedUid,
      );
      selectTable(role: role, table: table);
    } catch (exception) {
      actionError = _formatError(exception);
    }

    isResolvingTable = false;
    notifyListeners();
  }

  Future<bool> createBonusRound(String eventId) async {
    if (isSubmitting) {
      return false;
    }

    final sessions = await _sessionRepository.listSessions(eventId);
    final tournamentRoundSummary =
        await _seatingRepository.loadTournamentRoundSummary(eventId);
    hasLiveSessions = _hasBlockingLiveSessions(
      sessions,
      tournamentRoundSummary.round?.id,
    );
    if (hasLiveSessions) {
      actionError = bonusRoundLiveSessionBlockedMessage;
      notifyListeners();
      return false;
    }

    if (championSeats.length < 2) {
      actionError = bonusRoundMinimumPlayersMessage;
      notifyListeners();
      return false;
    }

    final selectedChampionsTable = championsTable;
    if (selectedChampionsTable == null) {
      actionError = 'Choose Table of Champions.';
      notifyListeners();
      return false;
    }

    final selectedRedemptionTable = redemptionRequired ? redemptionTable : null;
    if (redemptionRequired) {
      if (selectedRedemptionTable == null) {
        actionError = 'Choose Table of Redemption.';
        notifyListeners();
        return false;
      }

      if (selectedChampionsTable.id == selectedRedemptionTable.id) {
        actionError = 'Finals tables must be different.';
        notifyListeners();
        return false;
      }
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      await _seatingRepository.generateBonusRoundAssignments(
        eventId: eventId,
        championsTableId: selectedChampionsTable.id,
        redemptionTableId: selectedRedemptionTable?.id,
      );
      hasCreatedBonusRound = true;
      isSubmitting = false;
      notifyListeners();
      return true;
    } catch (exception) {
      actionError = _formatError(exception);
      isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  List<BonusRoundSeatPreview> _championSeats(List<LeaderboardEntry> entries) {
    if (entries.length < 2) {
      return const [];
    }

    final ranked = _rankedEntries(entries);
    final finalists = ranked.take(4).toList(growable: false);
    return _finalsSeatPreviews(finalists);
  }

  List<BonusRoundSeatPreview> _redemptionSeats(List<LeaderboardEntry> entries) {
    if (entries.length < 6) {
      return const [];
    }

    final ranked = _rankedEntries(entries);
    final remainingFinalists = ranked.skip(4).take(4).toList(growable: false);
    return _redemptionSeatPreviews(remainingFinalists);
  }

  List<LeaderboardEntry> _standingsEligibleEntries(
    List<LeaderboardEntry> entries,
  ) {
    final minimumHands = _minimumHandsForPrize(entries);
    if (minimumHands <= 0) {
      return const [];
    }
    return entries
        .where((entry) => entry.handsPlayed >= minimumHands)
        .toList(growable: false);
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

  List<BonusRoundSeatPreview> _finalsSeatPreviews(
    List<LeaderboardEntry> entries,
  ) {
    if (entries.length == 4) {
      return [
        _seatPreview('East', entries[3]),
        _seatPreview('South', entries[2]),
        _seatPreview('West', entries[1]),
        _seatPreview('North', entries[0]),
      ];
    }

    const windsByRank = ['East', 'South', 'West'];
    return [
      for (var index = 0; index < entries.length; index += 1)
        _seatPreview(windsByRank[index], entries[index]),
    ];
  }

  List<BonusRoundSeatPreview> _redemptionSeatPreviews(
    List<LeaderboardEntry> entries,
  ) {
    const windsByRank = ['East', 'South', 'West', 'North'];
    return [
      for (var index = 0; index < entries.length; index += 1)
        _seatPreview(windsByRank[index], entries[index]),
    ];
  }

  List<LeaderboardEntry> _rankedEntries(List<LeaderboardEntry> entries) {
    return [...entries]..sort((left, right) {
        final rankCompare = left.rank.compareTo(right.rank);
        if (rankCompare != 0) {
          return rankCompare;
        }
        final pointsCompare = right.totalPoints.compareTo(left.totalPoints);
        if (pointsCompare != 0) {
          return pointsCompare;
        }
        final nameCompare = left.displayName.compareTo(right.displayName);
        if (nameCompare != 0) {
          return nameCompare;
        }
        return left.eventGuestId.compareTo(right.eventGuestId);
      });
  }

  BonusRoundSeatPreview _seatPreview(
    String windLabel,
    LeaderboardEntry entry,
  ) {
    return BonusRoundSeatPreview(
      eventGuestId: entry.eventGuestId,
      windLabel: windLabel,
      seedLabel: '#${entry.rank}',
      playerName: entry.displayName,
      totalPoints: entry.totalPoints,
    );
  }

  bool _hasBlockingLiveSessions(
    List<TableSessionRecord> sessions,
    String? currentTournamentRoundId,
  ) {
    if (currentTournamentRoundId == null) {
      return false;
    }

    return sessions.any(
      (session) =>
          (session.status == SessionStatus.active ||
              session.status == SessionStatus.paused) &&
          session.scoringPhase == EventScoringPhase.tournament &&
          session.tournamentRoundId == currentTournamentRoundId,
    );
  }

  String _formatError(Object exception) {
    final message = exception.toString();
    const statePrefix = 'Bad state: ';
    if (message.startsWith(statePrefix)) {
      return message.substring(statePrefix.length);
    }
    return message;
  }
}

@immutable
class BonusRoundSeatPreview {
  const BonusRoundSeatPreview({
    required this.eventGuestId,
    required this.windLabel,
    required this.seedLabel,
    required this.playerName,
    required this.totalPoints,
  });

  final String eventGuestId;
  final String windLabel;
  final String seedLabel;
  final String playerName;
  final int totalPoints;
}
