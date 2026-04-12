import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';

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

  String _flagStatusLabel(bool isOpen) => isOpen ? 'Open' : 'Closed';

  @override
  Widget build(BuildContext context) {
    final event = _controller.event;
    final lifecycleStatus = event?.lifecycleStatus;
    final showLiveActions = lifecycleStatus != null &&
        lifecycleStatus != EventLifecycleStatus.completed &&
        lifecycleStatus != EventLifecycleStatus.finalized;
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
            Text('Status: ${event?.lifecycleStatus.name ?? 'draft'}'),
            const SizedBox(height: 8),
            Text('Guests: ${_controller.guestCount}'),
            if (_controller.lifecycleError case final lifecycleError?)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(lifecycleError),
                  ),
                ),
              ),
            const SizedBox(height: 20),
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
                      Text('Check-In: ${_flagStatusLabel(event!.checkinOpen)}'),
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
                      const SizedBox(height: 16),
                      Text('Scoring: ${_flagStatusLabel(event.scoringOpen)}'),
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
                      const Text('This event is finalized.'),
                    Text(
                      switch (lifecycleStatus) {
                        EventLifecycleStatus.draft =>
                          'Finish setup, then start the event to open check-in.',
                        EventLifecycleStatus.active =>
                          'Use the live operations controls to open or close check-in and scoring during the event.',
                        EventLifecycleStatus.completed =>
                          'This event is completed. Review standings and prizes before finalizing.',
                        EventLifecycleStatus.finalized =>
                          'Standings and awards are locked.',
                        _ =>
                          'Check-in, tables, sessions, scoring, and prizes are available from the dashboard actions above.',
                      },
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
