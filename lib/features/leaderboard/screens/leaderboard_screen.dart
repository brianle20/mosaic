import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/leaderboard/controllers/leaderboard_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.eventId,
    required this.leaderboardRepository,
  });

  final String eventId;
  final LeaderboardRepository leaderboardRepository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LeaderboardController(
      leaderboardRepository: widget.leaderboardRepository,
    )
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final entry in _controller.entries)
              Card(
                child: ListTile(
                  leading: Text('${entry.rank}'),
                  title: Text(entry.displayName),
                  subtitle: Text(
                    'Hands ${entry.handsWon} • Self-draw ${entry.selfDrawWins}',
                  ),
                  trailing: Text('${entry.totalPoints} pts'),
                ),
              ),
            if (_controller.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.leaderboard,
                  title: 'No scored results yet',
                  message:
                      'Record hands in an active session to populate the leaderboard.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
