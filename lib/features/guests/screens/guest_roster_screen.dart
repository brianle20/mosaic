import 'package:flutter/material.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/checkin/models/cover_entry_form_draft.dart';
import 'package:mosaic/features/checkin/screens/add_cover_entry_screen.dart';
import 'package:mosaic/features/guests/controllers/guest_roster_controller.dart';
import 'package:mosaic/features/guests/widgets/guest_quick_action_bar.dart';
import 'package:mosaic/services/nfc/nfc_service.dart';
import 'package:mosaic/widgets/empty_state_card.dart';
import 'package:mosaic/widgets/status_chip.dart';

enum _GuestRosterOverflowAction {
  markPaidManually,
}

const _guestCardSectionGap = 10.0;

class GuestRosterScreen extends StatefulWidget {
  const GuestRosterScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.eventCoverChargeCents,
    required this.guestRepository,
    required this.nfcService,
  });

  final String eventId;
  final String eventTitle;
  final int eventCoverChargeCents;
  final GuestRepository guestRepository;
  final NfcService nfcService;

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
        defaultCoverAmountCents: widget.eventCoverChargeCents,
      ),
    );
    if (!mounted) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    await _controller.load(widget.eventId);
  }

  Future<void> _markPaid(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.markPaid(guest.id),
      successMessage: '${guest.displayName} is now marked paid.',
    );
  }

  Future<void> _markComped(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.markComped(guest.id),
      successMessage: '${guest.displayName} is now marked comped.',
    );
  }

  Future<void> _checkInAndAssign(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.checkInAndAssign(
        guestId: guest.id,
        scanForTag: () => widget.nfcService.scanPlayerTagForAssignment(context),
      ),
      successMessage: '${guest.displayName} is checked in and tagged.',
    );
  }

  Future<void> _assignTag(EventGuestRecord guest) async {
    await _runQuickAction(
      () => _controller.assignTag(
        guestId: guest.id,
        scanForTag: () => widget.nfcService.scanPlayerTagForAssignment(context),
      ),
      successMessage: 'Player tag assigned to ${guest.displayName}.',
    );
  }

  Future<void> _addCoverEntry(EventGuestRecord guest) async {
    final submission = await Navigator.of(context).push<SubmitCoverEntryInput>(
      MaterialPageRoute(
        builder: (_) => const AddCoverEntryScreen(),
      ),
    );
    if (submission == null) {
      return;
    }

    await _runQuickAction(
      () => _controller.recordCoverEntry(
        guestId: guest.id,
        input: submission,
      ),
      successMessage: 'Cover entry saved for ${guest.displayName}.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runQuickAction(
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    try {
      final didComplete = await action();
      if (!mounted) {
        return;
      }
      if (!didComplete) {
        return;
      }
      _showMessage(successMessage);
    } catch (exception) {
      if (!mounted) {
        return;
      }
      _showMessage(_formatActionError(exception));
    }
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
                child: InkWell(
                  key: ValueKey('guest-row-${guest.id}'),
                  onTap: () => _openGuestDetail(guest),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                guest.displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            if (!guest.isEligibleForPlayerTagAssignment)
                              _buildOverflowMenu(guest),
                          ],
                        ),
                        const SizedBox(height: _guestCardSectionGap),
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
                        const SizedBox(height: _guestCardSectionGap),
                        Text(
                          _rowSummary(guest),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: _guestCardSectionGap),
                        _buildQuickActionsForGuest(guest),
                      ],
                    ),
                  ),
                ),
              ),
            if (_controller.guests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyStateCard(
                  icon: Icons.people_outline,
                  title: 'No guests yet',
                  message:
                      'Add guests to start check-in, tag assignment, and live seating.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _quickActionsForGuest(EventGuestRecord guest) {
    final hasTag = _controller.activeTagAssignments.containsKey(guest.id);
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    final actions = <Widget>[];

    if (!guest.isCheckedIn) {
      actions.add(
        FilledButton(
          onPressed: isSubmitting ? null : () => _checkInAndAssign(guest),
          child: const Text('Check In & Tag'),
        ),
      );
    } else if (!hasTag) {
      actions.add(
        FilledButton(
          onPressed: isSubmitting ? null : () => _assignTag(guest),
          child: const Text('Assign Tag'),
        ),
      );
    }

    if (guest.isEligibleForPlayerTagAssignment) {
      actions.add(
        TextButton(
          onPressed: isSubmitting ? null : () => _addCoverEntry(guest),
          child: const Text('Add Cover Entry'),
        ),
      );
    }

    return actions;
  }

  Widget _buildQuickActionsForGuest(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    if (!guest.isEligibleForPlayerTagAssignment) {
      return Row(
        children: [
          Expanded(
            flex: 5,
            child: FilledButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting ? null : () => _addCoverEntry(guest),
              child: _singleLineButtonLabel('Add Cover Entry'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: OutlinedButton(
              style: _compactActionButtonStyle(),
              onPressed: isSubmitting ? null : () => _markComped(guest),
              child: _singleLineButtonLabel('Mark Comped'),
            ),
          ),
        ],
      );
    }

    return GuestQuickActionBar(
      children: _quickActionsForGuest(guest),
    );
  }

  Widget _buildOverflowMenu(EventGuestRecord guest) {
    final isSubmitting = _controller.isSubmittingGuest(guest.id);
    return SizedBox.square(
      dimension: 32,
      child: PopupMenuButton<_GuestRosterOverflowAction>(
        enabled: !isSubmitting,
        padding: EdgeInsets.zero,
        iconSize: 20,
        splashRadius: 18,
        tooltip: 'More actions for ${guest.displayName}',
        onSelected: (action) {
          switch (action) {
            case _GuestRosterOverflowAction.markPaidManually:
              _markPaid(guest);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _GuestRosterOverflowAction.markPaidManually,
            child: Text('Mark Paid Manually'),
          ),
        ],
        icon: const Icon(Icons.more_horiz),
      ),
    );
  }

  ButtonStyle _compactActionButtonStyle() {
    return ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(0, 44)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _singleLineButtonLabel(String label) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
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

  String _formatActionError(Object exception) {
    final message = exception.toString();
    const prefix = 'Bad state: ';
    if (message.startsWith(prefix)) {
      return message.substring(prefix.length);
    }
    return message;
  }
}
