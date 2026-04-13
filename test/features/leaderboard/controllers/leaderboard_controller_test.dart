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
  test('loads cached leaderboard entries when the remote fetch fails',
      () async {
    final cachedEntry = const LeaderboardEntry(
      eventGuestId: 'gst_01',
      displayName: 'Alice Wong',
      totalPoints: 16,
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
