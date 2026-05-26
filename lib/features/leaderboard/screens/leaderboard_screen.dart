import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/leaderboard_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';
import 'package:mosaic/features/leaderboard/controllers/leaderboard_controller.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.eventId,
    required this.leaderboardRepository,
    this.guestRepository,
    this.sessionRepository,
    this.seatingRepository,
    this.initialQualificationTab = false,
  });

  final String eventId;
  final LeaderboardRepository leaderboardRepository;
  final GuestRepository? guestRepository;
  final SessionRepository? sessionRepository;
  final SeatingRepository? seatingRepository;
  final bool initialQualificationTab;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardController _controller;
  late _LeaderboardTab _selectedTab;
  var _qualificationRows = const <QualificationLeaderboardRow>[];
  var _qualificationLoading = false;
  String? _qualificationError;
  var _hasLoadedQualification = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialQualificationTab
        ? _LeaderboardTab.qualification
        : _LeaderboardTab.tournament;
    _controller = LeaderboardController(
      leaderboardRepository: widget.leaderboardRepository,
      sessionRepository: widget.sessionRepository,
      seatingRepository: widget.seatingRepository,
    )
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
    if (_selectedTab == _LeaderboardTab.qualification) {
      _loadQualificationStandings();
    }
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

  Future<void> _loadQualificationStandings({bool force = false}) async {
    final repository = widget.guestRepository;
    if (repository == null) {
      setState(() {
        _qualificationError = 'Qualification standings are not available.';
      });
      return;
    }
    if (_qualificationLoading || (_hasLoadedQualification && !force)) {
      return;
    }

    setState(() {
      _qualificationLoading = true;
      _qualificationError = null;
    });

    try {
      final rows = await repository.fetchQualificationLeaderboard(
        eventId: widget.eventId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _qualificationRows = rows;
        _hasLoadedQualification = true;
      });
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qualificationError = err.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _qualificationLoading = false;
        });
      }
    }
  }

  void _selectTab(_LeaderboardTab tab) {
    setState(() {
      _selectedTab = tab;
    });
    if (tab == _LeaderboardTab.qualification) {
      _loadQualificationStandings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_LeaderboardTab>(
                selected: {_selectedTab},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => _selectTab(selection.single),
                segments: const [
                  ButtonSegment(
                    value: _LeaderboardTab.qualification,
                    label: Text('Qualification'),
                  ),
                  ButtonSegment(
                    value: _LeaderboardTab.tournament,
                    label: Text('Tournament'),
                  ),
                  ButtonSegment(
                    value: _LeaderboardTab.finals,
                    label: Text('Finals'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: switch (_selectedTab) {
              _LeaderboardTab.tournament => _TournamentLeaderboardBody(
                  controller: _controller,
                  onRetry: () => _controller.load(widget.eventId),
                ),
              _LeaderboardTab.qualification => _QualificationLeaderboardBody(
                  isLoading: _qualificationLoading,
                  error: _qualificationError,
                  rows: _qualificationRows,
                  onRetry: () => _loadQualificationStandings(force: true),
                ),
              _LeaderboardTab.finals => _FinalsLeaderboardBody(
                  controller: _controller,
                  onRetry: () => _controller.load(widget.eventId),
                ),
            },
          ),
        ],
      ),
    );
  }
}

enum _LeaderboardTab { tournament, qualification, finals }

class _TournamentLeaderboardBody extends StatelessWidget {
  const _TournamentLeaderboardBody({
    required this.controller,
    required this.onRetry,
  });

  final LeaderboardController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      isLoading: controller.isLoading,
      error: controller.error,
      onRetry: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.entries.isNotEmpty) ...[
            if (controller.bonusRoundResults.hasResults) ...[
              _BonusRoundResultsCard(
                summary: controller.bonusRoundResults,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Minimum hands to qualify: ${controller.minimumHandsForPrize}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            if (controller.prizePlacementRows.isNotEmpty) ...[
              const _SectionLabel('Prize Placements'),
              const SizedBox(height: 8),
              for (final row in controller.prizePlacementRows)
                _LeaderboardCard(
                  entry: row.entry,
                  displayRank: row.placement,
                ),
            ],
            if (controller.notPrizeEligibleEntries.isNotEmpty) ...[
              const SizedBox(height: 12),
              const _SectionLabel('Not Prize Eligible'),
              const SizedBox(height: 8),
              for (final entry in controller.notPrizeEligibleEntries)
                _LeaderboardCard(
                  entry: entry,
                ),
            ],
          ],
          if (controller.entries.isEmpty)
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
    );
  }
}

class _QualificationLeaderboardBody extends StatelessWidget {
  const _QualificationLeaderboardBody({
    required this.isLoading,
    required this.error,
    required this.rows,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final List<QualificationLeaderboardRow> rows;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AsyncBody(
      isLoading: isLoading,
      error: error,
      onRetry: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (rows.isNotEmpty) ...[
            const _SectionLabel('Qualification Standings'),
            const SizedBox(height: 8),
            for (final row in _rankedRows)
              _QualificationLeaderboardCard(row: row),
          ],
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyStateCard(
                icon: Icons.fact_check,
                title: 'No qualification results yet',
                message:
                    'Record qualification hands to see host-only standings.',
              ),
            ),
        ],
      ),
    );
  }

  List<_RankedQualificationRow> get _rankedRows {
    final sortedRows = [...rows]..sort((left, right) {
        final pointsComparison = right.qualificationPoints.compareTo(
          left.qualificationPoints,
        );
        if (pointsComparison != 0) {
          return pointsComparison;
        }
        final winsComparison = right.wins.compareTo(left.wins);
        if (winsComparison != 0) {
          return winsComparison;
        }
        return left.fullName.compareTo(right.fullName);
      });

    final rankedRows = <_RankedQualificationRow>[];
    var rank = 0;
    int? previousPoints;
    for (final indexedRow in sortedRows.indexed) {
      final row = indexedRow.$2;
      if (previousPoints != row.qualificationPoints) {
        rank = indexedRow.$1 + 1;
        previousPoints = row.qualificationPoints;
      }
      rankedRows.add(_RankedQualificationRow(row: row, rank: rank));
    }
    return rankedRows;
  }
}

class _FinalsLeaderboardBody extends StatelessWidget {
  const _FinalsLeaderboardBody({
    required this.controller,
    required this.onRetry,
  });

  final LeaderboardController controller;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final finalsTables = controller.finalsTables;
    return AsyncBody(
      isLoading: controller.isLoading,
      error: controller.error,
      onRetry: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (finalsTables.isNotEmpty) ...[
            const _SectionLabel('Finals Standings'),
            const SizedBox(height: 8),
            for (final table in finalsTables) _FinalsTableCard(table: table),
          ],
          if (finalsTables.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyStateCard(
                icon: Icons.emoji_events,
                title: 'No finals standings yet',
                message:
                    'Begin finals to create Table of Champions and Table of Redemption standings.',
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalsTableCard extends StatelessWidget {
  const _FinalsTableCard({required this.table});

  final FinalsLeaderboardTable table;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              table.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              table.tableLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            for (final row in table.rows)
              _FinalsLeaderboardLine(row: row, showRank: table.hasScores),
          ],
        ),
      ),
    );
  }
}

class _FinalsLeaderboardLine extends StatelessWidget {
  const _FinalsLeaderboardLine({
    required this.row,
    required this.showRank,
  });

  final FinalsLeaderboardRow row;
  final bool showRank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              showRank ? '#${row.rank}' : _seatLabel(row.seatIndex),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  [
                    _pluralize(row.handsPlayed, 'hand'),
                    _pluralize(row.wins, 'win'),
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_signedPoints(row.points)} pts',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _RankedQualificationRow {
  const _RankedQualificationRow({required this.row, required this.rank});

  final QualificationLeaderboardRow row;
  final int rank;
}

class _QualificationLeaderboardCard extends StatelessWidget {
  const _QualificationLeaderboardCard({required this.row});

  final _RankedQualificationRow row;

  @override
  Widget build(BuildContext context) {
    final detailLabel = [
      _pluralize(row.row.handsPlayed, 'hand'),
      _pluralize(row.row.wins, 'win'),
    ].join(' • ');

    return Card(
      child: ListTile(
        leading: Text('#${row.rank}'),
        title: Text(row.row.fullName),
        subtitle: Text(detailLabel),
        trailing: Text('${row.row.qualificationPoints} pts'),
      ),
    );
  }
}

String _pluralize(int count, String singular) {
  final suffix = count == 1 ? '' : 's';
  return '$count $singular$suffix';
}

String _signedPoints(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}

String _seatLabel(int seatIndex) {
  return switch (seatIndex) {
    0 => 'East',
    1 => 'South',
    2 => 'West',
    3 => 'North',
    _ => 'Seat ${seatIndex + 1}',
  };
}

class _BonusRoundResultsCard extends StatelessWidget {
  const _BonusRoundResultsCard({required this.summary});

  final BonusRoundResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonus Round Results',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            if (summary.finalChampion != null)
              _BonusRoundResultLine(
                icon: Icons.emoji_events,
                label: 'Final champion',
                result: summary.finalChampion!,
              ),
            if (summary.finalChampion != null &&
                (summary.suddenDeathStatus != null ||
                    summary.redemptionWinner != null))
              const SizedBox(height: 10),
            if (summary.suddenDeathStatus != null)
              _BonusRoundStatusLine(status: summary.suddenDeathStatus!),
            if (summary.suddenDeathStatus != null &&
                summary.redemptionWinner != null)
              const SizedBox(height: 10),
            if (summary.redemptionWinner != null)
              _BonusRoundResultLine(
                icon: Icons.replay_circle_filled,
                label: 'Redemption winner',
                result: summary.redemptionWinner!,
              ),
          ],
        ),
      ),
    );
  }
}

class _BonusRoundStatusLine extends StatelessWidget {
  const _BonusRoundStatusLine({required this.status});

  final BonusRoundSuddenDeathStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.flash_on, size: 20, color: colorScheme.tertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.statusLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                status.detailLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BonusRoundResultLine extends StatelessWidget {
  const _BonusRoundResultLine({
    required this.icon,
    required this.label,
    required this.result,
  });

  final IconData icon;
  final String label;
  final BonusRoundResult result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: colorScheme.tertiary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                result.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          result.detailLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
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
          'Hands ${entry.handsPlayed} • Wins ${entry.handsWon} • '
          'Discard wins ${entry.discardWins} • Discard losses ${entry.discardLosses}',
        ),
        trailing: Text('${entry.totalPoints} pts'),
      ),
    );
  }
}
