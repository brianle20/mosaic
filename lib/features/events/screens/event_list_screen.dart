import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/events/controllers/event_list_controller.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({
    super.key,
    required this.eventRepository,
  });

  final EventRepository eventRepository;

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

  void _openCreateEvent() {
    Navigator.of(context).pushNamed(AppRouter.createEventRoute);
  }

  void _openEvent(EventRecord event) {
    Navigator.of(context).pushNamed(
      AppRouter.eventDashboardRoute,
      arguments: EventDashboardArgs(eventId: event.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
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
            for (final event in _controller.events)
              Card(
                child: ListTile(
                  title: Text(event.title),
                  subtitle: Text(
                    '${event.timezone} • ${event.lifecycleStatus.name}',
                  ),
                  onTap: () => _openEvent(event),
                ),
              ),
            if (_controller.events.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No events yet.'),
              ),
          ],
        ),
      ),
    );
  }
}
