import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/finals_state_models.dart';
import 'package:mosaic/data/models/session_models.dart';
import 'package:mosaic/data/models/table_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/table_list_controller.dart';
import 'package:mosaic/features/tables/models/table_overview_card_data.dart';
import 'package:mosaic/features/tables/models/finals_overview_view_models.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class TablesOverviewScreen extends StatefulWidget {
  const TablesOverviewScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.scoringOpen,
    this.scoringPhase = EventScoringPhase.tournament,
    this.readOnly = false,
    this.canManageTables = true,
    required this.tableRepository,
    required this.sessionRepository,
    required this.guestRepository,
    this.finalsRepository,
    this.seatingRepository,
    this.now,
  });

  final String eventId;
  final String eventTitle;
  final bool scoringOpen;
  final EventScoringPhase scoringPhase;
  final bool readOnly;
  final bool canManageTables;
  final TableRepository tableRepository;
  final SessionRepository sessionRepository;
  final GuestRepository guestRepository;
  final FinalsRepository? finalsRepository;
  final SeatingRepository? seatingRepository;
  final DateTime Function()? now;

  @override
  State<TablesOverviewScreen> createState() => _TablesOverviewScreenState();
}

class _TablesOverviewScreenState extends State<TablesOverviewScreen> {
  late final TableListController _controller;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _roundTimer;

  bool get _isQualificationPhase =>
      widget.scoringPhase == EventScoringPhase.qualification;

  @override
  void initState() {
    super.initState();
    _controller = TableListController(
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
      guestRepository: widget.guestRepository,
      finalsRepository: widget.finalsRepository,
      seatingRepository: widget.seatingRepository,
      scoringPhase: widget.scoringPhase,
      now: widget.now,
    )
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
    _searchController.addListener(_handleUpdate);
    _searchFocusNode.addListener(_handleUpdate);
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
    _searchController
      ..removeListener(_handleUpdate)
      ..dispose();
    _searchFocusNode
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

  Future<void> _enterReadyTable(EventTableRecord table) async {
    await Navigator.of(context).pushNamed(
      AppRouter.startSessionRoute,
      arguments: StartSessionArgs(
        eventId: widget.eventId,
        table: table,
        scoringPhase: _controller.effectiveScoringPhase,
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
          eventTitle: widget.eventTitle,
          initialAssignments: assignments,
        ),
      );
      await _controller.load(widget.eventId);
    }
  }

  Future<void> _startAllTables() async {
    await _controller.startAllTables(widget.eventId);
  }

  Future<void> _openBonusRound() async {
    await Navigator.of(context).pushNamed(
      AppRouter.bonusRoundRoute,
      arguments: BonusRoundArgs(eventId: widget.eventId),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _pauseSessionTimer(String sessionId) async {
    await _controller.pauseSessionTimer(widget.eventId, sessionId);
  }

  Future<void> _resumeSessionTimer(String sessionId) async {
    await _controller.resumeSessionTimer(widget.eventId, sessionId);
  }

  Future<void> _pauseAllRoundTimers() async {
    await _controller.pauseAllRoundTimers(widget.eventId);
  }

  Future<void> _resumeAllRoundTimers() async {
    await _controller.resumeAllRoundTimers(widget.eventId);
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
    final searchQuery = _searchController.text.trim().toLowerCase();
    final hasSearch = searchQuery.isNotEmpty;
    final filteredCards = _controller.cards
        .where((card) => _matchesSearch(card, searchQuery))
        .toList(growable: false);
    final filteredCurrentRoundCards = _controller.currentRoundCards
        .where((card) => _matchesSearch(card, searchQuery))
        .toList(growable: false);
    final filteredOtherCards = _controller.otherCards
        .where((card) => _matchesSearch(card, searchQuery))
        .toList(growable: false);
    final hasCurrentRoundSections = _controller.currentRoundCards.isNotEmpty;
    final hasSearchableTables =
        _controller.tables.isNotEmpty || hasCurrentRoundSections;
    final hasFilteredTables = hasCurrentRoundSections
        ? filteredCurrentRoundCards.isNotEmpty || filteredOtherCards.isNotEmpty
        : filteredCards.isNotEmpty;

    return ReconnectRefreshListener(
      onRefresh: () => _controller.load(widget.eventId, silent: true),
      child: Scaffold(
        appBar: AppBar(title: const Text('Tables')),
        body: AsyncBody(
          isLoading: _controller.isLoading,
          error: _controller.error,
          onRetry: () => _controller.load(widget.eventId),
          child: ListView(
            key: const ValueKey('tables-overview-list'),
            padding: const EdgeInsets.all(16),
            children: [
              if (!widget.readOnly && widget.canManageTables) ...[
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
              if (hasSearchableTables) ...[
                const SizedBox(height: 12),
                _buildSearchField(),
              ],
              const SizedBox(height: 16),
              if (_controller.effectiveScoringPhase ==
                      EventScoringPhase.bonus &&
                  _controller.finalsSummary != null) ...[
                _buildFinalsOverview(_controller.finalsSummary!),
                const SizedBox(height: 16),
              ],
              if (_controller.tournamentRoundSummary.hasCurrentRound) ...[
                _buildCurrentRoundStatusBoard(
                  _controller.tournamentRoundSummary,
                ),
                const SizedBox(height: 16),
              ],
              if (hasCurrentRoundSections && hasFilteredTables) ...[
                if (filteredCurrentRoundCards.isNotEmpty) ...[
                  _buildSectionHeader(
                    _controller.effectiveScoringPhase == EventScoringPhase.bonus
                        ? 'Finals Tables'
                        : 'Current Round',
                  ),
                  const SizedBox(height: 8),
                  for (final cardData in filteredCurrentRoundCards)
                    _buildCurrentRoundTableCard(cardData),
                ],
                if (filteredOtherCards.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _buildSectionHeader('Other Tables'),
                  const SizedBox(height: 8),
                  for (final cardData in filteredOtherCards)
                    _buildTableCard(cardData),
                ],
              ] else if (!hasCurrentRoundSections)
                for (final cardData in filteredCards) _buildTableCard(cardData),
              if (hasSearch && hasSearchableTables && !hasFilteredTables)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: EmptyStateCard(
                    icon: Icons.search_off,
                    title: 'No matching tables',
                    message: 'Try a different table or player search.',
                  ),
                ),
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
      ),
    );
  }

  Widget _buildFinalsOverview(FinalsOverviewSummary summary) {
    final recoveryAction = _controller.primaryFinalsAction;
    final showRecoveryAction = recoveryAction != null &&
        (recoveryAction.kind == FinalsActionKind.startFinalsTables ||
            recoveryAction.kind == FinalsActionKind.resumeFinalsStart);
    final inProgress = summary.activeCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showRecoveryAction &&
            !widget.readOnly &&
            widget.canManageTables) ...[
          FilledButton.icon(
            onPressed: _controller.isExecutingFinalsAction
                ? null
                : () => _controller.executeFinalsAction(recoveryAction),
            icon: const Icon(Icons.play_arrow),
            label: Text(recoveryAction.label),
          ),
          const SizedBox(height: 12),
        ],
        if (_controller.finalsActionError case final actionError?) ...[
          InfoPanel(message: actionError),
          const SizedBox(height: 12),
        ],
        AppListSurface(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Finals',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  StatusChip(
                    label: _finalsStatusLabel(summary.overallStatus),
                    tone: _finalsStatusTone(summary.overallStatus),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRoundMetric(
                    '${summary.completeCount} Complete',
                    StatusChipTone.success,
                  ),
                  _buildRoundMetric(
                    '$inProgress In Progress',
                    inProgress == 0
                        ? StatusChipTone.neutral
                        : StatusChipTone.info,
                  ),
                  _buildRoundMetric(
                    '${summary.notStartedCount} Not Started',
                    summary.notStartedCount == 0
                        ? StatusChipTone.neutral
                        : StatusChipTone.warning,
                  ),
                ],
              ),
              if (summary.blockingReason case final blockingReason?) ...[
                const SizedBox(height: 12),
                InfoPanel(message: blockingReason),
              ],
              if (summary.contests.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final contest in summary.contests)
                  _buildFinalsContest(contest),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinalsContest(FinalsContestOverview contest) {
    final action = _controller.finalsState?.allowedActions
        .where((action) => action.contestId == contest.id)
        .firstOrNull;
    final sessionId = contest.sessionId;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      contest.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  StatusChip(
                    label: _finalsContestStatusLabel(contest.status),
                    tone: _finalsContestStatusTone(contest.status),
                  ),
                ],
              ),
              if (contest.tableLabel case final tableLabel?) ...[
                const SizedBox(height: 2),
                Text(tableLabel),
              ],
              if (contest.participantNames.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(contest.participantNames.join(' • ')),
              ],
              if (contest.resultLabel case final resultLabel?) ...[
                const SizedBox(height: 6),
                Text(
                  resultLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (_finalsContestTimestamp(contest) case final timestamp?) ...[
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (contest.isReady &&
                  action != null &&
                  !widget.readOnly &&
                  widget.canManageTables) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _controller.isExecutingFinalsAction
                      ? null
                      : () => _executeContestAction(action),
                  child: Text(action.label),
                ),
              ] else if (contest.isActive && sessionId != null) ...[
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => _openSessionDetail(sessionId),
                  child: const Text('Open Table'),
                ),
              ] else if (contest.isComplete && sessionId != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openSessionDetail(sessionId),
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeContestAction(FinalsAction action) async {
    final usableTables = _controller.usableTablesForFinalsAction(action);
    final boundTableIsUsable = action.tableId != null &&
        usableTables.any((table) => table.id == action.tableId);
    if (boundTableIsUsable) {
      await _controller.executeFinalsAction(action);
      return;
    }

    final selected = await showModalBottomSheet<EventTableRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose a ready table',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (usableTables.isEmpty)
                const EmptyStateCard(
                  icon: Icons.table_bar,
                  title: 'No ready tables',
                  message:
                      'Finish conflicting play before starting this Finals table.',
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: usableTables.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final table = usableTables[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(table.label),
                        onTap: () => Navigator.of(sheetContext).pop(table),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await _controller.executeFinalsAction(action, tableId: selected.id);
    }
  }

  String? _finalsContestTimestamp(FinalsContestOverview contest) {
    final timestamp = contest.completedAt ?? contest.startedAt;
    if (timestamp == null) return null;
    final local = timestamp.toLocal();
    final material = MaterialLocalizations.of(context);
    final date = material.formatShortDate(local);
    final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return contest.completedAt == null
        ? 'Started $date at $time'
        : 'Completed $date at $time';
  }

  String _finalsStatusLabel(FinalsOverallStatus status) => switch (status) {
        FinalsOverallStatus.complete => 'Complete',
        FinalsOverallStatus.blockedLegacyState => 'Needs attention',
        FinalsOverallStatus.recoverableMissingSessions => 'Ready to start',
        FinalsOverallStatus.cancelled => 'Cancelled',
        FinalsOverallStatus.notStarted => 'Not Started',
        FinalsOverallStatus.active => 'In Progress',
      };

  StatusChipTone _finalsStatusTone(FinalsOverallStatus status) =>
      switch (status) {
        FinalsOverallStatus.complete => StatusChipTone.success,
        FinalsOverallStatus.blockedLegacyState => StatusChipTone.warning,
        FinalsOverallStatus.recoverableMissingSessions =>
          StatusChipTone.warning,
        FinalsOverallStatus.cancelled => StatusChipTone.neutral,
        FinalsOverallStatus.notStarted => StatusChipTone.neutral,
        FinalsOverallStatus.active => StatusChipTone.info,
      };

  String _finalsContestStatusLabel(FinalsContestStatus status) =>
      switch (status) {
        FinalsContestStatus.pending => 'Waiting',
        FinalsContestStatus.ready => 'Not Started',
        FinalsContestStatus.active => 'In Progress',
        FinalsContestStatus.complete => 'Complete',
        FinalsContestStatus.cancelled => 'Cancelled',
      };

  StatusChipTone _finalsContestStatusTone(FinalsContestStatus status) =>
      switch (status) {
        FinalsContestStatus.pending => StatusChipTone.neutral,
        FinalsContestStatus.ready => StatusChipTone.warning,
        FinalsContestStatus.active => StatusChipTone.info,
        FinalsContestStatus.complete => StatusChipTone.success,
        FinalsContestStatus.cancelled => StatusChipTone.neutral,
      };

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _searchFocusNode.unfocus(),
      decoration: InputDecoration(
        labelText: 'Search tables',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _buildSearchSuffixIcon(),
      ),
    );
  }

  Widget? _buildSearchSuffixIcon() {
    final hasSearchText = _searchController.text.isNotEmpty;
    final isFocused = _searchFocusNode.hasFocus;
    if (!hasSearchText && !isFocused) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSearchText)
          IconButton(
            tooltip: 'Clear search',
            onPressed: _searchController.clear,
            icon: const Icon(Icons.clear),
          ),
        if (isFocused)
          IconButton(
            tooltip: 'Dismiss keyboard',
            onPressed: _searchFocusNode.unfocus,
            icon: const Icon(Icons.keyboard_hide),
          ),
      ],
    );
  }

  bool _matchesSearch(TableOverviewCardData cardData, String searchQuery) {
    if (searchQuery.isEmpty) {
      return true;
    }

    final searchableValues = [
      cardData.table.label,
      cardData.assignmentTitle,
      cardData.assignmentSubtitle,
      for (final player in cardData.currentRoundSummary?.assignedPlayers ??
          const <TournamentRoundAssignedPlayer>[])
        player.displayName,
      for (final seat in cardData.liveSummary?.seats ?? const <SeatSummary>[])
        seat.guestName,
    ];

    return searchableValues.whereType<String>().any(
          (value) => value.toLowerCase().contains(searchQuery),
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
                  _currentBoardTitle(round),
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
          if (!widget.readOnly &&
              widget.canManageTables &&
              _controller.canStartAllTables) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _controller.isStartingAllTables ? null : _startAllTables,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _controller.isStartingAllTables
                      ? 'Starting Tables...'
                      : 'Start All Tables',
                ),
              ),
            ),
          ] else if (!widget.readOnly &&
              widget.canManageTables &&
              widget.scoringOpen &&
              _controller.effectiveScoringPhase ==
                  EventScoringPhase.tournament &&
              summary.isComplete) ...[
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _controller.isStartingNextRound ? null : _openBonusRound,
                icon: const Icon(Icons.emoji_events),
                label: const Text('Begin Finals'),
              ),
            ),
          ] else if (!widget.readOnly &&
              widget.canManageTables &&
              widget.scoringOpen &&
              summary.hasCurrentRound) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (summary.activeTableCount > 0)
                  OutlinedButton.icon(
                    onPressed: _controller.isUpdatingTimers
                        ? null
                        : _pauseAllRoundTimers,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause All Timers'),
                  ),
                if (summary.pausedTableCount > 0)
                  FilledButton.icon(
                    onPressed: _controller.isUpdatingTimers
                        ? null
                        : _resumeAllRoundTimers,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume All Timers'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _roundProgressLabel(TournamentRoundSummary summary) {
    final noun = _controller.effectiveScoringPhase == EventScoringPhase.bonus
        ? 'finals ${summary.assignedTableCount == 1 ? 'table' : 'tables'}'
        : summary.assignedTableCount == 1
            ? 'table'
            : 'tables';
    return '${summary.completeTableCount} / '
        '${summary.assignedTableCount} $noun complete';
  }

  String _currentBoardTitle(TournamentRoundRecord? round) {
    if (_controller.effectiveScoringPhase == EventScoringPhase.bonus) {
      if (_controller.isPlayInRequired) {
        return 'Play-In Required';
      }
      if (_controller.isPlayInActive) {
        return 'Play-In in progress';
      }
      if (_controller.isSuddenDeathRequired) {
        return 'Sudden Death Required';
      }
      if (_controller.isSuddenDeathActive) {
        return 'Sudden Death in progress';
      }
      return 'Finals';
    }
    return round == null ? 'Tournament Round' : 'Round ${round.roundNumber}';
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
                    cardData.assignmentTitle ?? cardData.table.label,
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
            if (cardData.assignmentSubtitle case final subtitle?) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            _buildAssignedSeatRows(players),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (action != _CurrentRoundAction.enter)
                  FilledButton(
                    onPressed: sessionId == null
                        ? null
                        : () => _openSessionDetail(sessionId),
                    child: Text(_currentRoundActionLabel(action)),
                  ),
                if (cardData.liveSummary case final liveSummary?)
                  if (liveSummary.showRoundTimer)
                    _buildTimerActionButton(liveSummary),
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

  Widget _buildAssignedSeatRows(
    List<TournamentRoundAssignedPlayer> players,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (players.isEmpty) {
      return Text(
        'No assigned players',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final player in players)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Text(
                    _seatLabel(player.seatIndex),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    player.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _seatLabel(int seatIndex) {
    return switch (seatIndex) {
      0 => 'East seat',
      1 => 'South seat',
      2 => 'West seat',
      3 => 'North seat',
      _ => 'Seat ${seatIndex + 1}',
    };
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: () => _openSessionDetail(summary.sessionId),
                  child: const Text('View Session'),
                ),
                if (summary.showRoundTimer) _buildTimerActionButton(summary),
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
                    if (!widget.readOnly && widget.canManageTables) ...[
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

  Widget _buildTimerActionButton(LiveTableSummary summary) {
    final isPaused = summary.status == SessionStatus.paused;
    final isActive = summary.status == SessionStatus.active;
    if (!isActive && !isPaused) {
      return const SizedBox.shrink();
    }

    final onPressed = _controller.isUpdatingTimers
        ? null
        : isPaused
            ? () => _resumeSessionTimer(summary.sessionId)
            : () => _pauseSessionTimer(summary.sessionId);
    final label = isPaused ? 'Resume Timer' : 'Pause Timer';
    final icon = isPaused ? Icons.play_arrow : Icons.pause;
    if (isPaused) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
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
    final statusLabel = widget.readOnly
        ? 'Locked'
        : hasTag || _isQualificationPhase
            ? 'Ready'
            : 'Needs Tag';
    final statusTone = widget.readOnly
        ? StatusChipTone.neutral
        : hasTag || _isQualificationPhase
            ? StatusChipTone.success
            : StatusChipTone.warning;
    final readyCopy = widget.readOnly
        ? 'This table is locked with the finalized event.'
        : _isQualificationPhase
            ? widget.scoringOpen
                ? 'Ready for assigned tournament seating. Start this table when players are seated.'
                : 'Open scoring before starting assigned tournament seating at this table.'
            : hasTag
                ? _controller.effectiveScoringPhase == EventScoringPhase.bonus
                    ? 'Use the Finals controls above when players are seated.'
                    : 'Scan this table from the event dashboard to start seating.'
                : 'Bind this table tag before live seating.';
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
                  label: statusLabel,
                  tone: statusTone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              readyCopy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!widget.readOnly || hasSessionHistory) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (!widget.readOnly) ...[
                    if (_isQualificationPhase && widget.scoringOpen)
                      FilledButton.icon(
                        onPressed: () => _enterReadyTable(table),
                        icon: const Icon(Icons.login),
                        label: const Text('Start Table'),
                      ),
                    if (widget.canManageTables) ...[
                      OutlinedButton(
                        onPressed: () => _openEditTable(table),
                        child: const Text('Edit'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openEditTable(table),
                        child: const Text('Bind Tag'),
                      ),
                    ],
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
      _CurrentRoundAction.enter => 'Not Started',
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
