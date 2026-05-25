import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class TablesOverviewScreen extends StatefulWidget {
  const TablesOverviewScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.scoringOpen,
    this.readOnly = false,
    required this.tableRepository,
    required this.sessionRepository,
    required this.guestRepository,
    this.seatingRepository,
    this.now,
  });

  final String eventId;
  final String eventTitle;
  final bool scoringOpen;
  final bool readOnly;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final GuestRepository guestRepository;
  final SeatingRepository? seatingRepository;
  final DateTime Function()? now;

  @override
  State<TablesOverviewScreen> createState() => _TablesOverviewScreenState();
}

class _TablesOverviewScreenState extends State<TablesOverviewScreen> {
  late final TableListController _controller;
  Timer? _roundTimer;

  @override
  void initState() {
    super.initState();
    _controller = TableListController(
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
      guestRepository: widget.guestRepository,
      seatingRepository: widget.seatingRepository,
      now: widget.now,
    )
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _controller.refreshRoundTimers();
    });
  }

  @override
  void dispose() {
    _roundTimer?.cancel();
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

  Future<void> _openAddTable() async {
    await Navigator.of(context).pushNamed(
      AppRouter.tableFormRoute,
      arguments: TableFormArgs(eventId: widget.eventId),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _openEditTable(EventTableRecord table) async {
    await Navigator.of(context).pushNamed(
      AppRouter.tableFormRoute,
      arguments: TableFormArgs(
        eventId: widget.eventId,
        initialTable: table,
      ),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _openSessionDetail(String sessionId) async {
    await Navigator.of(context).pushNamed(
      AppRouter.sessionDetailRoute,
      arguments: SessionDetailArgs(
        eventId: widget.eventId,
        sessionId: sessionId,
        scoringOpen: widget.scoringOpen,
      ),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _enterCurrentRoundTable(EventTableRecord table) async {
    await Navigator.of(context).pushNamed(
      AppRouter.startSessionRoute,
      arguments: StartSessionArgs(
        eventId: widget.eventId,
        table: table,
        scoringPhase: EventScoringPhase.tournament,
        allowAssignedTableEntry: true,
      ),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _startNextRound() async {
    final assignments =
        await _controller.startNextTournamentRound(widget.eventId);
    if (!mounted || assignments == null) {
      return;
    }

    if (assignments.isNotEmpty) {
      await Navigator.of(context).pushNamed(
        AppRouter.seatingAssignmentsRoute,
        arguments: SeatingAssignmentsArgs(
          eventId: widget.eventId,
          initialAssignments: assignments,
        ),
      );
      await _controller.load(widget.eventId);
    }
  }

  Future<void> _openSessionHistory(EventTableRecord table) async {
    final sessions = _controller.sessionsForTable(table.id);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session History',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    table.label,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    const EmptyStateCard(
                      icon: Icons.history,
                      title: 'No sessions yet',
                      message: 'Completed sessions will appear here.',
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Session ${session.sessionNumberForTable}',
                            ),
                            subtitle: Text(_sessionHistorySubtitle(session)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              Navigator.of(sheetContext).pop();
                              await _openSessionDetail(session.id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tables')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.readOnly) ...[
              FilledButton.icon(
                onPressed: _openAddTable,
                icon: const Icon(Icons.table_restaurant),
                label: const Text('Add Table'),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              widget.eventTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.readOnly) ...[
              const SizedBox(height: 12),
              const InfoPanel(
                message:
                    'This event is locked. Tables and tag bindings can no longer be changed.',
              ),
            ],
            const SizedBox(height: 16),
            if (_controller.tournamentRoundSummary.hasCurrentRound) ...[
              _buildCurrentRoundStatusBoard(_controller.tournamentRoundSummary),
              const SizedBox(height: 16),
            ],
            if (_controller.currentRoundCards.isNotEmpty) ...[
              _buildSectionHeader('Current Round'),
              const SizedBox(height: 8),
              for (final cardData in _controller.currentRoundCards)
                _buildCurrentRoundTableCard(cardData),
              if (_controller.otherCards.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildSectionHeader('Other Tables'),
                const SizedBox(height: 8),
                for (final cardData in _controller.otherCards)
                  _buildTableCard(cardData),
              ],
            ] else
              for (final cardData in _controller.cards)
                _buildTableCard(cardData),
            if (_controller.tables.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.table_restaurant,
                  title: 'No tables yet',
                  message: widget.readOnly
                      ? 'No tables were created before this event was locked.'
                      : 'Add a table before starting live seating.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentRoundStatusBoard(TournamentRoundSummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    final round = summary.round;
    final inProgress = summary.activeTableCount + summary.pausedTableCount;
    return AppListSurface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  round == null
                      ? 'Tournament Round'
                      : 'Round ${round.roundNumber}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              StatusChip(
                label: summary.isComplete ? 'Complete' : 'In Progress',
                tone: summary.isComplete
                    ? StatusChipTone.success
                    : StatusChipTone.info,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoundMetric(
                '${summary.completeTableCount} Complete',
                StatusChipTone.success,
              ),
              _buildRoundMetric(
                '$inProgress In Progress',
                inProgress == 0 ? StatusChipTone.neutral : StatusChipTone.info,
              ),
              _buildRoundMetric(
                '${summary.notStartedTableCount} Not Started',
                summary.notStartedTableCount == 0
                    ? StatusChipTone.neutral
                    : StatusChipTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _roundProgressLabel(summary),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (!widget.readOnly && widget.scoringOpen && summary.isComplete) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _controller.isStartingNextRound ? null : _startNextRound,
                icon: const Icon(Icons.skip_next),
                label: const Text('Start Next Round'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _roundProgressLabel(TournamentRoundSummary summary) {
    final tableLabel = summary.assignedTableCount == 1 ? 'table' : 'tables';
    return '${summary.completeTableCount} / '
        '${summary.assignedTableCount} $tableLabel complete';
  }

  Widget _buildRoundMetric(String label, StatusChipTone tone) {
    return StatusChip(label: label, tone: tone);
  }

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
    );
  }

  Widget _buildCurrentRoundTableCard(TableOverviewCardData cardData) {
    final roundTable = cardData.currentRoundSummary;
    if (roundTable == null) {
      return _buildTableCard(cardData);
    }

    final colorScheme = Theme.of(context).colorScheme;
    final players = [...roundTable.assignedPlayers]
      ..sort((left, right) => left.seatIndex.compareTo(right.seatIndex));
    final playersLabel = players.isEmpty
        ? 'No assigned players'
        : players.map((player) => player.displayName).join(', ');
    final sessionId =
        roundTable.activeSessionId ?? roundTable.latestEndedSessionId;
    final action = _currentRoundAction(roundTable);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppListSurface(
        key: ValueKey('table-card-${cardData.table.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    cardData.table.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 12),
                StatusChip(
                  label: _roundTableStatusLabel(roundTable.status),
                  tone: _roundTableStatusTone(roundTable.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              playersLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _sessionHandLabel(cardData.currentRoundHandCount),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (_shouldShowCurrentRoundLiveMeta(roundTable, cardData)) ...[
              const SizedBox(height: 8),
              _buildCurrentRoundLiveMeta(cardData.liveSummary!),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: action == _CurrentRoundAction.enter
                      ? () => _enterCurrentRoundTable(cardData.table)
                      : sessionId == null
                          ? null
                          : () => _openSessionDetail(sessionId),
                  child: Text(_currentRoundActionLabel(action)),
                ),
                const Spacer(),
                if (_controller.sessionsForTable(cardData.table.id).isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openSessionHistory(cardData.table),
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowCurrentRoundLiveMeta(
    TournamentRoundTableSummary roundTable,
    TableOverviewCardData cardData,
  ) {
    return cardData.liveSummary != null &&
        (roundTable.status == TournamentRoundTableStatus.active ||
            roundTable.status == TournamentRoundTableStatus.paused);
  }

  Widget _buildCurrentRoundLiveMeta(LiveTableSummary summary) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusChip(
          label: summary.roundWindLabel,
          tone: StatusChipTone.info,
        ),
        if (summary.showRoundTimer)
          StatusChip(
            label: summary.roundTimeLabel,
            tone: _roundTimeTone(summary),
          ),
        StatusChip(label: summary.dealerLabel),
      ],
    );
  }

  Widget _buildTableCard(TableOverviewCardData cardData) {
    final liveSummary = cardData.liveSummary;
    if (liveSummary != null) {
      return _buildLiveTableCard(cardData.table, liveSummary);
    }
    return _buildReadyTableCard(cardData.table);
  }

  Widget _buildLiveTableCard(
    EventTableRecord table,
    LiveTableSummary summary,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppListSurface(
        key: ValueKey('table-card-${table.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.progressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusChip(
                      label: _liveStatusLabel(summary.status),
                      tone: _liveStatusTone(summary.status),
                    ),
                    if (summary.showRoundTimer) ...[
                      const SizedBox(height: 6),
                      StatusChip(
                        label: summary.roundTimeLabel,
                        tone: _roundTimeTone(summary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                final arrangedSeats = _counterClockwiseSeats(summary.seats);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: arrangedSeats.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 64,
                  ),
                  itemBuilder: (context, index) => _buildSeatCell(
                    arrangedSeats[index],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildLastResultSummary(summary.lastHand),
            const SizedBox(height: 14),
            Row(
              children: [
                FilledButton(
                  onPressed: () => _openSessionDetail(summary.sessionId),
                  child: const Text('View Session'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Table options',
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        table.nfcTagId == null ? 'Tag missing' : 'Tag bound',
                      ),
                    ),
                    if (!widget.readOnly) ...[
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit table'),
                      ),
                      const PopupMenuItem(
                        value: 'bind',
                        child: Text('Bind table tag'),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('Session history'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'history') {
                      _openSessionHistory(table);
                      return;
                    }
                    if (!widget.readOnly) {
                      _openEditTable(table);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<SeatSummary> _counterClockwiseSeats(List<SeatSummary> seats) {
    if (seats.length != 4) {
      return seats;
    }

    final seatsByIndex = {for (final seat in seats) seat.seatIndex: seat};
    final orderedSeats = [
      seatsByIndex[0],
      seatsByIndex[3],
      seatsByIndex[1],
      seatsByIndex[2],
    ];
    if (orderedSeats.any((seat) => seat == null)) {
      return seats;
    }

    return [for (final seat in orderedSeats) seat!];
  }

  Widget _buildSeatCell(SeatSummary seat) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: seat.isDealer
            ? colorScheme.secondaryContainer.withValues(alpha: 0.34)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: seat.isDealer
              ? colorScheme.secondary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seat.windLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                  ),
                ),
                if (seat.isDealer) ...[
                  const SizedBox(width: 6),
                  _buildDealerBadge(colorScheme),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              seat.guestName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastResultSummary(LastHandSummary lastHand) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      key: const ValueKey('live-last-result-summary'),
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last Result',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                lastHand.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
              ),
              if (lastHand.detail case final detail?) ...[
                const SizedBox(height: 6),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDealerBadge(ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          'Dealer',
          maxLines: 1,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
        ),
      ),
    );
  }

  Widget _buildReadyTableCard(EventTableRecord table) {
    final hasTag = table.nfcTagId != null;
    final hasSessionHistory = _controller.sessionsForTable(table.id).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppListSurface(
        key: ValueKey('table-card-${table.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    table.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusChip(
                  label: widget.readOnly
                      ? 'Locked'
                      : hasTag
                          ? 'Ready'
                          : 'Needs Tag',
                  tone: widget.readOnly
                      ? StatusChipTone.neutral
                      : hasTag
                          ? StatusChipTone.success
                          : StatusChipTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.readOnly
                  ? 'This table is locked with the finalized event.'
                  : hasTag
                      ? 'Scan this table from the event dashboard to start seating.'
                      : 'Bind this table tag before live seating.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!widget.readOnly || hasSessionHistory) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (!widget.readOnly) ...[
                    OutlinedButton(
                      onPressed: () => _openEditTable(table),
                      child: const Text('Edit'),
                    ),
                    OutlinedButton(
                      onPressed: () => _openEditTable(table),
                      child: const Text('Bind Tag'),
                    ),
                  ],
                  if (hasSessionHistory)
                    OutlinedButton.icon(
                      onPressed: () => _openSessionHistory(table),
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _liveStatusLabel(SessionStatus status) {
    return switch (status) {
      SessionStatus.paused => 'Paused',
      _ => 'Active',
    };
  }

  _CurrentRoundAction _currentRoundAction(
    TournamentRoundTableSummary roundTable,
  ) {
    return switch (roundTable.status) {
      TournamentRoundTableStatus.active => _CurrentRoundAction.open,
      TournamentRoundTableStatus.paused => _CurrentRoundAction.open,
      TournamentRoundTableStatus.complete => _CurrentRoundAction.view,
      TournamentRoundTableStatus.notStarted => _CurrentRoundAction.enter,
      TournamentRoundTableStatus.other => _CurrentRoundAction.view,
    };
  }

  String _currentRoundActionLabel(_CurrentRoundAction action) {
    return switch (action) {
      _CurrentRoundAction.open => 'Open Session',
      _CurrentRoundAction.view => 'View Session',
      _CurrentRoundAction.enter => 'Enter Table',
    };
  }

  String _roundTableStatusLabel(TournamentRoundTableStatus status) {
    return switch (status) {
      TournamentRoundTableStatus.active => 'Active',
      TournamentRoundTableStatus.paused => 'Paused',
      TournamentRoundTableStatus.complete => 'Complete',
      TournamentRoundTableStatus.notStarted => 'Not Started',
      TournamentRoundTableStatus.other => 'Other',
    };
  }

  StatusChipTone _roundTableStatusTone(TournamentRoundTableStatus status) {
    return switch (status) {
      TournamentRoundTableStatus.active => StatusChipTone.info,
      TournamentRoundTableStatus.paused => StatusChipTone.warning,
      TournamentRoundTableStatus.complete => StatusChipTone.success,
      TournamentRoundTableStatus.notStarted => StatusChipTone.warning,
      TournamentRoundTableStatus.other => StatusChipTone.neutral,
    };
  }

  String _sessionHistorySubtitle(TableSessionRecord session) {
    return '${_sessionStatusLabel(session.status)} · '
        '${_sessionHandLabel(session.handCount)}';
  }

  String _sessionStatusLabel(SessionStatus status) {
    return switch (status) {
      SessionStatus.active => 'Active',
      SessionStatus.paused => 'Paused',
      SessionStatus.completed => 'Completed',
      SessionStatus.endedEarly => 'Ended Early',
      SessionStatus.aborted => 'Aborted',
    };
  }

  String _sessionHandLabel(int handCount) {
    return handCount == 0 ? 'No hands recorded' : 'Hand $handCount';
  }

  StatusChipTone _liveStatusTone(SessionStatus status) {
    return switch (status) {
      SessionStatus.paused => StatusChipTone.warning,
      _ => StatusChipTone.info,
    };
  }

  StatusChipTone _roundTimeTone(LiveTableSummary summary) {
    if (summary.isRoundExpired) {
      return StatusChipTone.danger;
    }
    if (summary.isRoundEndingSoon) {
      return StatusChipTone.warning;
    }
    return StatusChipTone.neutral;
  }
}

enum _CurrentRoundAction {
  open,
  view,
  enter,
}
