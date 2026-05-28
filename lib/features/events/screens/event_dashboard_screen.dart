import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/tournament_round_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';
import 'package:mosaic/features/events/models/bonus_round_results_summary.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/app_actions.dart';
import 'package:mosaic/widgets/app_chrome.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/status_chip.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({
    super.key,
    required this.args,
    required this.eventRepository,
    required this.guestRepository,
    required this.leaderboardRepository,
    this.prizeRepository,
    this.tableRepository,
    this.sessionRepository,
    this.seatingRepository,
    this.staffRepository,
    this.nfcService,
  });

  final EventDashboardArgs args;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final LeaderboardRepository leaderboardRepository;
  final PrizeRepository? prizeRepository;
  final TableRepository? tableRepository;
  final SessionRepository? sessionRepository;
  final SeatingRepository? seatingRepository;
  final StaffRepository? staffRepository;
  final NfcService? nfcService;

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  late final EventDashboardController _controller;
  final _scrollController = ScrollController();
  bool _isScanningTableTag = false;

  bool get _isTableScanInProgress =>
      _isScanningTableTag || _controller.isScanningTable;

  @override
  void initState() {
    super.initState();
    _controller = EventDashboardController(
      eventRepository: widget.eventRepository,
      guestRepository: widget.guestRepository,
      leaderboardRepository: widget.leaderboardRepository,
      prizeRepository: widget.prizeRepository,
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
      seatingRepository: widget.seatingRepository,
      callerRole: widget.args.callerRole,
    )
      ..addListener(_handleUpdate)
      ..load(widget.args.eventId);
  }

  @override
  void didUpdateWidget(covariant EventDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.updateRuntimeRepositories(
      sessionRepository: widget.sessionRepository,
      seatingRepository: widget.seatingRepository,
    );
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reloadDashboardAfterReturn(String eventId) async {
    if (!mounted) {
      return;
    }

    await _controller.load(eventId);
  }

  Future<void> _openGuests() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.guestRosterRoute,
      arguments: GuestRosterArgs(
        eventId: event.id,
        eventTitle: event.title,
        eventCoverChargeCents: event.coverChargeCents,
        canCheckIn: _controller.canScoreQualification,
        canManageGuests: _controller.canManageEvent,
        canManageCover: _controller.canManageEvent,
        canAssignTags: _controller.canManageEvent,
        canManageTournamentStatus: _controller.canManageEvent,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openTables() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.tablesOverviewRoute,
      arguments: TablesOverviewArgs(
        eventId: event.id,
        eventTitle: event.title,
        scoringOpen: event.scoringOpen,
        scoringPhase:
            _controller.effectiveScoringPhase ?? event.currentScoringPhase,
        readOnly: event.lifecycleStatus != EventLifecycleStatus.draft &&
            event.lifecycleStatus != EventLifecycleStatus.active,
        canManageTables: _controller.canManageEvent,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _scanTable() async {
    final nfcService = widget.nfcService;
    if (nfcService == null || _isTableScanInProgress) {
      return;
    }

    final TagScanResult? scanResult;
    setState(() {
      _isScanningTableTag = true;
    });

    try {
      scanResult = await nfcService.scanTableTag(context);
    } catch (exception) {
      if (mounted) {
        _controller.recordTableScanError(exception);
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isScanningTableTag = false;
        });
      }
    }

    if (!mounted || scanResult == null) {
      return;
    }

    final result = await _controller.resolveScannedTableTag(
      scanResult.normalizedUid,
    );
    if (!mounted || result == null) {
      return;
    }

    switch (result) {
      case DashboardTableScanOpenSession(:final sessionId):
        await Navigator.of(context).pushNamed(
          AppRouter.sessionDetailRoute,
          arguments: SessionDetailArgs(
            eventId: widget.args.eventId,
            sessionId: sessionId,
            scoringOpen: _controller.event?.scoringOpen ?? false,
          ),
        );
        await _reloadDashboardAfterReturn(widget.args.eventId);
      case DashboardTableScanStartSession(
          :final table,
          :final preverifiedTableTagUid,
        ):
        await Navigator.of(context).pushNamed(
          AppRouter.startSessionRoute,
          arguments: StartSessionArgs(
            eventId: widget.args.eventId,
            table: table,
            scoringPhase: _controller.effectiveScoringPhase ??
                _controller.event?.currentScoringPhase ??
                EventScoringPhase.qualification,
            preverifiedTableTagUid: preverifiedTableTagUid,
          ),
        );
        await _reloadDashboardAfterReturn(widget.args.eventId);
    }
  }

  Future<void> _openLeaderboard({bool initialQualificationTab = false}) async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.leaderboardRoute,
      arguments: LeaderboardArgs(
        eventId: event.id,
        initialQualificationTab: initialQualificationTab,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openPrizes() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.prizePlanRoute,
      arguments: PrizePlanArgs(
        eventId: event.id,
      ),
    );

    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openStaff() async {
    final event = _controller.event;
    if (event == null || !_controller.canManageStaff) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.eventStaffRoute,
      arguments: EventStaffArgs(
        eventId: event.id,
        eventTitle: event.title,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openSeating() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.seatingAssignmentsRoute,
      arguments: SeatingAssignmentsArgs(eventId: event.id),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openBonusRound() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.bonusRoundRoute,
      arguments: BonusRoundArgs(eventId: event.id),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openActivity() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.activityRoute,
      arguments: ActivityArgs(eventId: event.id),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _openHandLedger() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.eventHandLedgerRoute,
      arguments: EventHandLedgerArgs(eventId: event.id),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _startTournament() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    final assignments = await _controller.startTournament();
    if (!mounted || assignments == null) {
      _scrollToTop();
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.seatingAssignmentsRoute,
      arguments: SeatingAssignmentsArgs(
        eventId: event.id,
        initialAssignments: assignments,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _startNextTournamentRound() async {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    final assignments = await _controller.startNextTournamentRound();
    if (!mounted || assignments == null) {
      _scrollToTop();
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.seatingAssignmentsRoute,
      arguments: SeatingAssignmentsArgs(
        eventId: event.id,
        initialAssignments: assignments,
      ),
    );
    await _reloadDashboardAfterReturn(event.id);
  }

  Future<void> _confirmDeleteEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text(
          'This removes the draft event and its setup data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final deleted = await _controller.deleteEvent();
    if (!mounted || !deleted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _confirmCancelEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this event?'),
        content: const Text(
          'This closes check-in and scoring and marks the event as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _controller.cancelEvent();
    _scrollToTop();
  }

  Future<void> _confirmRevertToDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revert to draft?'),
        content: const Text(
          'Only events with no checked-in guests, sessions, or scores can go back to draft.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Live'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revert'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _controller.revertToDraft();
    _scrollToTop();
  }

  Future<void> _confirmCopyEventForTesting() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy this event?'),
        content: const Text(
          'This creates a draft testing copy with guests, tables, and prize setup, but no check-ins, player tag assignments, sessions, scores, standings, or awards.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final copiedEvent = await _controller.copyEventForTesting();
    if (!mounted || copiedEvent == null) {
      _scrollToTop();
      return;
    }

    await Navigator.of(context).pushReplacementNamed(
      AppRouter.eventDashboardRoute,
      arguments: EventDashboardArgs(eventId: copiedEvent.id),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  String _flagStatusLabel(bool isOpen) => isOpen ? 'Open' : 'Not Open';

  String _eventPhaseLabel(EventRecord? event) {
    return switch (event?.lifecycleStatus) {
      EventLifecycleStatus.draft => 'Setup',
      EventLifecycleStatus.active when event?.scoringOpen == true =>
        _activeScoringLabel(event!.currentScoringPhase),
      EventLifecycleStatus.active when event?.checkinOpen == true =>
        'Check-In Open',
      EventLifecycleStatus.active => 'Active',
      EventLifecycleStatus.completed => 'Review Before Finalizing',
      EventLifecycleStatus.finalized => 'Results Locked',
      EventLifecycleStatus.cancelled => 'Cancelled',
      null => 'Loading Event',
    };
  }

  String _activeScoringLabel(EventScoringPhase phase) {
    return switch (phase) {
      EventScoringPhase.qualification => 'Qualification Open',
      EventScoringPhase.tournament => 'Tournament Live',
      EventScoringPhase.bonus => 'Finals Live',
    };
  }

  StatusChipTone _eventPhaseTone(EventLifecycleStatus? status) {
    return switch (status) {
      EventLifecycleStatus.draft => StatusChipTone.warning,
      EventLifecycleStatus.active => StatusChipTone.success,
      EventLifecycleStatus.completed => StatusChipTone.warning,
      EventLifecycleStatus.finalized => StatusChipTone.neutral,
      EventLifecycleStatus.cancelled => StatusChipTone.danger,
      null => StatusChipTone.neutral,
    };
  }

  StatusChipTone _flagTone(bool isOpen) {
    return isOpen ? StatusChipTone.success : StatusChipTone.warning;
  }

  bool _usesTransitionalLiveDashboard(EventRecord? event) {
    return event?.lifecycleStatus == EventLifecycleStatus.active &&
        event?.checkinOpen == true &&
        event?.scoringOpen == false;
  }

  String _formatLifecycleMessage(EventLifecycleStatus? lifecycleStatus) {
    return switch (lifecycleStatus) {
      EventLifecycleStatus.draft =>
        'Finish setup, then open check-in when hosts are ready to receive guests.',
      EventLifecycleStatus.active =>
        'Use the live operations controls to open or close check-in and scoring during the event.',
      EventLifecycleStatus.completed =>
        'Review standings and locked prizes before finalizing.',
      EventLifecycleStatus.finalized =>
        'Standings and awards are locked for this event.',
      EventLifecycleStatus.cancelled =>
        'This event was cancelled and is no longer live.',
      null =>
        'Check-in, tables, sessions, scoring, and prizes are available from the dashboard actions above.',
    };
  }

  String _formatLifecycleError(String message) {
    if (message ==
        '1 active or paused session(s) must be ended before changing the event lifecycle.') {
      return 'End all active or paused sessions before changing the event phase.';
    }
    return message;
  }

  String _formatPrizePool(int? prizePoolCents) {
    if (prizePoolCents == null) {
      return 'Prize Pool: Not set';
    }

    return 'Prize Pool: \$${formatMoneyCents(prizePoolCents)}';
  }

  String _formatPrizePoolValue(int? prizePoolCents) {
    if (prizePoolCents == null) {
      return 'Not set';
    }

    return '\$${formatMoneyCents(prizePoolCents)}';
  }

  @override
  Widget build(BuildContext context) {
    final event = _controller.event;
    if (event != null) {
      return _buildLiveConsole(context, event);
    }

    final lifecycleStatus = event?.lifecycleStatus;
    final showLiveActions = lifecycleStatus != null &&
        _controller.canManageEvent &&
        lifecycleStatus != EventLifecycleStatus.completed &&
        lifecycleStatus != EventLifecycleStatus.finalized &&
        lifecycleStatus != EventLifecycleStatus.cancelled;
    final canScanTables = widget.tableRepository != null &&
        widget.sessionRepository != null &&
        widget.nfcService != null;
    final showTableScanAction =
        lifecycleStatus == EventLifecycleStatus.active &&
            canScanTables &&
            _canScorePhase(
              _controller.effectiveScoringPhase ??
                  event?.currentScoringPhase ??
                  EventScoringPhase.qualification,
            );
    return Scaffold(
      appBar: AppBar(title: Text(event?.title ?? 'Event Dashboard')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.args.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              event?.title ?? 'Unknown Event',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Event Phase',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: _eventPhaseLabel(event),
              tone: _eventPhaseTone(lifecycleStatus),
            ),
            const SizedBox(height: 8),
            Text('Guests: ${_controller.guestCount}'),
            const SizedBox(height: 4),
            Text(_formatPrizePool(_controller.prizePoolCents)),
            if (_controller.lifecycleError case final lifecycleError?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_formatLifecycleError(lifecycleError)),
                  ),
                ),
              ),
            if (_controller.tableScanError case final tableScanError?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tableScanError),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_usesTransitionalLiveDashboard(event)) ...[
              FilledButton(
                onPressed: _controller.isSubmittingLifecycle
                    ? null
                    : () => _controller.setOperationalFlags(
                          checkinOpen: event!.checkinOpen,
                          scoringOpen: true,
                        ),
                child: const Text('Open Scoring'),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (showLiveActions)
                  FilledButton(
                    onPressed: _openGuests,
                    child: const Text('Guests'),
                  ),
                if (showLiveActions)
                  FilledButton(
                    onPressed: _openTables,
                    child: const Text('Tables'),
                  ),
                if (showTableScanAction)
                  FilledButton(
                    onPressed: _isTableScanInProgress ? null : _scanTable,
                    child: Text(
                      _isTableScanInProgress ? 'Scanning...' : 'Scan Table',
                    ),
                  ),
                FilledButton(
                  onPressed: _openLeaderboard,
                  child: const Text('Leaderboard'),
                ),
                FilledButton(
                  onPressed: _openActivity,
                  child: const Text('Activity'),
                ),
                if (_controller.canManageEvent)
                  FilledButton(
                    onPressed: _openPrizes,
                    child: const Text('Prizes'),
                  ),
                if (showLiveActions)
                  OutlinedButton(
                    onPressed: _openGuests,
                    child: const Text('Add Guest'),
                  ),
                if (_controller.canManageEvent &&
                    lifecycleStatus == EventLifecycleStatus.draft)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.startEvent(),
                    child: const Text('Open Check-In'),
                  ),
                if (_controller.canManageEvent &&
                    lifecycleStatus == EventLifecycleStatus.active)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.completeEvent(),
                    child: const Text('Complete Event'),
                  ),
                if (_controller.canManageEvent &&
                    lifecycleStatus == EventLifecycleStatus.completed)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.finalizeEvent(),
                    child: const Text('Finalize Event'),
                  ),
                if (_controller.canManageEvent &&
                    lifecycleStatus == EventLifecycleStatus.draft)
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmDeleteEvent,
                    child: const Text('Delete Event'),
                  ),
                if (_controller.canManageEvent &&
                    lifecycleStatus == EventLifecycleStatus.active)
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmRevertToDraft,
                    child: const Text('Revert to Draft'),
                  ),
                if (_controller.canManageEvent &&
                    (lifecycleStatus == EventLifecycleStatus.active ||
                        lifecycleStatus == EventLifecycleStatus.completed))
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmCancelEvent,
                    child: const Text('Cancel Event'),
                  ),
              ],
            ),
            if (_controller.canManageEvent &&
                lifecycleStatus == EventLifecycleStatus.active) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Operations',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                            label:
                                'Check-In ${_flagStatusLabel(event!.checkinOpen)}',
                            tone: _flagTone(event.checkinOpen),
                          ),
                          StatusChip(
                            label:
                                'Scoring ${_flagStatusLabel(event.scoringOpen)}',
                            tone: _flagTone(event.scoringOpen),
                          ),
                        ],
                      ),
                      if (!event.checkinOpen) ...[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _controller.isSubmittingLifecycle
                              ? null
                              : () => _controller.setOperationalFlags(
                                    checkinOpen: true,
                                    scoringOpen: event.scoringOpen,
                                  ),
                          child: const Text('Open Check-In'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (!_usesTransitionalLiveDashboard(event))
                        OutlinedButton(
                          onPressed: _controller.isSubmittingLifecycle
                              ? null
                              : () => _controller.setOperationalFlags(
                                    checkinOpen: event.checkinOpen,
                                    scoringOpen: !event.scoringOpen,
                                  ),
                          child: Text(
                            event.scoringOpen
                                ? 'Pause Scoring'
                                : 'Open Scoring',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (lifecycleStatus == EventLifecycleStatus.finalized)
                      const Text('Final Event State'),
                    Text(
                      _formatLifecycleMessage(lifecycleStatus),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveConsole(BuildContext context, EventRecord event) {
    final colorScheme = Theme.of(context).colorScheme;
    final scoringPhase =
        _controller.effectiveScoringPhase ?? event.currentScoringPhase;
    final canScanTables = widget.tableRepository != null &&
        widget.sessionRepository != null &&
        widget.nfcService != null;
    final lifecycleStatus = event.lifecycleStatus;
    final showTableScanAction =
        lifecycleStatus == EventLifecycleStatus.active &&
            canScanTables &&
            _canScorePhase(scoringPhase);
    final showLiveNavigation =
        lifecycleStatus != EventLifecycleStatus.completed &&
            lifecycleStatus != EventLifecycleStatus.finalized &&
            lifecycleStatus != EventLifecycleStatus.cancelled;
    final showQualificationSetup = _usesQualificationSetupDashboard(event);
    final showTournamentCommandCenter = _controller.canManageEvent &&
        lifecycleStatus == EventLifecycleStatus.active &&
        event.scoringOpen &&
        scoringPhase == EventScoringPhase.tournament;
    final showFinalsCommandCenter = _controller.canManageEvent &&
        lifecycleStatus == EventLifecycleStatus.active &&
        event.scoringOpen &&
        scoringPhase == EventScoringPhase.bonus;
    final showRoundCommandCenter =
        showTournamentCommandCenter || showFinalsCommandCenter;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GlassCircleButton(
            visualKey: const ValueKey('eventDashboardBackButton'),
            icon: Icons.chevron_left,
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: GlassTitlePill(title: event.title),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.75),
              colorScheme.secondaryContainer.withValues(alpha: 0.35),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0, 0.26, 0.42],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight - 8, 16, 24),
            children: [
              _LiveStatusRow(
                phaseLabel: _eventPhaseLabel(event),
                phaseTone: _eventPhaseTone(lifecycleStatus),
                showPhase: !showRoundCommandCenter &&
                    (lifecycleStatus != EventLifecycleStatus.active ||
                        event.scoringOpen),
                showOperationalFlags:
                    lifecycleStatus == EventLifecycleStatus.active,
                checkinOpen: event.checkinOpen,
                scoringOpen: event.scoringOpen,
              ),
              const SizedBox(height: 14),
              if (showQualificationSetup)
                _QualificationSetupMetricsRow(
                  guestCount: _controller.guestCount,
                  checkedInCount: _controller.checkedInGuestCount,
                  qualifyingCount: _controller.qualifyingGuestCount,
                  qualifiedCount: _controller.qualifiedGuestCount,
                  onGuests: _openGuests,
                  onQualifying: _openGuests,
                  onQualified: _openGuests,
                )
              else
                _LiveMetricsRow(
                  guestCount: _controller.guestCount,
                  tableCount: _controller.tableCount,
                  prizePoolLabel: _formatPrizePoolValue(
                    _controller.prizePoolCents,
                  ),
                  leaderLabel: _controller.leaderLabel,
                  onGuests: _openGuests,
                  onTables: _openTables,
                  onPrizes: _openPrizes,
                  canOpenPrizes: _controller.canManageEvent,
                  onLeaderboard: _openLeaderboard,
                ),
              if (_controller.bonusRoundResults.hasResults) ...[
                const SizedBox(height: 12),
                _BonusRoundResultsPanel(summary: _controller.bonusRoundResults),
              ],
              const SizedBox(height: 16),
              if (showRoundCommandCenter)
                _TournamentRoundCommandCenter(
                  scoringPhase: scoringPhase,
                  summary: showFinalsCommandCenter
                      ? _controller.finalsRoundSummary
                      : _controller.tournamentRoundSummary,
                  suddenDeathStatus: showFinalsCommandCenter
                      ? _controller.bonusRoundResults.suddenDeathStatus
                      : null,
                  isBusy: _controller.isSubmittingLifecycle,
                  onOpenTables: _openTables,
                  onStartNextRound: _startNextTournamentRound,
                  onGenerateRound: _startNextTournamentRound,
                  onBeginFinals: _openBonusRound,
                )
              else
                HeroActionButton(
                  label: _primaryActionLabel(event),
                  icon: _primaryActionIcon(event),
                  enabled: _primaryActionEnabled(event, canScanTables),
                  isBusy: _primaryActionIsBusy(event),
                  onPressed: _primaryActionCallback(event),
                ),
              if (showTableScanAction && !event.scoringOpen) ...[
                const SizedBox(height: 10),
                WideSecondaryButton(
                  icon: Icons.nfc,
                  label: _isTableScanInProgress ? 'Scanning' : 'Scan Table',
                  onPressed: _isTableScanInProgress ? null : _scanTable,
                ),
              ],
              if (_controller.tableScanError case final tableScanError?) ...[
                const SizedBox(height: 12),
                InlineErrorBanner(message: tableScanError),
              ],
              if (_controller.lifecycleError case final lifecycleError?) ...[
                const SizedBox(height: 12),
                InlineErrorBanner(
                  message: _formatLifecycleError(lifecycleError),
                ),
              ],
              if (showLiveNavigation) const SizedBox(height: 14),
              if (_controller.canManageEvent &&
                  lifecycleStatus == EventLifecycleStatus.active) ...[
                _LiveOperationsStrip(
                  isSubmitting: _controller.isSubmittingLifecycle,
                  scoringOpen: event.scoringOpen,
                  title: showQualificationSetup
                      ? 'Qualification'
                      : 'Live Operations',
                  openMessage: event.currentScoringPhase ==
                          EventScoringPhase.qualification
                      ? 'Qualification scoring is open for hosts.'
                      : 'Scoring and check-in are open for hosts.',
                  closedMessage: showQualificationSetup
                      ? 'Start qualification when hosts are ready to log open-play games.'
                      : 'Open scoring when hosts are ready to start rounds.',
                  primaryActionLabel: event.currentScoringPhase ==
                              EventScoringPhase.qualification &&
                          event.scoringOpen
                      ? 'Start Tournament'
                      : null,
                  onPrimaryAction: event.currentScoringPhase ==
                              EventScoringPhase.qualification &&
                          event.scoringOpen
                      ? _startTournament
                      : null,
                  onToggleScoring: event.scoringOpen
                      ? () => _controller.setOperationalFlags(
                            checkinOpen: event.checkinOpen,
                            scoringOpen: false,
                          )
                      : null,
                ),
                const SizedBox(height: 18),
              ],
              if (lifecycleStatus != EventLifecycleStatus.active) ...[
                const SizedBox(height: 12),
                InfoPanel(
                  message: _formatLifecycleMessage(lifecycleStatus),
                ),
                const SizedBox(height: 18),
              ],
              _EventOptionsSection(
                lifecycleStatus: lifecycleStatus,
                isSubmitting: _controller.isSubmittingLifecycle,
                canManageEvent: _controller.canManageEvent,
                canManageStaff: _controller.canManageStaff,
                onSeating: _openSeating,
                onStaff: _openStaff,
                onActivity: _openActivity,
                onHandLedger: _openHandLedger,
                onCopy: _confirmCopyEventForTesting,
                onDelete: _confirmDeleteEvent,
                onComplete: () => _controller.completeEvent(),
                onFinalize: () => _controller.finalizeEvent(),
                onRevert: _confirmRevertToDraft,
                onCancel: _confirmCancelEvent,
              ),
              if (lifecycleStatus == EventLifecycleStatus.active) ...[
                const SizedBox(height: 14),
                if (event.currentScoringPhase ==
                    EventScoringPhase.qualification)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openLeaderboard(
                        initialQualificationTab: true,
                      ),
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('View Qualification Standings'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _primaryActionLabel(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => 'Open Check-In',
      EventLifecycleStatus.active when event.scoringOpen => 'Scan Table',
      EventLifecycleStatus.active
          when _usesQualificationSetupDashboard(event) =>
        'Start Qualification',
      EventLifecycleStatus.active => 'Open Scoring',
      EventLifecycleStatus.completed => 'Finalize Event',
      EventLifecycleStatus.finalized => 'View Leaderboard',
      EventLifecycleStatus.cancelled => 'View Activity',
    };
  }

  IconData _primaryActionIcon(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => Icons.how_to_reg,
      EventLifecycleStatus.active when event.scoringOpen => Icons.nfc,
      EventLifecycleStatus.active
          when _usesQualificationSetupDashboard(event) =>
        Icons.play_arrow,
      EventLifecycleStatus.active => Icons.play_arrow,
      EventLifecycleStatus.completed => Icons.verified,
      EventLifecycleStatus.finalized => Icons.leaderboard,
      EventLifecycleStatus.cancelled => Icons.history,
    };
  }

  bool _primaryActionEnabled(EventRecord event, bool canScanTables) {
    if (_controller.isSubmittingLifecycle) {
      return false;
    }

    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => true,
      EventLifecycleStatus.active when event.scoringOpen => canScanTables &&
          _canScorePhase(
              _controller.effectiveScoringPhase ?? event.currentScoringPhase) &&
          !_isTableScanInProgress,
      EventLifecycleStatus.active => _controller.canManageEvent,
      EventLifecycleStatus.completed => true,
      EventLifecycleStatus.finalized => true,
      EventLifecycleStatus.cancelled => true,
    };
  }

  bool _primaryActionIsBusy(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.active when event.scoringOpen =>
        _isTableScanInProgress,
      _ => _controller.isSubmittingLifecycle,
    };
  }

  VoidCallback _primaryActionCallback(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => () => _controller.startEvent(),
      EventLifecycleStatus.active when event.scoringOpen => _scanTable,
      EventLifecycleStatus.active => () => _controller.setOperationalFlags(
            checkinOpen: event.checkinOpen,
            scoringOpen: true,
          ),
      EventLifecycleStatus.completed => () => _controller.finalizeEvent(),
      EventLifecycleStatus.finalized => () => _openLeaderboard(),
      EventLifecycleStatus.cancelled => _openActivity,
    };
  }

  bool _usesQualificationSetupDashboard(EventRecord event) {
    return event.lifecycleStatus == EventLifecycleStatus.active &&
        !event.scoringOpen &&
        event.currentScoringPhase == EventScoringPhase.qualification;
  }

  bool _canScorePhase(EventScoringPhase phase) {
    return switch (phase) {
      EventScoringPhase.qualification => _controller.canScoreQualification,
      EventScoringPhase.tournament => _controller.canScoreTournament,
      EventScoringPhase.bonus => _controller.canScoreBonus,
    };
  }
}

class _TournamentRoundCommandCenter extends StatelessWidget {
  const _TournamentRoundCommandCenter({
    required this.scoringPhase,
    required this.summary,
    this.suddenDeathStatus,
    required this.isBusy,
    required this.onOpenTables,
    required this.onStartNextRound,
    required this.onGenerateRound,
    required this.onBeginFinals,
  });

  final EventScoringPhase scoringPhase;
  final TournamentRoundSummary summary;
  final BonusRoundSuddenDeathStatus? suddenDeathStatus;
  final bool isBusy;
  final VoidCallback onOpenTables;
  final VoidCallback onStartNextRound;
  final VoidCallback onGenerateRound;
  final VoidCallback onBeginFinals;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final round = summary.round;
    final isFinals = scoringPhase == EventScoringPhase.bonus;
    final pendingSuddenDeath = isFinals ? suddenDeathStatus : null;
    final title = isFinals
        ? 'Finals'
        : round == null
            ? 'Tournament Round'
            : 'Round ${round.roundNumber}';
    final tableNoun = isFinals ? 'finals tables' : 'tables';
    final progress = round == null
        ? isFinals
            ? 'No finals tables assigned'
            : 'No tournament round generated'
        : '${summary.completeTableCount} of ${summary.assignedTableCount} $tableNoun complete';
    final remainingTables = summary.activeTableCount +
        summary.pausedTableCount +
        summary.notStartedTableCount;
    final detail = pendingSuddenDeath?.detailLabel ??
        (isFinals
            ? _finalsDetail(round)
            : round == null
                ? 'Generate a round to assign players.'
                : summary.isComplete
                    ? 'Ready to start next round'
                    : '$remainingTables ${remainingTables == 1 ? 'table' : 'tables'} still in progress');
    final actionLabel = isFinals
        ? 'Open Finals Tables'
        : round == null
            ? 'Generate Tournament Round'
            : summary.isComplete
                ? 'Start Next Round'
                : 'Open Tables';
    final actionIcon = isFinals
        ? Icons.table_bar
        : round == null
            ? Icons.shuffle
            : summary.isComplete
                ? Icons.skip_next
                : Icons.table_bar;
    final callback = isFinals
        ? onOpenTables
        : round == null
            ? onGenerateRound
            : summary.isComplete
                ? onStartNextRound
                : onOpenTables;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(
            label: pendingSuddenDeath == null
                ? isFinals
                    ? 'Finals Live'
                    : 'Tournament Live'
                : _suddenDeathCommandLabel(pendingSuddenDeath),
            tone: StatusChipTone.success,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            progress,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : callback,
              icon: Icon(actionIcon),
              label: Text(actionLabel),
            ),
          ),
          if (!isFinals && round != null && summary.isComplete) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isBusy ? null : onBeginFinals,
                icon: const Icon(Icons.emoji_events),
                label: const Text('Begin Finals'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _finalsDetail(TournamentRoundRecord? round) {
    if (round == null) {
      return 'Open finals tables to review seating.';
    }
    if (summary.isComplete) {
      return 'Ready to complete event';
    }

    final parts = <String>[
      if (summary.activeTableCount > 0)
        _pluralize(summary.activeTableCount, 'finals table', 'in progress'),
      if (summary.pausedTableCount > 0)
        _pluralize(summary.pausedTableCount, 'finals table', 'paused'),
      if (summary.notStartedTableCount > 0)
        _pluralize(summary.notStartedTableCount, 'finals table', 'not started'),
    ];
    if (parts.isEmpty) {
      return 'Finals tables still in progress';
    }
    return parts.join(' • ');
  }

  String _pluralize(int count, String noun, String suffix) {
    return '$count $noun${count == 1 ? '' : 's'} $suffix';
  }

  String _suddenDeathCommandLabel(BonusRoundSuddenDeathStatus status) {
    return switch (status.statusLabel) {
      'Sudden death required' => 'Sudden Death Required',
      'Sudden death active' => 'Sudden Death Active',
      _ => status.statusLabel,
    };
  }
}

class _BonusRoundResultsPanel extends StatelessWidget {
  const _BonusRoundResultsPanel({required this.summary});

  final BonusRoundResultsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bonus Round Results',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 10),
          if (summary.suddenDeathStatus != null)
            _BonusRoundPendingLine(status: summary.suddenDeathStatus!),
          if (summary.suddenDeathStatus != null &&
              (summary.finalChampion != null ||
                  summary.redemptionWinner != null))
            const SizedBox(height: 10),
          if (summary.finalChampion != null)
            _BonusRoundResultLine(
              icon: Icons.emoji_events,
              label: 'Final champion',
              result: summary.finalChampion!,
            ),
          if (summary.finalChampion != null && summary.redemptionWinner != null)
            const SizedBox(height: 10),
          if (summary.redemptionWinner != null)
            _BonusRoundResultLine(
              icon: Icons.replay_circle_filled,
              label: 'Redemption winner',
              result: summary.redemptionWinner!,
            ),
        ],
      ),
    );
  }
}

class _BonusRoundPendingLine extends StatelessWidget {
  const _BonusRoundPendingLine({required this.status});

  final BonusRoundSuddenDeathStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.gavel, size: 20, color: colorScheme.tertiary),
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
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
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
        Icon(icon, size: 20, color: colorScheme.tertiary),
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

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({
    required this.phaseLabel,
    required this.phaseTone,
    required this.showPhase,
    required this.showOperationalFlags,
    required this.checkinOpen,
    required this.scoringOpen,
  });

  final String phaseLabel;
  final StatusChipTone phaseTone;
  final bool showPhase;
  final bool showOperationalFlags;
  final bool checkinOpen;
  final bool scoringOpen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showPhase) StatusChip(label: phaseLabel, tone: phaseTone),
        if (showOperationalFlags) ...[
          StatusChip(
            label: scoringOpen ? 'Scoring Open' : 'Scoring Not Open',
            tone: scoringOpen ? StatusChipTone.success : StatusChipTone.warning,
          ),
          StatusChip(
            label: checkinOpen ? 'Check-In Open' : 'Check-In Not Open',
            tone: checkinOpen ? StatusChipTone.success : StatusChipTone.warning,
          ),
        ],
      ],
    );
  }
}

class _LiveMetricsRow extends StatelessWidget {
  const _LiveMetricsRow({
    required this.guestCount,
    required this.tableCount,
    required this.prizePoolLabel,
    required this.leaderLabel,
    required this.onGuests,
    required this.onTables,
    required this.onPrizes,
    required this.canOpenPrizes,
    required this.onLeaderboard,
  });

  final int guestCount;
  final int tableCount;
  final String prizePoolLabel;
  final String leaderLabel;
  final VoidCallback onGuests;
  final VoidCallback onTables;
  final VoidCallback onPrizes;
  final bool canOpenPrizes;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Guests',
                value: guestCount.toString(),
                onTap: onGuests,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Tables',
                value: tableCount.toString(),
                onTap: onTables,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Prize Pool',
                value: prizePoolLabel,
                onTap: canOpenPrizes ? onPrizes : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Leader',
                value: leaderLabel,
                onTap: onLeaderboard,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QualificationSetupMetricsRow extends StatelessWidget {
  const _QualificationSetupMetricsRow({
    required this.guestCount,
    required this.checkedInCount,
    required this.qualifyingCount,
    required this.qualifiedCount,
    required this.onGuests,
    required this.onQualifying,
    required this.onQualified,
  });

  final int guestCount;
  final int checkedInCount;
  final int qualifyingCount;
  final int qualifiedCount;
  final VoidCallback onGuests;
  final VoidCallback onQualifying;
  final VoidCallback onQualified;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Guests',
                value: guestCount.toString(),
                onTap: onGuests,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Checked In',
                value: checkedInCount.toString(),
                onTap: onGuests,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                label: 'Qualifying',
                value: qualifyingCount.toString(),
                onTap: onQualifying,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: 'Qualified',
                value: qualifiedCount.toString(),
                onTap: onQualified,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LiveOperationsStrip extends StatelessWidget {
  const _LiveOperationsStrip({
    required this.isSubmitting,
    required this.scoringOpen,
    required this.title,
    required this.openMessage,
    required this.closedMessage,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    required this.onToggleScoring,
  });

  final bool isSubmitting;
  final bool scoringOpen;
  final String title;
  final String openMessage;
  final String closedMessage;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final VoidCallback? onToggleScoring;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoringOpen ? openMessage : closedMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (primaryActionLabel != null)
                FilledButton(
                  onPressed: isSubmitting ? null : onPrimaryAction,
                  child: Text(primaryActionLabel!),
                ),
              if (primaryActionLabel != null && scoringOpen)
                const SizedBox(height: 8),
              if (scoringOpen)
                OutlinedButton(
                  onPressed: isSubmitting ? null : onToggleScoring,
                  child: const Text('Pause Scoring'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EventOptionsSection extends StatelessWidget {
  const _EventOptionsSection({
    required this.lifecycleStatus,
    required this.isSubmitting,
    required this.canManageEvent,
    required this.canManageStaff,
    required this.onSeating,
    required this.onStaff,
    required this.onActivity,
    required this.onHandLedger,
    required this.onCopy,
    required this.onDelete,
    required this.onComplete,
    required this.onFinalize,
    required this.onRevert,
    required this.onCancel,
  });

  final EventLifecycleStatus lifecycleStatus;
  final bool isSubmitting;
  final bool canManageEvent;
  final bool canManageStaff;
  final VoidCallback onSeating;
  final VoidCallback onStaff;
  final VoidCallback onActivity;
  final VoidCallback onHandLedger;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onFinalize;
  final VoidCallback onRevert;
  final VoidCallback onCancel;

  bool get _showsSeatingPrepAction {
    return switch (lifecycleStatus) {
      EventLifecycleStatus.draft || EventLifecycleStatus.completed => true,
      EventLifecycleStatus.active ||
      EventLifecycleStatus.finalized ||
      EventLifecycleStatus.cancelled =>
        false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event options',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (canManageEvent && _showsSeatingPrepAction)
              UtilityActionButton(label: 'Seating', onPressed: onSeating),
            if (canManageStaff)
              UtilityActionButton(label: 'Staff', onPressed: onStaff),
            UtilityActionButton(label: 'Activity', onPressed: onActivity),
            UtilityActionButton(
              label: 'Hand Ledger',
              onPressed: onHandLedger,
            ),
            if (canManageEvent)
              UtilityActionButton(
                label: 'Copy Event',
                onPressed: isSubmitting ? null : onCopy,
              ),
            if (canManageEvent && lifecycleStatus == EventLifecycleStatus.draft)
              UtilityActionButton(
                label: 'Delete Event',
                onPressed: isSubmitting ? null : onDelete,
                isDanger: true,
              ),
            if (canManageEvent &&
                lifecycleStatus == EventLifecycleStatus.active) ...[
              UtilityActionButton(
                label: 'Complete Event',
                onPressed: isSubmitting ? null : onComplete,
              ),
              UtilityActionButton(
                label: 'Revert to Draft',
                onPressed: isSubmitting ? null : onRevert,
              ),
              UtilityActionButton(
                label: 'Cancel Event',
                onPressed: isSubmitting ? null : onCancel,
                isDanger: true,
              ),
            ],
            if (canManageEvent &&
                lifecycleStatus == EventLifecycleStatus.completed) ...[
              UtilityActionButton(
                label: 'Cancel Event',
                onPressed: isSubmitting ? null : onCancel,
                isDanger: true,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
