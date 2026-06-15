import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/controllers/guest_check_in_controller.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/features/guests/screens/guest_form_screen.dart';
import 'package:mosaic/widgets/status_chip.dart';

class GuestDetailScreen extends StatefulWidget {
  const GuestDetailScreen({
    super.key,
    required this.guestId,
    required this.eventId,
    this.canCheckIn = true,
    this.canManageGuests = true,
    this.canManageCover = true,
    required this.guestRepository,
  });

  final String guestId;
  final String eventId;
  final bool canCheckIn;
  final bool canManageGuests;
  final bool canManageCover;
  final GuestRepository guestRepository;

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
    if (!widget.canManageCover) {
      return;
    }
    final detail = _controller.detail;
    final submission = await Navigator.of(context).push<SubmitCoverEntryInput>(
      MaterialPageRoute(
        builder: (_) => AddCoverEntryScreen(
          initialAmountCents: detail == null
              ? 0
              : suggestedCoverEntryAmountCents(
                  guest: detail.guest,
                  coverEntries: detail.coverEntries,
                ),
        ),
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

  Future<void> _openEditCoverEntry(GuestCoverEntryRecord entry) async {
    if (!widget.canManageCover) {
      return;
    }
    final submission = await Navigator.of(context).push<SubmitCoverEntryInput>(
      MaterialPageRoute(
        builder: (_) => AddCoverEntryScreen(
          title: 'Edit Cover Entry',
          submitButtonLabel: 'Save Changes',
          initialAmountCents: entry.amountCents.abs(),
          initialMethod: entry.method,
          initialTransactionOn: entry.transactionOn,
          initialNote: entry.note,
        ),
      ),
    );
    if (submission == null) {
      return;
    }

    await _controller.updateCoverEntry(
      guestId: widget.guestId,
      coverEntryId: entry.id,
      input: submission,
    );
  }

  Future<void> _confirmDeleteCoverEntry(GuestCoverEntryRecord entry) async {
    if (!widget.canManageCover) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete cover entry?'),
        content: Text(
          'Delete ${_coverEntrySummary(entry)} from the ledger?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
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

    await _controller.deleteCoverEntry(
      guestId: widget.guestId,
      coverEntryId: entry.id,
    );
  }

  Future<void> _openEditGuest(EventGuestRecord guest) async {
    if (!widget.canManageGuests) {
      return;
    }
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

    return Scaffold(
      appBar: AppBar(
        title: Text(guest?.displayName ?? 'Guest'),
        actions: [
          if (guest != null && widget.canManageGuests)
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
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cover Ledger',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (widget.canManageCover)
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
                    trailing: widget.canManageCover
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit cover entry',
                                onPressed: _controller.isSubmitting
                                    ? null
                                    : () => _openEditCoverEntry(entry),
                                icon: const Icon(Icons.edit),
                              ),
                              IconButton(
                                tooltip: 'Delete cover entry',
                                onPressed: _controller.isSubmitting
                                    ? null
                                    : () => _confirmDeleteCoverEntry(entry),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          )
                        : null,
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
                        'Mark this guest paid or comped before check-in.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Update the cover status, then return here to continue check-in.',
                      ),
                    ],
                  ),
                ),
              ),
            if (guest != null &&
                guest.isEligibleForPlayerTagAssignment &&
                !guest.isCheckedIn &&
                widget.canCheckIn &&
                guest.tournamentStatus != EventTournamentStatus.withdrawn)
              FilledButton(
                onPressed: _controller.isSubmitting
                    ? null
                    : () => _controller.checkIn(
                          guestId: widget.guestId,
                        ),
                child: Text(
                  _controller.isSubmitting
                      ? 'Saving...'
                      : _checkInLabel(guest.tournamentStatus),
                ),
              ),
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

  String _checkInLabel(EventTournamentStatus status) {
    return switch (status) {
      EventTournamentStatus.qualified => 'Check In: Prequalified',
      EventTournamentStatus.qualifying => 'Check In: Considered',
      EventTournamentStatus.openPlayOnly => 'Check In: Not Playing Tournament',
      EventTournamentStatus.withdrawn => 'Check In',
    };
  }
}
