import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/auth_models.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_list_controller.dart';
import 'package:mosaic/features/events/models/event_form_formatters.dart';
import 'package:mosaic/widgets/app_actions.dart';
import 'package:mosaic/widgets/app_chrome.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({
    super.key,
    required this.eventRepository,
    this.accessState,
    this.onSignOut,
  });

  final EventRepository eventRepository;
  final MosaicAccessState? accessState;
  final Future<void> Function()? onSignOut;

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  late EventListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController()..load();
  }

  @override
  void didUpdateWidget(covariant EventListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventRepository == widget.eventRepository &&
        oldWidget.accessState == widget.accessState) {
      return;
    }

    _controller
      ..removeListener(_handleUpdate)
      ..dispose();
    _controller = _createController()..load();
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

  EventListController _createController() {
    return EventListController(
      eventRepository: widget.eventRepository,
      accessState: widget.accessState,
    )..addListener(_handleUpdate);
  }

  Future<void> _openCreateEvent() async {
    await Navigator.of(context).pushNamed(AppRouter.createEventRoute);
    if (!mounted) {
      return;
    }

    await _controller.load();
  }

  Future<void> _openEvent(EventRecord event) async {
    final role = _controller.roleForEvent(event.id);
    if (role == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRouter.eventDashboardRoute,
      arguments: EventDashboardArgs(
        eventId: event.id,
        callerRole: role,
      ),
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
      EventLifecycleStatus.active when event.scoringOpen =>
        _activeScoringLabel(event.currentScoringPhase),
      EventLifecycleStatus.active when event.checkinOpen => 'Check-In Open',
      EventLifecycleStatus.active => 'Active',
      EventLifecycleStatus.completed => 'Completed',
      EventLifecycleStatus.finalized => 'Finalized',
      EventLifecycleStatus.cancelled => 'Cancelled',
    };
  }

  String _activeScoringLabel(EventScoringPhase phase) {
    return switch (phase) {
      EventScoringPhase.qualification => 'Tournament Live',
      EventScoringPhase.tournament => 'Tournament Live',
      EventScoringPhase.bonus => 'Finals Live',
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

  String _roleLabel(MosaicAccessRole role) {
    return switch (role) {
      MosaicAccessRole.owner => 'Owner',
      MosaicAccessRole.eventScorer => 'Event Scorer',
    };
  }

  Widget _buildEventCard(EventRecord event) {
    final location = _eventLocation(event);
    final role = _controller.roleForEvent(event.id);
    if (role == null) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppListSurface(
        key: ValueKey('eventRowSurface-${event.id}'),
        onTap: () => _openEvent(event),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  label: _eventPhaseLabel(event),
                  tone: _eventPhaseTone(event),
                ),
                StatusChip(
                  label: _roleLabel(role),
                  tone: role == MosaicAccessRole.owner
                      ? StatusChipTone.success
                      : StatusChipTone.info,
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
              const SizedBox(height: 6),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftHostScaffold(
      title: 'Events',
      actions: [
        if (widget.onSignOut != null)
          GlassCircleButton(
            visualKey: const ValueKey('eventsSignOutAction'),
            icon: Icons.logout,
            tooltip: 'Sign out',
            onPressed: _signOut,
          ),
      ],
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: _controller.load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_controller.canCreateEvents) ...[
              HeroActionButton(
                key: const ValueKey('eventsCreateHeroAction'),
                onPressed: _openCreateEvent,
                icon: Icons.add,
                label: 'Create Event',
              ),
              const SizedBox(height: 16),
            ],
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
