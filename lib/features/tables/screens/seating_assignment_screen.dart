import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mosaic/core/routing/app_router.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/event_models.dart';
import 'package:mosaic/data/models/guest_models.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/data/offline/offline_recovery_scope.dart';
import 'package:mosaic/features/tables/controllers/seating_assignment_controller.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class SeatingAssignmentScreen extends StatefulWidget {
  const SeatingAssignmentScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.seatingRepository,
    required this.guestRepository,
    required this.sessionRepository,
    this.initialAssignments = const [],
    this.bonusTableRoleFilter,
    this.showUnassignedGuests = true,
  });

  final String eventId;
  final String eventTitle;
  final SeatingRepository seatingRepository;
  final GuestRepository guestRepository;
  final SessionRepository sessionRepository;
  final List<SeatingAssignmentRecord> initialAssignments;
  final BonusTableRole? bonusTableRoleFilter;
  final bool showUnassignedGuests;

  @override
  State<SeatingAssignmentScreen> createState() =>
      _SeatingAssignmentScreenState();
}

class _SeatingAssignmentScreenState extends State<SeatingAssignmentScreen> {
  late final SeatingAssignmentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SeatingAssignmentController(
      seatingRepository: widget.seatingRepository,
      guestRepository: widget.guestRepository,
      sessionRepository: widget.sessionRepository,
      initialAssignments: widget.initialAssignments,
      bonusTableRoleFilter: widget.bonusTableRoleFilter,
      showUnassignedGuests: widget.showUnassignedGuests,
    )
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

  Future<void> _copySeatingAssignments() async {
    final tableGroups = _controller.tableGroups;
    final publicNamesByGuestId = {
      for (final guest in _controller.eligibleGuests)
        guest.id: guest.publicName,
    };
    final missingPublicName = tableGroups.any(
      (group) => group.seats.any(
        (seat) => !publicNamesByGuestId.containsKey(seat.eventGuestId),
      ),
    );

    if (missingPublicName) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Public names are still loading.')),
        );
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: _formatSeatingAssignmentsForClipboard(
          tableGroups,
          publicNamesByGuestId: publicNamesByGuestId,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Seating copied.')));
  }

  Future<void> _startAllTables() async {
    await _controller.startAllTables(widget.eventId);
    if (!mounted || _controller.error != null || !_controller.hasLiveSessions) {
      return;
    }

    await Navigator.of(context).pushReplacementNamed(
      AppRouter.tablesOverviewRoute,
      arguments: TablesOverviewArgs(
        eventId: widget.eventId,
        eventTitle: widget.eventTitle,
        scoringOpen: true,
        scoringPhase: _currentSeatingScoringPhase,
      ),
    );
  }

  Future<void> _openFinalsTables() {
    return Navigator.of(context).pushReplacementNamed(
      AppRouter.tablesOverviewRoute,
      arguments: TablesOverviewArgs(
        eventId: widget.eventId,
        eventTitle: widget.eventTitle,
        scoringOpen: true,
        scoringPhase: EventScoringPhase.bonus,
      ),
    );
  }

  EventScoringPhase get _currentSeatingScoringPhase {
    final assignments = _controller.assignments;
    if (assignments.isNotEmpty &&
        assignments.every(
          (assignment) =>
              assignment.assignmentType == SeatingAssignmentType.bonus,
        )) {
      return EventScoringPhase.bonus;
    }
    return EventScoringPhase.tournament;
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignments = _controller.assignments.isNotEmpty;

    return ReconnectRefreshListener(
      onRefresh: () => _controller.load(widget.eventId, silent: true),
      child: Scaffold(
        appBar: AppBar(title: const Text('Seating')),
        body: AsyncBody(
          isLoading: _controller.isLoading,
          error: _controller.error != null && !hasAssignments
              ? _controller.error
              : null,
          onRetry: () => _controller.load(widget.eventId),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_controller.error != null && hasAssignments) ...[
                InlineErrorBanner(message: _controller.error!),
                const SizedBox(height: 12),
              ],
              if (hasAssignments) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copySeatingAssignments,
                    icon: const Icon(Icons.content_copy),
                    label: const Text('Copy Seating'),
                  ),
                ),
                const SizedBox(height: 12),
                if (_controller.isBonusSeating) ...[
                  const InfoPanel(
                    message:
                        'Review Finals seating, then open Finals Tables for the current status and next action.',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openFinalsTables,
                      icon: const Icon(Icons.table_restaurant),
                      label: const Text('Open Finals Tables'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (_controller.canStartAllTables ||
                    _controller.isSubmitting) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _controller.isSubmitting ? null : _startAllTables,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _controller.isSubmitting
                            ? 'Starting Tables...'
                            : _controller.startAllTablesLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              if (!hasAssignments)
                const EmptyStateCard(
                  icon: Icons.event_seat,
                  title: 'No seating yet',
                  message:
                      'Round seating appears after starting a tournament round.',
                )
              else
                for (final group in _controller.tableGroups) ...[
                  _TableSeatingCard(group: group),
                  const SizedBox(height: 12),
                ],
              if (hasAssignments &&
                  _controller.unassignedGuests.isNotEmpty) ...[
                _UnassignedGuestsCard(guests: _controller.unassignedGuests),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnassignedGuestsCard extends StatelessWidget {
  const _UnassignedGuestsCard({required this.guests});

  final List<EventGuestRecord> guests;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unassigned',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final guest in guests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(guest.displayName),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableSeatingCard extends StatelessWidget {
  const _TableSeatingCard({required this.group});

  final SeatingTableGroup group;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group.tableLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            for (final seat in group.seats)
              _SeatRow(
                windLabel: _windLabel(seat.seatIndex),
                assignment: seat,
              ),
          ],
        ),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.windLabel,
    required this.assignment,
  });

  final String windLabel;
  final SeatingAssignmentRecord assignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              windLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(assignment.displayName)),
        ],
      ),
    );
  }
}

String _windLabel(int seatIndex) {
  return switch (seatIndex) {
    0 => 'East',
    1 => 'South',
    2 => 'West',
    3 => 'North',
    _ => 'Seat ${seatIndex + 1}',
  };
}

String _formatSeatingAssignmentsForClipboard(
  List<SeatingTableGroup> groups, {
  Map<String, String> publicNamesByGuestId = const {},
}) {
  return groups.map((group) {
    final lines = [
      group.tableLabel,
      for (final seat in group.seats)
        '${_windLabel(seat.seatIndex)}: '
            '${publicNamesByGuestId[seat.eventGuestId]!}',
    ];
    return lines.join('\n');
  }).join('\n\n');
}
