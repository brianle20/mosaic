import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_list_controller.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({
    super.key,
    required this.eventRepository,
    this.onSignOut,
  });

  final EventRepository eventRepository;
  final Future<void> Function()? onSignOut;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  late final EventListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = EventListController(eventRepository: widget.eventRepository)
      ..addListener(_handleUpdate)
      ..load();
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

  Future<void> _openCreateEvent() async {
    await Navigator.of(context).pushNamed(AppRouter.createEventRoute);
    if (!mounted) {
      return;
    }

    await _controller.load();
  }

  Future<void> _openEvent(EventRecord event) async {
    await Navigator.of(context).pushNamed(
      AppRouter.eventDashboardRoute,
      arguments: EventDashboardArgs(eventId: event.id),
    );
    if (!mounted) {
      return;
    }

    await _controller.load();
  }

  Future<void> _signOut() async {
    await widget.onSignOut?.call();
  }

  String _eventPhaseLabel(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => 'Setup',
      EventLifecycleStatus.active when event.scoringOpen => 'Scoring Open',
      EventLifecycleStatus.active when event.checkinOpen => 'Check-In Open',
      EventLifecycleStatus.active => 'Active',
      EventLifecycleStatus.completed => 'Completed',
      EventLifecycleStatus.finalized => 'Finalized',
      EventLifecycleStatus.cancelled => 'Cancelled',
    };
  }

  StatusChipTone _eventPhaseTone(EventRecord event) {
    return switch (event.lifecycleStatus) {
      EventLifecycleStatus.draft => StatusChipTone.warning,
      EventLifecycleStatus.active when event.scoringOpen => StatusChipTone.info,
      EventLifecycleStatus.active => StatusChipTone.success,
      EventLifecycleStatus.completed => StatusChipTone.warning,
      EventLifecycleStatus.finalized => StatusChipTone.neutral,
      EventLifecycleStatus.cancelled => StatusChipTone.danger,
    };
  }

  String? _eventLocation(EventRecord event) {
    final venueName = event.venueName?.trim();
    if (venueName != null && venueName.isNotEmpty) {
      return venueName;
    }

    final venueAddress = event.venueAddress?.trim();
    if (venueAddress != null && venueAddress.isNotEmpty) {
      return venueAddress;
    }

    return null;
  }

  Widget _buildEventCard(EventRecord event) {
    final location = _eventLocation(event);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEvent(event),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                    label: _eventPhaseLabel(event),
                    tone: _eventPhaseTone(event),
                  ),
                  Text(
                    formatEventTileStart(
                      event.startsAt,
                      timezone: event.timezone,
                    ),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (location != null) ...[
                const SizedBox(height: 2),
                Text(
                  location,
                  style: textTheme.bodyMedium?.copyWith(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          if (widget.onSignOut != null)
            TextButton(
              onPressed: _signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: _controller.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openCreateEvent,
                icon: const Icon(Icons.add),
                label: const Text('Create Event'),
              ),
            ),
            const SizedBox(height: 16),
            for (final event in _controller.events) _buildEventCard(event),
            if (_controller.events.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.event_note,
                  title: 'No events yet',
                  message:
                      'Create your first event to start check-in, seating, scoring, and prizes.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
