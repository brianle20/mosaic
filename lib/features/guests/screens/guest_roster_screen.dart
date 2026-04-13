import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';
import 'package:mosaic/widgets/status_chip.dart';

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

  Future<void> _openGuestDetail(EventGuestRecord guest) async {
    await Navigator.of(context).pushNamed(
      AppRouter.guestDetailRoute,
      arguments: GuestDetailArgs(
        eventId: widget.eventId,
        guestId: guest.id,
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
                  key: ValueKey('guest-row-${guest.id}'),
                  title: Text(guest.displayName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          StatusChip(
                            label: _coverStatusLabel(guest.coverStatus),
                            tone: _coverStatusTone(guest.coverStatus),
                          ),
                          StatusChip(
                            label: _attendanceLabel(guest.attendanceStatus),
                            tone: guest.isCheckedIn
                                ? StatusChipTone.success
                                : StatusChipTone.neutral,
                          ),
                          StatusChip(
                            label: _controller.activeTagAssignments
                                    .containsKey(guest.id)
                                ? 'Tag Assigned'
                                : 'Tag Unassigned',
                            tone: _controller.activeTagAssignments
                                    .containsKey(guest.id)
                                ? StatusChipTone.success
                                : StatusChipTone.warning,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _rowSummary(guest),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  onTap: () => _openGuestDetail(guest),
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

  String _attendanceLabel(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.expected => 'Expected',
      AttendanceStatus.checkedIn => 'Checked In',
      AttendanceStatus.checkedOut => 'Checked Out',
      AttendanceStatus.noShow => 'No Show',
    };
  }

  String _coverStatusLabel(CoverStatus status) {
    return switch (status) {
      CoverStatus.unpaid => 'Unpaid',
      CoverStatus.paid => 'Paid',
      CoverStatus.partial => 'Partial',
      CoverStatus.comped => 'Comped',
      CoverStatus.refunded => 'Refunded',
    };
  }

  StatusChipTone _coverStatusTone(CoverStatus status) {
    return switch (status) {
      CoverStatus.paid => StatusChipTone.success,
      CoverStatus.comped => StatusChipTone.success,
      CoverStatus.partial => StatusChipTone.warning,
      CoverStatus.unpaid => StatusChipTone.warning,
      CoverStatus.refunded => StatusChipTone.neutral,
    };
  }

  String _rowSummary(EventGuestRecord guest) {
    final hasTag = _controller.activeTagAssignments.containsKey(guest.id);
    if (guest.isCheckedIn && guest.isEligibleForPlayerTagAssignment && hasTag) {
      return 'Ready to Play';
    }
    if (!guest.isEligibleForPlayerTagAssignment) {
      return 'Needs payment or comp before tag assignment';
    }
    if (!guest.isCheckedIn) {
      return 'Ready for check-in';
    }
    if (!hasTag) {
      return 'Needs player tag';
    }
    return 'Operational status available';
  }
}
