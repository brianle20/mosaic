import 'package:flutter/material.dart';
import 'package:mosaic/core/widgets/async_body.dart';
import 'package:mosaic/data/models/seating_assignment_models.dart';
import 'package:mosaic/data/repositories/repository_interfaces.dart';
import 'package:mosaic/features/tables/controllers/seating_assignment_controller.dart';
import 'package:mosaic/widgets/app_surfaces.dart';
import 'package:mosaic/widgets/empty_state_card.dart';

class SeatingAssignmentScreen extends StatefulWidget {
  const SeatingAssignmentScreen({
    super.key,
    required this.eventId,
    required this.seatingRepository,
  });

  final String eventId;
  final SeatingRepository seatingRepository;

  @override
  State<SeatingAssignmentScreen> createState() =>
      _SeatingAssignmentScreenState();
}

class _SeatingAssignmentScreenState extends State<SeatingAssignmentScreen> {
  late final SeatingAssignmentController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SeatingAssignmentController(widget.seatingRepository)
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

  Future<void> _generateSeating() async {
    if (_controller.assignments.isNotEmpty) {
      final confirmed = await _confirmAction(
        title: 'Regenerate Seating',
        message: 'This will replace the current seating assignments.',
        confirmLabel: 'Regenerate',
      );
      if (!confirmed) {
        return;
      }
    }

    await _controller.generate(widget.eventId);
  }

  Future<void> _clearSeating() async {
    final confirmed = await _confirmAction(
      title: 'Clear Seating',
      message: 'This will remove the current seating assignments.',
      confirmLabel: 'Clear',
    );
    if (!confirmed) {
      return;
    }

    await _controller.clear(widget.eventId);
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final hasAssignments = _controller.assignments.isNotEmpty;

    return Scaffold(
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
            if (!hasAssignments)
              const EmptyStateCard(
                icon: Icons.event_seat,
                title: 'No seating yet',
                message: 'Generate random seating for checked-in players.',
              )
            else
              for (final group in _controller.tableGroups) ...[
                _TableSeatingCard(group: group),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _controller.isSubmitting ? null : _generateSeating,
              child: Text(
                _controller.isSubmitting ? 'Working' : 'Generate Seating',
              ),
            ),
            if (hasAssignments) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _controller.isSubmitting ? null : _clearSeating,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Clear Assignments'),
              ),
            ],
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
