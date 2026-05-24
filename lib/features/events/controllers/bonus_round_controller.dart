import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

const bonusRoundLiveSessionBlockedMessage =
    'End active or paused sessions first.';
const bonusRoundMinimumPlayersMessage =
    'At least eight ranked players are required.';

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

  List<EventTableRecord> get readyTables {
    return tables
        .where((table) => table.nfcTagId != null)
        .toList(growable: false);
  }

  bool get canCreateBonusRound {
    return !hasLiveSessions &&
        !hasCreatedBonusRound &&
        championSeats.length == 4 &&
        redemptionSeats.length == 4 &&
        championsTable != null &&
        redemptionTable != null;
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
      tables = loadedTables;
      championSeats = _championSeats(leaderboard);
      redemptionSeats = _redemptionSeats(leaderboard);
      hasLiveSessions = _hasLiveSessions(sessions);
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
    hasLiveSessions = _hasLiveSessions(sessions);
    if (hasLiveSessions) {
      actionError = bonusRoundLiveSessionBlockedMessage;
      notifyListeners();
      return false;
    }

    if (championSeats.length != 4 || redemptionSeats.length != 4) {
      actionError = bonusRoundMinimumPlayersMessage;
      notifyListeners();
      return false;
    }

    final selectedChampionsTable = championsTable;
    final selectedRedemptionTable = redemptionTable;
    if (selectedChampionsTable == null || selectedRedemptionTable == null) {
      actionError = 'Choose both bonus round tables.';
      notifyListeners();
      return false;
    }

    if (selectedChampionsTable.id == selectedRedemptionTable.id) {
      actionError = 'Bonus round tables must be different.';
      notifyListeners();
      return false;
    }

    isSubmitting = true;
    actionError = null;
    notifyListeners();

    try {
      await _seatingRepository.generateBonusRoundAssignments(
        eventId: eventId,
        championsTableId: selectedChampionsTable.id,
        redemptionTableId: selectedRedemptionTable.id,
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
    if (entries.length < 8) {
      return const [];
    }

    final ranked = _rankedEntries(entries);
    return [
      _seatPreview('East', ranked[3]),
      _seatPreview('South', ranked[2]),
      _seatPreview('West', ranked[1]),
      _seatPreview('North', ranked[0]),
    ];
  }

  List<BonusRoundSeatPreview> _redemptionSeats(List<LeaderboardEntry> entries) {
    if (entries.length < 8) {
      return const [];
    }

    final ranked = _rankedEntries(entries);
    final bottom = ranked.sublist(ranked.length - 4);
    return [
      _seatPreview('East', bottom[0]),
      _seatPreview('South', bottom[1]),
      _seatPreview('West', bottom[2]),
      _seatPreview('North', bottom[3]),
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
        return left.displayName.compareTo(right.displayName);
      });
  }

  BonusRoundSeatPreview _seatPreview(
    String windLabel,
    LeaderboardEntry entry,
  ) {
    return BonusRoundSeatPreview(
      windLabel: windLabel,
      seedLabel: '#${entry.rank}',
      playerName: entry.displayName,
      totalPoints: entry.totalPoints,
    );
  }

  bool _hasLiveSessions(List<TableSessionRecord> sessions) {
    return sessions.any(
      (session) =>
          session.status == SessionStatus.active ||
          session.status == SessionStatus.paused,
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
    required this.windLabel,
    required this.seedLabel,
    required this.playerName,
    required this.totalPoints,
  });

  final String windLabel;
  final String seedLabel;
  final String playerName;
  final int totalPoints;
}
