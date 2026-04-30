import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
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
            if (_controller.entries.isNotEmpty) ...[
              Text(
                'Minimum hands to qualify: ${_controller.minimumHandsForPrize}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              if (_controller.prizePlacementRows.isNotEmpty) ...[
                const _SectionLabel('Prize Placements'),
                const SizedBox(height: 8),
                for (final row in _controller.prizePlacementRows)
                  _LeaderboardCard(
                    entry: row.entry,
                    displayRank: row.placement,
                  ),
              ],
              if (_controller.notPrizeEligibleEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionLabel('Not Prize Eligible'),
                const SizedBox(height: 8),
                for (final entry in _controller.notPrizeEligibleEntries)
                  _LeaderboardCard(
                    entry: entry,
                  ),
              ],
            ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({
    required this.entry,
    this.displayRank,
  });

  final LeaderboardEntry entry;
  final int? displayRank;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: displayRank == null ? null : Text('$displayRank'),
        title: Text(entry.displayName),
        subtitle: Text(
          'Hands played ${entry.handsPlayed} • Wins ${entry.handsWon}',
        ),
        trailing: Text('${entry.totalPoints} pts'),
      ),
    );
  }
}
