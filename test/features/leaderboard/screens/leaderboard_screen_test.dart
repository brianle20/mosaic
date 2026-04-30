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
  testWidgets('renders an intentional empty state when no scored results exist',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(entries: const []);

    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          eventId: 'evt_01',
          leaderboardRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No scored results yet'), findsOneWidget);
    expect(
      find.text(
          'Record hands in an active session to populate the leaderboard.'),
      findsOneWidget,
    );
  });

  testWidgets('renders ordered leaderboard standings', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsPlayed: 3,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_east',
          displayName: 'East Guest',
          totalPoints: 8,
          handsPlayed: 3,
          handsWon: 0,
          selfDrawWins: 0,
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
    expect(find.text('Minimum hands to qualify: 2'), findsOneWidget);
    expect(find.text('Hands played 3 • Wins 1'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    expect(find.text('East Guest'), findsOneWidget);
  });

  testWidgets('uses local dense placement ranks for prize-eligible players',
      (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_giang',
          displayName: 'Giang Pham',
          totalPoints: 40,
          handsPlayed: 1,
          handsWon: 1,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 1,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_brian',
          displayName: 'Brian Le',
          totalPoints: 0,
          handsPlayed: 0,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 0,
          rank: 2,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_wen',
          displayName: 'Wen Lee',
          totalPoints: -8,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 1,
          discardWins: 1,
          rank: 3,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_estevon',
          displayName: 'Estevon Jackson',
          totalPoints: -16,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 4,
        ),
        LeaderboardEntry(
          eventGuestId: 'gst_justin',
          displayName: 'Justin Park',
          totalPoints: -16,
          handsPlayed: 1,
          handsWon: 0,
          selfDrawWins: 0,
          discardWins: 1,
          rank: 4,
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

    expect(find.text('Minimum hands to qualify: 1'), findsOneWidget);
    expect(find.text('Prize Placements'), findsOneWidget);
    expect(find.text('Not Prize Eligible'), findsOneWidget);
    expect(find.text('Hands played 1 • Wins 1'), findsOneWidget);
    expect(find.text('Hands played 1 • Wins 0'), findsNWidgets(3));
    expect(find.text('Hands played 0 • Wins 0'), findsOneWidget);
    expect(find.textContaining('Prize #'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Giang Pham'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Wen Lee'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Estevon Jackson'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Justin Park'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Brian Le'),
          matching: find.byType(ListTile),
        ),
        matching: find.text('2'),
      ),
      findsNothing,
    );
  });

  testWidgets('retries after a loading error', (tester) async {
    final repository = _RecordingLeaderboardRepository(
      entries: const [
        LeaderboardEntry(
          eventGuestId: 'gst_west',
          displayName: 'West Guest',
          totalPoints: 16,
          handsPlayed: 3,
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
