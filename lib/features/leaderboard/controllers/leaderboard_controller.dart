import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/bonus_round_state_models.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/models/scoring_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';

class PrizePlacementRow {
  const PrizePlacementRow({
    required this.entry,
    required this.placement,
  });

  final LeaderboardEntry entry;
  final int placement;
}

class FinalsLeaderboardTable {
  const FinalsLeaderboardTable({
    required this.title,
    required this.tableLabel,
    required this.rows,
    required this.hasScores,
  });

  final String title;
  final String tableLabel;
  final List<FinalsLeaderboardRow> rows;
  final bool hasScores;
}

class FinalsLeaderboardRow {
  const FinalsLeaderboardRow({
    required this.eventGuestId,
    required this.displayName,
    required this.seatIndex,
    required this.points,
    required this.handsPlayed,
    required this.wins,
    required this.rank,
  });

  final String eventGuestId;
  final String displayName;
  final int seatIndex;
  final int points;
  final int handsPlayed;
  final int wins;
  final int rank;
}

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required this.leaderboardRepository,
    this.sessionRepository,
    this.seatingRepository,
  });

  final LeaderboardRepository leaderboardRepository;
  final SessionRepository? sessionRepository;
  final SeatingRepository? seatingRepository;

  bool isLoading = false;
  String? error;
  List<LeaderboardEntry> entries = const [];
  BonusRoundResultsSummary bonusRoundResults = const BonusRoundResultsSummary();
  BonusRoundState? bonusRoundState;
  List<SeatingAssignmentRecord> finalsAssignments = const [];
  List<EventHandLedgerEntry> bonusLedgerEntries = const [];

  int get minimumHandsForPrize {
    final scoredHands = entries
        .where(_canQualifyForPrize)
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

  List<LeaderboardEntry> get prizePlacementEntries {
    final minimumHands = minimumHandsForPrize;
    if (minimumHands <= 0) {
      return const [];
    }

    return entries
        .where(
          (entry) =>
              _canQualifyForPrize(entry) && entry.handsPlayed >= minimumHands,
        )
        .toList(growable: false);
  }

  List<PrizePlacementRow> get prizePlacementRows {
    final placements = <PrizePlacementRow>[];
    int placement = 0;
    int? previousPoints;

    for (final indexedEntry in prizePlacementEntries.indexed) {
      final displayPosition = indexedEntry.$1 + 1;
      final entry = indexedEntry.$2;
      if (previousPoints != entry.totalPoints) {
        placement = displayPosition;
        previousPoints = entry.totalPoints;
      }

      placements.add(PrizePlacementRow(entry: entry, placement: placement));
    }

    return placements;
  }

  List<LeaderboardEntry> get notPrizeEligibleEntries {
    final minimumHands = minimumHandsForPrize;
    if (minimumHands <= 0) {
      return entries
          .where((entry) => !_canQualifyForPrize(entry))
          .toList(growable: false);
    }

    return entries
        .where(
          (entry) =>
              !_canQualifyForPrize(entry) || entry.handsPlayed < minimumHands,
        )
        .toList(growable: false);
  }

  bool _canQualifyForPrize(LeaderboardEntry entry) {
    return entry.tournamentStatus == EventTournamentStatus.qualified;
  }

  List<FinalsLeaderboardTable> get finalsTables {
    final assignments = finalsAssignments
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
    final assignmentsByTable = <String, List<SeatingAssignmentRecord>>{};
    for (final assignment in assignments) {
      assignmentsByTable
          .putIfAbsent(assignment.eventTableId, () => [])
          .add(assignment);
    }

    final tables = <FinalsLeaderboardTable>[];
    for (final entry in assignmentsByTable.entries) {
      final tableAssignments = entry.value;
      final role = tableAssignments.first.bonusTableRole;
      final totalsByGuest = {
        for (final assignment in tableAssignments)
          assignment.eventGuestId: _FinalsGuestAccumulator(
            eventGuestId: assignment.eventGuestId,
            displayName: assignment.displayName,
            seatIndex: assignment.seatIndex,
          ),
      };

      for (final ledgerEntry in bonusLedgerEntries) {
        if (ledgerEntry.rowType != EventHandLedgerRowType.hand ||
            ledgerEntry.tableId != entry.key ||
            ledgerEntry.status != HandResultStatus.recorded ||
            ledgerEntry.bonusTableRole != _bonusRoleJson(role)) {
          continue;
        }

        for (final cell in ledgerEntry.cells) {
          final accumulator = totalsByGuest[cell.eventGuestId] ??
              _FinalsGuestAccumulator(
                eventGuestId: cell.eventGuestId,
                displayName: cell.displayName,
                seatIndex: cell.seatIndex,
              );
          totalsByGuest[cell.eventGuestId] = accumulator.add(
            pointsDelta: cell.pointsDelta,
            wonHand: ledgerEntry.resultType == HandResultType.win &&
                cell.pointsDelta > 0,
          );
        }
      }

      final rows = totalsByGuest.values
          .map((accumulator) => accumulator.toRow(rank: 0))
          .toList(growable: false);
      final hasScores = rows.any((row) => row.handsPlayed > 0);
      final sortedRows = [...rows]..sort((left, right) {
          if (!hasScores) {
            return left.seatIndex.compareTo(right.seatIndex);
          }
          final pointsCompare = right.points.compareTo(left.points);
          if (pointsCompare != 0) {
            return pointsCompare;
          }
          final winsCompare = right.wins.compareTo(left.wins);
          if (winsCompare != 0) {
            return winsCompare;
          }
          return left.displayName.compareTo(right.displayName);
        });
      tables.add(
        FinalsLeaderboardTable(
          title: _bonusRoleTitle(role),
          tableLabel: tableAssignments.first.tableLabel,
          hasScores: hasScores,
          rows: _rankFinalsRows(sortedRows),
        ),
      );
    }

    tables.sort((left, right) => _finalsTableSort(left.title).compareTo(
          _finalsTableSort(right.title),
        ));
    return tables;
  }

  List<FinalsLeaderboardRow> _rankFinalsRows(
    List<FinalsLeaderboardRow> rows,
  ) {
    final rankedRows = <FinalsLeaderboardRow>[];
    var rank = 0;
    int? previousPoints;
    for (final indexedRow in rows.indexed) {
      final row = indexedRow.$2;
      if (previousPoints != row.points) {
        rank = indexedRow.$1 + 1;
        previousPoints = row.points;
      }
      rankedRows.add(
        FinalsLeaderboardRow(
          eventGuestId: row.eventGuestId,
          displayName: row.displayName,
          seatIndex: row.seatIndex,
          points: row.points,
          handsPlayed: row.handsPlayed,
          wins: row.wins,
          rank: rank,
        ),
      );
    }
    return rankedRows;
  }

  Future<void> load(String eventId, {bool silent = false}) async {
    final shouldShowLoading = !silent;
    final previousEntries = entries;
    final previousBonusLedgerEntries = bonusLedgerEntries;
    final previousFinalsAssignments = finalsAssignments;
    if (shouldShowLoading) {
      isLoading = true;
    }
    error = null;
    final cachedEntries =
        await leaderboardRepository.readCachedLeaderboard(eventId);
    if (cachedEntries.isNotEmpty || entries.isEmpty) {
      entries = cachedEntries;
    }
    final cachedBonusLedger = await _readCachedBonusLedger(eventId);
    if (cachedBonusLedger.isNotEmpty || bonusLedgerEntries.isEmpty) {
      bonusLedgerEntries = cachedBonusLedger;
    }
    final cachedFinalsAssignments = await _readCachedFinalsAssignments(eventId);
    if (cachedFinalsAssignments.isNotEmpty || finalsAssignments.isEmpty) {
      finalsAssignments = cachedFinalsAssignments;
    }
    bonusRoundResults = buildBonusRoundResultsSummary(
      ledgerEntries: bonusLedgerEntries,
      leaderboardEntries: entries,
      bonusRoundState: bonusRoundState,
    );
    notifyListeners();

    try {
      entries = await leaderboardRepository.loadLeaderboard(eventId);
      var optionalReadFailed = false;
      final loadedBonusLedger = await _loadBonusLedger(eventId);
      if (loadedBonusLedger.succeeded) {
        bonusLedgerEntries = loadedBonusLedger.value!;
      } else {
        optionalReadFailed = true;
      }
      final loadedFinalsAssignments = await _loadFinalsAssignments(eventId);
      if (loadedFinalsAssignments.succeeded) {
        finalsAssignments = loadedFinalsAssignments.value!;
      } else {
        optionalReadFailed = true;
      }
      final loadedBonusRoundState = await _loadBonusRoundState(eventId);
      if (loadedBonusRoundState.succeeded) {
        bonusRoundState = loadedBonusRoundState.value;
      } else {
        optionalReadFailed = true;
      }
      if (optionalReadFailed && !_hasVisibleContent) {
        error = 'Unable to refresh leaderboard details.';
      }
      bonusRoundResults = buildBonusRoundResultsSummary(
        ledgerEntries: bonusLedgerEntries,
        leaderboardEntries: entries,
        bonusRoundState: bonusRoundState,
      );
    } catch (err) {
      if (previousEntries.isNotEmpty) {
        entries = previousEntries;
      }
      if (previousBonusLedgerEntries.isNotEmpty) {
        bonusLedgerEntries = previousBonusLedgerEntries;
      }
      if (previousFinalsAssignments.isNotEmpty) {
        finalsAssignments = previousFinalsAssignments;
      }
      bonusRoundResults = buildBonusRoundResultsSummary(
        ledgerEntries: bonusLedgerEntries,
        leaderboardEntries: entries,
        bonusRoundState: bonusRoundState,
      );
      if (!_hasVisibleContent) {
        error = err.toString();
      }
    } finally {
      if (shouldShowLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  bool get _hasVisibleContent =>
      entries.isNotEmpty ||
      finalsAssignments.isNotEmpty ||
      bonusRoundResults.hasResults;

  Future<List<EventHandLedgerEntry>> _readCachedBonusLedger(
    String eventId,
  ) async {
    final repository = sessionRepository;
    if (repository == null) {
      return const [];
    }

    return repository.readCachedEventHandLedger(eventId);
  }

  Future<_OptionalLoadResult<List<EventHandLedgerEntry>>> _loadBonusLedger(
    String eventId,
  ) async {
    final repository = sessionRepository;
    if (repository == null) {
      return const _OptionalLoadResult.success([]);
    }

    try {
      return _OptionalLoadResult.success(
        await repository.loadEventHandLedger(eventId),
      );
    } catch (_) {
      return const _OptionalLoadResult.failure();
    }
  }

  Future<List<SeatingAssignmentRecord>> _readCachedFinalsAssignments(
    String eventId,
  ) async {
    final repository = seatingRepository;
    if (repository == null) {
      return const [];
    }

    return repository.readCachedAssignments(eventId);
  }

  Future<_OptionalLoadResult<List<SeatingAssignmentRecord>>>
      _loadFinalsAssignments(
    String eventId,
  ) async {
    final repository = seatingRepository;
    if (repository == null) {
      return const _OptionalLoadResult.success([]);
    }

    try {
      return _OptionalLoadResult.success(
        await repository.loadAssignments(eventId),
      );
    } catch (_) {
      return const _OptionalLoadResult.failure();
    }
  }

  Future<_OptionalLoadResult<BonusRoundState?>> _loadBonusRoundState(
    String eventId,
  ) async {
    final repository = seatingRepository;
    if (repository == null) {
      return const _OptionalLoadResult.success(null);
    }

    try {
      return _OptionalLoadResult.success(
        await repository.loadBonusRoundState(eventId),
      );
    } catch (_) {
      return const _OptionalLoadResult.failure();
    }
  }
}

class _OptionalLoadResult<T> {
  const _OptionalLoadResult.success(this.value) : succeeded = true;

  const _OptionalLoadResult.failure()
      : value = null,
        succeeded = false;

  final T? value;
  final bool succeeded;
}

@immutable
class _FinalsGuestAccumulator {
  const _FinalsGuestAccumulator({
    required this.eventGuestId,
    required this.displayName,
    required this.seatIndex,
    this.points = 0,
    this.handsPlayed = 0,
    this.wins = 0,
  });

  final String eventGuestId;
  final String displayName;
  final int seatIndex;
  final int points;
  final int handsPlayed;
  final int wins;

  _FinalsGuestAccumulator add({
    required int pointsDelta,
    required bool wonHand,
  }) {
    return _FinalsGuestAccumulator(
      eventGuestId: eventGuestId,
      displayName: displayName,
      seatIndex: seatIndex,
      points: points + pointsDelta,
      handsPlayed: handsPlayed + 1,
      wins: wins + (wonHand ? 1 : 0),
    );
  }

  FinalsLeaderboardRow toRow({required int rank}) {
    return FinalsLeaderboardRow(
      eventGuestId: eventGuestId,
      displayName: displayName,
      seatIndex: seatIndex,
      points: points,
      handsPlayed: handsPlayed,
      wins: wins,
      rank: rank,
    );
  }
}

String _bonusRoleTitle(BonusTableRole? role) {
  return switch (role) {
    BonusTableRole.tableOfChampions => 'Table of Champions',
    BonusTableRole.tableOfRedemption => 'Table of Redemption',
    BonusTableRole.tableOfChampionsPlayIn => 'Table of Champions Play-In',
    BonusTableRole.tableOfChampionsSuddenDeath =>
      'Table of Champions Sudden Death',
    null => 'Finals Table',
  };
}

String? _bonusRoleJson(BonusTableRole? role) {
  return switch (role) {
    BonusTableRole.tableOfChampions => 'table_of_champions',
    BonusTableRole.tableOfRedemption => 'table_of_redemption',
    BonusTableRole.tableOfChampionsPlayIn => 'table_of_champions_play_in',
    BonusTableRole.tableOfChampionsSuddenDeath =>
      'table_of_champions_sudden_death',
    null => null,
  };
}

int _finalsTableSort(String title) {
  return switch (title) {
    'Table of Champions' => 0,
    'Table of Redemption' => 1,
    'Table of Champions Sudden Death' => 2,
    _ => 3,
  };
}
