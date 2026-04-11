import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/controllers/guest_check_in_controller.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';

class GuestDetailScreen extends StatefulWidget {
  const GuestDetailScreen({
    super.key,
    required this.guestId,
    required this.eventId,
    required this.guestRepository,
    required this.nfcService,
  });

  final String guestId;
  final String eventId;
  final GuestRepository guestRepository;
  final NfcService nfcService;

  @override
  State<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends State<GuestDetailScreen> {
  late final GuestCheckInController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        GuestCheckInController(guestRepository: widget.guestRepository)
          ..addListener(_handleUpdate)
          ..load(widget.guestId);
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

  @override
  Widget build(BuildContext context) {
    final detail = _controller.detail;
    final guest = detail?.guest;
    final assignment = detail?.activeTagAssignment;

    return Scaffold(
      appBar: AppBar(
        title: Text(guest?.displayName ?? 'Guest'),
      ),
      body: AsyncBody(
        isLoading: _controller.isLoading,
        error: _controller.error,
        onRetry: () => _controller.load(widget.guestId),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              guest?.displayName ?? 'Unknown Guest',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text('Attendance: ${guest?.attendanceStatus.name ?? 'expected'}'),
            const SizedBox(height: 8),
            Text('Cover: ${guest?.coverStatus.name ?? 'unpaid'}'),
            const SizedBox(height: 8),
            Text(assignment == null ? 'Tag Unassigned' : 'Tag Assigned'),
            if (assignment?.tag.displayLabel != null) ...[
              const SizedBox(height: 8),
              Text(assignment!.tag.displayLabel!),
            ],
            const SizedBox(height: 24),
            if (guest != null && !guest.isEligibleForPlayerTagAssignment)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Guests must be paid or comped before receiving a player tag.',
                  ),
                ),
              ),
            if (guest != null && guest.isEligibleForPlayerTagAssignment) ...[
              if (!guest.isCheckedIn && assignment == null)
                FilledButton(
                  onPressed: _controller.isSubmitting
                      ? null
                      : () => _controller.checkInAndAssign(
                            guestId: widget.guestId,
                            scanForTag: () => widget.nfcService
                                .scanPlayerTagForAssignment(context),
                          ),
                  child: Text(
                    _controller.isSubmitting
                        ? 'Saving...'
                        : 'Check In and Assign Tag',
                  ),
                ),
              if (guest.isCheckedIn && assignment == null)
                FilledButton(
                  onPressed: _controller.isSubmitting
                      ? null
                      : () => _controller.assignTag(
                            guestId: widget.guestId,
                            scanForTag: () => widget.nfcService
                                .scanPlayerTagForAssignment(context),
                          ),
                  child: Text(
                    _controller.isSubmitting ? 'Saving...' : 'Assign Tag',
                  ),
                ),
              if (assignment != null)
                FilledButton(
                  onPressed: _controller.isSubmitting
                      ? null
                      : () => _controller.replaceTag(
                            guestId: widget.guestId,
                            scanForTag: () => widget.nfcService
                                .scanPlayerTagForAssignment(context),
                          ),
                  child: Text(
                    _controller.isSubmitting ? 'Saving...' : 'Replace Tag',
                  ),
                ),
            ],
            if (_controller.actionError != null) ...[
              const SizedBox(height: 12),
              Text(_controller.actionError!),
            ],
          ],
        ),
      ),
    );
  }
}
