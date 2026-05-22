import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/event_hand_ledger_models.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
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

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required this.leaderboardRepository,
    this.sessionRepository,
  });

  final LeaderboardRepository leaderboardRepository;
  final SessionRepository? sessionRepository;

  bool isLoading = false;
  String? error;
  List<LeaderboardEntry> entries = const [];
  BonusRoundResultsSummary bonusRoundResults = const BonusRoundResultsSummary();

  int get minimumHandsForPrize {
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

  List<LeaderboardEntry> get prizePlacementEntries {
    final minimumHands = minimumHandsForPrize;
    if (minimumHands <= 0) {
      return const [];
    }

    return entries
        .where((entry) => entry.handsPlayed >= minimumHands)
        .toList(growable: false);
  }

  List<PrizePlacementRow> get prizePlacementRows {
    final placements = <PrizePlacementRow>[];
    int placement = 0;
    int? previousPoints;

    for (final entry in prizePlacementEntries) {
      if (previousPoints != entry.totalPoints) {
        placement += 1;
        previousPoints = entry.totalPoints;
      }

      placements.add(PrizePlacementRow(entry: entry, placement: placement));
    }

    return placements;
  }

  List<LeaderboardEntry> get notPrizeEligibleEntries {
    final minimumHands = minimumHandsForPrize;
    if (minimumHands <= 0) {
      return const [];
    }

    return entries
        .where((entry) => entry.handsPlayed < minimumHands)
        .toList(growable: false);
  }

  Future<void> load(String eventId) async {
    isLoading = true;
    error = null;
    entries = await leaderboardRepository.readCachedLeaderboard(eventId);
    bonusRoundResults = buildBonusRoundResultsSummary(
      ledgerEntries: await _readCachedBonusLedger(eventId),
      leaderboardEntries: entries,
    );
    notifyListeners();

    try {
      entries = await leaderboardRepository.loadLeaderboard(eventId);
      bonusRoundResults = buildBonusRoundResultsSummary(
        ledgerEntries: await _loadBonusLedger(eventId),
        leaderboardEntries: entries,
      );
    } catch (err) {
      if (entries.isEmpty) {
        error = err.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<List<EventHandLedgerEntry>> _readCachedBonusLedger(
    String eventId,
  ) async {
    final repository = sessionRepository;
    if (repository == null) {
      return const [];
    }

    return repository.readCachedEventHandLedger(eventId);
  }

  Future<List<EventHandLedgerEntry>> _loadBonusLedger(String eventId) async {
    final repository = sessionRepository;
    if (repository == null) {
      return const [];
    }

    try {
      return await repository.loadEventHandLedger(eventId);
    } catch (_) {
      return const [];
    }
  }
}
