import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/guest_models.dart';
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
  test('stale leaderboard load cannot overwrite a newer recovery load',
      () async {
    final firstRemote = Completer<List<LeaderboardEntry>>();
    final firstRemoteStarted = Completer<void>();
    var loadCount = 0;
    const cached = LeaderboardEntry(
      eventGuestId: 'gst_cached',
      displayName: 'Cached Player',
      totalPoints: 1,
      handsPlayed: 1,
      handsWon: 0,
      selfDrawWins: 0,
      discardWins: 0,
      rank: 1,
    );
    const recovered = LeaderboardEntry(
      eventGuestId: 'gst_recovered',
      displayName: 'Recovered Player',
      totalPoints: 20,
      handsPlayed: 4,
      handsWon: 2,
      selfDrawWins: 1,
      discardWins: 1,
      rank: 1,
    );
    final repository = _FakeLeaderboardRepository(
      cachedEntries: [cached],
      loader: (_) {
        loadCount += 1;
        if (loadCount == 1) {
          firstRemoteStarted.complete();
          return firstRemote.future;
        }
        return Future.value([recovered]);
      },
    );
    final controller = LeaderboardController(leaderboardRepository: repository);

    final firstLoad = controller.load('evt_01');
    await firstRemoteStarted.future;
    final secondLoad = controller.load('evt_01', silent: true);
    await secondLoad;
    expect(controller.entries.single.displayName, 'Recovered Player');

    firstRemote.complete([cached]);
    await firstLoad;
    expect(controller.entries.single.displayName, 'Recovered Player');
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

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

  test('uses competition placement ranks for tied prize-eligible players',
      () async {
    final controller = LeaderboardController(
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: const [
          LeaderboardEntry(
            eventGuestId: 'gst_alice',
            displayName: 'Alice Wong',
            totalPoints: 40,
            handsPlayed: 4,
            handsWon: 2,
            selfDrawWins: 1,
            discardWins: 1,
            discardLosses: 0,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            totalPoints: 40,
            handsPlayed: 4,
            handsWon: 2,
            selfDrawWins: 0,
            discardWins: 2,
            discardLosses: 1,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_chris',
            displayName: 'Chris Ng',
            totalPoints: 8,
            handsPlayed: 4,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            discardLosses: 2,
            rank: 3,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(
      controller.prizePlacementRows.map((row) => row.placement),
      [1, 1, 3],
    );
  });

  test('keeps withdrawn players on leaderboard but out of prize placements',
      () async {
    final controller = LeaderboardController(
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: const [
          LeaderboardEntry(
            eventGuestId: 'gst_alice',
            displayName: 'Alice Wong',
            tournamentStatus: EventTournamentStatus.qualified,
            totalPoints: 64,
            handsPlayed: 8,
            handsWon: 3,
            selfDrawWins: 1,
            discardWins: 2,
            rank: 1,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            tournamentStatus: EventTournamentStatus.withdrawn,
            totalPoints: 48,
            handsPlayed: 8,
            handsWon: 2,
            selfDrawWins: 0,
            discardWins: 2,
            rank: 2,
          ),
          LeaderboardEntry(
            eventGuestId: 'gst_carla',
            displayName: 'Carla Park',
            tournamentStatus: EventTournamentStatus.qualified,
            totalPoints: 24,
            handsPlayed: 1,
            handsWon: 1,
            selfDrawWins: 0,
            discardWins: 1,
            rank: 3,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(
      controller.entries.map((entry) => entry.displayName),
      ['Alice Wong', 'Brian Le', 'Carla Park'],
    );
    expect(
      controller.prizePlacementEntries.map((entry) => entry.displayName),
      ['Alice Wong'],
    );
    expect(
      controller.notPrizeEligibleEntries.map((entry) => entry.displayName),
      ['Brian Le', 'Carla Park'],
    );
  });

  test('still lists withdrawn players when no qualified players remain',
      () async {
    final controller = LeaderboardController(
      leaderboardRepository: _FakeLeaderboardRepository(
        cachedEntries: const [
          LeaderboardEntry(
            eventGuestId: 'gst_brian',
            displayName: 'Brian Le',
            tournamentStatus: EventTournamentStatus.withdrawn,
            totalPoints: 48,
            handsPlayed: 8,
            handsWon: 2,
            selfDrawWins: 0,
            discardWins: 2,
            rank: 1,
          ),
        ],
      ),
    );

    await controller.load('evt_01');

    expect(controller.minimumHandsForPrize, 0);
    expect(controller.prizePlacementEntries, isEmpty);
    expect(
      controller.notPrizeEligibleEntries.map((entry) => entry.displayName),
      ['Brian Le'],
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
