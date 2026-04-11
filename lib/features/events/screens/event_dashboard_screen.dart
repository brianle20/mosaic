import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_dashboard_controller.dart';

class EventDashboardScreen extends StatefulWidget {
  const EventDashboardScreen({
    super.key,
    required this.args,
    required this.eventRepository,
    required this.guestRepository,
  });

  final EventDashboardArgs args;
  final EventRepository eventRepository;
  final GuestRepository guestRepository;

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

  @override
  Widget build(BuildContext context) {
    final event = _controller.event;
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
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: _openGuests,
                  child: const Text('Guests'),
                ),
                OutlinedButton(
                  onPressed: _openGuests,
                  child: const Text('Add Guest'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Check-in, tables, sessions, scoring, and prizes will land in later slices.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
