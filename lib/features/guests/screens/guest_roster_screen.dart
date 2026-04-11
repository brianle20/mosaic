import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';

class GuestRosterScreen extends StatefulWidget {
  const GuestRosterScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.guestRepository,
  });

  final String eventId;
  final String eventTitle;
  final GuestRepository guestRepository;

  @override
  State<GuestRosterScreen> createState() => _GuestRosterScreenState();
}

class _GuestRosterScreenState extends State<GuestRosterScreen> {
  late final GuestRosterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GuestRosterController(guestRepository: widget.guestRepository)
      ..addListener(_handleUpdate)
      ..load(widget.eventId);
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

  Future<void> _openAddGuest() async {
    await Navigator.of(context).pushNamed(
      AppRouter.guestFormRoute,
      arguments: GuestFormArgs(
        eventId: widget.eventId,
        existingGuests: _controller.guests,
      ),
    );
    await _controller.load(widget.eventId);
  }

  Future<void> _openEditGuest(EventGuestRecord guest) async {
    await Navigator.of(context).pushNamed(
      AppRouter.guestFormRoute,
      arguments: GuestFormArgs(
        eventId: widget.eventId,
        existingGuests: _controller.guests,
        initialGuest: guest,
      ),
    );
    await _controller.load(widget.eventId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guests')),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.eventId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: _openAddGuest,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Guest'),
            ),
            const SizedBox(height: 16),
            Text(widget.eventTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            for (final guest in _controller.guests)
              Card(
                child: ListTile(
                  title: Text(guest.displayName),
                  subtitle: Wrap(
                    spacing: 8,
                    children: [
                      Text(guest.coverStatus.name),
                      Text(guest.attendanceStatus.name),
                    ],
                  ),
                  onTap: () => _openEditGuest(guest),
                ),
              ),
            if (_controller.guests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('No guests yet.'),
              ),
          ],
        ),
      ),
    );
  }
}
