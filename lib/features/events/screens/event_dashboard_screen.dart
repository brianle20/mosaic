import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';
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
    this.nfcService,
  });

  final EventDashboardArgs args;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final LeaderboardRepository leaderboardRepository;
  final PrizeRepository? prizeRepository;
  final TableRepository? tableRepository;
  final SessionRepository? sessionRepository;
  final NfcService? nfcService;

  @override
  State<EventDashboardScreen> createState() => _EventDashboardScreenState();
}

class _EventDashboardScreenState extends State<EventDashboardScreen> {
  late final EventDashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventDashboardController(
      eventRepository: widget.eventRepository,
      guestRepository: widget.guestRepository,
      prizeRepository: widget.prizeRepository,
      tableRepository: widget.tableRepository,
      sessionRepository: widget.sessionRepository,
    )
      ..addListener(_handleUpdate)
      ..load(widget.args.eventId);
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

  void _openGuests() {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.guestRosterRoute,
      arguments: GuestRosterArgs(
        eventId: event.id,
        eventTitle: event.title,
        eventCoverChargeCents: event.coverChargeCents,
      ),
    );
  }

  void _openTables() {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.tablesOverviewRoute,
      arguments: TablesOverviewArgs(
        eventId: event.id,
        eventTitle: event.title,
        scoringOpen: event.scoringOpen,
      ),
    );
  }

  Future<void> _scanTable() async {
    final nfcService = widget.nfcService;
    if (nfcService == null || _controller.isScanningTable) {
      return;
    }

    final scanResult = await nfcService.scanTableTag(context);
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
        Navigator.of(context).pushNamed(
          AppRouter.sessionDetailRoute,
          arguments: SessionDetailArgs(
            eventId: widget.args.eventId,
            sessionId: sessionId,
          ),
        );
      case DashboardTableScanStartSession(
          :final table,
          :final preverifiedTableTagUid,
        ):
        Navigator.of(context).pushNamed(
          AppRouter.startSessionRoute,
          arguments: StartSessionArgs(
            eventId: widget.args.eventId,
            table: table,
            preverifiedTableTagUid: preverifiedTableTagUid,
          ),
        );
    }
  }

  void _openLeaderboard() {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.leaderboardRoute,
      arguments: LeaderboardArgs(eventId: event.id),
    );
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

    if (!mounted) {
      return;
    }

    await _controller.load(event.id);
  }

  void _openActivity() {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.activityRoute,
      arguments: ActivityArgs(eventId: event.id),
    );
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
  }

  String _flagStatusLabel(bool isOpen) => isOpen ? 'Open' : 'Closed';

  String _eventPhaseLabel(EventRecord? event) {
    return switch (event?.lifecycleStatus) {
      EventLifecycleStatus.draft => 'Setup',
      EventLifecycleStatus.active when event?.scoringOpen == true =>
        'Scoring Open',
      EventLifecycleStatus.active when event?.checkinOpen == true =>
        'Check-In Open',
      EventLifecycleStatus.active => 'Active',
      EventLifecycleStatus.completed => 'Review Before Finalizing',
      EventLifecycleStatus.finalized => 'Results Locked',
      EventLifecycleStatus.cancelled => 'Cancelled',
      null => 'Loading Event',
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
        lifecycleStatus != EventLifecycleStatus.completed &&
        lifecycleStatus != EventLifecycleStatus.finalized &&
        lifecycleStatus != EventLifecycleStatus.cancelled;
    final canScanTables = widget.tableRepository != null &&
        widget.sessionRepository != null &&
        widget.nfcService != null;
    final showTableScanAction =
        lifecycleStatus == EventLifecycleStatus.active && canScanTables;
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
                    onPressed: _controller.isScanningTable ? null : _scanTable,
                    child: Text(
                      _controller.isScanningTable
                          ? 'Scanning...'
                          : 'Scan Table',
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
                FilledButton(
                  onPressed: _openPrizes,
                  child: const Text('Prizes'),
                ),
                if (showLiveActions)
                  OutlinedButton(
                    onPressed: _openGuests,
                    child: const Text('Add Guest'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.draft)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.startEvent(),
                    child: const Text('Open Check-In'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.active)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.completeEvent(),
                    child: const Text('Complete Event'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.completed)
                  FilledButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : () => _controller.finalizeEvent(),
                    child: const Text('Finalize Event'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.draft)
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmDeleteEvent,
                    child: const Text('Delete Event'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.active)
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmRevertToDraft,
                    child: const Text('Revert to Draft'),
                  ),
                if (lifecycleStatus == EventLifecycleStatus.active ||
                    lifecycleStatus == EventLifecycleStatus.completed)
                  OutlinedButton(
                    onPressed: _controller.isSubmittingLifecycle
                        ? null
                        : _confirmCancelEvent,
                    child: const Text('Cancel Event'),
                  ),
              ],
            ),
            if (lifecycleStatus == EventLifecycleStatus.active) ...[
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
                                ? 'Close Scoring'
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
    final canScanTables = widget.tableRepository != null &&
        widget.sessionRepository != null &&
        widget.nfcService != null;
    final lifecycleStatus = event.lifecycleStatus;
    final showTableScanAction =
        lifecycleStatus == EventLifecycleStatus.active && canScanTables;
    final showLiveNavigation =
        lifecycleStatus != EventLifecycleStatus.completed &&
            lifecycleStatus != EventLifecycleStatus.finalized &&
            lifecycleStatus != EventLifecycleStatus.cancelled;

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
            padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 12, 16, 24),
            children: [
              _LiveStatusRow(
                phaseLabel: _eventPhaseLabel(event),
                phaseTone: _eventPhaseTone(lifecycleStatus),
                showPhase: lifecycleStatus != EventLifecycleStatus.active,
                checkinOpen: event.checkinOpen,
                scoringOpen: event.scoringOpen,
              ),
              const SizedBox(height: 14),
              _LiveMetricsRow(
                guestCount: _controller.guestCount,
                prizePoolLabel: _formatPrizePoolValue(
                  _controller.prizePoolCents,
                ),
              ),
              const SizedBox(height: 16),
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
                  label:
                      _controller.isScanningTable ? 'Scanning' : 'Scan Table',
                  onPressed: _controller.isScanningTable ? null : _scanTable,
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
              const SizedBox(height: 14),
              if (showLiveNavigation) ...[
                _SecondaryLiveNavigation(
                  onGuests: _openGuests,
                  onTables: _openTables,
                  onLeaderboard: _openLeaderboard,
                ),
                const SizedBox(height: 16),
              ],
              if (lifecycleStatus == EventLifecycleStatus.active) ...[
                _LiveOperationsStrip(
                  isSubmitting: _controller.isSubmittingLifecycle,
                  scoringOpen: event.scoringOpen,
                  onToggleScoring: event.scoringOpen
                      ? () => _controller.setOperationalFlags(
                            checkinOpen: event.checkinOpen,
                            scoringOpen: false,
                          )
                      : null,
                ),
                const SizedBox(height: 18),
              ],
              InfoPanel(
                message: _formatLifecycleMessage(lifecycleStatus),
              ),
              const SizedBox(height: 18),
              _EventOptionsSection(
                lifecycleStatus: lifecycleStatus,
                isSubmitting: _controller.isSubmittingLifecycle,
                onActivity: _openActivity,
                onPrizes: _openPrizes,
                onDelete: _confirmDeleteEvent,
                onComplete: () => _controller.completeEvent(),
                onFinalize: () => _controller.finalizeEvent(),
                onRevert: _confirmRevertToDraft,
                onCancel: _confirmCancelEvent,
              ),
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
      EventLifecycleStatus.active when event.scoringOpen =>
        canScanTables && !_controller.isScanningTable,
      EventLifecycleStatus.active => true,
      EventLifecycleStatus.completed => true,
      EventLifecycleStatus.finalized => true,
      EventLifecycleStatus.cancelled => true,
    };
  }

  bool _primaryActionIsBusy(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.active when event.scoringOpen =>
        _controller.isScanningTable,
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
      EventLifecycleStatus.finalized => _openLeaderboard,
      EventLifecycleStatus.cancelled => _openActivity,
    };
  }
}

class _LiveStatusRow extends StatelessWidget {
  const _LiveStatusRow({
    required this.phaseLabel,
    required this.phaseTone,
    required this.showPhase,
    required this.checkinOpen,
    required this.scoringOpen,
  });

  final String phaseLabel;
  final StatusChipTone phaseTone;
  final bool showPhase;
  final bool checkinOpen;
  final bool scoringOpen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showPhase) StatusChip(label: phaseLabel, tone: phaseTone),
        StatusChip(
          label: scoringOpen ? 'Scoring Open' : 'Scoring Closed',
          tone: scoringOpen ? StatusChipTone.success : StatusChipTone.warning,
        ),
        StatusChip(
          label: checkinOpen ? 'Check-In Open' : 'Check-In Closed',
          tone: checkinOpen ? StatusChipTone.success : StatusChipTone.warning,
        ),
      ],
    );
  }
}

class _LiveMetricsRow extends StatelessWidget {
  const _LiveMetricsRow({
    required this.guestCount,
    required this.prizePoolLabel,
  });

  final int guestCount;
  final String prizePoolLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricTile(
            label: 'Guests',
            value: guestCount.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MetricTile(
            label: 'Prize Pool',
            value: prizePoolLabel,
          ),
        ),
      ],
    );
  }
}

class _SecondaryLiveNavigation extends StatelessWidget {
  const _SecondaryLiveNavigation({
    required this.onGuests,
    required this.onTables,
    required this.onLeaderboard,
  });

  final VoidCallback onGuests;
  final VoidCallback onTables;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _LiveNavButton(label: 'Guests', onPressed: onGuests),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LiveNavButton(label: 'Tables', onPressed: onTables),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LiveNavButton(
            label: 'Leaderboard',
            onPressed: onLeaderboard,
          ),
        ),
      ],
    );
  }
}

class _LiveNavButton extends StatelessWidget {
  const _LiveNavButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: FittedBox(child: Text(label)),
      ),
    );
  }
}

class _LiveOperationsStrip extends StatelessWidget {
  const _LiveOperationsStrip({
    required this.isSubmitting,
    required this.scoringOpen,
    required this.onToggleScoring,
  });

  final bool isSubmitting;
  final bool scoringOpen;
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
                  'Live Operations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  scoringOpen
                      ? 'Scoring and check-in are open for hosts.'
                      : 'Open scoring when hosts are ready to start rounds.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (scoringOpen)
            OutlinedButton(
              onPressed: isSubmitting ? null : onToggleScoring,
              child: const Text('Close Scoring'),
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
    required this.onActivity,
    required this.onPrizes,
    required this.onDelete,
    required this.onComplete,
    required this.onFinalize,
    required this.onRevert,
    required this.onCancel,
  });

  final EventLifecycleStatus lifecycleStatus;
  final bool isSubmitting;
  final VoidCallback onActivity;
  final VoidCallback onPrizes;
  final VoidCallback onDelete;
  final VoidCallback onComplete;
  final VoidCallback onFinalize;
  final VoidCallback onRevert;
  final VoidCallback onCancel;

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
            UtilityActionButton(label: 'Activity', onPressed: onActivity),
            UtilityActionButton(label: 'Prizes', onPressed: onPrizes),
            if (lifecycleStatus == EventLifecycleStatus.draft)
              UtilityActionButton(
                label: 'Delete Event',
                onPressed: isSubmitting ? null : onDelete,
                isDanger: true,
              ),
            if (lifecycleStatus == EventLifecycleStatus.active) ...[
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
            if (lifecycleStatus == EventLifecycleStatus.completed) ...[
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
