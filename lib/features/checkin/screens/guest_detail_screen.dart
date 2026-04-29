import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/controllers/guest_check_in_controller.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/status_chip.dart';

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

  Future<void> _openAddCoverEntry() async {
    final submission = await Navigator.of(context).push<SubmitCoverEntryInput>(
      MaterialPageRoute(
        builder: (_) => const AddCoverEntryScreen(),
      ),
    );
    if (submission == null) {
      return;
    }

    await _controller.recordCoverEntry(
      guestId: widget.guestId,
      input: submission,
    );
  }

  Future<void> _openEditGuest(EventGuestRecord guest) async {
    var existingGuests = await widget.guestRepository.readCachedGuests(
      widget.eventId,
    );
    if (existingGuests.isEmpty) {
      existingGuests = await widget.guestRepository.listGuests(widget.eventId);
    }
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<EventGuestRecord>(
      MaterialPageRoute(
        builder: (_) => GuestFormScreen(
          eventId: widget.eventId,
          existingGuests: existingGuests,
          initialGuest: guest,
          defaultCoverAmountCents: guest.coverAmountCents,
          guestRepository: widget.guestRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }

    await _controller.load(widget.guestId);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _controller.detail;
    final guest = detail?.guest;
    final assignment = detail?.activeTagAssignment;

    return Scaffold(
      appBar: AppBar(
        title: Text(guest?.displayName ?? 'Guest'),
        actions: [
          if (guest != null)
            TextButton(
              onPressed:
                  _controller.isSubmitting ? null : () => _openEditGuest(guest),
              child: const Text('Edit'),
            ),
        ],
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
            Text(
              'Attendance Status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: guest == null
                  ? 'Expected'
                  : _attendanceLabel(guest.attendanceStatus),
              tone: guest?.isCheckedIn == true
                  ? StatusChipTone.success
                  : StatusChipTone.neutral,
            ),
            const SizedBox(height: 12),
            Text(
              'Cover Status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: guest == null
                  ? 'Unpaid'
                  : _coverStatusLabel(guest.coverStatus),
              tone: guest == null
                  ? StatusChipTone.neutral
                  : _coverStatusTone(guest.coverStatus),
            ),
            const SizedBox(height: 12),
            Text(
              'Player Tag',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            StatusChip(
              label: assignment == null ? 'Tag Unassigned' : 'Tag Assigned',
              tone: assignment == null
                  ? StatusChipTone.warning
                  : StatusChipTone.success,
            ),
            if (assignment?.tag.displayLabel != null) ...[
              const SizedBox(height: 8),
              Text(assignment!.tag.displayLabel!),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cover Ledger',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed:
                      _controller.isSubmitting ? null : _openAddCoverEntry,
                  child: const Text('Add Cover Entry'),
                ),
              ],
            ),
            if (detail != null && detail.coverEntries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No cover entries recorded yet.'),
                ),
              ),
            if (detail != null && detail.coverEntries.isNotEmpty)
              ...detail.coverEntries.map(
                (entry) => Card(
                  child: ListTile(
                    title: Text(_coverEntrySummary(entry)),
                    subtitle: entry.note == null ? null : Text(entry.note!),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (guest != null && !guest.isEligibleForPlayerTagAssignment)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mark this guest paid or comped before assigning a player tag.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Update the cover status, then return here to continue check-in.',
                      ),
                    ],
                  ),
                ),
              ),
            if (guest != null && guest.isEligibleForPlayerTagAssignment) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  assignment == null
                      ? (guest.isCheckedIn
                          ? 'This guest is ready for a player tag.'
                          : 'This guest is ready to check in and receive a player tag.')
                      : 'This guest already has a player tag. Replace it only if needed.',
                ),
              ),
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

  String _coverEntrySummary(GuestCoverEntryRecord entry) {
    final methodLabel = switch (entry.method) {
      CoverEntryMethod.cash => 'Cash',
      CoverEntryMethod.venmo => 'Venmo',
      CoverEntryMethod.zelle => 'Zelle',
      CoverEntryMethod.other => 'Other',
      CoverEntryMethod.comp => 'Comp',
      CoverEntryMethod.refund => 'Refund',
    };
    return '$methodLabel \$${_formatMoneyCents(entry.amountCents)} - '
        '${_formatDate(entry.transactionOn)}';
  }

  String _formatMoneyCents(int cents) {
    final absoluteCents = cents.abs();
    final formatted =
        '${absoluteCents ~/ 100}.${(absoluteCents % 100).toString().padLeft(2, '0')}';
    return cents < 0 ? '-$formatted' : formatted;
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
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
}
