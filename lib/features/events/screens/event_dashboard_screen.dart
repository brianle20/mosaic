import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';
import 'package:mosaic/widgets/status_chip.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({
    super.key,
    required this.args,
    required this.eventRepository,
    required this.guestRepository,
    required this.leaderboardRepository,
  });

  final EventDashboardArgs args;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;
  final LeaderboardRepository leaderboardRepository;

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
      ),
    );
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

  void _openPrizes() {
    final event = _controller.event;
    if (event == null) {
      return;
    }

    Navigator.of(context).pushNamed(
      AppRouter.prizePlanRoute,
      arguments: PrizePlanArgs(
        eventId: event.id,
        prizeBudgetCents: event.prizeBudgetCents,
      ),
    );
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

  String _eventPhaseLabel(EventLifecycleStatus? status) {
    return switch (status) {
      EventLifecycleStatus.draft => 'Ready to Start',
      EventLifecycleStatus.active => 'Live Event',
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

  String _formatLifecycleMessage(EventLifecycleStatus? lifecycleStatus) {
    return switch (lifecycleStatus) {
      EventLifecycleStatus.draft =>
        'Finish setup, then start the event to open check-in.',
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

  @override
  Widget build(BuildContext context) {
    final event = _controller.event;
    final lifecycleStatus = event?.lifecycleStatus;
    final showLiveActions = lifecycleStatus != null &&
        lifecycleStatus != EventLifecycleStatus.completed &&
        lifecycleStatus != EventLifecycleStatus.finalized &&
        lifecycleStatus != EventLifecycleStatus.cancelled;
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
              label: _eventPhaseLabel(lifecycleStatus),
              tone: _eventPhaseTone(lifecycleStatus),
            ),
            const SizedBox(height: 8),
            Text('Guests: ${_controller.guestCount}'),
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
            const SizedBox(height: 20),
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
                    child: const Text('Start Event'),
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
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _controller.isSubmittingLifecycle
                            ? null
                            : () => _controller.setOperationalFlags(
                                  checkinOpen: !event.checkinOpen,
                                  scoringOpen: event.scoringOpen,
                                ),
                        child: Text(
                          event.checkinOpen
                              ? 'Close Check-In'
                              : 'Open Check-In',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _controller.isSubmittingLifecycle
                            ? null
                            : () => _controller.setOperationalFlags(
                                  checkinOpen: event.checkinOpen,
                                  scoringOpen: !event.scoringOpen,
                                ),
                        child: Text(
                          event.scoringOpen ? 'Close Scoring' : 'Open Scoring',
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
}
