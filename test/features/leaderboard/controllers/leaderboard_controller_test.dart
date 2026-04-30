import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/leaderboard/controllers/leaderboard_controller.dart';

class _FakeLeaderboardRepository implements LeaderboardRepository {
  _FakeLeaderboardRepository({
    required this.cachedEntries,
    this.loader,
  });

  final List<LeaderboardEntry> cachedEntries;
  final Future<List<LeaderboardEntry>> Function(String eventId)? loader;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async {
    final load = loader;
    if (load != null) {
      return load(eventId);
    }
    return cachedEntries;
  }

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      cachedEntries;
}

void main() {
  test('uses half of median scored-player hands for prize eligibility',
      () async {
    final controller = LeaderboardController(
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: const [
          LeaderboardEntry(
            eventGuestId: 'gst_regular',
            displayName: 'Regular Player',
            totalPoints: 40,
            handsPlayed: 8,
            handsWon: 2,
            selfDrawWins: 1,
            discardWins: 1,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_lucky',
            displayName: 'One Hand Spike',
            totalPoints: 50,
            handsPlayed: 1,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 2,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_grinder',
            displayName: 'Late Grinder',
            totalPoints: 10,
            handsPlayed: 30,
            handsWon: 3,
            selfDrawWins: 2,
            discardWins: 1,
            rank: 3,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_observer',
            displayName: 'Observer',
            totalPoints: 0,
            handsPlayed: 0,
            handsWon: 0,
            selfDrawWins: 0,
            discardWins: 0,
            rank: 4,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(controller.minimumHandsForPrize, 4);
    expect(
      controller.prizePlacementEntries.map((entry) => entry.displayName),
      ['Regular Player', 'Late Grinder'],
    );
    expect(
      controller.notPrizeEligibleEntries.map((entry) => entry.displayName),
      ['One Hand Spike', 'Observer'],
    );
  });

  test('loads cached leaderboard entries when the remote fetch fails',
      () async {
    final cachedEntry = const LeaderboardEntry(
      eventGuestId: 'gst_01',
      displayName: 'Alice Wong',
      totalPoints: 16,
      handsPlayed: 3,
      handsWon: 1,
      selfDrawWins: 0,
      discardWins: 1,
      rank: 1,
    );
    final controller = LeaderboardController(
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: [cachedEntry],
        loader: (_) async => throw Exception('leaderboard fetch failed'),
      ),
    );

    await controller.load('evt_01');

    expect(controller.entries.map((entry) => entry.eventGuestId), ['gst_01']);
    expect(controller.error, isNull);
  });
}
