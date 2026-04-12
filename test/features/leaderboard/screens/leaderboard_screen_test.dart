import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/leaderboard/screens/leaderboard_screen.dart';

class _RecordingLeaderboardRepository implements LeaderboardRepository {
  _RecordingLeaderboardRepository({
    required this.entries,
    this.failFirstLoad = false,
  });

  final List<LeaderboardEntry> entries;
  final bool failFirstLoad;
  int loadCount = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard(String eventId) async {
    loadCount += 1;
    if (failFirstLoad && loadCount == 1) {
      throw Exception('temporary leaderboard failure');
    }

    return entries;
  }

  @override
  Future<List<LeaderboardEntry>> readCachedLeaderboard(String eventId) async =>
      const [];
}

void main() {
  testWidgets('renders ordered leaderboard standings', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_east',
          displayName: 'East Guest',
          totalPoints: 8,
          handsWon: 1,
          selfDrawWins: 1,
          discardWins: 0,
          rank: 2,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('West Guest'), findsOneWidget);
    expect(find.text('16 pts'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('East Guest'), findsOneWidget);
  });

  testWidgets('retries after a loading error', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
      ],
      failFirstLoad: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
        find.textContaining('temporary leaderboard failure'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
    expect(find.text('West Guest'), findsOneWidget);
  });
}
