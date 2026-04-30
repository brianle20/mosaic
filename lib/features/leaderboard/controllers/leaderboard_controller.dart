import 'package:flutter/foundation.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';

class PrizePlacementRow {
  const PrizePlacementRow({
    required this.entry,
    required this.placement,
  });

  final LeaderboardEntry entry;
  final int placement;
}

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({required this.leaderboardRepository});

  final LeaderboardRepository leaderboardRepository;

  bool isLoading = false;
  String? error;
  List<LeaderboardEntry> entries = const [];

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
    notifyListeners();

    try {
      entries = await leaderboardRepository.loadLeaderboard(eventId);
    } catch (err) {
      if (entries.isEmpty) {
        error = err.toString();
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
